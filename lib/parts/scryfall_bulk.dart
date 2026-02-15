part of 'package:tcg_tracker/main.dart';

typedef ImportProgressCallback = void Function(int count, double progress);

class ScryfallBulkImporter {
  static const _batchSize = 200;

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
      await database.transaction(() async {
        await ScryfallDatabase.instance.deleteAllCards(database);
        await for (final message in receivePort) {
          if (message is Map) {
            final type = message['type'] as String?;
            if (type == 'progress') {
              count = message['count'] as int? ?? count;
              final progress = message['progress'] as double? ?? 0;
              onProgress(count, progress);
            } else if (type == 'batch') {
              final items = message['items'] as List<dynamic>? ?? [];
              final mapped = items
                  .whereType<Map<String, dynamic>>()
                  .toList(growable: false);
              await ScryfallDatabase.instance.insertCardsBatch(
                database,
                mapped,
              );
              count += items.length;
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
      });
    } finally {
      receivePort.close();
      isolate.kill(priority: Isolate.immediate);
    }

    if (error != null) {
      throw Exception(error);
    }

    if (updatedAtRaw != null && bulkType != null) {
      await ScryfallBulkChecker()
          .markAllCardsInstalled(updatedAtRaw, bulkType: bulkType);
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
  final batch = <Map<String, dynamic>>[];
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
    final stream = file.openRead().map((chunk) {
      bytesRead += chunk.length;
      final now = DateTime.now();
      if (now.difference(lastProgress).inMilliseconds > 200) {
        lastProgress = now;
        sendProgress();
      }
      return chunk;
    }).transform(utf8.decoder);

    final parser = JsonArrayObjectParser(stream);
    await for (final card in parser.objects()) {
      if (config.allowedLanguages.isNotEmpty) {
        final lang = card['lang'];
        if (lang is! String || !config.allowedLanguages.contains(lang)) {
          continue;
        }
      }
      batch.add(card);
      count += 1;
      if (batch.length >= config.batchSize) {
        final progress = totalBytes > 0 ? bytesRead / totalBytes : 0;
        config.sendPort.send({
          'type': 'batch',
          'items': List<Map<String, dynamic>>.from(batch),
          'progress': progress,
        });
        batch.clear();
      }
    }

    if (batch.isNotEmpty) {
      final progress = totalBytes > 0 ? bytesRead / totalBytes : 0;
      config.sendPort.send({
        'type': 'batch',
        'items': List<Map<String, dynamic>>.from(batch),
        'progress': progress,
      });
      batch.clear();
    }

    config.sendPort.send({
      'type': 'done',
      'count': count,
    });
  } catch (error) {
    config.sendPort.send({
      'type': 'error',
      'message': error.toString(),
    });
  }
}



class ScryfallBulkCheckResult {
  const ScryfallBulkCheckResult({
    required this.updateAvailable,
    this.updatedAt,
    this.downloadUri,
    this.updatedAtRaw,
  });

  final bool updateAvailable;
  final DateTime? updatedAt;
  final String? downloadUri;
  final String? updatedAtRaw;
}

class ScryfallBulkChecker {
  static const _bulkEndpoint = 'https://api.scryfall.com/bulk-data';
  static String _prefsKeyLatestUpdatedAt(String bulkType) =>
      'scryfall_${bulkType}_latest_updated_at';
  static String _prefsKeyInstalledUpdatedAt(String bulkType) =>
      'scryfall_${bulkType}_installed_updated_at';
  static String _prefsKeyDownloadUri(String bulkType) =>
      'scryfall_${bulkType}_download_uri';

  Future<ScryfallBulkCheckResult> checkAllCardsUpdate(String bulkType) async {
    try {
      final response = await ScryfallApiClient.instance.get(
        Uri.parse(_bulkEndpoint),
        timeout: const Duration(seconds: 10),
        maxRetries: 2,
      );
      if (response.statusCode != 200) {
        return const ScryfallBulkCheckResult(updateAvailable: false);
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final data = payload['data'] as List<dynamic>?;
      if (data == null) {
        return const ScryfallBulkCheckResult(updateAvailable: false);
      }

      final entry = data.whereType<Map<String, dynamic>>().firstWhere(
            (item) => item['type'] == bulkType,
            orElse: () => const {},
          );
      if (entry.isEmpty) {
        return const ScryfallBulkCheckResult(updateAvailable: false);
      }

      final updatedAtRaw = entry['updated_at'] as String?;
      final downloadUri = entry['download_uri'] as String?;
      final updatedAt =
          updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null;

      final prefs = await SharedPreferences.getInstance();
      if (updatedAtRaw != null) {
        await prefs.setString(_prefsKeyLatestUpdatedAt(bulkType), updatedAtRaw);
      }
      if (downloadUri != null) {
        await prefs.setString(_prefsKeyDownloadUri(bulkType), downloadUri);
      }

      final installedUpdatedAt =
          prefs.getString(_prefsKeyInstalledUpdatedAt(bulkType));
      final updateAvailable =
          updatedAtRaw != null && updatedAtRaw != installedUpdatedAt;

      return ScryfallBulkCheckResult(
        updateAvailable: updateAvailable,
        updatedAt: updatedAt,
        downloadUri: downloadUri,
        updatedAtRaw: updatedAtRaw,
      );
    } catch (_) {
      return const ScryfallBulkCheckResult(updateAvailable: false);
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
    }
  }
}
