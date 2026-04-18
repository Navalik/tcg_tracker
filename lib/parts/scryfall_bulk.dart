part of 'package:tcg_tracker/main.dart';

typedef ImportProgressCallback = void Function(int count, double progress);

class BulkLanguageInspectResult {
  const BulkLanguageInspectResult({
    required this.sampledCards,
    required this.languageCounts,
  });

  final int sampledCards;
  final Map<String, int> languageCounts;
}

bool _isAllowedScryfallDownloadUri(String? rawUri) {
  if (rawUri == null || rawUri.trim().isEmpty) {
    return false;
  }
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
  return host == 'api.scryfall.com' ||
      host == 'data.scryfall.io' ||
      host.endsWith('.scryfall.com') ||
      host.endsWith('.scryfall.io');
}

bool _isAllowedMtgFirebaseDownloadUri(String? rawUri) {
  if (rawUri == null || rawUri.trim().isEmpty) {
    return false;
  }
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
  if (uri.host.toLowerCase() != 'firebasestorage.googleapis.com') {
    return false;
  }
  if (uri.path !=
          '/v0/b/bindervault.firebasestorage.app/o/catalog%2Fmtg%2Flatest%2Fmanifest.json' &&
      !uri.path.startsWith('/v0/b/bindervault.firebasestorage.app/o/')) {
    return false;
  }
  final encodedObject = uri.pathSegments.length >= 5 ? uri.pathSegments[4] : '';
  final objectName = Uri.decodeComponent(encodedObject);
  return objectName == 'catalog/mtg/latest/manifest.json' ||
      objectName.startsWith('catalog/mtg/releases/');
}

class MtgHostedBundleArtifact {
  const MtgHostedBundleArtifact({
    required this.id,
    required this.language,
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  final String id;
  final String language;
  final String name;
  final String downloadUrl;
  final int sizeBytes;
}

class MtgHostedBundleCheckResult {
  const MtgHostedBundleCheckResult({
    required this.updateAvailable,
    required this.version,
    required this.updatedAtRaw,
    required this.artifacts,
    this.updatedAt,
  });

  final bool updateAvailable;
  final String version;
  final String updatedAtRaw;
  final DateTime? updatedAt;
  final List<MtgHostedBundleArtifact> artifacts;

  int get sizeBytes =>
      artifacts.fold<int>(0, (total, artifact) => total + artifact.sizeBytes);
}

class MtgHostedBundleService {
  static const manifestUrl =
      'https://firebasestorage.googleapis.com/v0/b/bindervault.firebasestorage.app/o/catalog%2Fmtg%2Flatest%2Fmanifest.json?alt=media';
  static const _installedVersionKey = 'mtg_firebase_installed_version';

  Future<MtgHostedBundleCheckResult> checkForUpdate({
    required Set<String> languages,
  }) async {
    final uri = Uri.parse(manifestUrl);
    if (!_isAllowedMtgFirebaseDownloadUri(uri.toString())) {
      throw const FormatException('mtg_manifest_url_not_allowed');
    }
    if (kDebugMode) {
      debugPrint('mtg_bundle_download manifest $manifestUrl');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    var manifestBody = response.body;
    if (manifestBody.isNotEmpty && manifestBody.codeUnitAt(0) == 0xFEFF) {
      manifestBody = manifestBody.substring(1);
    }
    final manifest = jsonDecode(manifestBody) as Map<String, dynamic>;
    final version = (manifest['version'] as String?)?.trim();
    if (version == null || version.isEmpty) {
      throw const FormatException('mtg_manifest_missing_version');
    }
    final source = manifest['source'];
    final updatedAtRaw = source is Map
        ? ((source['updated_at'] as String?)?.trim() ?? version)
        : version;
    final updatedAt = DateTime.tryParse(updatedAtRaw);
    final artifacts = _selectArtifacts(manifest, languages);
    if (artifacts.isEmpty) {
      throw const FormatException('mtg_manifest_missing_artifacts');
    }
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString(_installedVersionKey);
    return MtgHostedBundleCheckResult(
      updateAvailable: installedVersion != version,
      version: version,
      updatedAtRaw: updatedAtRaw,
      updatedAt: updatedAt,
      artifacts: artifacts,
    );
  }

  Future<void> markInstalled(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_installedVersionKey, version);
  }

  Future<String> downloadCombinedJson({
    required MtgHostedBundleCheckResult bundle,
    required String targetPath,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    final targetFile = File('$targetPath.download');
    final sink = targetFile.openWrite();
    final client = http.Client();
    var received = 0;
    var firstObject = true;

    try {
      sink.write('[');
      for (final artifact in bundle.artifacts) {
        final url = artifact.downloadUrl.trim();
        if (!_isAllowedMtgFirebaseDownloadUri(url)) {
          throw const FormatException('mtg_artifact_url_not_allowed');
        }
        if (kDebugMode) {
          debugPrint('mtg_bundle_download asset ${artifact.id} $url');
        }
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request);
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        final compressedStream = response.stream.map((chunk) {
          received += chunk.length;
          onProgress(received, bundle.sizeBytes);
          return chunk;
        });
        final decodedStream = compressedStream
            .transform(gzip.decoder)
            .transform(utf8.decoder);
        final parser = JsonArrayObjectParser(decodedStream);
        await for (final card in parser.objects()) {
          if (!firstObject) {
            sink.write(',');
          }
          firstObject = false;
          sink.write(jsonEncode(card));
        }
      }
      sink.write(']');
      await sink.flush();
      await sink.close();
      final finalFile = File(targetPath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await targetFile.rename(targetPath);
      onProgress(bundle.sizeBytes, bundle.sizeBytes);
      return targetPath;
    } catch (_) {
      await sink.close();
      try {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  List<MtgHostedBundleArtifact> _selectArtifacts(
    Map<String, dynamic> manifest,
    Set<String> languages,
  ) {
    final normalizedLanguages = languages
        .map((language) => language.trim().toLowerCase())
        .where((language) => language.isNotEmpty)
        .toSet();
    final includeItalian = normalizedLanguages.contains('it');
    final wantedBundleIds = <String>{'base_en'};
    if (includeItalian) {
      wantedBundleIds.add('delta_it');
    }

    final selected = <MtgHostedBundleArtifact>[];
    final bundles = manifest['bundles'];
    if (bundles is! List) {
      return selected;
    }
    for (final bundle in bundles) {
      if (bundle is! Map) {
        continue;
      }
      final id = (bundle['id'] as String?)?.trim() ?? '';
      if (!wantedBundleIds.contains(id)) {
        continue;
      }
      final language = (bundle['language'] as String?)?.trim() ?? '';
      final artifacts = bundle['artifacts'];
      if (artifacts is! List) {
        continue;
      }
      for (final artifact in artifacts) {
        if (artifact is! Map) {
          continue;
        }
        final name = (artifact['name'] as String?)?.trim() ?? '';
        final downloadUrl = (artifact['download_url'] as String?)?.trim() ?? '';
        final sizeBytes = artifact['size_bytes'];
        if (name.isEmpty ||
            downloadUrl.isEmpty ||
            !_isAllowedMtgFirebaseDownloadUri(downloadUrl)) {
          continue;
        }
        selected.add(
          MtgHostedBundleArtifact(
            id: id,
            language: language,
            name: name,
            downloadUrl: downloadUrl,
            sizeBytes: sizeBytes is int ? sizeBytes : 0,
          ),
        );
      }
    }
    selected.sort((a, b) {
      const order = {'base_en': 0, 'delta_it': 1};
      return (order[a.id] ?? 99).compareTo(order[b.id] ?? 99);
    });
    return selected;
  }
}

class ScryfallBulkImporter {
  static const _batchSize = 20;

  Future<BulkLanguageInspectResult> inspectLocalBulkLanguageCounts(
    String filePath, {
    int maxCards = 120000,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('bulk_file_not_found', filePath);
    }
    final counts = <String, int>{};
    final parser = JsonArrayObjectParser(
      file.openRead().transform(utf8.decoder),
    );
    var read = 0;
    await for (final card in parser.objects()) {
      final lang = (card['lang'] as String?)?.trim().toLowerCase();
      if (lang != null && lang.isNotEmpty) {
        counts[lang] = (counts[lang] ?? 0) + 1;
      }
      read += 1;
      if (read >= maxCards) {
        break;
      }
    }
    return BulkLanguageInspectResult(
      sampledCards: read,
      languageCounts: counts,
    );
  }

  Future<void> importAllCardsJson(
    String filePath, {
    required ImportProgressCallback onProgress,
    String? updatedAtRaw,
    String? bulkType,
    List<String>? allowedLanguages,
  }) async {
    final database = await ScryfallDatabase.instance.open();
    final receivePort = ReceivePort();
    final languageFilter = allowedLanguages ?? const <String>[];
    final isolate = await Isolate.spawn<_ScryfallParseConfig>(
      _scryfallParseIsolate,
      _ScryfallParseConfig(
        filePath: filePath,
        sendPort: receivePort.sendPort,
        batchSize: _batchSize,
        allowedLanguages: languageFilter,
      ),
    );

    var count = 0;
    Object? error;

    try {
      await ScryfallDatabase.instance.deleteAllCards(database);
      await for (final message in receivePort) {
        if (message is Map) {
          final type = message['type'] as String?;
          if (type == 'progress') {
            count = message['count'] as int? ?? count;
            final progress = message['progress'] as double? ?? 0;
            onProgress(count, progress);
          } else if (type == 'batch') {
            final items = (message['items'] as List?)
                ?.cast<Map<String, dynamic>>();
            final mapped = items ?? const <Map<String, dynamic>>[];
            await ScryfallDatabase.instance.insertCardsBatch(database, mapped);
            count += mapped.length;
            onProgress(count, message['progress'] as double? ?? 0);
          } else if (type == 'done') {
            count = message['count'] as int? ?? count;
            onProgress(count, 1);
            break;
          } else if (type == 'error') {
            error = message['message'];
            break;
          }
        }
      }
    } finally {
      receivePort.close();
      isolate.kill(priority: Isolate.immediate);
    }

    if (error != null) {
      throw Exception(error);
    }

    await ScryfallDatabase.instance.rebuildPrintedNameSearchIndex();

    if (updatedAtRaw != null && bulkType != null) {
      await ScryfallBulkChecker().markAllCardsInstalled(
        updatedAtRaw,
        bulkType: bulkType,
      );
    }
  }
}

class JsonArrayObjectParser {
  JsonArrayObjectParser(this._input);

  final Stream<String> _input;

  Stream<Map<String, dynamic>> objects() async* {
    var arrayStarted = false;
    var inString = false;
    var escape = false;
    var depth = 0;
    var inObject = false;
    StringBuffer? buffer;

    await for (final chunk in _input) {
      for (var i = 0; i < chunk.length; i++) {
        final char = chunk[i];

        if (!arrayStarted) {
          if (char == '[') {
            arrayStarted = true;
          }
          continue;
        }

        if (!inObject) {
          if (char == '{') {
            inObject = true;
            depth = 1;
            buffer = StringBuffer()..write(char);
          } else if (char == ']') {
            return;
          }
          continue;
        }

        buffer?.write(char);

        if (escape) {
          escape = false;
          continue;
        }

        if (char == '\\' && inString) {
          escape = true;
          continue;
        }

        if (char == '"') {
          inString = !inString;
          continue;
        }

        if (!inString) {
          if (char == '{') {
            depth += 1;
          } else if (char == '}') {
            depth -= 1;
            if (depth == 0) {
              final jsonText = buffer.toString();
              buffer = null;
              inObject = false;
              yield jsonDecode(jsonText) as Map<String, dynamic>;
            }
          }
        }
      }
    }
  }
}

class _ScryfallParseConfig {
  const _ScryfallParseConfig({
    required this.filePath,
    required this.sendPort,
    required this.batchSize,
    required this.allowedLanguages,
  });

  final String filePath;
  final SendPort sendPort;
  final int batchSize;
  final List<String> allowedLanguages;
}

Future<void> _scryfallParseIsolate(_ScryfallParseConfig config) async {
  final file = File(config.filePath);
  final totalBytes = await file.length();
  var bytesRead = 0;
  var count = 0;
  var batch = <Map<String, dynamic>>[];
  var lastProgress = DateTime.now();

  void sendProgress() {
    final progress = totalBytes > 0 ? bytesRead / totalBytes : 0;
    config.sendPort.send({
      'type': 'progress',
      'count': count,
      'progress': progress,
    });
  }

  try {
    final stream = file
        .openRead()
        .map((chunk) {
          bytesRead += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastProgress).inMilliseconds > 200) {
            lastProgress = now;
            sendProgress();
          }
          return chunk;
        })
        .transform(utf8.decoder);

    final parser = JsonArrayObjectParser(stream);
    await for (final card in parser.objects()) {
      if (config.allowedLanguages.isNotEmpty) {
        final lang = card['lang'];
        if (lang is! String || !config.allowedLanguages.contains(lang)) {
          continue;
        }
      }
      batch.add(_compactScryfallCard(card));
      count += 1;
      if (batch.length >= config.batchSize) {
        final progress = totalBytes > 0 ? bytesRead / totalBytes : 0;
        final outgoing = batch;
        batch = <Map<String, dynamic>>[];
        config.sendPort.send({
          'type': 'batch',
          'items': outgoing,
          'progress': progress,
        });
      }
    }

    if (batch.isNotEmpty) {
      final progress = totalBytes > 0 ? bytesRead / totalBytes : 0;
      config.sendPort.send({
        'type': 'batch',
        'items': batch,
        'progress': progress,
      });
    }

    config.sendPort.send({'type': 'done', 'count': count});
  } catch (_) {
    config.sendPort.send({'type': 'error', 'message': 'parse_failed'});
  }
}

Map<String, dynamic> _compactScryfallCard(Map<String, dynamic> card) {
  final compact = <String, dynamic>{};

  void copyScalar(String key) {
    final value = card[key];
    if (value != null) {
      compact[key] = value;
    }
  }

  copyScalar('id');
  copyScalar('name');
  copyScalar('oracle_id');
  copyScalar('set');
  copyScalar('set_name');
  copyScalar('collector_number');
  copyScalar('rarity');
  copyScalar('type_line');
  copyScalar('mana_cost');
  copyScalar('oracle_text');
  copyScalar('cmc');
  copyScalar('artist');
  copyScalar('power');
  copyScalar('toughness');
  copyScalar('loyalty');
  copyScalar('lang');
  copyScalar('released_at');
  copyScalar('printed_name');
  copyScalar('printed_text');
  copyScalar('printed_type_line');
  copyScalar('set_type');

  final colors = card['colors'];
  if (colors is List) {
    compact['colors'] = colors.whereType<String>().toList(growable: false);
  }
  final colorIdentity = card['color_identity'];
  if (colorIdentity is List) {
    compact['color_identity'] = colorIdentity.whereType<String>().toList(
      growable: false,
    );
  }
  final imageUris = card['image_uris'];
  if (imageUris is Map) {
    compact['image_uris'] = Map<String, dynamic>.from(imageUris);
  }
  final cardFaces = card['card_faces'];
  if (cardFaces is List) {
    final normalizedFaces = <Map<String, dynamic>>[];
    for (final face in cardFaces) {
      if (face is! Map) {
        continue;
      }
      final faceMap = Map<String, dynamic>.from(face);
      final minimalFace = <String, dynamic>{};
      for (final key in const [
        'name',
        'printed_name',
        'printed_text',
        'printed_type_line',
        'type_line',
        'oracle_text',
        'mana_cost',
        'image_uris',
        'colors',
        'color_identity',
        'artist',
        'power',
        'toughness',
        'loyalty',
      ]) {
        final value = faceMap[key];
        if (value != null) {
          minimalFace[key] = value;
        }
      }
      if (minimalFace.isNotEmpty) {
        normalizedFaces.add(minimalFace);
      }
    }
    if (normalizedFaces.isNotEmpty) {
      compact['card_faces'] = normalizedFaces;
    }
  }
  final prices = card['prices'];
  if (prices is Map) {
    final pricesMap = Map<String, dynamic>.from(prices);
    final minimalPrices = <String, dynamic>{};
    for (final key in const [
      'usd',
      'usd_foil',
      'usd_etched',
      'eur',
      'eur_foil',
      'tix',
    ]) {
      final value = pricesMap[key];
      if (value != null) {
        minimalPrices[key] = value;
      }
    }
    if (minimalPrices.isNotEmpty) {
      compact['prices'] = minimalPrices;
    }
  }
  final legalities = card['legalities'];
  if (legalities is Map) {
    compact['legalities'] = Map<String, dynamic>.from(legalities);
  }
  return compact;
}

class ScryfallBulkCheckResult {
  const ScryfallBulkCheckResult({
    required this.updateAvailable,
    this.updatedAt,
    this.downloadUri,
    this.updatedAtRaw,
    this.sizeBytes,
  });

  final bool updateAvailable;
  final DateTime? updatedAt;
  final String? downloadUri;
  final String? updatedAtRaw;
  final int? sizeBytes;
}

class ScryfallBulkChecker {
  static const _bulkEndpoint = 'https://api.scryfall.com/bulk-data';
  static String _prefsKeyLatestUpdatedAt(String bulkType) =>
      'scryfall_${bulkType}_latest_updated_at';
  static String _prefsKeyInstalledUpdatedAt(String bulkType) =>
      'scryfall_${bulkType}_installed_updated_at';
  static String _prefsKeyDownloadUri(String bulkType) =>
      'scryfall_${bulkType}_download_uri';
  static String _prefsKeyExpectedSize(String bulkType) =>
      'scryfall_${bulkType}_expected_size';

  Future<ScryfallBulkCheckResult> _cachedResult(String bulkType) async {
    final prefs = await SharedPreferences.getInstance();
    final latestUpdatedAt = prefs.getString(_prefsKeyLatestUpdatedAt(bulkType));
    final installedUpdatedAt = prefs.getString(
      _prefsKeyInstalledUpdatedAt(bulkType),
    );
    final cachedDownloadUriRaw = prefs.getString(
      _prefsKeyDownloadUri(bulkType),
    );
    final cachedDownloadUri =
        _isAllowedScryfallDownloadUri(cachedDownloadUriRaw)
        ? cachedDownloadUriRaw
        : null;
    final sizeRaw = prefs.getString(_prefsKeyExpectedSize(bulkType));
    final cachedSize = int.tryParse(sizeRaw ?? '');
    final cachedUpdatedAt = latestUpdatedAt == null
        ? null
        : DateTime.tryParse(latestUpdatedAt);
    final updateAvailable =
        latestUpdatedAt != null && latestUpdatedAt != installedUpdatedAt;
    return ScryfallBulkCheckResult(
      updateAvailable: updateAvailable,
      updatedAt: cachedUpdatedAt,
      downloadUri: cachedDownloadUri,
      updatedAtRaw: latestUpdatedAt,
      sizeBytes: cachedSize,
    );
  }

  Future<ScryfallBulkCheckResult> checkAllCardsUpdate(String bulkType) async {
    try {
      final response = await ScryfallApiClient.instance.get(
        Uri.parse(_bulkEndpoint),
        timeout: const Duration(seconds: 10),
        maxRetries: 2,
      );
      if (response.statusCode != 200) {
        return _cachedResult(bulkType);
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final data = payload['data'] as List<dynamic>?;
      if (data == null) {
        return _cachedResult(bulkType);
      }

      final entry = data.whereType<Map<String, dynamic>>().firstWhere(
        (item) => item['type'] == bulkType,
        orElse: () => const {},
      );
      if (entry.isEmpty) {
        return _cachedResult(bulkType);
      }

      final updatedAtRaw = entry['updated_at'] as String?;
      final downloadUriRaw = entry['download_uri'] as String?;
      final sizeBytes = (entry['size'] as num?)?.toInt();
      final downloadUri = _isAllowedScryfallDownloadUri(downloadUriRaw)
          ? downloadUriRaw
          : null;
      final updatedAt = updatedAtRaw != null
          ? DateTime.tryParse(updatedAtRaw)
          : null;

      final prefs = await SharedPreferences.getInstance();
      if (updatedAtRaw != null) {
        await prefs.setString(_prefsKeyLatestUpdatedAt(bulkType), updatedAtRaw);
      }
      if (downloadUri != null) {
        await prefs.setString(_prefsKeyDownloadUri(bulkType), downloadUri);
      }
      if (sizeBytes != null && sizeBytes > 0) {
        await prefs.setString(_prefsKeyExpectedSize(bulkType), '$sizeBytes');
      }
      final cachedDownloadUriRaw = prefs.getString(
        _prefsKeyDownloadUri(bulkType),
      );
      final cachedDownloadUri =
          _isAllowedScryfallDownloadUri(cachedDownloadUriRaw)
          ? cachedDownloadUriRaw
          : null;

      final installedUpdatedAt = prefs.getString(
        _prefsKeyInstalledUpdatedAt(bulkType),
      );
      final updateAvailable =
          updatedAtRaw != null && updatedAtRaw != installedUpdatedAt;

      return ScryfallBulkCheckResult(
        updateAvailable: updateAvailable,
        updatedAt: updatedAt,
        downloadUri: downloadUri ?? cachedDownloadUri,
        updatedAtRaw: updatedAtRaw,
        sizeBytes: sizeBytes,
      );
    } catch (_) {
      return _cachedResult(bulkType);
    }
  }

  Future<void> markAllCardsInstalled(
    String updatedAtRaw, {
    required String bulkType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyInstalledUpdatedAt(bulkType), updatedAtRaw);
  }

  Future<void> resetState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final option in _bulkOptions) {
      await prefs.remove(_prefsKeyLatestUpdatedAt(option.type));
      await prefs.remove(_prefsKeyInstalledUpdatedAt(option.type));
      await prefs.remove(_prefsKeyDownloadUri(option.type));
      await prefs.remove(_prefsKeyExpectedSize(option.type));
    }
  }
}
