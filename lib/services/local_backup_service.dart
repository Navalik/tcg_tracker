import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';

class LocalBackupService {
  LocalBackupService._();

  static final LocalBackupService instance = LocalBackupService._();
  static const int _maxBackupFiles = 3;
  static const String pokemonAutomaticBackupPrefix =
      'collections_auto_backup_pokemon';

  Future<LocalBackupExportResult?> exportCollectionsBackup({
    Map<String, Object?>? metadata,
    String filePrefix = 'collections_backup',
    bool skipIfEmpty = false,
  }) async {
    final payload = await ScryfallDatabase.instance.exportCollectionsBackupPayload(
      metadata: metadata,
    );
    final collections = (payload['collections'] as List?)?.length ?? 0;
    final collectionCards = (payload['collectionCards'] as List?)?.length ?? 0;
    final cards = (payload['cards'] as List?)?.length ?? 0;
    if (skipIfEmpty && collections == 0 && collectionCards == 0) {
      return null;
    }
    final directory = await _backupDirectory();
    final now = DateTime.now().toLocal();
    final normalizedPrefix = _normalizeFilePrefix(filePrefix);
    final fileName = '${normalizedPrefix}_${_stamp(now)}.json';
    final target = File(path.join(directory.path, fileName));
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    await target.writeAsString(encoded, flush: true);
    await _pruneOldBackups(prefix: normalizedPrefix);
    return LocalBackupExportResult(
      file: target,
      collections: collections,
      collectionCards: collectionCards,
      cards: cards,
    );
  }

  Future<List<File>> listBackupFiles({String? prefix}) async {
    final directory = await _backupDirectory();
    final normalizedPrefix = prefix == null ? null : _normalizeFilePrefix(prefix);
    final items = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .where((file) {
          if (normalizedPrefix == null) {
            return true;
          }
          final name = path.basenameWithoutExtension(file.path).toLowerCase();
          return name.startsWith(normalizedPrefix.toLowerCase());
        })
        .toList(growable: false);
    items.sort((a, b) {
      final aTime = a.statSync().modified;
      final bTime = b.statSync().modified;
      return bTime.compareTo(aTime);
    });
    return items;
  }

  Future<void> _pruneOldBackups({String? prefix}) async {
    final backups = await listBackupFiles(prefix: prefix);
    if (backups.length <= _maxBackupFiles) {
      return;
    }
    for (final file in backups.skip(_maxBackupFiles)) {
      try {
        await file.delete();
      } catch (_) {
        // Keep export successful even if cleanup fails for a specific file.
      }
    }
  }

  Future<Map<String, int>> importCollectionsBackupFromFile(
    File file, {
    bool replaceExisting = true,
  }) async {
    final jsonText = await file.readAsString();
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('invalid_backup_file');
    }
    final payload = <String, dynamic>{};
    for (final entry in decoded.entries) {
      payload[entry.key.toString()] = entry.value;
    }
    return ScryfallDatabase.instance.restoreCollectionsBackupPayload(
      payload,
      replaceExisting: replaceExisting,
    );
  }

  Future<File?> latestBackupFile({String? prefix}) async {
    final backups = await listBackupFiles(prefix: prefix);
    if (backups.isEmpty) {
      return null;
    }
    return backups.first;
  }

  Future<Directory> _backupDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(documents.path, 'backups'));
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }
    return backupDir;
  }

  String _normalizeFilePrefix(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) {
      return 'collections_backup';
    }
    return normalized;
  }

  String _stamp(DateTime dt) {
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$yyyy$mm${dd}_$hh$min$ss';
  }
}

class LocalBackupExportResult {
  const LocalBackupExportResult({
    required this.file,
    required this.collections,
    required this.collectionCards,
    required this.cards,
  });

  final File file;
  final int collections;
  final int collectionCards;
  final int cards;
}
