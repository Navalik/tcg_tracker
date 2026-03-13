import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../db/canonical_catalog_store.dart';
import 'app_settings.dart';
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
  static const int _maxAttemptsPerPage = 4;
  static const String _apiKey = String.fromEnvironment(
    'POKEMON_TCG_API_KEY',
    defaultValue: '',
  );

  Future<bool> isInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString(_prefsKeyInstalledVersion);
    final installedProfile = prefs.getString(_prefsKeyInstalledProfile);
    final selectedProfile = await AppSettings.loadPokemonDatasetProfile();
    final count = await ScryfallDatabase.instance.countCards();
    final canonicalInstalled = await _hasCanonicalPokemonCatalog();
    return installedVersion == datasetVersion &&
        installedProfile == selectedProfile &&
        count > 0 &&
        canonicalInstalled;
  }

  Future<PokemonDatasetUpdateStatus> checkForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString(_prefsKeyInstalledVersion);
    final installedFingerprint = prefs.getString(_prefsKeyManifestFingerprint);
    final selectedProfile = await AppSettings.loadPokemonDatasetProfile();
    final installedProfile = prefs.getString(_prefsKeyInstalledProfile);
    final count = await ScryfallDatabase.instance.countCards();
    final installed =
        installedVersion == datasetVersion &&
        installedProfile == selectedProfile &&
        count > 0;
    if (!installed) {
      return const PokemonDatasetUpdateStatus(
        installed: false,
        updateAvailable: false,
      );
    }
    if (selectedProfile == 'full') {
      final remoteTotal = await _fetchApiTotalCount();
      final updateAvailable = remoteTotal != null && count < remoteTotal;
      return PokemonDatasetUpdateStatus(
        installed: true,
        updateAvailable: updateAvailable,
        installedFingerprint: installedFingerprint,
        remoteFingerprint: remoteTotal?.toString(),
      );
    }
    final remoteFingerprint = await _fetchManifestFingerprint(
      profile: selectedProfile,
    );
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
  }) async {
    final selectedProfile = await AppSettings.loadPokemonDatasetProfile();
    onStatus?.call('Importing Pokemon catalog (TCGdex)');
    onProgress(0.01);
    await _installCanonicalCatalog(
      profile: selectedProfile,
      onProgress: (progress) {
        final scaled = 0.01 + (progress.clamp(0.0, 1.0) * 0.37);
        onProgress(scaled);
      },
    );

    final database = await ScryfallDatabase.instance.open();
    onProgress(0.40);
    var inserted = 0;
    String? manifestFingerprint;
    String source = '';
    final datasetDir = await _ensureDatasetDirectory();
    await _clearDatasetJsonCacheDirectory(datasetDir);
    onStatus?.call('Building legacy compatibility dataset');
    onProgress(0.42);
    Object? manifestError;
    Object? apiError;
    final client = http.Client();
    try {
      if (selectedProfile == 'full') {
        try {
          onStatus?.call('Downloading sets index (GitHub)');
          onProgress(0.46);
          inserted = await _installFromFullManifest(
            database: database,
            client: client,
            onProgress: onProgress,
            progressStart: 0.48,
            progressEnd: 0.90,
          );
          onStatus?.call('Downloaded from GitHub dataset');
          manifestFingerprint = await _fetchManifestFingerprint(
            client: client,
            profile: selectedProfile,
          );
          source = 'github_manifest_full';
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
              progressStart: 0.52,
              progressEnd: 0.90,
            );
            source = 'api_v2_full_fallback';
            onStatus?.call('Downloading from Pokemon API');
          } catch (error) {
            apiError = error;
          }
        }
      } else {
        try {
          onStatus?.call('Downloading selected sets (GitHub)');
          inserted = await _installFromManifest(
            database: database,
            client: client,
            onProgress: onProgress,
            profile: selectedProfile,
            progressStart: 0.44,
            progressEnd: 0.90,
          );
          onStatus?.call('Downloaded from GitHub dataset');
          manifestFingerprint = await _fetchManifestFingerprint(
            client: client,
            profile: selectedProfile,
          );
          source = 'github_manifest';
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
              progressStart: 0.52,
              progressEnd: 0.90,
            );
            source = 'api_v2_fallback';
            onStatus?.call('Downloading from Pokemon API');
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
        if (manifestError != null) 'manifest=${manifestError.toString()}',
        if (apiError != null) 'api=${apiError.toString()}',
      ].join(';');
      throw HttpException(
        'pokemon_dataset_install_failed${details.isEmpty ? '' : ':$details'}',
      );
    }

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
    await prefs.setString(_prefsKeyInstalledProfile, selectedProfile);
    final fingerprint = manifestFingerprint;
    if (fingerprint != null && fingerprint.isNotEmpty) {
      await prefs.setString(_prefsKeyManifestFingerprint, fingerprint);
    }
    onStatus?.call('Completed');
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

  Future<void> _installCanonicalCatalog({
    required String profile,
    required void Function(double progress) onProgress,
  }) async {
    final store = await CanonicalCatalogStore.openDefault();
    try {
      final service = PokemonCanonicalImportService(store: store);
      await service.importProfile(
        profile: profile,
        onProgress: onProgress,
      );
    } finally {
      store.dispose();
    }
  }

  Future<void> reimportFromLocalCache({
    required void Function(double progress) onProgress,
    void Function(String status)? onStatus,
  }) async {
    final database = await ScryfallDatabase.instance.open();
    final selectedProfile = await AppSettings.loadPokemonDatasetProfile();
    final datasetDir = await _ensureDatasetDirectory();
    final files = datasetDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    if (files.isEmpty) {
      throw const FormatException('pokemon_dataset_cache_empty');
    }

    onStatus?.call('Reimporting from local cache');
    onProgress(0.02);

    var inserted = 0;
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
        final progress = 0.05 + (((i + 1) / files.length) * 0.90);
        onProgress(progress.clamp(0.0, 0.98));
      }
    });

    if (inserted <= 0) {
      throw const FormatException('pokemon_dataset_cache_invalid');
    }

    await ScryfallDatabase.instance.rebuildPrintedNameSearchIndex();

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_prefsKeyInstalledVersion, datasetVersion);
    await prefs.setString(_prefsKeyInstalledSource, 'local_cache');
    await prefs.setInt(_prefsKeyInstalledAt, nowMs);
    await prefs.setString(_prefsKeyInstalledProfile, selectedProfile);
    await prefs.setString(
      _prefsKeyManifestFingerprint,
      'local_cache:${files.length}:$inserted:$nowMs',
    );
    onStatus?.call('Completed');
    onProgress(1);
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

  Future<int> _installFromManifest({
    required AppDatabase database,
    required http.Client client,
    required void Function(double progress) onProgress,
    required String profile,
    required double progressStart,
    required double progressEnd,
  }) async {
    final sets = PokemonDatasetManifest.setsForProfile(profile);
    if (sets.isEmpty) {
      throw const FormatException('pokemon_dataset_manifest_empty');
    }
    final datasetDir = await _ensureDatasetDirectory();
    var inserted = 0;
    await database.transaction(() async {
      await ScryfallDatabase.instance.deleteAllCards(database);
      for (var i = 0; i < sets.length; i++) {
        final range = (progressEnd - progressStart).clamp(0.05, 0.95);
        final setStart = progressStart + ((i / sets.length) * range);
        final setAfterDownload = setStart + (range / sets.length) * 0.35;
        onProgress(setStart.clamp(progressStart, progressEnd));
        final spec = sets[i];
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
        final progress = progressStart + (((i + 1) / sets.length) * range);
        onProgress(progress.clamp(progressStart, progressEnd));
      }
    });
    if (inserted <= 0) {
      throw const FormatException('pokemon_dataset_empty');
    }
    return inserted;
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
    required String profile,
  }) async {
    final managedClient = client ?? http.Client();
    final ownClient = client == null;
    try {
      final parts = <String>[];
      final sets = PokemonDatasetManifest.setsForProfile(profile);
      for (final setSpec in sets) {
        final uri = Uri.parse(setSpec.url);
        final response = await _fetchHeadOrGetWithRetry(
          client: managedClient,
          uri: uri,
        );
        final etag = (response.headers['etag'] ?? '').trim();
        final lastModified = (response.headers['last-modified'] ?? '').trim();
        final contentLength = (response.headers['content-length'] ?? '').trim();
        final marker = etag.isNotEmpty
            ? etag
            : (lastModified.isNotEmpty
                  ? lastModified
                  : (contentLength.isNotEmpty ? contentLength : 'unknown'));
        parts.add('${setSpec.setCode}:$marker');
      }
      if (parts.isEmpty) {
        return null;
      }
      return parts.join('|');
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
