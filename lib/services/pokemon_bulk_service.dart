import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../db/canonical_catalog_store.dart';
import '../domain/domain_models.dart';
import '../providers/tcgdex_pokemon_provider.dart';
import 'pokemon_dataset_manifest.dart';
import 'pokemon_canonical_import_service.dart';

class PokemonBulkService {
  PokemonBulkService._();

  static final PokemonBulkService instance = PokemonBulkService._();

  static const String datasetVersion = PokemonDatasetManifest.version;
  static const String _cardsEndpoint = 'https://api.pokemontcg.io/v2/cards';
  static const String _setsIndexEndpoint =
      'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/sets/en.json';
  static const int _pageSize = 250;
  static const String _prefsKeyInstalledVersion = 'pokemon_dataset_version';
  static const String _prefsKeyInstalledSource = 'pokemon_dataset_source';
  static const String _prefsKeyInstalledAt = 'pokemon_dataset_installed_at';
  static const String _prefsKeyManifestFingerprint =
      'pokemon_dataset_manifest_fingerprint';
  static const String _prefsKeyInstalledProfile =
      'pokemon_dataset_profile_installed';
  static const String _prefsKeyInstalledLanguages =
      'pokemon_dataset_languages_installed';
  static const int _maxAttemptsPerPage = 4;
  static const String _canonicalSnapshotFileName =
      'canonical_catalog_snapshot.json';
  static const String _tcgdexDistributionZipUrl =
      'https://codeload.github.com/tcgdex/distribution/zip/refs/heads/master';
  static const String _tcgdexDistributionZipFileName =
      'tcgdex_distribution_master.zip';
  static const String _hostedBundleManifestUrl =
      'https://github.com/Navalik/tcg_tracker/releases/latest/download/manifest.json';
  static const String _hostedCanonicalSnapshotAssetName =
      'canonical_catalog_snapshot.json.gz';
  static const String _fixedProfile = 'full';
  static const int _minFullProfileCards = 10000;
  static const String _apiKey = String.fromEnvironment(
    'POKEMON_TCG_API_KEY',
    defaultValue: '',
  );

  void _logPhaseDuration(String label, Stopwatch stopwatch) {
    final elapsed = stopwatch.elapsed;
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = elapsed.inMilliseconds
        .remainder(1000)
        .toString()
        .padLeft(3, '0');
    debugPrint(
      'Pokemon import phase "$label" took ${minutes}m $seconds.${millis}s',
    );
  }

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
    final remoteTotal = await _fetchApiTotalCount();
    final remoteFingerprint = remoteTotal?.toString();
    if (remoteFingerprint == null || remoteFingerprint.isEmpty) {
      return PokemonDatasetUpdateStatus(
        installed: true,
        updateAvailable: false,
        installedFingerprint: installedFingerprint,
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyInstalledVersion);
    await prefs.remove(_prefsKeyInstalledSource);
    await prefs.remove(_prefsKeyInstalledAt);
    await prefs.remove(_prefsKeyManifestFingerprint);
    await prefs.remove(_prefsKeyInstalledProfile);
    await prefs.remove(_prefsKeyInstalledLanguages);
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
    final selectedCanonicalLanguages =
        await _selectedPokemonCanonicalLanguages();
    final selectedLanguageSignature = await _selectedPokemonLanguageSignature();
    final languageLabel =
        selectedCanonicalLanguages
            .map((language) => language.code.toUpperCase())
            .toList(growable: false)
          ..sort();
    final totalStopwatch = Stopwatch()..start();
    final canonicalDownloadStopwatch = Stopwatch()..start();
    onStatus?.call(
      'Downloading Pokemon catalog (TCGdex, profile=${_fixedProfile.toUpperCase()}, lang=${languageLabel.join(",")})',
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
    _logPhaseDuration(
      'download canonical catalog snapshot',
      canonicalDownloadStopwatch,
    );

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
    _logPhaseDuration(
      'import canonical catalog snapshot',
      canonicalImportStopwatch,
    );

    final database = await ScryfallDatabase.instance.open();
    onProgress(0.70);
    var inserted = 0;
    String? manifestFingerprint;
    String source = '';
    final datasetDir = await _ensureDatasetDirectory();
    await _clearDatasetJsonCacheDirectory(datasetDir);
    onStatus?.call('Building legacy compatibility dataset');
    onProgress(0.72);
    final legacyBuildStopwatch = Stopwatch()..start();
    Object? canonicalLegacyError;
    Object? manifestError;
    Object? apiError;
    final client = http.Client();
    try {
      try {
        inserted = await _installFromCanonicalBatch(
          database: database,
          batch: canonicalBatch,
          languages: selectedCanonicalLanguages,
          onProgress: onProgress,
          progressStart: 0.74,
          progressEnd: 0.90,
        );
        source = 'tcgdex_canonical_snapshot';
        if (inserted < _minFullProfileCards) {
          canonicalLegacyError = StateError(
            'pokemon_full_dataset_too_small:$inserted',
          );
          inserted = 0;
          source = '';
        }
      } catch (error) {
        canonicalLegacyError = error;
      }
      if (inserted <= 0) {
        try {
          onStatus?.call('Downloading sets index (GitHub)');
          onProgress(0.46);
          inserted = await _installFromFullManifest(
            database: database,
            client: client,
            onProgress: onProgress,
            progressStart: 0.74,
            progressEnd: 0.90,
          );
          onStatus?.call('Downloaded from GitHub dataset');
          manifestFingerprint = await _fetchManifestFingerprint(client: client);
          source = 'github_manifest_full';
          if (inserted < _minFullProfileCards) {
            manifestError = StateError(
              'pokemon_full_dataset_too_small:$inserted',
            );
            inserted = 0;
            source = '';
          }
        } catch (error) {
          manifestError = error;
        }
        if (inserted <= 0) {
          try {
            onStatus?.call('GitHub failed, switching to Pokemon API');
            inserted = await _installFromApi(
              database: database,
              client: client,
              onProgress: onProgress,
              progressStart: 0.76,
              progressEnd: 0.90,
            );
            source = 'api_v2_full_fallback';
            onStatus?.call('Downloading from Pokemon API');
            if (inserted < _minFullProfileCards) {
              apiError = StateError('pokemon_full_dataset_too_small:$inserted');
              inserted = 0;
              source = '';
            }
          } catch (error) {
            apiError = error;
          }
        }
      }
    } finally {
      client.close();
    }

    if (inserted <= 0) {
      final details = [
        if (canonicalLegacyError != null)
          'canonical=${canonicalLegacyError.toString()}',
        if (manifestError != null) 'manifest=${manifestError.toString()}',
        if (apiError != null) 'api=${apiError.toString()}',
      ].join(';');
      throw HttpException(
        'pokemon_dataset_install_failed${details.isEmpty ? '' : ':$details'}',
      );
    }
    if (inserted < _minFullProfileCards) {
      throw HttpException(
        'pokemon_dataset_install_failed:full_too_small:$inserted',
      );
    }
    legacyBuildStopwatch.stop();
    _logPhaseDuration(
      'build legacy compatibility dataset',
      legacyBuildStopwatch,
    );

    final finalizeStopwatch = Stopwatch()..start();
    onStatus?.call('Finalizing local database');
    onProgress(0.93);
    await ScryfallDatabase.instance.rebuildPrintedNameSearchIndex();
    onProgress(0.95);
    await database.rebuildFts();
    onProgress(0.97);
    await backfillSetNames();
    onProgress(0.99);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyInstalledVersion, datasetVersion);
    await prefs.setString(_prefsKeyInstalledSource, 'tcgdex+$source');
    await prefs.setInt(
      _prefsKeyInstalledAt,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await prefs.setString(_prefsKeyInstalledProfile, _fixedProfile);
    await prefs.setString(
      _prefsKeyInstalledLanguages,
      selectedLanguageSignature,
    );
    final fingerprint = manifestFingerprint;
    if (fingerprint != null && fingerprint.isNotEmpty) {
      await prefs.setString(_prefsKeyManifestFingerprint, fingerprint);
    }
    finalizeStopwatch.stop();
    _logPhaseDuration('finalize local database', finalizeStopwatch);
    totalStopwatch.stop();
    _logPhaseDuration('full pokemon install', totalStopwatch);
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
    required List<TcgCardLanguage> languages,
    required String languageSignature,
    required bool allowUseExistingSnapshot,
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    final normalizedProfile = profile.trim().toLowerCase();
    final requestedLanguageCodes = languages
        .map((language) => language.code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    final snapshot = await _readCanonicalSnapshotPayload();
    if (allowUseExistingSnapshot &&
        snapshot != null &&
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
      final missingLanguages = missingCodes
          .map(_languageFromCode)
          .whereType<TcgCardLanguage>()
          .toList(growable: false);
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
        onStatus?.call(
          'Downloading Pokemon language delta: ${missingCodes.join(', ').toUpperCase()}',
        );
        CanonicalCatalogImportBatch deltaBatch;
        try {
          deltaBatch = await _importCanonicalProfileBatchFromDistribution(
            profile: normalizedProfile,
            languages: missingLanguages,
            onProgress: onProgress,
            onStatus: onStatus,
          );
        } catch (_) {
          deltaBatch = await _importCanonicalProfileBatch(
            profile: normalizedProfile,
            languages: missingLanguages,
            onProgress: onProgress,
            onStatus: onStatus,
          );
        }
        final merged = _mergeCanonicalCatalogBatches(
          snapshot.batch,
          deltaBatch,
        );
        await _writeCanonicalCatalogSnapshot(
          merged,
          profile: normalizedProfile,
          languageSignature: _normalizeLanguageSignature({
            ...existingLanguageCodes,
            ...missingCodes,
          }),
        );
        onProgress(1);
        return merged;
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
    if (requestedLanguageCodes.contains('it')) {
      throw const HttpException('pokemon_hosted_bundle_required_for_it');
    }

    CanonicalCatalogImportBatch batch;
    try {
      batch = await _importCanonicalProfileBatchFromDistribution(
        profile: normalizedProfile,
        languages: languages,
        onProgress: onProgress,
        onStatus: onStatus,
      );
    } catch (_) {
      batch = await _importCanonicalProfileBatch(
        profile: normalizedProfile,
        languages: languages,
        onProgress: onProgress,
        onStatus: onStatus,
      );
    }
    await _writeCanonicalCatalogSnapshot(
      batch,
      profile: normalizedProfile,
      languageSignature: languageSignature,
    );
    return batch;
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
    try {
      onStatus?.call('Checking hosted Pokemon bundle');
      onProgress(0.05);
      final manifestRaw = await _fetchJsonWithRetry(
        client: client,
        uri: Uri.parse(_hostedBundleManifestUrl),
        retryAttempts: 2,
        requestTimeout: const Duration(seconds: 20),
      );
      final manifestParsed = jsonDecode(manifestRaw);
      if (manifestParsed is! Map<String, dynamic>) {
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
          final assetPath = _resolveCanonicalSnapshotAssetPathFromBundle(bundle);
          if (assetPath == null || assetPath.trim().isEmpty) {
            return null;
          }
          final assetUri = Uri.parse(
            'https://github.com/Navalik/tcg_tracker/releases/latest/download/$assetPath',
          );
          if (!_isAllowedDownloadUri(assetUri.toString())) {
            return null;
          }
          onStatus?.call('Downloading hosted Pokemon snapshot');
          final gzipBytes = await _fetchBytesWithRetry(
            client: client,
            uri: assetUri,
            onProgress: (value) => onProgress(
              ((i + value) / selectedBundles.length).clamp(0.08, 0.98),
            ),
          );
          onStatus?.call('Preparing hosted Pokemon snapshot');
          final jsonBytes = GZipDecoder().decodeBytes(gzipBytes);
          final jsonText = utf8.decode(jsonBytes, allowMalformed: true);
          final parsed = jsonDecode(jsonText);
          if (parsed is! Map<String, dynamic>) {
            return null;
          }
          final downloadedProfile =
              (parsed['profile'] as String?)?.trim().toLowerCase() ?? '';
          if (downloadedProfile.isNotEmpty && downloadedProfile != profile) {
            return null;
          }
          final downloadedSignature =
              (parsed['languages_signature'] as String?)?.trim().toLowerCase() ??
              '';
          if (downloadedSignature.isNotEmpty) {
            downloadedLanguages.addAll(
              _languageCodeSetFromSignature(downloadedSignature),
            );
          } else {
            downloadedLanguages.addAll(
              _bundleLanguageSet(bundle),
            );
          }
          final batchJson = parsed['batch'];
          if (batchJson is! Map) {
            return null;
          }
          final batch = canonicalCatalogBatchFromJson(
            Map<String, dynamic>.from(batchJson),
          );
          if (batch.cards.isEmpty || batch.printings.isEmpty) {
            return null;
          }
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
        await _writeCanonicalCatalogSnapshot(
          mergedBatch,
          profile: profile.trim().toLowerCase(),
          languageSignature: mergedSignature,
        );
        onStatus?.call('Using hosted Pokemon snapshot');
        onProgress(1);
        return mergedBatch;
      }

      String? assetPath;
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
          assetPath = path.isEmpty ? name : path;
          break;
        }
      }
      assetPath ??= _hostedCanonicalSnapshotAssetName;
      final assetUri = Uri.parse(
        'https://github.com/Navalik/tcg_tracker/releases/latest/download/$assetPath',
      );
      if (!_isAllowedDownloadUri(assetUri.toString())) {
        return null;
      }
      onStatus?.call('Downloading hosted Pokemon snapshot');
      final gzipBytes = await _fetchBytesWithRetry(
        client: client,
        uri: assetUri,
        onProgress: (value) => onProgress((0.08 + (value * 0.90)).clamp(0, 1)),
      );
      onStatus?.call('Preparing hosted Pokemon snapshot');
      final jsonBytes = GZipDecoder().decodeBytes(gzipBytes);
      final jsonText = utf8.decode(jsonBytes, allowMalformed: true);
      final parsed = jsonDecode(jsonText);
      if (parsed is! Map<String, dynamic>) {
        return null;
      }
      final downloadedProfile =
          (parsed['profile'] as String?)?.trim().toLowerCase() ?? '';
      if (downloadedProfile.isNotEmpty && downloadedProfile != profile) {
        return null;
      }
      final downloadedSignature =
          (parsed['languages_signature'] as String?)?.trim().toLowerCase() ??
          '';
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
      final batch = canonicalCatalogBatchFromJson(
        Map<String, dynamic>.from(batchJson),
      );
      if (batch.cards.isEmpty || batch.printings.isEmpty) {
        return null;
      }
      final snapshotFile = await _canonicalSnapshotFile();
      await snapshotFile.writeAsString(jsonText);
      onStatus?.call('Using hosted Pokemon snapshot');
      onProgress(1);
      return batch;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<CanonicalCatalogImportBatch> _importCanonicalProfileBatch({
    required String profile,
    required List<TcgCardLanguage> languages,
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    final service = PokemonCanonicalImportService();
    CanonicalCatalogImportBatch? batch;
    await service.importProfile(
      profile: profile,
      languages: languages,
      onProgress: onProgress,
      onStatus: onStatus,
      onBatchBuilt: (value) {
        batch = value;
      },
    );
    if (batch == null) {
      throw const FormatException('pokemon_canonical_snapshot_empty');
    }
    return batch!;
  }

  Future<CanonicalCatalogImportBatch>
  _importCanonicalProfileBatchFromDistribution({
    required String profile,
    required List<TcgCardLanguage> languages,
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    final archive = await _decodeTcgdexDistributionArchive(
      onProgress: (value) => onProgress((value * 0.35).clamp(0.0, 0.35)),
      onStatus: onStatus,
    );

    final fileByPath = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile) {
        fileByPath[file.name.toLowerCase()] = file;
      }
    }

    final setIndexPattern = RegExp(
      r'^[^/]+/v2/([a-z]{2})/sets/[^/]+/index\.json$',
      caseSensitive: false,
    );
    final setEntriesByLanguage = <String, Map<String, _ArchiveSetEntry>>{};
    var scannedSetIndexes = 0;
    final indexCandidates = archive.files
        .where((file) => file.isFile && file.name.endsWith('/index.json'))
        .toList(growable: false);
    for (final file in indexCandidates) {
      final lowerPath = file.name.toLowerCase();
      final match = setIndexPattern.firstMatch(lowerPath);
      if (match == null) {
        continue;
      }
      final languageCode = match.group(1)?.trim().toLowerCase() ?? '';
      final payload = _readArchiveJsonMap(file);
      final setId = (payload?['id'] as String?)?.trim().toLowerCase() ?? '';
      if (languageCode.isEmpty || setId.isEmpty || payload == null) {
        continue;
      }
      final dirPath = file.name.substring(
        0,
        file.name.length - '/index.json'.length,
      );
      setEntriesByLanguage.putIfAbsent(
        languageCode,
        () => <String, _ArchiveSetEntry>{},
      )[setId] = _ArchiveSetEntry(
        setId: setId,
        indexPath: file.name,
        dirPath: dirPath,
        payload: payload,
      );
      scannedSetIndexes += 1;
      if (scannedSetIndexes % 64 == 0) {
        onProgress(
          (0.35 + ((scannedSetIndexes / (indexCandidates.length + 1)) * 0.10))
              .clamp(0.0, 0.45),
        );
      }
    }

    final selectedSetCodes = _resolveProfileSetCodesFromDistribution(
      setEntriesByLanguage: setEntriesByLanguage,
    );
    if (selectedSetCodes.isEmpty) {
      throw const FormatException('pokemon_canonical_snapshot_empty');
    }

    final provider = TcgdexPokemonProvider();
    final canonicalLanguage = TcgdexPokemonProvider.canonicalLanguage;
    final canonicalSetEntries = setEntriesByLanguage[canonicalLanguage.code];
    if (canonicalSetEntries == null || canonicalSetEntries.isEmpty) {
      throw const FormatException('pokemon_canonical_snapshot_empty');
    }

    final cardsById = <String, CatalogCard>{};
    final setsById = <String, CatalogSet>{};
    final printingsById = <String, CardPrintingRef>{};
    final cardLocalizationsByKey = <String, LocalizedCardData>{};
    final setLocalizationsByKey = <String, LocalizedSetData>{};
    final providerMappings = <String, ProviderMappingRecord>{};
    final priceSnapshotsByKey = <String, PriceSnapshot>{};

    var totalCards = 0;
    for (final setCode in selectedSetCodes) {
      final entry = canonicalSetEntries[setCode];
      if (entry == null) {
        continue;
      }
      final cards = entry.payload['cards'];
      if (cards is List) {
        totalCards += cards.length;
      }
    }
    if (totalCards <= 0) {
      throw const FormatException('pokemon_canonical_snapshot_empty');
    }

    var processedCards = 0;
    var processedSets = 0;
    for (final setCode in selectedSetCodes) {
      final canonicalSetEntry = canonicalSetEntries[setCode];
      if (canonicalSetEntry == null) {
        continue;
      }
      onStatus?.call(
        'Importing set ${setCode.toUpperCase()} (${processedSets + 1}/${selectedSetCodes.length})',
      );
      final localizedSetEntries = <TcgCardLanguage, _ArchiveSetEntry>{
        canonicalLanguage: canonicalSetEntry,
      };
      for (final language in languages) {
        if (language == canonicalLanguage) {
          continue;
        }
        final byLanguage = setEntriesByLanguage[language.code];
        final localized = byLanguage?[setCode];
        if (localized != null) {
          localizedSetEntries[language] = localized;
        }
      }

      for (final entry in localizedSetEntries.entries) {
        final mappedSet = provider.mapSetPayload(
          Map<String, dynamic>.from(entry.value.payload),
          language: entry.key,
        );
        if (mappedSet == null) {
          continue;
        }
        setsById[mappedSet.setId] = mappedSet;
        for (final localized in mappedSet.localizedData) {
          setLocalizationsByKey['${localized.setId}:${localized.language.code}'] =
              localized;
        }
      }

      final rawCards = canonicalSetEntry.payload['cards'];
      if (rawCards is! List) {
        processedSets += 1;
        continue;
      }

      for (final card in rawCards) {
        if (card is! Map) {
          continue;
        }
        final cardMap = Map<String, dynamic>.from(card);
        final localId = (cardMap['localId'] as String?)?.trim();
        final fallbackId = (cardMap['id'] as String?)?.trim().toLowerCase();
        if ((localId == null || localId.isEmpty) &&
            (fallbackId == null || fallbackId.isEmpty)) {
          continue;
        }
        final cardFolder = localId?.isNotEmpty == true ? localId! : fallbackId!;
        final canonicalCardPath =
            '${canonicalSetEntry.dirPath}/$cardFolder/index.json';
        final canonicalCardFile = fileByPath[canonicalCardPath.toLowerCase()];
        if (canonicalCardFile == null) {
          continue;
        }
        final canonicalRaw = _readArchiveJsonMap(canonicalCardFile);
        if (canonicalRaw == null) {
          continue;
        }
        final canonicalPayload = _mergeCardWithSetPayload(
          canonicalRaw,
          canonicalSetEntry.payload,
        );
        final localizedPayloads = <TcgCardLanguage, Map<String, dynamic>>{
          canonicalLanguage: canonicalPayload,
        };
        for (final entry in localizedSetEntries.entries) {
          if (entry.key == canonicalLanguage) {
            continue;
          }
          final localizedCardPath =
              '${entry.value.dirPath}/$cardFolder/index.json';
          final localizedCardFile = fileByPath[localizedCardPath.toLowerCase()];
          if (localizedCardFile == null) {
            continue;
          }
          final localizedRaw = _readArchiveJsonMap(localizedCardFile);
          if (localizedRaw == null) {
            continue;
          }
          localizedPayloads[entry.key] = _mergeCardWithSetPayload(
            localizedRaw,
            entry.value.payload,
          );
        }

        final bundle = provider.mapPrintingBundleFromPayloads(
          canonicalPayload,
          localizedPayloads,
        );
        if (bundle == null) {
          continue;
        }
        cardsById[bundle.card.cardId] = bundle.card;
        setsById[bundle.set.setId] = bundle.set;
        printingsById[bundle.printing.printingId] = bundle.printing;
        for (final localized in bundle.card.localizedData) {
          cardLocalizationsByKey['${localized.cardId}:${localized.language.code}'] =
              localized;
        }
        for (final localized in bundle.set.localizedData) {
          setLocalizationsByKey['${localized.setId}:${localized.language.code}'] =
              localized;
        }
        for (final mapping in bundle.printing.providerMappings) {
          providerMappings['${mapping.providerId.value}:${mapping.objectType}:${mapping.providerObjectId}:${bundle.printing.printingId}'] =
              ProviderMappingRecord(
                mapping: mapping,
                cardId: bundle.card.cardId,
                printingId: bundle.printing.printingId,
                setId: bundle.set.setId,
              );
        }
        final snapshots = provider.extractPriceSnapshotsFromBundle(bundle);
        for (final snapshot in snapshots) {
          priceSnapshotsByKey['${snapshot.printingId}:${snapshot.sourceId.value}:${snapshot.currencyCode}:${snapshot.finishKey ?? 'default'}'] =
              snapshot;
        }
        processedCards += 1;
        if (processedCards % 32 == 0) {
          final cardProgress = processedCards / totalCards;
          onProgress((0.45 + (cardProgress * 0.55)).clamp(0.0, 1.0));
        }
      }
      processedSets += 1;
    }

    onProgress(1);
    return CanonicalCatalogImportBatch(
      cards: cardsById.values.toList(growable: false),
      sets: setsById.values.toList(growable: false),
      printings: printingsById.values.toList(growable: false),
      cardLocalizations: cardLocalizationsByKey.values.toList(growable: false),
      setLocalizations: setLocalizationsByKey.values.toList(growable: false),
      providerMappings: providerMappings.values.toList(growable: false),
      priceSnapshots: priceSnapshotsByKey.values.toList(growable: false),
    );
  }

  Future<Archive> _decodeTcgdexDistributionArchive({
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Downloading Pokemon catalog snapshot');
    final archiveFile = await _downloadTcgdexDistributionZip(
      onProgress: onProgress,
    );
    onStatus?.call('Preparing Pokemon catalog snapshot');
    onProgress(1);
    final input = InputFileStream(archiveFile.path);
    try {
      return ZipDecoder().decodeStream(input, verify: false);
    } finally {
      input.close();
    }
  }

  Future<File> _downloadTcgdexDistributionZip({
    required void Function(double progress) onProgress,
  }) async {
    final datasetDir = await _ensureDatasetDirectory();
    final targetFile = File(
      p.join(datasetDir.path, _tcgdexDistributionZipFileName),
    );
    if (await targetFile.exists()) {
      final size = await targetFile.length();
      if (size > 10 * 1024 * 1024) {
        onProgress(1);
        return targetFile;
      }
    }
    final tempFile = File('${targetFile.path}.part');
    final client = http.Client();
    try {
      await _downloadFileWithProgress(
        client: client,
        uri: Uri.parse(_tcgdexDistributionZipUrl),
        targetFile: tempFile,
        onProgress: onProgress,
      );
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
      return targetFile;
    } finally {
      client.close();
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _downloadFileWithProgress({
    required http.Client client,
    required Uri uri,
    required File targetFile,
    required void Function(double fraction) onProgress,
  }) async {
    const assumedStreamLengthBytes = 600 * 1024 * 1024;
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttemptsPerPage; attempt++) {
      IOSink? sink;
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
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          sink = targetFile.openWrite();
          final expected = streamed.contentLength ?? 0;
          var received = 0;
          await for (final chunk in streamed.stream) {
            sink.add(chunk);
            received += chunk.length;
            if (expected > 0) {
              onProgress((received / expected).clamp(0.0, 1.0));
            } else {
              // Some hosts don't provide Content-Length; keep progress moving.
              final estimated = (received / assumedStreamLengthBytes).clamp(
                0.0,
                0.98,
              );
              onProgress(estimated);
            }
          }
          await sink.flush();
          await sink.close();
          onProgress(1);
          return;
        }
      } on TimeoutException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      } finally {
        await sink?.close();
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

  List<String> _resolveProfileSetCodesFromDistribution({
    required Map<String, Map<String, _ArchiveSetEntry>> setEntriesByLanguage,
  }) {
    final allSetCodes = (setEntriesByLanguage['en'] ?? const {}).keys.toList()
      ..sort();
    return allSetCodes;
  }

  Map<String, dynamic>? _readArchiveJsonMap(ArchiveFile file) {
    try {
      final content = file.readBytes();
      if (content == null) {
        return null;
      }
      final raw = utf8.decode(content, allowMalformed: true);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, dynamic> _mergeCardWithSetPayload(
    Map<String, dynamic> cardPayload,
    Map<String, dynamic> setPayload,
  ) {
    final merged = Map<String, dynamic>.from(cardPayload);
    final cardSet = merged['set'];
    final mergedSet = <String, dynamic>{};
    if (setPayload.isNotEmpty) {
      mergedSet.addAll(setPayload);
    }
    if (cardSet is Map) {
      mergedSet.addAll(Map<String, dynamic>.from(cardSet));
    }
    if (mergedSet.isNotEmpty) {
      merged['set'] = mergedSet;
    }
    return merged;
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
    _logPhaseDuration(
      'restore canonical catalog snapshot',
      canonicalRestoreStopwatch,
    );
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
    _logPhaseDuration(
      'reimport legacy compatibility dataset from cache',
      legacyReimportStopwatch,
    );

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
    _logPhaseDuration('full pokemon cache reimport', totalStopwatch);
    onStatus?.call('Completed');
    onProgress(1);
  }

  Future<void> reimportOrInstallForCurrentSelection({
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
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
    await installDataset(
      onProgress: onProgress,
      onStatus: onStatus,
      allowLanguageDeltaFromCache: true,
    );
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
    final canonicalRestoreStopwatch = Stopwatch()..start();
    await _importCanonicalCatalogBatch(
      snapshot.batch,
      onProgress: (_) {},
      onStatus: null,
    );
    canonicalRestoreStopwatch.stop();
    _logPhaseDuration(
      'restore canonical catalog snapshot',
      canonicalRestoreStopwatch,
    );

    onStatus?.call('Rebuilding local Pokemon database');
    onProgress(0.08);
    final legacyReimportStopwatch = Stopwatch()..start();
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
    legacyReimportStopwatch.stop();
    _logPhaseDuration(
      'reimport legacy compatibility dataset from canonical snapshot',
      legacyReimportStopwatch,
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
    _logPhaseDuration('full pokemon canonical cache reimport', totalStopwatch);
    onStatus?.call('Completed');
    onProgress(1);
  }

  Future<List<TcgCardLanguage>> _selectedPokemonCanonicalLanguages() async {
    // Intermediate release strategy: always build/download the full Pokemon
    // canonical catalog for EN+IT to guarantee deterministic local coverage.
    return const <TcgCardLanguage>[TcgCardLanguage.en, TcgCardLanguage.it];
  }

  Future<String> _selectedPokemonLanguageSignature() async {
    final languages = await _selectedPokemonCanonicalLanguages();
    final codes =
        languages
            .map((language) => language.code.trim().toLowerCase())
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

  Future<void> _writeCanonicalCatalogSnapshot(
    CanonicalCatalogImportBatch batch, {
    required String profile,
    required String languageSignature,
  }) async {
    final file = await _canonicalSnapshotFile();
    final payload = <String, Object?>{
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

  List<String> _bundleRequiresList(Map<String, dynamic> bundle) {
    return (bundle['requires'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  String? _resolveCanonicalSnapshotAssetPathFromBundle(
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
      final candidate = path.isEmpty ? name : path;
      final normalized = candidate.toLowerCase();
      if (normalized.endsWith('.json.gz') &&
          normalized.contains('canonical_catalog_snapshot')) {
        return candidate;
      }
    }
    return null;
  }

  List<Map<String, dynamic>>? _selectHostedBundlesForMissingLanguages({
    required List<Map<String, dynamic>> bundles,
    required String profile,
    required Set<String> requiredLanguages,
    required Set<String> existingLanguages,
  }) {
    final profileBundles = bundles.where((bundle) {
      final bundleProfile =
          (bundle['profile'] as String?)?.trim().toLowerCase() ?? '';
      return bundleProfile.isEmpty ||
          bundleProfile == profile.trim().toLowerCase();
    }).toList(growable: false);
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

  TcgCardLanguage? _languageFromCode(String code) {
    final normalized = code.trim().toLowerCase();
    for (final language in TcgCardLanguage.values) {
      if (language.code == normalized) {
        return language;
      }
    }
    return null;
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
      for (final value in delta.printings) value.printingId: value,
    };
    final cardLocalizations = <String, LocalizedCardData>{
      for (final value in base.cardLocalizations)
        '${value.cardId}:${value.language.code}': value,
      for (final value in delta.cardLocalizations)
        '${value.cardId}:${value.language.code}': value,
    };
    final setLocalizations = <String, LocalizedSetData>{
      for (final value in base.setLocalizations)
        '${value.setId}:${value.language.code}': value,
      for (final value in delta.setLocalizations)
        '${value.setId}:${value.language.code}': value,
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
    final managedClient = client ?? http.Client();
    final ownClient = client == null;
    try {
      final names = await _fetchSetNamesIndex(client: managedClient);
      if (names.isEmpty) {
        return 0;
      }
      return ScryfallDatabase.instance.backfillSetNames(names);
    } catch (_) {
      return 0;
    } finally {
      if (ownClient) {
        managedClient.close();
      }
    }
  }

  Future<int?> _fetchApiTotalCount({http.Client? client}) async {
    final managedClient = client ?? http.Client();
    final ownClient = client == null;
    try {
      final uri = Uri.parse(_cardsEndpoint).replace(
        queryParameters: const <String, String>{'page': '1', 'pageSize': '1'},
      );
      final payload = await _fetchJsonWithRetry(
        client: managedClient,
        uri: uri,
      );
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final total = (decoded['totalCount'] as num?)?.toInt();
        return total;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (ownClient) {
        managedClient.close();
      }
    }
  }

  Future<int> _installFromCanonicalBatch({
    required AppDatabase database,
    required CanonicalCatalogImportBatch batch,
    required List<TcgCardLanguage> languages,
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
      final langCode = localized.language.code.trim().toLowerCase();
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
      final langCode = localized.language.code.trim().toLowerCase();
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
        .map((language) => language.code.trim().toLowerCase())
        .where((code) => code.isNotEmpty && code != 'en')
        .followedBy(
          languages
              .map((language) => language.code.trim().toLowerCase())
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
        final localizedCard =
            _selectCardLocalization(
              cardId: card.cardId,
              localizedCardsByLanguage: localizedCardsByLanguage,
              preferredLanguageCodes: preferredLanguageCodes,
            ) ??
            card.defaultLocalizedData;
        final localizedSet = set == null
            ? null
            : (_selectSetLocalization(
                    setId: set.setId,
                    localizedSetsByLanguage: localizedSetsByLanguage,
                    preferredLanguageCodes: preferredLanguageCodes,
                  ) ??
                  set.defaultLocalizedData);
        final primaryName = (localizedCard?.name ?? card.canonicalName).trim();
        final secondaryName = _pickSecondaryCardName(
          cardId: card.cardId,
          preferredLanguageCodes: preferredLanguageCodes,
          localizedCardsByLanguage: localizedCardsByLanguage,
          primaryName: primaryName,
        );
        final languageCode = (localizedCard?.language.code ?? 'en')
            .trim()
            .toLowerCase();
        final row = _canonicalPrintingToLegacyRow(
          card: card,
          printing: printing,
          set: set,
          localizedCard: localizedCard,
          localizedSet: localizedSet,
          languageCode: languageCode.isEmpty ? 'en' : languageCode,
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
      if (mapping.providerId == CatalogProviderId.tcgdex &&
          (mapping.objectType == 'printing' || mapping.objectType == 'card')) {
        final value = mapping.providerObjectId.trim();
        if (value.isNotEmpty) {
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

  Future<int> _installFromApi({
    required AppDatabase database,
    required http.Client client,
    required void Function(double progress) onProgress,
    required double progressStart,
    required double progressEnd,
  }) async {
    if (!_isAllowedDownloadUri(_cardsEndpoint)) {
      throw const FormatException('pokemon_dataset_url_not_allowed');
    }
    var inserted = 0;
    await database.transaction(() async {
      await ScryfallDatabase.instance.deleteAllCards(database);
      var page = 1;
      var totalCount = 0;
      final range = (progressEnd - progressStart).clamp(0.05, 0.95);
      while (true) {
        final pageProgress = progressStart + (page * (range / 120));
        onProgress(pageProgress.clamp(progressStart, progressEnd));
        final payload = await _fetchCardsPage(
          client: client,
          page: page,
          pageSize: _pageSize,
        );
        final responseTotal = (payload['totalCount'] as num?)?.toInt() ?? 0;
        if (totalCount == 0 && responseTotal > 0) {
          totalCount = responseTotal;
        }
        final data = payload['data'];
        if (data is! List || data.isEmpty) {
          break;
        }
        final mapped = <Map<String, dynamic>>[];
        for (final row in data) {
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
          await ScryfallDatabase.instance.insertPokemonCardsBatch(
            database,
            mapped,
          );
          inserted += mapped.length;
        }
        if (totalCount > 0) {
          final progress = progressStart + ((inserted / totalCount) * range);
          onProgress(progress.clamp(progressStart, progressEnd));
        }
        page += 1;
      }
    });
    if (inserted <= 0) {
      throw const FormatException('pokemon_dataset_empty');
    }
    return inserted;
  }

  Future<int> _installFromFullManifest({
    required AppDatabase database,
    required http.Client client,
    required void Function(double progress) onProgress,
    required double progressStart,
    required double progressEnd,
  }) async {
    if (!_isAllowedDownloadUri(_setsIndexEndpoint)) {
      throw const FormatException('pokemon_dataset_url_not_allowed');
    }
    final indexPayload = await _fetchJsonWithRetry(
      client: client,
      uri: Uri.parse(_setsIndexEndpoint),
      retryAttempts: 2,
      requestTimeout: const Duration(seconds: 12),
    );
    final parsed = jsonDecode(indexPayload);
    if (parsed is! List) {
      throw const FormatException('pokemon_sets_index_invalid_payload');
    }
    final setSpecs = <PokemonDatasetSet>[];
    for (final row in parsed) {
      if (row is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(row);
      final id = ((map['id'] as String?) ?? '').trim().toLowerCase();
      if (id.isEmpty) {
        continue;
      }
      setSpecs.add(
        PokemonDatasetSet(
          setCode: id,
          language: 'en',
          url:
              'https://raw.githubusercontent.com/PokemonTCG/pokemon-tcg-data/master/cards/en/$id.json',
        ),
      );
    }
    if (setSpecs.isEmpty) {
      throw const FormatException('pokemon_sets_index_empty');
    }

    final datasetDir = await _ensureDatasetDirectory();
    var inserted = 0;
    await database.transaction(() async {
      await ScryfallDatabase.instance.deleteAllCards(database);
      for (var i = 0; i < setSpecs.length; i++) {
        final range = (progressEnd - progressStart).clamp(0.05, 0.95);
        final setStart = progressStart + ((i / setSpecs.length) * range);
        final setAfterDownload = setStart + (range / setSpecs.length) * 0.35;
        onProgress(setStart.clamp(progressStart, progressEnd));
        final spec = setSpecs[i];
        final cards = await _downloadManifestSet(
          client: client,
          setSpec: spec,
          datasetDir: datasetDir,
          onDownloadProgress: (fraction) {
            final clamped = fraction.clamp(0.0, 1.0);
            final value = setStart + ((setAfterDownload - setStart) * clamped);
            onProgress(value.clamp(progressStart, progressEnd));
          },
        );
        onProgress(setAfterDownload.clamp(progressStart, progressEnd));
        final mapped = <Map<String, dynamic>>[];
        for (final row in cards) {
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
        final progress = progressStart + (((i + 1) / setSpecs.length) * range);
        onProgress(progress.clamp(progressStart, progressEnd));
      }
    });
    if (inserted <= 0) {
      throw const FormatException('pokemon_dataset_empty');
    }
    return inserted;
  }

  Future<List<dynamic>> _downloadManifestSet({
    required http.Client client,
    required PokemonDatasetSet setSpec,
    required Directory datasetDir,
    void Function(double fraction)? onDownloadProgress,
  }) async {
    if (!_isAllowedDownloadUri(setSpec.url)) {
      throw const FormatException('pokemon_dataset_url_not_allowed');
    }
    final uri = Uri.parse(setSpec.url);
    final payload = await _fetchJsonWithProgress(
      client: client,
      uri: uri,
      onProgress: onDownloadProgress,
    );
    final targetFile = File(
      p.join(
        datasetDir.path,
        '${setSpec.language.toLowerCase()}_${setSpec.setCode.toLowerCase()}.json',
      ),
    );
    await targetFile.writeAsString(payload, flush: true);
    final parsed = jsonDecode(payload);
    if (parsed is List) {
      return parsed;
    }
    if (parsed is Map<String, dynamic>) {
      final data = parsed['data'];
      if (data is List) {
        return data;
      }
    }
    throw const FormatException('pokemon_dataset_invalid_payload');
  }

  Future<String> _fetchJsonWithProgress({
    required http.Client client,
    required Uri uri,
    void Function(double fraction)? onProgress,
  }) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'user-agent': 'bindervault/1.0',
    };
    if (_apiKey.trim().isNotEmpty &&
        uri.host.toLowerCase() == 'api.pokemontcg.io') {
      headers['x-api-key'] = _apiKey.trim();
    }
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttemptsPerPage; attempt++) {
      try {
        final request = http.Request('GET', uri)..headers.addAll(headers);
        final streamed = await client
            .send(request)
            .timeout(const Duration(seconds: 35));
        if (streamed.statusCode != 200) {
          final retryable =
              streamed.statusCode == 404 ||
              streamed.statusCode == 429 ||
              streamed.statusCode >= 500;
          if (!retryable || attempt == _maxAttemptsPerPage) {
            throw HttpException('pokemon_api_http_${streamed.statusCode}');
          }
          lastError = HttpException('pokemon_api_http_${streamed.statusCode}');
        } else {
          final expected = streamed.contentLength ?? 0;
          var received = 0;
          final sink = BytesBuilder(copy: false);
          await for (final chunk in streamed.stream) {
            sink.add(chunk);
            received += chunk.length;
            if (expected > 0) {
              onProgress?.call((received / expected).clamp(0.0, 1.0));
            }
          }
          if (expected <= 0) {
            onProgress?.call(1);
          }
          return utf8.decode(sink.takeBytes(), allowMalformed: true);
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
    if (host == 'api.pokemontcg.io') {
      return true;
    }
    if (host == 'raw.githubusercontent.com') {
      final normalizedPath = uri.path.toLowerCase();
      return normalizedPath.startsWith('/pokemontcg/pokemon-tcg-data/');
    }
    if (host == 'github.com') {
      final normalizedPath = uri.path.toLowerCase();
      return normalizedPath.startsWith(
            '/navalik/tcg_tracker/releases/latest/download/',
          ) ||
          normalizedPath.startsWith('/navalik/tcg_tracker/releases/download/');
    }
    return false;
  }

  Future<Map<String, dynamic>> _fetchCardsPage({
    required http.Client client,
    required int page,
    required int pageSize,
  }) async {
    final requestUris = <Uri>[
      Uri.parse(_cardsEndpoint).replace(
        queryParameters: <String, String>{
          'page': '$page',
          'pageSize': '$pageSize',
          'select':
              'id,name,number,rarity,supertype,types,subtypes,set.id,set.name,set.releaseDate,images.small,images.large',
        },
      ),
      Uri.parse(_cardsEndpoint).replace(
        queryParameters: <String, String>{
          'page': '$page',
          'pageSize': '$pageSize',
        },
      ),
      Uri.parse(_cardsEndpoint).replace(
        queryParameters: <String, String>{
          'q': '*',
          'page': '$page',
          'pageSize': '$pageSize',
        },
      ),
      Uri.parse('$_cardsEndpoint/').replace(
        queryParameters: <String, String>{
          'q': '*',
          'page': '$page',
          'pageSize': '$pageSize',
        },
      ),
    ];
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttemptsPerPage; attempt++) {
      for (final uri in requestUris) {
        try {
          final payload = await _fetchJsonWithRetry(
            client: client,
            uri: uri,
            retryAttempts: 1,
          );
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          throw const FormatException('pokemon_api_invalid_payload');
        } on HttpException catch (error) {
          final status = _parsePokemonHttpStatus(error.message);
          if (status == 404 && page > 1) {
            return const <String, dynamic>{'data': <dynamic>[]};
          }
          lastError = error;
        } on FormatException catch (error) {
          lastError = error;
        } on TimeoutException catch (error) {
          lastError = error;
        } on SocketException catch (error) {
          lastError = error;
        } on http.ClientException catch (error) {
          lastError = error;
        }
      }
      if (attempt == _maxAttemptsPerPage) {
        break;
      }
      await Future<void>.delayed(_retryDelay(attempt));
    }

    if (lastError is HttpException) {
      throw lastError;
    }
    if (lastError is FormatException) {
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
    if (_apiKey.trim().isNotEmpty &&
        uri.host.toLowerCase() == 'api.pokemontcg.io') {
      headers['x-api-key'] = _apiKey.trim();
    }
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

  Future<String?> _fetchManifestFingerprint({
    http.Client? client,
  }) async {
    final managedClient = client ?? http.Client();
    final ownClient = client == null;
    try {
      final response = await _fetchHeadOrGetWithRetry(
        client: managedClient,
        uri: Uri.parse(_setsIndexEndpoint),
      );
      final etag = (response.headers['etag'] ?? '').trim();
      final lastModified = (response.headers['last-modified'] ?? '').trim();
      final contentLength = (response.headers['content-length'] ?? '').trim();
      if (etag.isNotEmpty) {
        return 'sets-index:$etag';
      }
      if (lastModified.isNotEmpty) {
        return 'sets-index:$lastModified';
      }
      if (contentLength.isNotEmpty) {
        return 'sets-index:$contentLength';
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (ownClient) {
        managedClient.close();
      }
    }
  }

  Future<Map<String, String>> _fetchSetNamesIndex({
    required http.Client client,
  }) async {
    if (!_isAllowedDownloadUri(_setsIndexEndpoint)) {
      throw const FormatException('pokemon_dataset_url_not_allowed');
    }
    final payload = await _fetchJsonWithRetry(
      client: client,
      uri: Uri.parse(_setsIndexEndpoint),
    );
    final parsed = jsonDecode(payload);
    if (parsed is! List) {
      throw const FormatException('pokemon_sets_index_invalid_payload');
    }
    final result = <String, String>{};
    for (final row in parsed) {
      if (row is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(row);
      final id = ((map['id'] as String?) ?? '').trim().toLowerCase();
      final name = ((map['name'] as String?) ?? '').trim();
      if (id.isEmpty || name.isEmpty) {
        continue;
      }
      result[id] = name;
    }
    return result;
  }

  Future<http.Response> _fetchHeadOrGetWithRetry({
    required http.Client client,
    required Uri uri,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttemptsPerPage; attempt++) {
      try {
        final headResponse = await client
            .head(uri, headers: const {'user-agent': 'bindervault/1.0'})
            .timeout(const Duration(seconds: 25));
        if (headResponse.statusCode == 200) {
          return headResponse;
        }
      } catch (error) {
        lastError = error;
      }

      try {
        final getResponse = await client
            .get(uri, headers: const {'user-agent': 'bindervault/1.0'})
            .timeout(const Duration(seconds: 25));
        if (getResponse.statusCode == 200) {
          return getResponse;
        }
        final retryable =
            getResponse.statusCode == 429 || getResponse.statusCode >= 500;
        if (!retryable || attempt == _maxAttemptsPerPage) {
          throw HttpException('pokemon_api_http_${getResponse.statusCode}');
        }
        lastError = HttpException('pokemon_api_http_${getResponse.statusCode}');
      } catch (error) {
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

  int? _parsePokemonHttpStatus(String message) {
    final match = RegExp(r'pokemon_api_http_(\d{3})').firstMatch(message);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
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
  });

  final bool installed;
  final bool updateAvailable;
  final String? installedFingerprint;
  final String? remoteFingerprint;
}

class _CanonicalSnapshotPayload {
  const _CanonicalSnapshotPayload({
    required this.profile,
    required this.languageSignature,
    required this.batch,
  });

  final String profile;
  final String languageSignature;
  final CanonicalCatalogImportBatch batch;
}

class _ArchiveSetEntry {
  const _ArchiveSetEntry({
    required this.setId,
    required this.indexPath,
    required this.dirPath,
    required this.payload,
  });

  final String setId;
  final String indexPath;
  final String dirPath;
  final Map<String, dynamic> payload;
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
