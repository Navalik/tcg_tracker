import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../db/canonical_catalog_store.dart';
import '../domain/domain_models.dart';
import 'local_backup_service.dart';
import 'pokemon_dataset_manifest.dart';

class PokemonBulkService {
  PokemonBulkService._();

  static final PokemonBulkService instance = PokemonBulkService._();

  static const String datasetVersion = PokemonDatasetManifest.version;
  static const String _prefsKeyInstalledVersion = 'pokemon_dataset_version';
  static const String _prefsKeyInstalledSource = 'pokemon_dataset_source';
  static const String _prefsKeyInstalledAt = 'pokemon_dataset_installed_at';
  static const String _prefsKeyManifestFingerprint =
      'pokemon_dataset_manifest_fingerprint';
  static const String _prefsKeyInstalledSourceRepo =
      'pokemon_dataset_source_repo';
  static const String _prefsKeyInstalledSourceRef =
      'pokemon_dataset_source_ref';
  static const String _prefsKeyInstalledSourceCommit =
      'pokemon_dataset_source_commit';
  static const String _prefsKeyInstalledProfile =
      'pokemon_dataset_profile_installed';
  static const String _prefsKeyInstalledLanguages =
      'pokemon_dataset_languages_installed';
  static const String _prefsKeyLastError = 'pokemon_dataset_last_error';
  static const String _prefsKeyLastErrorStage =
      'pokemon_dataset_last_error_stage';
  static const String _prefsKeyLastErrorDetail =
      'pokemon_dataset_last_error_detail';
  static const int _maxAttemptsPerPage = 4;
  static const String _canonicalSnapshotFileName =
      'canonical_catalog_snapshot.json';
  static const int _canonicalSnapshotSchemaVersion = 2;
  static const int _hostedBundleCompatibilityVersion = 2;
  static const String _firebaseCatalogBucket =
      'bindervault.firebasestorage.app';
  static const String _firebaseCatalogObjectPrefix = 'catalog/pokemon/';
  static const String _hostedBundleManifestUrl =
      'https://firebasestorage.googleapis.com/v0/b/$_firebaseCatalogBucket/o/catalog%2Fpokemon%2Flatest%2Fmanifest.json?alt=media';
  static const String _hostedCanonicalSnapshotAssetName =
      'canonical_catalog_snapshot.json.gz';
  static const String _fixedProfile = 'full';
  static const int _minFullProfileCards = 10000;
  File? _lastAutomaticCollectionsBackupFile;

  File? get lastAutomaticCollectionsBackupFile =>
      _lastAutomaticCollectionsBackupFile;

  Future<bool> isInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString(_prefsKeyInstalledVersion);
    final installedProfile = prefs.getString(_prefsKeyInstalledProfile);
    final installedLanguages =
        prefs.getString(_prefsKeyInstalledLanguages) ?? 'en';
    final selectedLanguages = await _selectedPokemonLanguageSignature();
    final count = await ScryfallDatabase.instance.countCards();
    final canonicalInstalled = await _hasCanonicalPokemonCatalog();
    return installedVersion == datasetVersion &&
        installedProfile == _fixedProfile &&
        installedLanguages == selectedLanguages &&
        count > 0 &&
        canonicalInstalled;
  }

  Future<PokemonDatasetUpdateStatus> checkForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString(_prefsKeyInstalledVersion);
    final installedFingerprint = prefs.getString(_prefsKeyManifestFingerprint);
    final installedSourceRepo = prefs.getString(_prefsKeyInstalledSourceRepo);
    final installedSourceRef = prefs.getString(_prefsKeyInstalledSourceRef);
    final installedSourceCommit = prefs.getString(
      _prefsKeyInstalledSourceCommit,
    );
    final selectedLanguages = await _selectedPokemonLanguageSignature();
    final installedProfile = prefs.getString(_prefsKeyInstalledProfile);
    final installedLanguages = prefs.getString(_prefsKeyInstalledLanguages);
    final count = await ScryfallDatabase.instance.countCards();
    final installed =
        installedVersion == datasetVersion &&
        installedProfile == _fixedProfile &&
        installedLanguages == selectedLanguages &&
        count > 0;
    if (!installed) {
      return const PokemonDatasetUpdateStatus(
        installed: false,
        updateAvailable: false,
      );
    }
    final remoteManifest = await _fetchHostedManifestInfo();
    final remoteFingerprint = remoteManifest?.fingerprint;
    if (remoteFingerprint == null || remoteFingerprint.isEmpty) {
      return PokemonDatasetUpdateStatus(
        installed: true,
        updateAvailable: false,
        installedFingerprint: installedFingerprint,
        installedSourceRepo: installedSourceRepo,
        installedSourceRef: installedSourceRef,
        installedSourceCommit: installedSourceCommit,
      );
    }
    final updateAvailable =
        installedFingerprint == null ||
        installedFingerprint.isEmpty ||
        remoteFingerprint != installedFingerprint;
    return PokemonDatasetUpdateStatus(
      installed: true,
      updateAvailable: updateAvailable,
      installedFingerprint: installedFingerprint,
      remoteFingerprint: remoteFingerprint,
      installedSourceRepo: installedSourceRepo,
      installedSourceRef: installedSourceRef,
      installedSourceCommit: installedSourceCommit,
      remoteSourceRepo: remoteManifest?.sourceRepo,
      remoteSourceRef: remoteManifest?.sourceRef,
      remoteSourceCommit: remoteManifest?.sourceCommit,
    );
  }

  Future<void> ensureInstalled({
    required void Function(double progress) onProgress,
  }) async {
    if (await isInstalled()) {
      onProgress(1);
      return;
    }
    await installDataset(onProgress: onProgress);
  }

  Future<void> clearLocalDatasetArtifacts() async {
    _lastAutomaticCollectionsBackupFile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyInstalledVersion);
    await prefs.remove(_prefsKeyInstalledSource);
    await prefs.remove(_prefsKeyInstalledAt);
    await prefs.remove(_prefsKeyManifestFingerprint);
    await prefs.remove(_prefsKeyInstalledSourceRepo);
    await prefs.remove(_prefsKeyInstalledSourceRef);
    await prefs.remove(_prefsKeyInstalledSourceCommit);
    await prefs.remove(_prefsKeyInstalledProfile);
    await prefs.remove(_prefsKeyInstalledLanguages);
    await _clearHostedBundleDiagnostic();
    final appDir = await getApplicationDocumentsDirectory();
    final datasetDir = Directory(p.join(appDir.path, 'pokemon', 'datasets'));
    if (await datasetDir.exists()) {
      await datasetDir.delete(recursive: true);
    }
    final canonicalDb = File(
      p.join(appDir.path, CanonicalCatalogStore.defaultFileName),
    );
    if (await canonicalDb.exists()) {
      await canonicalDb.delete();
    }
  }

  Future<void> installDataset({
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
    bool allowLanguageDeltaFromCache = false,
  }) async {
    await _clearHostedBundleDiagnostic();
    final selectedCanonicalLanguages =
        await _selectedPokemonCanonicalLanguages();
    final selectedLanguageSignature = await _selectedPokemonLanguageSignature();
    final languageLabel =
        selectedCanonicalLanguages
            .map((language) => language.toUpperCase())
            .toList(growable: false)
          ..sort();
    final totalStopwatch = Stopwatch()..start();
    final canonicalDownloadStopwatch = Stopwatch()..start();
    onStatus?.call(
      'Downloading Pokemon bundle (Firebase, profile=${_fixedProfile.toUpperCase()}, lang=${languageLabel.join(",")})',
    );
    onProgress(0.01);
    final canonicalBatch = await _downloadCanonicalCatalogSnapshot(
      profile: _fixedProfile,
      languages: selectedCanonicalLanguages,
      languageSignature: selectedLanguageSignature,
      allowUseExistingSnapshot: allowLanguageDeltaFromCache,
      onProgress: (progress) {
        final scaled = 0.01 + (progress.clamp(0.0, 1.0) * 0.54);
        onProgress(scaled);
      },
      onStatus: onStatus,
    );
    canonicalDownloadStopwatch.stop();

    final canonicalImportStopwatch = Stopwatch()..start();
    onStatus?.call('Importing local Pokemon catalog');
    onProgress(0.57);
    await _importCanonicalCatalogBatch(
      canonicalBatch,
      onStatus: onStatus,
      onProgress: (progress) {
        final scaled = 0.57 + (progress.clamp(0.0, 1.0) * 0.11);
        onProgress(scaled);
      },
    );
    canonicalImportStopwatch.stop();

    final database = await ScryfallDatabase.instance.open();
    onProgress(0.70);
    late final int inserted;
    final datasetDir = await _ensureDatasetDirectory();
    await _clearDatasetJsonCacheDirectory(datasetDir);
    onStatus?.call('Building legacy compatibility dataset');
    onProgress(0.72);
    final legacyBuildStopwatch = Stopwatch()..start();
    inserted = await _installFromCanonicalBatch(
      database: database,
      batch: canonicalBatch,
      languages: selectedCanonicalLanguages,
      onProgress: onProgress,
      progressStart: 0.74,
      progressEnd: 0.90,
    );
    if (inserted < _minFullProfileCards) {
      throw HttpException('pokemon_hosted_bundle_incomplete:$inserted');
    }
    legacyBuildStopwatch.stop();

    final finalizeStopwatch = Stopwatch()..start();
    onStatus?.call('Finalizing local database');
    onProgress(0.93);
    await ScryfallDatabase.instance.rebuildPrintedNameSearchIndex();
    onProgress(0.95);
    await database.rebuildFts();
    onProgress(0.97);
    onProgress(0.99);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyInstalledVersion, datasetVersion);
    await prefs.setString(_prefsKeyInstalledSource, 'firebase_catalog_bundle');
    await prefs.setInt(
      _prefsKeyInstalledAt,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await prefs.setString(_prefsKeyInstalledProfile, _fixedProfile);
    await prefs.setString(
      _prefsKeyInstalledLanguages,
      selectedLanguageSignature,
    );
    final remoteManifest = await _fetchHostedManifestInfo();
    final remoteFingerprint = remoteManifest?.fingerprint;
    if (remoteFingerprint != null && remoteFingerprint.isNotEmpty) {
      await prefs.setString(_prefsKeyManifestFingerprint, remoteFingerprint);
    }
    if (remoteManifest != null) {
      await _saveInstalledSourceMetadata(
        prefs,
        repo: remoteManifest.sourceRepo,
        ref: remoteManifest.sourceRef,
        commit: remoteManifest.sourceCommit,
      );
    }
    await _clearHostedBundleDiagnostic();
    finalizeStopwatch.stop();
    totalStopwatch.stop();
    onStatus?.call('Completed ($inserted cards)');
    onProgress(1);
  }

  Future<bool> _hasCanonicalPokemonCatalog() async {
    final store = await CanonicalCatalogStore.openDefault();
    try {
      return store.countTableRows('card_printings') > 0 &&
          store.countTableRows('catalog_cards') > 0;
    } finally {
      store.dispose();
    }
  }

  Future<CanonicalCatalogImportBatch> _downloadCanonicalCatalogSnapshot({
    required String profile,
    required List<String> languages,
    required String languageSignature,
    required bool allowUseExistingSnapshot,
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    final normalizedProfile = profile.trim().toLowerCase();
    final requestedLanguageCodes = languages
        .map((language) => language.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    final snapshot = await _readCanonicalSnapshotPayload();
    if (allowUseExistingSnapshot &&
        snapshot != null &&
        snapshot.schemaVersion >= _canonicalSnapshotSchemaVersion &&
        _isSupportedHostedCompatibilityVersion(snapshot.compatibilityVersion) &&
        snapshot.profile == normalizedProfile &&
        snapshot.batch.cards.isNotEmpty &&
        snapshot.batch.printings.isNotEmpty) {
      final existingLanguageCodes = _languageCodeSetFromSignature(
        snapshot.languageSignature,
      );
      final missingCodes = requestedLanguageCodes.difference(
        existingLanguageCodes,
      );
      if (missingCodes.isEmpty) {
        onStatus?.call('Using cached Pokemon catalog snapshot');
        onProgress(1);
        if (snapshot.languageSignature != languageSignature) {
          await _writeCanonicalCatalogSnapshot(
            snapshot.batch,
            profile: normalizedProfile,
            languageSignature: languageSignature,
          );
        }
        return snapshot.batch;
      }
      final missingLanguages = missingCodes.toList(growable: false);
      if (missingLanguages.isNotEmpty) {
        final hostedDeltaBatch = await _tryDownloadHostedCanonicalSnapshot(
          profile: normalizedProfile,
          expectedLanguageSignature: languageSignature,
          onProgress: onProgress,
          onStatus: onStatus,
        );
        if (hostedDeltaBatch != null) {
          return hostedDeltaBatch;
        }
        throw HttpException(
          'pokemon_hosted_bundle_missing_languages:${missingCodes.join(",")}',
        );
      }
    }

    final hostedBatch = await _tryDownloadHostedCanonicalSnapshot(
      profile: normalizedProfile,
      expectedLanguageSignature: languageSignature,
      onProgress: onProgress,
      onStatus: onStatus,
    );
    if (hostedBatch != null) {
      return hostedBatch;
    }
    throw HttpException('pokemon_hosted_bundle_unavailable:$languageSignature');
  }

  Future<CanonicalCatalogImportBatch?> _tryDownloadHostedCanonicalSnapshot({
    required String profile,
    required String expectedLanguageSignature,
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    if (!_isAllowedDownloadUri(_hostedBundleManifestUrl)) {
      return null;
    }
    final client = http.Client();
    var stage = 'manifest_fetch';
    try {
      onStatus?.call('Checking hosted Pokemon bundle');
      onProgress(0.05);
      final manifestRaw = await _fetchJsonWithRetry(
        client: client,
        uri: Uri.parse(_hostedBundleManifestUrl),
        retryAttempts: 2,
        requestTimeout: const Duration(seconds: 20),
      );
      stage = 'manifest_parse';
      final manifestParsed = jsonDecode(manifestRaw);
      if (manifestParsed is! Map<String, dynamic>) {
        return null;
      }
      final manifestCompatibilityVersion =
          (manifestParsed['compatibility_version'] as num?)?.toInt() ?? 1;
      if (!_isSupportedHostedCompatibilityVersion(
        manifestCompatibilityVersion,
      )) {
        return null;
      }
      final requiredLanguages = _languageCodeSetFromSignature(
        expectedLanguageSignature,
      );

      final bundles =
          (manifestParsed['bundles'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList(growable: false);
      if (bundles.isNotEmpty) {
        // Hosted bundle releases are the authoritative source for the
        // intermediate Pokemon flow. Ignore local snapshots here so we do not
        // accidentally merge a fresh GitHub base with an older/incomplete
        // distribution-derived snapshot.
        const existingLanguages = <String>{};
        final selectedBundles = _selectHostedBundlesForMissingLanguages(
          bundles: bundles,
          profile: profile,
          requiredLanguages: requiredLanguages,
          existingLanguages: existingLanguages,
        );
        if (selectedBundles == null) {
          return null;
        }
        CanonicalCatalogImportBatch? mergedBatch;
        final downloadedLanguages = <String>{};
        for (var i = 0; i < selectedBundles.length; i++) {
          final bundle = selectedBundles[i];
          final bundleId =
              ((bundle['id'] as String?)?.trim().toLowerCase() ?? '').isEmpty
              ? 'bundle_$i'
              : (bundle['id'] as String).trim().toLowerCase();
          final assetUri = _resolveCanonicalSnapshotAssetUriFromBundle(bundle);
          if (assetUri == null || !_isAllowedDownloadUri(assetUri.toString())) {
            return null;
          }
          stage = 'asset_download:$bundleId';
          onStatus?.call('Downloading hosted Pokemon snapshot');
          final gzipBytes = await _fetchBytesWithRetry(
            client: client,
            uri: assetUri,
            onProgress: (value) => onProgress(
              ((i + value) / selectedBundles.length).clamp(0.08, 0.98),
            ),
          );
          stage = 'gzip_decode:$bundleId';
          onStatus?.call('Preparing hosted Pokemon snapshot');
          final jsonBytes = GZipDecoder().decodeBytes(gzipBytes);
          stage = 'utf8_decode:$bundleId';
          final jsonText = utf8.decode(jsonBytes, allowMalformed: true);
          stage = 'json_decode:$bundleId';
          final parsed = jsonDecode(jsonText);
          if (parsed is! Map<String, dynamic>) {
            return null;
          }
          stage = 'validate_payload:$bundleId';
          final downloadedProfile =
              (parsed['profile'] as String?)?.trim().toLowerCase() ?? '';
          if (downloadedProfile.isNotEmpty && downloadedProfile != profile) {
            return null;
          }
          final downloadedSignature =
              (parsed['languages_signature'] as String?)
                  ?.trim()
                  .toLowerCase() ??
              '';
          if (downloadedSignature.isNotEmpty) {
            downloadedLanguages.addAll(
              _languageCodeSetFromSignature(downloadedSignature),
            );
          } else {
            downloadedLanguages.addAll(_bundleLanguageSet(bundle));
          }
          final batchJson = parsed['batch'];
          if (batchJson is! Map) {
            return null;
          }
          stage = 'batch_parse:$bundleId';
          var batch = canonicalCatalogBatchFromJson(
            Map<String, dynamic>.from(batchJson),
          );
          final snapshotSchemaVersion =
              (parsed['schema_version'] as num?)?.toInt() ?? 1;
          final snapshotCompatibilityVersion =
              (parsed['compatibility_version'] as num?)?.toInt() ?? 1;
          if (!_isSupportedHostedCompatibilityVersion(
            snapshotCompatibilityVersion,
          )) {
            return null;
          }
          final bundleLanguages = _bundleLanguageSet(
            bundle,
          ).toList(growable: false);
          if (snapshotSchemaVersion < _canonicalSnapshotSchemaVersion &&
              bundleLanguages.length == 1) {
            batch = _upgradeHostedSnapshotBatchForLanguage(
              batch,
              languageCode: bundleLanguages.first,
            );
          }
          if (batch.cards.isEmpty || batch.printings.isEmpty) {
            return null;
          }
          stage = 'batch_merge:$bundleId';
          mergedBatch = mergedBatch == null
              ? batch
              : _mergeCanonicalCatalogBatches(mergedBatch, batch);
        }
        if (mergedBatch == null) {
          return null;
        }
        final mergedSignature = _normalizeLanguageSignature({
          ...existingLanguages,
          ...downloadedLanguages,
        });
        stage = 'snapshot_write';
        await _writeCanonicalCatalogSnapshot(
          mergedBatch,
          profile: profile.trim().toLowerCase(),
          languageSignature: mergedSignature,
        );
        await _clearHostedBundleDiagnostic();
        onStatus?.call('Using hosted Pokemon snapshot');
        onProgress(1);
        return mergedBatch;
      }

      Uri? assetUri;
      final manifestProfile =
          (manifestParsed['profile'] as String?)?.trim().toLowerCase() ?? '';
      if (manifestProfile.isNotEmpty && manifestProfile != profile) {
        return null;
      }
      final manifestLanguages =
          (manifestParsed['languages'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .map((code) => code.trim().toLowerCase())
              .where((code) => code.isNotEmpty)
              .toList(growable: false);
      if (manifestLanguages.isNotEmpty) {
        final hostedSignature = _normalizeLanguageSignature(manifestLanguages);
        if (!_signatureContainsRequiredLanguages(
          availableSignature: hostedSignature,
          requiredSignature: expectedLanguageSignature,
        )) {
          return null;
        }
      }
      final artifacts =
          (manifestParsed['artifacts'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList(growable: false);
      for (final artifact in artifacts) {
        final name = (artifact['name'] as String?)?.trim() ?? '';
        final path = (artifact['path'] as String?)?.trim() ?? '';
        if (name == _hostedCanonicalSnapshotAssetName ||
            path == _hostedCanonicalSnapshotAssetName) {
          assetUri = _resolveHostedArtifactUri(artifact);
          break;
        }
      }
      assetUri ??= _firebaseDownloadUriForObjectPath(
        '$_firebaseCatalogObjectPrefix$_hostedCanonicalSnapshotAssetName',
      );
      if (assetUri == null || !_isAllowedDownloadUri(assetUri.toString())) {
        return null;
      }
      stage = 'asset_download:canonical_catalog_snapshot';
      onStatus?.call('Downloading hosted Pokemon snapshot');
      final gzipBytes = await _fetchBytesWithRetry(
        client: client,
        uri: assetUri,
        onProgress: (value) => onProgress((0.08 + (value * 0.90)).clamp(0, 1)),
      );
      stage = 'gzip_decode:canonical_catalog_snapshot';
      onStatus?.call('Preparing hosted Pokemon snapshot');
      final jsonBytes = GZipDecoder().decodeBytes(gzipBytes);
      stage = 'utf8_decode:canonical_catalog_snapshot';
      final jsonText = utf8.decode(jsonBytes, allowMalformed: true);
      stage = 'json_decode:canonical_catalog_snapshot';
      final parsed = jsonDecode(jsonText);
      if (parsed is! Map<String, dynamic>) {
        return null;
      }
      stage = 'validate_payload:canonical_catalog_snapshot';
      final downloadedProfile =
          (parsed['profile'] as String?)?.trim().toLowerCase() ?? '';
      if (downloadedProfile.isNotEmpty && downloadedProfile != profile) {
        return null;
      }
      final downloadedSignature =
          (parsed['languages_signature'] as String?)?.trim().toLowerCase() ??
          '';
      final snapshotCompatibilityVersion =
          (parsed['compatibility_version'] as num?)?.toInt() ?? 1;
      if (!_isSupportedHostedCompatibilityVersion(
        snapshotCompatibilityVersion,
      )) {
        return null;
      }
      if (downloadedSignature.isNotEmpty &&
          !_signatureContainsRequiredLanguages(
            availableSignature: downloadedSignature,
            requiredSignature: expectedLanguageSignature,
          )) {
        return null;
      }
      final batchJson = parsed['batch'];
      if (batchJson is! Map) {
        return null;
      }
      stage = 'batch_parse:canonical_catalog_snapshot';
      var batch = canonicalCatalogBatchFromJson(
        Map<String, dynamic>.from(batchJson),
      );
      final snapshotSchemaVersion =
          (parsed['schema_version'] as num?)?.toInt() ?? 1;
      final downloadedLanguageCodes = _languageCodeSetFromSignature(
        downloadedSignature.isNotEmpty
            ? downloadedSignature
            : expectedLanguageSignature,
      ).toList(growable: false);
      if (snapshotSchemaVersion < _canonicalSnapshotSchemaVersion &&
          downloadedLanguageCodes.length == 1) {
        batch = _upgradeHostedSnapshotBatchForLanguage(
          batch,
          languageCode: downloadedLanguageCodes.first,
        );
      }
      if (batch.cards.isEmpty || batch.printings.isEmpty) {
        return null;
      }
      stage = 'snapshot_write';
      await _writeCanonicalCatalogSnapshot(
        batch,
        profile: profile.trim().toLowerCase(),
        languageSignature: downloadedSignature.isNotEmpty
            ? downloadedSignature
            : expectedLanguageSignature,
      );
      await _clearHostedBundleDiagnostic();
      onStatus?.call('Using hosted Pokemon snapshot');
      onProgress(1);
      return batch;
    } catch (error) {
      final code = _describeHostedBundleError(error);
      final detail = _sanitizeHostedBundleErrorDetail(error);
      await _persistHostedBundleDiagnostic(
        code: code,
        stage: stage,
        detail: detail,
      );
      throw HttpException('$code||stage=$stage||detail=$detail');
    } finally {
      client.close();
    }
  }

  Future<Uint8List> _fetchBytesWithRetry({
    required http.Client client,
    required Uri uri,
    required void Function(double fraction) onProgress,
  }) async {
    const assumedStreamLengthBytes = 600 * 1024 * 1024;
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttemptsPerPage; attempt++) {
      try {
        final request = http.Request('GET', uri)
          ..headers.addAll(const <String, String>{
            'user-agent': 'bindervault/1.0',
          });
        final streamed = await client
            .send(request)
            .timeout(const Duration(seconds: 90));
        if (streamed.statusCode != 200) {
          final retryable =
              streamed.statusCode == 429 || streamed.statusCode >= 500;
          if (!retryable || attempt == _maxAttemptsPerPage) {
            throw HttpException('pokemon_api_http_${streamed.statusCode}');
          }
          lastError = HttpException('pokemon_api_http_${streamed.statusCode}');
        } else {
          final expected = streamed.contentLength ?? 0;
          var received = 0;
          final chunks = <int>[];
          await for (final chunk in streamed.stream) {
            chunks.addAll(chunk);
            received += chunk.length;
            if (expected > 0) {
              onProgress((received / expected).clamp(0.0, 1.0));
            } else {
              final estimated = (received / assumedStreamLengthBytes).clamp(
                0.0,
                0.98,
              );
              onProgress(estimated);
            }
          }
          onProgress(1);
          return Uint8List.fromList(chunks);
        }
      } on TimeoutException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }
      if (attempt < _maxAttemptsPerPage) {
        await Future<void>.delayed(_retryDelay(attempt));
      }
    }
    if (lastError is HttpException) {
      throw lastError;
    }
    if (lastError is TimeoutException) {
      throw const SocketException('pokemon_api_timeout');
    }
    if (lastError is SocketException) {
      throw const SocketException('pokemon_api_unreachable');
    }
    if (lastError is http.ClientException) {
      throw HttpException('pokemon_api_client_error');
    }
    throw const HttpException('pokemon_api_failed');
  }

  Future<void> _importCanonicalCatalogBatch(
    CanonicalCatalogImportBatch batch, {
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Loading local Pokemon catalog snapshot');
    onProgress(0.15);
    if (batch.cards.isEmpty || batch.printings.isEmpty) {
      throw const FormatException('pokemon_canonical_cache_invalid');
    }
    final store = await CanonicalCatalogStore.openDefault();
    try {
      store.replacePokemonCatalog(batch);
    } finally {
      store.dispose();
    }
    onProgress(1);
  }

  Future<void> reimportFromLocalCache({
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    final database = await ScryfallDatabase.instance.open();
    final selectedLanguageSignature = await _selectedPokemonLanguageSignature();
    final datasetDir = await _ensureDatasetDirectory();
    onStatus?.call('Restoring Pokemon canonical catalog');
    onProgress(0.02);
    final snapshotFile = await _canonicalSnapshotFile();
    if (!await snapshotFile.exists()) {
      throw const FormatException('pokemon_canonical_cache_empty');
    }
    final canonicalRestoreStopwatch = Stopwatch()..start();
    await _restoreCanonicalCatalogSnapshot(snapshotFile);
    canonicalRestoreStopwatch.stop();
    final files =
        datasetDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .where(
              (file) => p.basename(file.path) != _canonicalSnapshotFileName,
            )
            .toList()
          ..sort(
            (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
          );

    if (files.isEmpty) {
      throw const FormatException('pokemon_dataset_cache_empty');
    }

    onStatus?.call('Reimporting from local cache');
    onProgress(0.12);

    var inserted = 0;
    final legacyReimportStopwatch = Stopwatch()..start();
    await database.transaction(() async {
      await ScryfallDatabase.instance.deleteAllCards(database);
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        onStatus?.call('Reading ${p.basename(file.path)}');
        final raw = await file.readAsString();
        final parsed = jsonDecode(raw);
        final rows = _extractDatasetRows(parsed);
        final mapped = <Map<String, dynamic>>[];
        for (final row in rows) {
          if (row is! Map) {
            continue;
          }
          final normalized = _mapPokemonCardPayload(
            Map<String, dynamic>.from(row),
          );
          if (normalized != null) {
            mapped.add(normalized);
          }
        }
        if (mapped.isNotEmpty) {
          for (var offset = 0; offset < mapped.length; offset += 400) {
            final end = (offset + 400 < mapped.length)
                ? offset + 400
                : mapped.length;
            await ScryfallDatabase.instance.insertPokemonCardsBatch(
              database,
              mapped.sublist(offset, end),
            );
          }
          inserted += mapped.length;
        }
        final progress = 0.12 + (((i + 1) / files.length) * 0.84);
        onProgress(progress.clamp(0.0, 0.98));
      }
    });
    legacyReimportStopwatch.stop();

    if (inserted <= 0) {
      throw const FormatException('pokemon_dataset_cache_invalid');
    }

    await ScryfallDatabase.instance.rebuildPrintedNameSearchIndex();

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_prefsKeyInstalledVersion, datasetVersion);
    await prefs.setString(_prefsKeyInstalledSource, 'local_cache');
    await prefs.setInt(_prefsKeyInstalledAt, nowMs);
    await prefs.setString(_prefsKeyInstalledProfile, _fixedProfile);
    await prefs.setString(
      _prefsKeyInstalledLanguages,
      selectedLanguageSignature,
    );
    await prefs.setString(
      _prefsKeyManifestFingerprint,
      'local_cache:${files.length}:$inserted:$nowMs',
    );
    totalStopwatch.stop();
    onStatus?.call('Completed');
    onProgress(1);
  }

  Future<void> reimportOrInstallForCurrentSelection({
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    await _createAutomaticCollectionsBackup(
      reason: 'pokemon_reimport_or_install',
      onStatus: onStatus,
    );
    final selectedLanguageSignature = await _selectedPokemonLanguageSignature();
    final snapshotCompatible = await _isCanonicalSnapshotCompatible(
      expectedProfile: _fixedProfile,
      expectedLanguageSignature: selectedLanguageSignature,
    );
    if (snapshotCompatible) {
      try {
        await reimportFromCanonicalSnapshot(
          onProgress: onProgress,
          onStatus: onStatus,
        );
        return;
      } catch (error) {
        if (!_isCacheRestoreError(error)) {
          rethrow;
        }
      }
    }
    onStatus?.call('Refreshing Pokemon catalog for selected languages');
    onProgress(0.0);
    await _deleteCanonicalSnapshotIfPresent();
    await installDataset(
      onProgress: onProgress,
      onStatus: onStatus,
      allowLanguageDeltaFromCache: false,
    );
  }

  Future<void> _createAutomaticCollectionsBackup({
    required String reason,
    void Function(String status)? onStatus,
  }) async {
    final metadata = await _buildAutomaticBackupMetadata(reason: reason);
    onStatus?.call('Saving local collection safety backup');
    final result = await LocalBackupService.instance.exportCollectionsBackup(
      metadata: metadata,
      filePrefix: LocalBackupService.pokemonAutomaticBackupPrefix,
      skipIfEmpty: true,
    );
    _lastAutomaticCollectionsBackupFile = result?.file;
    if (result == null) {
      return;
    }
  }

  Future<Map<String, Object?>> _buildAutomaticBackupMetadata({
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedLanguageSignature = await _selectedPokemonLanguageSignature();
    return <String, Object?>{
      'kind': 'automatic_pre_update_backup',
      'game': 'pokemon',
      'reason': reason,
      'created_by': 'pokemon_bulk_service',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'selected_language_signature': selectedLanguageSignature,
      'installed_dataset_version': prefs.getString(_prefsKeyInstalledVersion),
      'installed_dataset_source': prefs.getString(_prefsKeyInstalledSource),
      'installed_dataset_profile': prefs.getString(_prefsKeyInstalledProfile),
      'installed_dataset_languages': prefs.getString(
        _prefsKeyInstalledLanguages,
      ),
      'installed_dataset_at': prefs.getInt(_prefsKeyInstalledAt),
      'installed_manifest_fingerprint': prefs.getString(
        _prefsKeyManifestFingerprint,
      ),
      'installed_source_repo': prefs.getString(_prefsKeyInstalledSourceRepo),
      'installed_source_ref': prefs.getString(_prefsKeyInstalledSourceRef),
      'installed_source_commit': prefs.getString(
        _prefsKeyInstalledSourceCommit,
      ),
      'expected_bundle_compatibility_version':
          _hostedBundleCompatibilityVersion,
    };
  }

  Future<void> reimportFromCanonicalSnapshot({
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    final snapshot = await _readCanonicalSnapshotPayload();
    if (snapshot == null ||
        snapshot.batch.cards.isEmpty ||
        snapshot.batch.printings.isEmpty) {
      throw const FormatException('pokemon_canonical_cache_empty');
    }
    final selectedCanonicalLanguages =
        await _selectedPokemonCanonicalLanguages();
    final selectedLanguageSignature = await _selectedPokemonLanguageSignature();
    final database = await ScryfallDatabase.instance.open();

    onStatus?.call('Restoring Pokemon canonical catalog');
    onProgress(0.02);
    await _importCanonicalCatalogBatch(
      snapshot.batch,
      onProgress: (_) {},
      onStatus: null,
    );

    onStatus?.call('Rebuilding local Pokemon database');
    onProgress(0.08);
    final inserted = await _installFromCanonicalBatch(
      database: database,
      batch: snapshot.batch,
      languages: selectedCanonicalLanguages,
      onProgress: (progress) {
        final scaled = 0.08 + (progress.clamp(0.0, 1.0) * 0.84);
        onProgress(scaled);
      },
      progressStart: 0.0,
      progressEnd: 1.0,
    );
    if (inserted <= 0) {
      throw const FormatException('pokemon_dataset_cache_invalid');
    }

    onStatus?.call('Finalizing local database');
    onProgress(0.94);
    await ScryfallDatabase.instance.rebuildPrintedNameSearchIndex();
    onProgress(0.98);
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_prefsKeyInstalledVersion, datasetVersion);
    await prefs.setString(_prefsKeyInstalledSource, 'canonical_snapshot_cache');
    await prefs.setInt(_prefsKeyInstalledAt, nowMs);
    await prefs.setString(_prefsKeyInstalledProfile, _fixedProfile);
    await prefs.setString(
      _prefsKeyInstalledLanguages,
      selectedLanguageSignature,
    );
    await prefs.setString(
      _prefsKeyManifestFingerprint,
      'canonical_snapshot_cache:${snapshot.batch.printings.length}:$inserted:$nowMs',
    );
    totalStopwatch.stop();
    onStatus?.call('Completed');
    onProgress(1);
  }

  Future<List<String>> _selectedPokemonCanonicalLanguages() async {
    // Intermediate release strategy: always build/download the full Pokemon
    // canonical catalog for EN+IT to guarantee deterministic local coverage.
    return const <String>[TcgLanguageCodes.en, TcgLanguageCodes.it];
  }

  Future<String> _selectedPokemonLanguageSignature() async {
    final languages = await _selectedPokemonCanonicalLanguages();
    final codes =
        languages
            .map((language) => language.trim().toLowerCase())
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return codes.join(',');
  }

  Future<File> _canonicalSnapshotFile() async {
    final datasetDir = await _ensureDatasetDirectory();
    return File(p.join(datasetDir.path, _canonicalSnapshotFileName));
  }

  Future<void> _deleteCanonicalSnapshotIfPresent() async {
    final file = await _canonicalSnapshotFile();
    if (!await file.exists()) {
      return;
    }
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<void> _writeCanonicalCatalogSnapshot(
    CanonicalCatalogImportBatch batch, {
    required String profile,
    required String languageSignature,
  }) async {
    final file = await _canonicalSnapshotFile();
    final payload = <String, Object?>{
      'schema_version': _canonicalSnapshotSchemaVersion,
      'compatibility_version': _hostedBundleCompatibilityVersion,
      'profile': profile,
      'languages_signature': languageSignature,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'batch': canonicalCatalogBatchToJson(batch),
    };
    await file.writeAsString(jsonEncode(payload));
  }

  Future<bool> _isCanonicalSnapshotCompatible({
    required String expectedProfile,
    required String expectedLanguageSignature,
  }) async {
    final snapshotFile = await _canonicalSnapshotFile();
    if (!await snapshotFile.exists()) {
      return false;
    }
    try {
      final raw = await snapshotFile.readAsString();
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        return false;
      }
      final profile =
          (parsed['profile'] as String?)?.trim().toLowerCase() ?? '';
      if (profile != expectedProfile.trim().toLowerCase()) {
        return false;
      }
      final schemaVersion = (parsed['schema_version'] as num?)?.toInt() ?? 1;
      if (schemaVersion < _canonicalSnapshotSchemaVersion) {
        return false;
      }
      final compatibilityVersion =
          (parsed['compatibility_version'] as num?)?.toInt() ?? 1;
      if (!_isSupportedHostedCompatibilityVersion(compatibilityVersion)) {
        return false;
      }
      final languageSignature =
          (parsed['languages_signature'] as String?)?.trim().toLowerCase() ??
          '';
      if (languageSignature.isNotEmpty) {
        return _signatureContainsRequiredLanguages(
          availableSignature: languageSignature,
          requiredSignature: expectedLanguageSignature,
        );
      }
      // Legacy snapshots (without explicit language metadata) were EN-only.
      return expectedLanguageSignature.trim().toLowerCase() == 'en';
    } catch (_) {
      return false;
    }
  }

  Future<_CanonicalSnapshotPayload?> _readCanonicalSnapshotPayload() async {
    final snapshotFile = await _canonicalSnapshotFile();
    if (!await snapshotFile.exists()) {
      return null;
    }
    try {
      final raw = await snapshotFile.readAsString();
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        return null;
      }
      final profile =
          (parsed['profile'] as String?)?.trim().toLowerCase() ?? '';
      final languageSignature =
          (parsed['languages_signature'] as String?)?.trim().toLowerCase() ??
          'en';
      final schemaVersion = (parsed['schema_version'] as num?)?.toInt() ?? 1;
      final compatibilityVersion =
          (parsed['compatibility_version'] as num?)?.toInt() ?? 1;
      final batchJson = parsed['batch'];
      if (batchJson is! Map) {
        return null;
      }
      final batch = canonicalCatalogBatchFromJson(
        Map<String, dynamic>.from(batchJson),
      );
      return _CanonicalSnapshotPayload(
        profile: profile,
        languageSignature: languageSignature,
        schemaVersion: schemaVersion,
        compatibilityVersion: compatibilityVersion,
        batch: batch,
      );
    } catch (_) {
      return null;
    }
  }

  Set<String> _languageCodeSetFromSignature(String signature) {
    final normalized = signature
        .split(',')
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) {
      normalized.add('en');
    }
    return normalized;
  }

  Set<String> _bundleLanguageSet(Map<String, dynamic> bundle) {
    return (bundle['languages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  int _bundleCompatibilityVersion(Map<String, dynamic> bundle) {
    return (bundle['compatibility_version'] as num?)?.toInt() ?? 1;
  }

  List<Map<String, dynamic>>? selectHostedBundlesForMissingLanguagesForTesting({
    required List<Map<String, dynamic>> bundles,
    required String profile,
    required Set<String> requiredLanguages,
    Set<String> existingLanguages = const <String>{},
  }) {
    return _selectHostedBundlesForMissingLanguages(
      bundles: bundles,
      profile: profile,
      requiredLanguages: requiredLanguages,
      existingLanguages: existingLanguages,
    );
  }

  bool _isSupportedHostedCompatibilityVersion(int version) {
    return version >= _hostedBundleCompatibilityVersion;
  }

  List<String> _bundleRequiresList(Map<String, dynamic> bundle) {
    return (bundle['requires'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  Uri? resolveCanonicalSnapshotAssetUriFromBundleForTesting(
    Map<String, dynamic> bundle,
  ) {
    return _resolveCanonicalSnapshotAssetUriFromBundle(bundle);
  }

  bool isAllowedDownloadUriForTesting(String rawUri) {
    return _isAllowedDownloadUri(rawUri);
  }

  Uri? _resolveCanonicalSnapshotAssetUriFromBundle(
    Map<String, dynamic> bundle,
  ) {
    final artifacts =
        (bundle['artifacts'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList(growable: false);
    for (final artifact in artifacts) {
      final name = (artifact['name'] as String?)?.trim() ?? '';
      final path = (artifact['path'] as String?)?.trim() ?? '';
      final downloadUrl = (artifact['download_url'] as String?)?.trim() ?? '';
      final candidate = path.isEmpty ? name : path;
      final normalizedCandidate = candidate.toLowerCase();
      final normalizedDownloadUrl = downloadUrl.toLowerCase();
      final hasCanonicalSnapshotName =
          normalizedCandidate.contains('canonical_catalog_snapshot') ||
          normalizedDownloadUrl.contains('canonical_catalog_snapshot');
      final hasJsonGzipName =
          normalizedCandidate.endsWith('.json.gz') ||
          normalizedDownloadUrl.contains('.json.gz');
      if (hasCanonicalSnapshotName && hasJsonGzipName) {
        return _resolveHostedArtifactUri(artifact);
      }
    }
    return null;
  }

  Uri? _resolveHostedArtifactUri(Map<String, dynamic> artifact) {
    final downloadUrl = (artifact['download_url'] as String?)?.trim() ?? '';
    if (downloadUrl.isNotEmpty) {
      final uri = Uri.tryParse(downloadUrl);
      if (uri != null && uri.hasScheme) {
        return uri;
      }
    }

    final path = (artifact['path'] as String?)?.trim() ?? '';
    final name = (artifact['name'] as String?)?.trim() ?? '';
    final candidate = path.isEmpty ? name : path;
    if (candidate.isEmpty) {
      return null;
    }
    final absoluteUri = Uri.tryParse(candidate);
    if (absoluteUri != null && absoluteUri.hasScheme) {
      return absoluteUri;
    }
    final objectPath = candidate.startsWith(_firebaseCatalogObjectPrefix)
        ? candidate
        : '$_firebaseCatalogObjectPrefix$candidate';
    return _firebaseDownloadUriForObjectPath(objectPath);
  }

  Uri? _firebaseDownloadUriForObjectPath(String objectPath) {
    final normalized = objectPath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty ||
        !normalized.startsWith(_firebaseCatalogObjectPrefix)) {
      return null;
    }
    return Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$_firebaseCatalogBucket/o/${Uri.encodeComponent(normalized)}',
      const <String, String>{'alt': 'media'},
    );
  }

  List<Map<String, dynamic>>? _selectHostedBundlesForMissingLanguages({
    required List<Map<String, dynamic>> bundles,
    required String profile,
    required Set<String> requiredLanguages,
    required Set<String> existingLanguages,
  }) {
    final profileBundles = bundles
        .where((bundle) {
          final bundleProfile =
              (bundle['profile'] as String?)?.trim().toLowerCase() ?? '';
          return (bundleProfile.isEmpty ||
                  bundleProfile == profile.trim().toLowerCase()) &&
              _isSupportedHostedCompatibilityVersion(
                _bundleCompatibilityVersion(bundle),
              );
        })
        .toList(growable: false);
    final byId = <String, Map<String, dynamic>>{};
    for (final bundle in profileBundles) {
      final id = (bundle['id'] as String?)?.trim();
      if (id != null && id.isNotEmpty) {
        byId[id] = bundle;
      }
    }

    final targetMissing = requiredLanguages.difference(existingLanguages);
    if (targetMissing.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final selected = <Map<String, dynamic>>[];
    final selectedIds = <String>{};
    var covered = <String>{...existingLanguages};

    while (!covered.containsAll(requiredLanguages)) {
      Map<String, dynamic>? best;
      var bestNewCoverage = 0;
      var bestExtra = 1 << 30;
      for (final bundle in profileBundles) {
        final id = (bundle['id'] as String?)?.trim();
        if (id != null && id.isNotEmpty && selectedIds.contains(id)) {
          continue;
        }
        final languages = _bundleLanguageSet(bundle);
        final newCoverage = languages
            .intersection(requiredLanguages)
            .difference(covered);
        if (newCoverage.isEmpty) {
          continue;
        }
        final extra = languages.length - newCoverage.length;
        if (newCoverage.length > bestNewCoverage ||
            (newCoverage.length == bestNewCoverage && extra < bestExtra)) {
          best = bundle;
          bestNewCoverage = newCoverage.length;
          bestExtra = extra;
        }
      }
      if (best == null) {
        return null;
      }
      final id = (best['id'] as String?)?.trim();
      if (id != null && id.isNotEmpty) {
        selectedIds.add(id);
      }
      selected.add(best);
      covered.addAll(_bundleLanguageSet(best));
    }

    final queue = List<Map<String, dynamic>>.from(selected);
    var index = 0;
    while (index < queue.length) {
      final bundle = queue[index];
      index += 1;
      for (final dependencyId in _bundleRequiresList(bundle)) {
        if (selectedIds.contains(dependencyId)) {
          continue;
        }
        final dependency = byId[dependencyId];
        if (dependency == null) {
          return null;
        }
        final dependencyLanguages = _bundleLanguageSet(dependency);
        if (covered.containsAll(dependencyLanguages)) {
          continue;
        }
        selectedIds.add(dependencyId);
        selected.add(dependency);
        covered.addAll(dependencyLanguages);
        queue.add(dependency);
      }
    }

    selected.sort((a, b) {
      final kindA = (a['kind'] as String?)?.trim().toLowerCase() ?? '';
      final kindB = (b['kind'] as String?)?.trim().toLowerCase() ?? '';
      final scoreA = kindA == 'base' ? 0 : 1;
      final scoreB = kindB == 'base' ? 0 : 1;
      if (scoreA != scoreB) {
        return scoreA.compareTo(scoreB);
      }
      final idA = (a['id'] as String?)?.trim() ?? '';
      final idB = (b['id'] as String?)?.trim() ?? '';
      return idA.compareTo(idB);
    });
    return selected;
  }

  bool _signatureContainsRequiredLanguages({
    required String availableSignature,
    required String requiredSignature,
  }) {
    final available = _languageCodeSetFromSignature(availableSignature);
    final required = _languageCodeSetFromSignature(requiredSignature);
    return available.containsAll(required);
  }

  String _normalizeLanguageSignature(Iterable<String> codes) {
    final normalized =
        codes
            .map((code) => code.trim().toLowerCase())
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (normalized.isEmpty) {
      return 'en';
    }
    return normalized.join(',');
  }

  CanonicalCatalogImportBatch _mergeCanonicalCatalogBatches(
    CanonicalCatalogImportBatch base,
    CanonicalCatalogImportBatch delta,
  ) {
    final cards = <String, CatalogCard>{
      for (final value in base.cards) value.cardId: value,
      for (final value in delta.cards) value.cardId: value,
    };
    final sets = <String, CatalogSet>{
      for (final value in base.sets) value.setId: value,
      for (final value in delta.sets) value.setId: value,
    };
    final printings = <String, CardPrintingRef>{
      for (final value in base.printings) value.printingId: value,
    };
    for (final value in delta.printings) {
      final existing = printings[value.printingId];
      printings[value.printingId] = existing == null
          ? value
          : _mergeCardPrintingRefs(existing, value);
    }
    final cardLocalizations = <String, LocalizedCardData>{
      for (final value in base.cardLocalizations)
        '${value.cardId}:${value.languageCode}': value,
      for (final value in delta.cardLocalizations)
        '${value.cardId}:${value.languageCode}': value,
    };
    final setLocalizations = <String, LocalizedSetData>{
      for (final value in base.setLocalizations)
        '${value.setId}:${value.languageCode}': value,
      for (final value in delta.setLocalizations)
        '${value.setId}:${value.languageCode}': value,
    };
    final providerMappings = <String, ProviderMappingRecord>{
      for (final value in base.providerMappings)
        _providerMappingRecordKey(value): value,
      for (final value in delta.providerMappings)
        _providerMappingRecordKey(value): value,
    };
    final priceSnapshots = <String, PriceSnapshot>{
      for (final value in base.priceSnapshots) _priceSnapshotKey(value): value,
      for (final value in delta.priceSnapshots) _priceSnapshotKey(value): value,
    };
    return CanonicalCatalogImportBatch(
      cards: cards.values.toList(growable: false),
      sets: sets.values.toList(growable: false),
      printings: printings.values.toList(growable: false),
      cardLocalizations: cardLocalizations.values.toList(growable: false),
      setLocalizations: setLocalizations.values.toList(growable: false),
      providerMappings: providerMappings.values.toList(growable: false),
      priceSnapshots: priceSnapshots.values.toList(growable: false),
    );
  }

  CardPrintingRef _mergeCardPrintingRefs(
    CardPrintingRef base,
    CardPrintingRef delta,
  ) {
    final providerMappings = <String, ProviderMapping>{
      for (final mapping in base.providerMappings)
        _providerMappingKey(mapping): mapping,
      for (final mapping in delta.providerMappings)
        _providerMappingKey(mapping): mapping,
    };
    return CardPrintingRef(
      printingId: delta.printingId,
      cardId: delta.cardId,
      setId: delta.setId,
      gameId: delta.gameId,
      collectorNumber: delta.collectorNumber.trim().isNotEmpty
          ? delta.collectorNumber
          : base.collectorNumber,
      languageCode: delta.languageCode.trim().isNotEmpty
          ? delta.languageCode
          : base.languageCode,
      providerMappings: providerMappings.values.toList(growable: false),
      rarity: (delta.rarity ?? '').trim().isNotEmpty
          ? delta.rarity
          : base.rarity,
      releaseDate: delta.releaseDate ?? base.releaseDate,
      imageUris: delta.imageUris.isNotEmpty ? delta.imageUris : base.imageUris,
      finishKeys: {...base.finishKeys, ...delta.finishKeys},
      metadata: <String, Object?>{...base.metadata, ...delta.metadata},
    );
  }

  String _providerMappingKey(ProviderMapping value) {
    return [
      value.providerId.value,
      value.objectType.trim().toLowerCase(),
      value.providerObjectId.trim().toLowerCase(),
      (value.providerObjectVersion ?? '').trim().toLowerCase(),
    ].join('|');
  }

  String _providerMappingRecordKey(ProviderMappingRecord value) {
    final mapping = value.mapping;
    return [
      mapping.providerId.value,
      mapping.objectType.trim().toLowerCase(),
      mapping.providerObjectId.trim().toLowerCase(),
      (value.printingId ?? '').trim().toLowerCase(),
      (value.cardId ?? '').trim().toLowerCase(),
      (value.setId ?? '').trim().toLowerCase(),
    ].join('|');
  }

  String _priceSnapshotKey(PriceSnapshot value) {
    final finish = (value.finishKey ?? '').trim().toLowerCase();
    return [
      value.printingId.trim().toLowerCase(),
      value.sourceId.value,
      value.currencyCode.trim().toLowerCase(),
      finish,
    ].join('|');
  }

  bool _isCacheRestoreError(Object error) {
    final text = error.toString();
    return text.contains('pokemon_canonical_cache_') ||
        text.contains('pokemon_dataset_cache_');
  }

  Future<void> _restoreCanonicalCatalogSnapshot(File snapshotFile) async {
    final raw = await snapshotFile.readAsString();
    final parsed = jsonDecode(raw);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('pokemon_canonical_cache_invalid');
    }
    final batchJson = parsed['batch'];
    if (batchJson is! Map) {
      throw const FormatException('pokemon_canonical_cache_invalid');
    }
    final batch = canonicalCatalogBatchFromJson(
      Map<String, dynamic>.from(batchJson),
    );
    if (batch.cards.isEmpty || batch.printings.isEmpty) {
      throw const FormatException('pokemon_canonical_cache_invalid');
    }
    final store = await CanonicalCatalogStore.openDefault();
    try {
      store.replacePokemonCatalog(batch);
    } finally {
      store.dispose();
    }
  }

  List<dynamic> _extractDatasetRows(dynamic parsed) {
    if (parsed is List) {
      return parsed;
    }
    if (parsed is Map<String, dynamic>) {
      final data = parsed['data'];
      if (data is List) {
        return data;
      }
    }
    return const <dynamic>[];
  }

  Future<int> backfillSetNames({http.Client? client}) async {
    return 0;
  }

  Future<int> _installFromCanonicalBatch({
    required AppDatabase database,
    required CanonicalCatalogImportBatch batch,
    required List<String> languages,
    required void Function(double progress) onProgress,
    required double progressStart,
    required double progressEnd,
  }) async {
    if (batch.cards.isEmpty || batch.printings.isEmpty) {
      throw const FormatException('pokemon_canonical_snapshot_empty');
    }
    final cardsById = <String, CatalogCard>{
      for (final card in batch.cards) card.cardId: card,
    };
    final setsById = <String, CatalogSet>{
      for (final set in batch.sets) set.setId: set,
    };
    final localizedCardsByLanguage = <String, Map<String, LocalizedCardData>>{};
    for (final localized in batch.cardLocalizations) {
      final langCode = localized.languageCode.trim().toLowerCase();
      if (langCode.isEmpty) {
        continue;
      }
      final map = localizedCardsByLanguage.putIfAbsent(
        langCode,
        () => <String, LocalizedCardData>{},
      );
      if (!map.containsKey(localized.cardId)) {
        map[localized.cardId] = localized;
      }
    }
    final localizedSetsByLanguage = <String, Map<String, LocalizedSetData>>{};
    for (final localized in batch.setLocalizations) {
      final langCode = localized.languageCode.trim().toLowerCase();
      if (langCode.isEmpty) {
        continue;
      }
      final map = localizedSetsByLanguage.putIfAbsent(
        langCode,
        () => <String, LocalizedSetData>{},
      );
      if (!map.containsKey(localized.setId)) {
        map[localized.setId] = localized;
      }
    }
    final preferredLanguageCodes = languages
        .map((language) => language.trim().toLowerCase())
        .where((code) => code.isNotEmpty && code != 'en')
        .followedBy(
          languages
              .map((language) => language.trim().toLowerCase())
              .where((code) => code.isNotEmpty && code == 'en'),
        )
        .toSet()
        .toList(growable: false);

    await ScryfallDatabase.instance.deleteAllCards(database);
    final pendingChunk = <Map<String, dynamic>>[];
    var inserted = 0;
    final total = batch.printings.length;
    await database.transaction(() async {
      for (var index = 0; index < total; index += 1) {
        final printing = batch.printings[index];
        final card = cardsById[printing.cardId];
        if (card == null) {
          continue;
        }
        final set = setsById[printing.setId];
        final rowLanguageCode = printing.languageCode.trim().toLowerCase();
        final rowPreferredLanguages = <String>[
          if (rowLanguageCode.isNotEmpty) rowLanguageCode,
          ...preferredLanguageCodes.where((code) => code != rowLanguageCode),
        ];
        final localizedCard =
            _selectCardLocalization(
              cardId: card.cardId,
              localizedCardsByLanguage: localizedCardsByLanguage,
              preferredLanguageCodes: rowPreferredLanguages,
            ) ??
            card.defaultLocalizedData;
        final localizedSet = set == null
            ? null
            : (_selectSetLocalization(
                    setId: set.setId,
                    localizedSetsByLanguage: localizedSetsByLanguage,
                    preferredLanguageCodes: rowPreferredLanguages,
                  ) ??
                  set.defaultLocalizedData);
        final primaryName = (localizedCard?.name ?? card.canonicalName).trim();
        final secondaryName = _pickSecondaryCardName(
          cardId: card.cardId,
          preferredLanguageCodes: preferredLanguageCodes,
          localizedCardsByLanguage: localizedCardsByLanguage,
          primaryName: primaryName,
        );
        final row = _canonicalPrintingToLegacyRow(
          card: card,
          printing: printing,
          set: set,
          localizedCard: localizedCard,
          localizedSet: localizedSet,
          languageCode: rowLanguageCode.isEmpty ? 'en' : rowLanguageCode,
          secondarySearchName: secondaryName,
        );
        if (row != null) {
          pendingChunk.add(row);
          if (pendingChunk.length >= 500) {
            await ScryfallDatabase.instance.insertPokemonCardsBatch(
              database,
              List<Map<String, dynamic>>.from(pendingChunk),
            );
            inserted += pendingChunk.length;
            pendingChunk.clear();
          }
        }
        if ((index + 1) % 25 == 0 || index + 1 == total) {
          final progress =
              progressStart +
              (((index + 1) / total) * (progressEnd - progressStart));
          onProgress(progress.clamp(progressStart, progressEnd));
        }
      }
      if (pendingChunk.isNotEmpty) {
        await ScryfallDatabase.instance.insertPokemonCardsBatch(
          database,
          pendingChunk,
        );
        inserted += pendingChunk.length;
      }
    });
    if (inserted <= 0 && pendingChunk.isEmpty) {
      throw const FormatException('pokemon_legacy_from_canonical_empty');
    }
    return inserted;
  }

  Map<String, dynamic>? _canonicalPrintingToLegacyRow({
    required CatalogCard card,
    required CardPrintingRef printing,
    required CatalogSet? set,
    required LocalizedCardData? localizedCard,
    required LocalizedSetData? localizedSet,
    required String languageCode,
    String? secondarySearchName,
  }) {
    final id = _providerObjectIdForPrinting(printing);
    if (id.isEmpty) {
      return null;
    }
    final name = (localizedCard?.name ?? card.canonicalName).trim();
    if (name.isEmpty) {
      return null;
    }
    final pokemon = card.pokemon;
    final setCode = (set?.code ?? '').trim().toLowerCase();
    final setName = (localizedSet?.name ?? set?.canonicalName ?? '').trim();
    final setTotal = _toIntValue(set?.metadata['card_count']);
    final typeLine =
        (localizedCard?.subtypeLine ?? _pokemonTypeLineFromMetadata(pokemon))
            .trim();
    final manaValue = _minConvertedEnergyCost(pokemon);
    final colorCodes = _pokemonTypeNamesToColorCodes(
      pokemon?.types ?? const <String>[],
    );
    final releaseDate = _formatDateOnly(
      printing.releaseDate ?? set?.releaseDate,
    );
    final artist =
        (pokemon?.illustrator ??
                (card.metadata['illustrator'] as String?) ??
                '')
            .trim();
    final cardJson = <String, Object?>{
      'id': id,
      'name': name,
      'artist': artist,
      'legalities': _normalizeLegalities(printing.metadata['legalities']),
      'pokemon': _pokemonMetadataToLegacyJson(pokemon),
      if ((secondarySearchName ?? '').trim().isNotEmpty)
        'search_aliases_flat': secondarySearchName!.trim(),
    };
    return <String, dynamic>{
      'id': id,
      'name': name,
      'lang': languageCode,
      'set_code': setCode,
      'set_name': setName,
      'set_total': setTotal,
      'collector_number': printing.collectorNumber,
      'rarity': (printing.rarity ?? '').trim(),
      'type_line': typeLine,
      'mana_value': manaValue,
      'colors': colorCodes,
      'color_identity': colorCodes,
      'released_at': releaseDate,
      'artist': artist,
      'image_small': _resolveImageUri(printing, const <String>[
        'small',
        'default',
        'normal',
        'high_res',
      ]),
      'image_large': _resolveImageUri(printing, const <String>[
        'normal',
        'high_res',
        'default',
        'small',
      ]),
      'card_json': cardJson,
    };
  }

  LocalizedCardData? _selectCardLocalization({
    required String cardId,
    required Map<String, Map<String, LocalizedCardData>>
    localizedCardsByLanguage,
    required List<String> preferredLanguageCodes,
  }) {
    for (final code in preferredLanguageCodes) {
      final localized = localizedCardsByLanguage[code]?[cardId];
      if (localized != null) {
        return localized;
      }
    }
    return localizedCardsByLanguage['en']?[cardId];
  }

  LocalizedSetData? _selectSetLocalization({
    required String setId,
    required Map<String, Map<String, LocalizedSetData>> localizedSetsByLanguage,
    required List<String> preferredLanguageCodes,
  }) {
    for (final code in preferredLanguageCodes) {
      final localized = localizedSetsByLanguage[code]?[setId];
      if (localized != null) {
        return localized;
      }
    }
    return localizedSetsByLanguage['en']?[setId];
  }

  String? _pickSecondaryCardName({
    required String cardId,
    required List<String> preferredLanguageCodes,
    required Map<String, Map<String, LocalizedCardData>>
    localizedCardsByLanguage,
    required String primaryName,
  }) {
    final visited = <String>{};
    for (final code in <String>{...preferredLanguageCodes, 'en', 'it'}) {
      if (!visited.add(code)) {
        continue;
      }
      final localized = localizedCardsByLanguage[code]?[cardId];
      final candidate = localized?.name.trim() ?? '';
      if (candidate.isEmpty) {
        continue;
      }
      if (candidate.toLowerCase() != primaryName.toLowerCase()) {
        return candidate;
      }
    }
    return null;
  }

  String _providerObjectIdForPrinting(CardPrintingRef printing) {
    for (final mapping in printing.providerMappings) {
      if (mapping.objectType == 'legacy_printing') {
        final value = mapping.providerObjectId.trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    for (final mapping in printing.providerMappings) {
      if (mapping.providerId == CatalogProviderId.tcgdex &&
          mapping.objectType == 'printing_localized') {
        final value = mapping.providerObjectId.trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    for (final mapping in printing.providerMappings) {
      if (mapping.providerId == CatalogProviderId.tcgdex &&
          (mapping.objectType == 'printing' || mapping.objectType == 'card')) {
        final value = mapping.providerObjectId.trim();
        if (value.isNotEmpty) {
          final languageCode = printing.languageCode.trim().toLowerCase();
          if (languageCode.isNotEmpty && languageCode != 'en') {
            return '$value:$languageCode';
          }
          return value;
        }
      }
    }
    final fallback = printing.printingId.trim();
    if (fallback.isEmpty) {
      return '';
    }
    final separator = fallback.lastIndexOf(':');
    return separator >= 0 ? fallback.substring(separator + 1) : fallback;
  }

  CanonicalCatalogImportBatch _upgradeHostedSnapshotBatchForLanguage(
    CanonicalCatalogImportBatch batch, {
    required String languageCode,
  }) {
    final normalizedLanguage = languageCode.trim().toLowerCase();
    if (normalizedLanguage.isEmpty) {
      return batch;
    }

    String localizedPrintingId(String printingId) {
      final normalizedPrintingId = printingId.trim();
      if (normalizedPrintingId.isEmpty ||
          normalizedPrintingId.endsWith(':$normalizedLanguage')) {
        return normalizedPrintingId;
      }
      return '$normalizedPrintingId:$normalizedLanguage';
    }

    ProviderMapping localizedMapping(ProviderMapping mapping) {
      final objectType = mapping.objectType.trim().toLowerCase();
      final objectId = mapping.providerObjectId.trim();
      if (objectId.isEmpty) {
        return mapping;
      }
      if (mapping.providerId == CatalogProviderId.tcgdex &&
          objectType == 'printing') {
        return ProviderMapping(
          providerId: mapping.providerId,
          objectType: 'printing_localized',
          providerObjectId: '$objectId:$normalizedLanguage',
          providerObjectVersion: mapping.providerObjectVersion,
          mappingConfidence: mapping.mappingConfidence,
        );
      }
      if (objectType == 'legacy_printing') {
        return ProviderMapping(
          providerId: mapping.providerId,
          objectType: mapping.objectType,
          providerObjectId: '$objectId:$normalizedLanguage',
          providerObjectVersion: mapping.providerObjectVersion,
          mappingConfidence: mapping.mappingConfidence,
        );
      }
      return mapping;
    }

    final printings = batch.printings
        .map(
          (printing) => CardPrintingRef(
            printingId: localizedPrintingId(printing.printingId),
            cardId: printing.cardId,
            setId: printing.setId,
            gameId: printing.gameId,
            collectorNumber: printing.collectorNumber,
            languageCode: normalizedLanguage,
            providerMappings: [
              for (final mapping in printing.providerMappings)
                localizedMapping(mapping),
            ],
            rarity: printing.rarity,
            releaseDate: printing.releaseDate,
            imageUris: printing.imageUris,
            finishKeys: printing.finishKeys,
            metadata: <String, Object?>{
              ...printing.metadata,
              'base_printing_id': printing.printingId,
            },
          ),
        )
        .toList(growable: false);

    final providerMappings = batch.providerMappings
        .map(
          (record) => ProviderMappingRecord(
            mapping: localizedMapping(record.mapping),
            cardId: record.cardId,
            printingId: record.printingId == null
                ? null
                : localizedPrintingId(record.printingId!),
            setId: record.setId,
          ),
        )
        .toList(growable: false);

    final priceSnapshots = batch.priceSnapshots
        .map(
          (snapshot) => PriceSnapshot(
            printingId: localizedPrintingId(snapshot.printingId),
            sourceId: snapshot.sourceId,
            currencyCode: snapshot.currencyCode,
            amount: snapshot.amount,
            capturedAt: snapshot.capturedAt,
            finishKey: snapshot.finishKey,
          ),
        )
        .toList(growable: false);

    return CanonicalCatalogImportBatch(
      cards: batch.cards,
      sets: batch.sets,
      printings: printings,
      cardLocalizations: batch.cardLocalizations,
      setLocalizations: batch.setLocalizations,
      providerMappings: providerMappings,
      priceSnapshots: priceSnapshots,
    );
  }

  String _pokemonTypeLineFromMetadata(PokemonCardMetadata? metadata) {
    if (metadata == null) {
      return '';
    }
    final parts = <String>[
      if ((metadata.category ?? '').trim().isNotEmpty)
        (metadata.category ?? '').trim(),
      if ((metadata.stage ?? '').trim().isNotEmpty)
        (metadata.stage ?? '').trim(),
      if (metadata.subtypes.isNotEmpty) '(${metadata.subtypes.join(', ')})',
    ];
    return parts.join(' ').trim();
  }

  int? _minConvertedEnergyCost(PokemonCardMetadata? metadata) {
    if (metadata == null || metadata.attacks.isEmpty) {
      return null;
    }
    int? best;
    for (final attack in metadata.attacks) {
      final value = attack.convertedEnergyCost ?? attack.energyCost.length;
      if (best == null || value < best) {
        best = value;
      }
    }
    return best;
  }

  String _formatDateOnly(DateTime? value) {
    if (value == null) {
      return '';
    }
    return value.toUtc().toIso8601String().split('T').first;
  }

  int? _toIntValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  String _resolveImageUri(CardPrintingRef printing, List<String> keys) {
    for (final key in keys) {
      final value = printing.imageUris[key]?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  Map<String, Object?> _normalizeLegalities(Object? raw) {
    if (raw is! Map) {
      return const <String, Object?>{};
    }
    final normalized = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      final value = entry.value;
      if (value is bool) {
        normalized[key] = value ? 'legal' : 'not_legal';
      } else if (value is String) {
        normalized[key] = value.trim().toLowerCase();
      } else {
        normalized[key] = value?.toString().toLowerCase();
      }
    }
    return normalized;
  }

  Map<String, Object?> _pokemonMetadataToLegacyJson(
    PokemonCardMetadata? metadata,
  ) {
    if (metadata == null) {
      return const <String, Object?>{};
    }
    return <String, Object?>{
      'category': metadata.category,
      'hp': metadata.hp,
      'types': metadata.types,
      'subtypes': metadata.subtypes,
      'stage': metadata.stage,
      'evolves_from': metadata.evolvesFrom,
      'regulation_mark': metadata.regulationMark,
      'retreat_cost': metadata.retreatCost,
      'illustrator': metadata.illustrator,
      'attacks': metadata.attacks
          .map(
            (attack) => <String, Object?>{
              'name': attack.name,
              'text': attack.text,
              'damage': attack.damage,
              'energy_cost': attack.energyCost,
              'converted_energy_cost': attack.convertedEnergyCost,
            },
          )
          .toList(growable: false),
      'abilities': metadata.abilities
          .map(
            (ability) => <String, Object?>{
              'name': ability.name,
              'type': ability.type,
              'text': ability.text,
            },
          )
          .toList(growable: false),
      'weaknesses': metadata.weaknesses
          .map(
            (weakness) => <String, Object?>{
              'type': weakness.type,
              'value': weakness.value,
            },
          )
          .toList(growable: false),
      'resistances': metadata.resistances
          .map(
            (resistance) => <String, Object?>{
              'type': resistance.type,
              'value': resistance.value,
            },
          )
          .toList(growable: false),
    };
  }

  Future<Directory> _ensureDatasetDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final datasetDir = Directory(p.join(appDir.path, 'pokemon', 'datasets'));
    if (!datasetDir.existsSync()) {
      await datasetDir.create(recursive: true);
    }
    return datasetDir;
  }

  Future<void> _clearDatasetJsonCacheDirectory(Directory datasetDir) async {
    if (!await datasetDir.exists()) {
      return;
    }
    await for (final entity in datasetDir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.json')) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {}
    }
  }

  bool _isAllowedDownloadUri(String rawUri) {
    final uri = Uri.tryParse(rawUri.trim());
    if (uri == null) {
      return false;
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return false;
    }
    if (uri.userInfo.isNotEmpty || uri.host.trim().isEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host == 'firebasestorage.googleapis.com') {
      const objectPathPrefix = '/v0/b/$_firebaseCatalogBucket/o/';
      if (!uri.path.startsWith(objectPathPrefix)) {
        return false;
      }
      final encodedObjectPath = uri.path.substring(objectPathPrefix.length);
      final objectPath = Uri.decodeComponent(encodedObjectPath);
      if (!objectPath.startsWith(_firebaseCatalogObjectPrefix)) {
        return false;
      }
      final alt = uri.queryParameters['alt'];
      return alt == null || alt == 'media';
    }
    return false;
  }

  Future<String> _fetchJsonWithRetry({
    required http.Client client,
    required Uri uri,
    int retryAttempts = _maxAttemptsPerPage,
    Duration requestTimeout = const Duration(seconds: 35),
  }) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'user-agent': 'bindervault/1.0',
    };
    Object? lastError;
    for (var attempt = 1; attempt <= retryAttempts; attempt++) {
      try {
        final response = await client
            .get(uri, headers: headers)
            .timeout(requestTimeout);
        if (response.statusCode == 200) {
          return response.body;
        }
        final retryable =
            response.statusCode == 404 ||
            response.statusCode == 429 ||
            response.statusCode >= 500;
        if (!retryable || attempt == retryAttempts) {
          throw HttpException('pokemon_api_http_${response.statusCode}');
        }
        lastError = HttpException('pokemon_api_http_${response.statusCode}');
      } on TimeoutException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }
      if (attempt < retryAttempts) {
        await Future<void>.delayed(_retryDelay(attempt));
      }
    }
    if (lastError is HttpException) {
      throw lastError;
    }
    if (lastError is TimeoutException) {
      throw const SocketException('pokemon_api_timeout');
    }
    if (lastError is SocketException) {
      throw const SocketException('pokemon_api_unreachable');
    }
    if (lastError is http.ClientException) {
      throw HttpException('pokemon_api_client_error');
    }
    throw const HttpException('pokemon_api_failed');
  }

  Future<void> _saveInstalledSourceMetadata(
    SharedPreferences prefs, {
    String? repo,
    String? ref,
    String? commit,
  }) async {
    Future<void> writeOrRemove(String key, String? value) async {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, normalized);
      }
    }

    await writeOrRemove(_prefsKeyInstalledSourceRepo, repo);
    await writeOrRemove(_prefsKeyInstalledSourceRef, ref);
    await writeOrRemove(_prefsKeyInstalledSourceCommit, commit);
  }

  Future<_HostedBundleManifestInfo?> _fetchHostedManifestInfo() async {
    final client = http.Client();
    try {
      final payload = await _fetchJsonWithRetry(
        client: client,
        uri: Uri.parse(_hostedBundleManifestUrl),
        retryAttempts: 2,
        requestTimeout: const Duration(seconds: 20),
      );
      var hash = 0;
      for (final unit in payload.codeUnits) {
        hash = ((hash * 31) + unit) & 0x7fffffff;
      }
      final parsed = jsonDecode(payload);
      String? sourceRepo;
      String? sourceRef;
      String? sourceCommit;
      if (parsed is Map<String, dynamic>) {
        final source = parsed['source'];
        if (source is Map<String, dynamic>) {
          sourceRepo = (source['repo'] as String?)?.trim();
          sourceRef = (source['ref'] as String?)?.trim();
          sourceCommit = (source['commit'] as String?)?.trim();
        }
      }
      return _HostedBundleManifestInfo(
        fingerprint: 'hosted:$hash',
        sourceRepo: sourceRepo,
        sourceRef: sourceRef,
        sourceCommit: sourceCommit,
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  String _describeHostedBundleError(Object error) {
    final text = error.toString();
    if (text.contains('pokemon_api_timeout')) {
      return 'pokemon_hosted_bundle_timeout';
    }
    if (text.contains('pokemon_api_unreachable')) {
      return 'pokemon_hosted_bundle_unreachable';
    }
    if (text.contains('pokemon_api_http_404')) {
      return 'pokemon_hosted_bundle_http_404';
    }
    if (text.contains('pokemon_api_http_')) {
      return text;
    }
    if (error is FormatException) {
      return 'pokemon_hosted_bundle_invalid_payload';
    }
    return 'pokemon_hosted_bundle_failed:${error.runtimeType}';
  }

  String _sanitizeHostedBundleErrorDetail(Object error) {
    final detail = error.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    if (detail.isEmpty) {
      return error.runtimeType.toString();
    }
    return detail.length <= 180 ? detail : '${detail.substring(0, 180)}...';
  }

  Future<void> _persistHostedBundleDiagnostic({
    required String code,
    required String stage,
    required String detail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyLastError, code);
    await prefs.setString(_prefsKeyLastErrorStage, stage);
    await prefs.setString(_prefsKeyLastErrorDetail, detail);
  }

  Future<void> _clearHostedBundleDiagnostic() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyLastError);
    await prefs.remove(_prefsKeyLastErrorStage);
    await prefs.remove(_prefsKeyLastErrorDetail);
  }

  Duration _retryDelay(int attempt) {
    switch (attempt) {
      case 1:
        return const Duration(milliseconds: 600);
      case 2:
        return const Duration(milliseconds: 1300);
      default:
        return const Duration(seconds: 2);
    }
  }
}

class PokemonDatasetUpdateStatus {
  const PokemonDatasetUpdateStatus({
    required this.installed,
    required this.updateAvailable,
    this.installedFingerprint,
    this.remoteFingerprint,
    this.installedSourceRepo,
    this.installedSourceRef,
    this.installedSourceCommit,
    this.remoteSourceRepo,
    this.remoteSourceRef,
    this.remoteSourceCommit,
  });

  final bool installed;
  final bool updateAvailable;
  final String? installedFingerprint;
  final String? remoteFingerprint;
  final String? installedSourceRepo;
  final String? installedSourceRef;
  final String? installedSourceCommit;
  final String? remoteSourceRepo;
  final String? remoteSourceRef;
  final String? remoteSourceCommit;
}

class _HostedBundleManifestInfo {
  const _HostedBundleManifestInfo({
    required this.fingerprint,
    this.sourceRepo,
    this.sourceRef,
    this.sourceCommit,
  });

  final String fingerprint;
  final String? sourceRepo;
  final String? sourceRef;
  final String? sourceCommit;
}

class _CanonicalSnapshotPayload {
  const _CanonicalSnapshotPayload({
    required this.profile,
    required this.languageSignature,
    required this.schemaVersion,
    required this.compatibilityVersion,
    required this.batch,
  });

  final String profile;
  final String languageSignature;
  final int schemaVersion;
  final int compatibilityVersion;
  final CanonicalCatalogImportBatch batch;
}

Map<String, dynamic>? _mapPokemonCardPayload(Map<String, dynamic> card) {
  final id = (card['id'] as String?)?.trim();
  final name = (card['name'] as String?)?.trim();
  if (id == null || id.isEmpty || name == null || name.isEmpty) {
    return null;
  }

  final set = card['set'];
  String setCode = '';
  String setName = '';
  String releasedAt = '';
  int? setTotal;
  if (set is Map) {
    final setMap = Map<String, dynamic>.from(set);
    setCode = ((setMap['id'] as String?) ?? '').trim().toLowerCase();
    setName = ((setMap['name'] as String?) ?? '').trim();
    releasedAt = _normalizePokemonDate(
      ((setMap['releaseDate'] as String?) ?? '').trim(),
    );
    setTotal =
        (setMap['printedTotal'] as num?)?.toInt() ??
        (setMap['total'] as num?)?.toInt();
  }
  if (setCode.isEmpty) {
    for (final key in const [
      'setId',
      'set_id',
      'setCode',
      'set_code',
      'set.id',
    ]) {
      final candidate = (card[key] as String?)?.trim().toLowerCase() ?? '';
      if (candidate.isNotEmpty) {
        setCode = candidate;
        break;
      }
    }
  }
  if (setName.isEmpty) {
    for (final key in const ['setName', 'set_name', 'set.name']) {
      final candidate = (card[key] as String?)?.trim() ?? '';
      if (candidate.isNotEmpty) {
        setName = candidate;
        break;
      }
    }
  }
  if (releasedAt.isEmpty) {
    for (final key in const [
      'setReleaseDate',
      'set_release_date',
      'set.releaseDate',
    ]) {
      final candidate = (card[key] as String?)?.trim() ?? '';
      if (candidate.isNotEmpty) {
        releasedAt = _normalizePokemonDate(candidate);
        break;
      }
    }
  }
  if (setTotal == null) {
    for (final key in const [
      'setPrintedTotal',
      'set_printed_total',
      'set.printedTotal',
      'setTotal',
      'set_total',
      'set.total',
    ]) {
      final raw = card[key];
      if (raw is num) {
        setTotal = raw.toInt();
        break;
      }
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) {
          setTotal = parsed;
          break;
        }
      }
    }
  }
  if (setCode.isEmpty) {
    final dash = id.indexOf('-');
    if (dash > 0) {
      setCode = id.substring(0, dash).trim().toLowerCase();
    }
  }

  final number = ((card['number'] as String?) ?? '').trim();
  final rarity = ((card['rarity'] as String?) ?? '').trim();
  final artist = ((card['artist'] as String?) ?? '').trim();
  final supertype = ((card['supertype'] as String?) ?? '').trim();
  final types = (card['types'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .map((it) => it.trim())
      .where((it) => it.isNotEmpty)
      .toList(growable: false);
  final subtypes = (card['subtypes'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .map((it) => it.trim())
      .where((it) => it.isNotEmpty)
      .toList(growable: false);
  final typeParts = <String>[
    if (supertype.isNotEmpty) supertype,
    if (types.isNotEmpty) ...types,
    if (subtypes.isNotEmpty) '(${subtypes.join(', ')})',
  ];
  final typeLine = typeParts.join(' ').trim();
  final colorCodes = _pokemonTypeNamesToColorCodes(types);
  final minAttackEnergyCost = _extractPokemonMinAttackEnergyCost(card);

  final images = card['images'];
  String imageSmall = '';
  String imageLarge = '';
  if (images is Map) {
    final imageMap = Map<String, dynamic>.from(images);
    imageSmall = ((imageMap['small'] as String?) ?? '').trim();
    imageLarge = ((imageMap['large'] as String?) ?? '').trim();
  }

  return {
    'id': id,
    'name': name,
    'set_code': setCode,
    'set_name': setName,
    'set_total': setTotal,
    'collector_number': number,
    'rarity': rarity,
    'type_line': typeLine,
    'mana_value': minAttackEnergyCost,
    'colors': colorCodes,
    'color_identity': colorCodes,
    'released_at': releasedAt,
    'artist': artist,
    'image_small': imageSmall,
    'image_large': imageLarge,
  };
}

int? _extractPokemonMinAttackEnergyCost(Map<String, dynamic> card) {
  final attacks = card['attacks'];
  if (attacks is! List || attacks.isEmpty) {
    return null;
  }
  int? best;
  for (final attack in attacks) {
    if (attack is! Map) {
      continue;
    }
    final attackMap = Map<String, dynamic>.from(attack);
    int? cost;
    final converted = attackMap['convertedEnergyCost'];
    if (converted is num) {
      cost = converted.toInt();
    } else if (converted is String) {
      cost = int.tryParse(converted.trim());
    }
    cost ??= ((attackMap['cost'] as List<dynamic>?) ?? const [])
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .length;
    if (best == null || cost < best) {
      best = cost;
    }
  }
  return best;
}

String _normalizePokemonDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  return value.replaceAll('/', '-');
}

List<String> _pokemonTypeNamesToColorCodes(List<String> types) {
  if (types.isEmpty) {
    return const ['N'];
  }
  final codes = <String>{};
  for (final raw in types) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) {
      continue;
    }
    switch (value) {
      case 'grass':
        codes.add('G');
        break;
      case 'fire':
        codes.add('R');
        break;
      case 'fighting':
        codes.add('F');
        break;
      case 'dragon':
        codes.add('D');
        break;
      case 'lightning':
      case 'electric':
        codes.add('L');
        break;
      case 'water':
      case 'ice':
        codes.add('U');
        break;
      case 'psychic':
      case 'darkness':
      case 'dark':
      case 'ghost':
        codes.add('B');
        break;
      case 'fairy':
      case 'white':
        codes.add('W');
        break;
      case 'metal':
      case 'steel':
        codes.add('M');
        break;
      case 'colorless':
        codes.add('C');
        break;
      default:
        codes.add('N');
        break;
    }
  }
  if (codes.isEmpty) {
    return const ['N'];
  }
  return codes.toList(growable: false);
}
