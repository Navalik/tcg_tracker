import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../db/app_database.dart';
import 'app_settings.dart';
import 'entitlement_sync_service.dart';
import 'game_registry.dart';
import 'local_backup_service.dart';
import 'purchase_manager.dart';

class CloudBackupEligibility {
  const CloudBackupEligibility({
    required this.supported,
    required this.signedIn,
    required this.plus,
  });

  final bool supported;
  final bool signedIn;
  final bool plus;

  bool get canAccess => supported && signedIn && plus;
}

class CloudBackupSnapshotInfo {
  const CloudBackupSnapshotInfo({
    required this.path,
    required this.updatedAt,
    required this.sizeBytes,
    required this.hash,
    required this.automatic,
    required this.appVersion,
    required this.reason,
    required this.collections,
    required this.collectionCards,
    required this.cards,
  });

  final String path;
  final DateTime? updatedAt;
  final int? sizeBytes;
  final String? hash;
  final bool automatic;
  final String? appVersion;
  final String? reason;
  final int? collections;
  final int? collectionCards;
  final int? cards;
}

class CloudBackupUploadResult {
  const CloudBackupUploadResult({
    required this.snapshot,
    required this.skipped,
  });

  final CloudBackupSnapshotInfo snapshot;
  final bool skipped;
}

class CloudBackupRestoreGamePreview {
  const CloudBackupRestoreGamePreview({
    required this.game,
    required this.localCollections,
    required this.localCollectionCards,
    required this.backupCollections,
    required this.backupCollectionCards,
    required this.backupCards,
    required this.presentInBackup,
    required this.destructive,
  });

  final AppTcgGame game;
  final int localCollections;
  final int localCollectionCards;
  final int backupCollections;
  final int backupCollectionCards;
  final int backupCards;
  final bool presentInBackup;
  final bool destructive;
}

class CloudBackupRestorePreview {
  const CloudBackupRestorePreview({
    required this.games,
    required this.requiresExplicitConfirmation,
  });

  final List<CloudBackupRestoreGamePreview> games;
  final bool requiresExplicitConfirmation;
}

class CloudBackupRestoreResult {
  const CloudBackupRestoreResult({
    required this.stats,
    required this.preview,
    required this.preRestoreBackupFile,
    required this.rollbackPerformed,
  });

  final Map<String, int> stats;
  final CloudBackupRestorePreview preview;
  final File? preRestoreBackupFile;
  final bool rollbackPerformed;
}

class CloudBackupService {
  CloudBackupService._();

  static final CloudBackupService instance = CloudBackupService._();
  static const int backupSchemaVersion = 3;
  static const String _latestObjectName = 'latest.json.gz';
  static const String _historyDirectoryName = 'snapshots';
  static const double _destructiveDropThreshold = 0.3;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<CloudBackupEligibility> checkEligibility() async {
    final user = FirebaseAuth.instance.currentUser;
    await PurchaseManager.instance.init();
    final claimTier = await EntitlementSyncService.instance.loadClaimTier();
    return CloudBackupEligibility(
      supported: isSupported,
      signedIn: user != null && !user.isAnonymous,
      plus: PurchaseManager.instance.isPro && claimTier == 'plus',
    );
  }

  Future<CloudBackupUploadResult> uploadLatestBackup({
    bool automatic = false,
    bool force = false,
    String reason = 'manual',
  }) async {
    final eligibility = await checkEligibility();
    if (!eligibility.canAccess) {
      throw StateError('cloud_backup_unavailable');
    }
    final user = FirebaseAuth.instance.currentUser!;
    final packageInfo = await PackageInfo.fromPlatform();
    final payload = await _buildCloudBackupPayload(
      automatic: automatic,
      reason: reason,
      uid: user.uid,
      appVersion: packageInfo.version,
    );
    final jsonString = jsonEncode(payload);
    final payloadBytes = utf8.encode(jsonString);
    final payloadHash = sha256.convert(payloadBytes).toString();
    final previousHash = await AppSettings.loadCloudBackupLastHash();
    final ref = _latestRef(user.uid);
    if (!force && previousHash == payloadHash) {
      final existing = await fetchLatestSnapshotInfo();
      if (existing != null) {
        return CloudBackupUploadResult(snapshot: existing, skipped: true);
      }
    }
    final counts = _countGamesPayload(payload['games']);
    final collections = counts.collections;
    final collectionCards = counts.collectionCards;
    final cards = counts.cards;
    final existing = await _fetchSnapshotInfo(ref);
    final payloadLooksEmpty = collections == 0 && collectionCards == 0;
    final wouldOverwriteNonEmptyBackup =
        (existing?.collections ?? 0) > 0 || (existing?.collectionCards ?? 0) > 0;
    if (automatic && payloadLooksEmpty && wouldOverwriteNonEmptyBackup) {
      final message =
          'cloud_backup_suspicious_empty_payload collections=$collections collectionCards=$collectionCards existingCollections=${existing?.collections ?? 0} existingCollectionCards=${existing?.collectionCards ?? 0}';
      await saveLastError(message);
      throw StateError(message);
    }
    if (!force && payloadLooksEmpty) {
      final message =
          'cloud_backup_empty_payload collections=$collections collectionCards=$collectionCards';
      await saveLastError(message);
      throw StateError(message);
    }
    final gzipBytes = gzip.encode(payloadBytes);
    final metadata = SettableMetadata(
      contentType: 'application/gzip',
      contentEncoding: 'gzip',
      customMetadata: <String, String>{
        'payloadHash': payloadHash,
        'exportedAt': payload['exportedAt']?.toString() ?? '',
        'automatic': automatic ? 'true' : 'false',
        'reason': reason,
        'appVersion': packageInfo.version,
        'schemaVersion': '$backupSchemaVersion',
        'collections': '$collections',
        'collectionCards': '$collectionCards',
        'cards': '$cards',
      },
    );
    final data = Uint8List.fromList(gzipBytes);
    await _historyRef(
      user.uid,
      exportedAt: payload['exportedAt']?.toString(),
    ).putData(data, metadata);
    final task = await ref.putData(data, metadata);
    final taskMetadata = task.metadata ?? await ref.getMetadata();
    final snapshot = _snapshotInfoFromMetadata(taskMetadata);
    await AppSettings.saveCloudBackupLastHash(payloadHash);
    await AppSettings.saveCloudBackupLastUploadedAtMs(
      snapshot.updatedAt?.millisecondsSinceEpoch,
    );
    await AppSettings.saveCloudBackupLastRemotePath(snapshot.path);
    await AppSettings.saveCloudBackupLastError(null);
    return CloudBackupUploadResult(snapshot: snapshot, skipped: false);
  }

  Future<CloudBackupSnapshotInfo?> fetchLatestSnapshotInfo() async {
    final eligibility = await checkEligibility();
    if (!eligibility.canAccess) {
      return null;
    }
    final user = FirebaseAuth.instance.currentUser!;
    try {
      final snapshot = await _fetchSnapshotInfo(_latestRef(user.uid));
      if (snapshot == null) {
        return null;
      }
      await AppSettings.saveCloudBackupLastUploadedAtMs(
        snapshot.updatedAt?.millisecondsSinceEpoch,
      );
      await AppSettings.saveCloudBackupLastRemotePath(snapshot.path);
      if (snapshot.hash != null && snapshot.hash!.isNotEmpty) {
        await AppSettings.saveCloudBackupLastHash(snapshot.hash);
      }
      return snapshot;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found' ||
          error.code == 'unauthorized' ||
          error.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  Future<CloudBackupRestorePreview> previewLatestBackupRestore() async {
    final eligibility = await checkEligibility();
    if (!eligibility.canAccess) {
      throw StateError('cloud_backup_unavailable');
    }
    final user = FirebaseAuth.instance.currentUser!;
    final data = await _readLatestBackupData(user.uid);
    if (data == null || data.isEmpty) {
      throw const FormatException('cloud_backup_empty');
    }
    final payload = _decodeAndNormalizePayload(data);
    return _buildRestorePreview(payload);
  }

  Future<CloudBackupRestoreResult> restoreLatestBackup({
    bool allowDestructive = false,
  }) async {
    final eligibility = await checkEligibility();
    if (!eligibility.canAccess) {
      throw StateError('cloud_backup_unavailable');
    }
    final user = FirebaseAuth.instance.currentUser!;
    final data = await _readLatestBackupData(user.uid);
    if (data == null || data.isEmpty) {
      throw const FormatException('cloud_backup_empty');
    }
    final normalized = _decodeAndNormalizePayload(data);
    final preview = await _buildRestorePreview(normalized);
    if (preview.requiresExplicitConfirmation && !allowDestructive) {
      throw StateError('cloud_backup_restore_confirmation_required');
    }
    final preRestoreBackup = await LocalBackupService.instance.exportFullBackup(
      filePrefix: LocalBackupService.preRestoreBackupPrefix,
      metadata: <String, Object?>{
        'source': 'pre_cloud_restore',
        'uid': user.uid,
      },
    );
    var rollbackPerformed = false;
    late final Map<String, int> stats;
    try {
      stats = await _restorePayload(normalized);
      await _verifyRestoredPayload(normalized);
    } catch (error) {
      final backupFile = preRestoreBackup?.file;
      if (backupFile != null) {
        try {
          await LocalBackupService.instance.importCollectionsBackupFromFile(
            backupFile,
            replaceExisting: true,
          );
          rollbackPerformed = true;
        } catch (rollbackError) {
          throw StateError(
            'cloud_backup_restore_failed rollback_failed:$rollbackError original:$error',
          );
        }
      }
      throw StateError('cloud_backup_restore_failed:$error');
    }
    final remote = await fetchLatestSnapshotInfo();
    await AppSettings.saveCloudBackupLastHash(remote?.hash);
    await AppSettings.saveCloudBackupLastUploadedAtMs(
      remote?.updatedAt?.millisecondsSinceEpoch,
    );
    await AppSettings.saveCloudBackupLastError(null);
    return CloudBackupRestoreResult(
      stats: stats,
      preview: preview,
      preRestoreBackupFile: preRestoreBackup?.file,
      rollbackPerformed: rollbackPerformed,
    );
  }

  Future<void> deleteLatestBackup() async {
    final eligibility = await checkEligibility();
    if (!eligibility.canAccess) {
      throw StateError('cloud_backup_unavailable');
    }
    final user = FirebaseAuth.instance.currentUser!;
    await _latestRef(user.uid).delete();
    await AppSettings.saveCloudBackupLastHash(null);
    await AppSettings.saveCloudBackupLastUploadedAtMs(null);
    await AppSettings.saveCloudBackupLastRemotePath(null);
    await AppSettings.saveCloudBackupLastError(null);
  }

  Future<String?> loadLastError() => AppSettings.loadCloudBackupLastError();

  Future<void> saveLastError(Object error) async {
    await AppSettings.saveCloudBackupLastError(
      error.toString().replaceAll(RegExp(r'[\r\n]+'), ' ').trim(),
    );
  }

  String _decodeBackupPayloadText(Uint8List data) {
    try {
      return utf8.decode(gzip.decode(data));
    } on Object {
      return utf8.decode(data);
    }
  }

  Map<String, dynamic> _decodeAndNormalizePayload(Uint8List data) {
    final decodedText = _decodeBackupPayloadText(data);
    final payload = jsonDecode(decodedText);
    if (payload is! Map) {
      throw const FormatException('cloud_backup_invalid');
    }
    final normalized = <String, dynamic>{};
    for (final entry in payload.entries) {
      normalized[entry.key.toString()] = entry.value;
    }
    return normalized;
  }

  Reference _latestRef(String uid) {
    return FirebaseStorage.instance.ref(
      'users/$uid/cloud-backup/$_latestObjectName',
    );
  }

  Reference _legacyGameScopedLatestRef(String uid, AppTcgGame game) {
    return FirebaseStorage.instance.ref(
      'users/$uid/cloud-backup/${_cloudGameKey(game)}/$_latestObjectName',
    );
  }

  Reference _historyRef(String uid, {String? exportedAt}) {
    final suffix = _historyObjectName(exportedAt);
    return FirebaseStorage.instance.ref(
      'users/$uid/cloud-backup/$_historyDirectoryName/$suffix',
    );
  }

  String _historyObjectName(String? exportedAt) {
    final raw = (exportedAt ?? DateTime.now().toUtc().toIso8601String()).trim();
    final normalized = raw
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${normalized.isEmpty ? DateTime.now().millisecondsSinceEpoch : normalized}.json.gz';
  }

  Future<CloudBackupSnapshotInfo?> _fetchSnapshotInfo(Reference ref) async {
    try {
      final metadata = await ref.getMetadata();
      return _snapshotInfoFromMetadata(metadata);
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found' ||
          error.code == 'unauthorized' ||
          error.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  Future<Uint8List?> _readLatestBackupData(String uid) async {
    try {
      final current = await _latestRef(uid).getData();
      if (current != null && current.isNotEmpty) {
        return current;
      }
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found' &&
          error.code != 'unauthorized' &&
          error.code != 'permission-denied') {
        rethrow;
      }
    }
    for (final definition in _backupDefinitions()) {
      final game = definition.appSettingsGame;
      if (game == null) {
        continue;
      }
      try {
        final scoped = await _legacyGameScopedLatestRef(uid, game).getData();
        if (scoped != null && scoped.isNotEmpty) {
          return scoped;
        }
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found' &&
            error.code != 'unauthorized' &&
            error.code != 'permission-denied') {
          rethrow;
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _buildCloudBackupPayload({
    required bool automatic,
    required String reason,
    required String uid,
    required String appVersion,
  }) async {
    final previousDbFileName = ScryfallDatabase.instance.databaseFileName;
    final games = <String, Map<String, dynamic>>{};
    try {
      for (final definition in _backupDefinitions()) {
        final game = definition.appSettingsGame;
        if (game == null) {
          continue;
        }
        final payload = await ScryfallDatabase.instance.runWithDatabaseFileName(
          definition.dbFileName,
          () => ScryfallDatabase.instance.exportCollectionsBackupPayload(
            metadata: <String, Object?>{
              'automatic': automatic,
              'reason': reason,
              'appVersion': appVersion,
              'uid': uid,
            },
          ),
        );
        games[_cloudGameKey(game)] = payload;
      }
    } finally {
      await ScryfallDatabase.instance.setDatabaseFileName(previousDbFileName);
    }

    return <String, dynamic>{
      'schemaVersion': backupSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'metadata': <String, Object?>{
        'cloudBackupSchemaVersion': backupSchemaVersion,
        'automatic': automatic,
        'reason': reason,
        'appVersion': appVersion,
        'uid': uid,
        'games': games.keys.toList()..sort(),
      },
      'games': games,
    };
  }

  Future<CloudBackupRestorePreview> _buildRestorePreview(
    Map<String, dynamic> payload,
  ) async {
    final backupSummaries = _summariesFromPayload(payload);
    final localSummaries = await _summariesFromLocalDatabases();
    final games = <CloudBackupRestoreGamePreview>[];
    var requiresExplicitConfirmation = false;

    for (final definition in _backupDefinitions()) {
      final game = definition.appSettingsGame;
      if (game == null) {
        continue;
      }
      final key = _cloudGameKey(game);
      final local = localSummaries[key] ?? const _BackupGameSummary.empty();
      final backup = backupSummaries[key] ?? const _BackupGameSummary.empty();
      final destructive = _isDestructiveRestore(local: local, backup: backup);
      requiresExplicitConfirmation =
          requiresExplicitConfirmation || destructive;
      games.add(
        CloudBackupRestoreGamePreview(
          game: game,
          localCollections: local.collections,
          localCollectionCards: local.collectionCards,
          backupCollections: backup.collections,
          backupCollectionCards: backup.collectionCards,
          backupCards: backup.cards,
          presentInBackup: backup.present,
          destructive: destructive,
        ),
      );
    }

    return CloudBackupRestorePreview(
      games: games,
      requiresExplicitConfirmation: requiresExplicitConfirmation,
    );
  }

  bool _isDestructiveRestore({
    required _BackupGameSummary local,
    required _BackupGameSummary backup,
  }) {
    if (!backup.present) {
      return local.collections > 0 || local.collectionCards > 0;
    }
    if (local.collectionCards >= 10 &&
        backup.collectionCards <
            (local.collectionCards * (1 - _destructiveDropThreshold))) {
      return true;
    }
    if (local.collections >= 3 &&
        backup.collections <
            (local.collections * (1 - _destructiveDropThreshold))) {
      return true;
    }
    return false;
  }

  Future<Map<String, _BackupGameSummary>> _summariesFromLocalDatabases() async {
    final previousDbFileName = ScryfallDatabase.instance.databaseFileName;
    final result = <String, _BackupGameSummary>{};
    try {
      for (final definition in _backupDefinitions()) {
        final game = definition.appSettingsGame;
        if (game == null) {
          continue;
        }
        final payload = await ScryfallDatabase.instance.runWithDatabaseFileName(
          definition.dbFileName,
          () => ScryfallDatabase.instance.exportCollectionsBackupPayload(),
        );
        result[_cloudGameKey(game)] = _summaryFromSingleGamePayload(payload);
      }
    } finally {
      await ScryfallDatabase.instance.setDatabaseFileName(previousDbFileName);
    }
    return result;
  }

  Map<String, _BackupGameSummary> _summariesFromPayload(
    Map<String, dynamic> payload,
  ) {
    final rawGames = payload['games'];
    if (rawGames is Map) {
      final result = <String, _BackupGameSummary>{};
      for (final entry in rawGames.entries) {
        final value = entry.value;
        if (value is! Map) {
          continue;
        }
        final normalized = <String, dynamic>{};
        for (final item in value.entries) {
          normalized[item.key.toString()] = item.value;
        }
        result[entry.key.toString()] = _summaryFromSingleGamePayload(normalized);
      }
      return result;
    }
    final game = _inferLegacyPayloadGame(payload);
    if (game == null) {
      return const <String, _BackupGameSummary>{};
    }
    return <String, _BackupGameSummary>{
      _cloudGameKey(game): _summaryFromSingleGamePayload(payload),
    };
  }

  _BackupGameSummary _summaryFromSingleGamePayload(Map<String, dynamic> payload) {
    return _BackupGameSummary(
      collections: (payload['collections'] as List?)?.length ?? 0,
      collectionCards: (payload['collectionCards'] as List?)?.length ?? 0,
      cards: (payload['cards'] as List?)?.length ?? 0,
      present: true,
    );
  }

  List<GameDefinition> _backupDefinitions() {
    return GameRegistry.instance.enabledDefinitions
        .where((definition) => definition.appSettingsGame != null)
        .toList(growable: false);
  }

  ({int collections, int collectionCards, int cards}) _countGamesPayload(
    Object? rawGames,
  ) {
    if (rawGames is! Map) {
      return (collections: 0, collectionCards: 0, cards: 0);
    }
    var collections = 0;
    var collectionCards = 0;
    var cards = 0;
    for (final entry in rawGames.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final payload = <String, dynamic>{};
      for (final item in value.entries) {
        payload[item.key.toString()] = item.value;
      }
      collections += (payload['collections'] as List?)?.length ?? 0;
      collectionCards += (payload['collectionCards'] as List?)?.length ?? 0;
      cards += (payload['cards'] as List?)?.length ?? 0;
    }
    return (
      collections: collections,
      collectionCards: collectionCards,
      cards: cards,
    );
  }

  Future<Map<String, int>> _restorePayload(Map<String, dynamic> payload) async {
    final rawGames = payload['games'];
    if (rawGames is Map) {
      return _restoreMultiGamePayload(rawGames);
    }
    return _restoreSingleGamePayload(payload);
  }

  Future<Map<String, int>> _restoreMultiGamePayload(Map rawGames) async {
    final previousDbFileName = ScryfallDatabase.instance.databaseFileName;
    final totals = <String, int>{
      'cards': 0,
      'collections': 0,
      'collectionCards': 0,
    };
    try {
      for (final definition in _backupDefinitions()) {
        final game = definition.appSettingsGame;
        if (game == null) {
          continue;
        }
        final rawPayload = rawGames[_cloudGameKey(game)];
        if (rawPayload is! Map) {
          continue;
        }
        final payload = <String, dynamic>{};
        for (final entry in rawPayload.entries) {
          payload[entry.key.toString()] = entry.value;
        }
        final stats = await ScryfallDatabase.instance.runWithDatabaseFileName(
          definition.dbFileName,
          () => ScryfallDatabase.instance.restoreCollectionsBackupPayload(
            payload,
            replaceExisting: true,
          ),
        );
        totals.update('cards', (value) => value + (stats['cards'] ?? 0));
        totals.update(
          'collections',
          (value) => value + (stats['collections'] ?? 0),
        );
        totals.update(
          'collectionCards',
          (value) => value + (stats['collectionCards'] ?? 0),
        );
      }
    } finally {
      await ScryfallDatabase.instance.setDatabaseFileName(previousDbFileName);
    }
    return totals;
  }

  Future<void> _verifyRestoredPayload(Map<String, dynamic> payload) async {
    final expected = _summariesFromPayload(payload);
    final actual = await _summariesFromLocalDatabases();
    for (final entry in expected.entries) {
      final actualSummary = actual[entry.key] ?? const _BackupGameSummary.empty();
      final expectedSummary = entry.value;
      if (actualSummary.collections != expectedSummary.collections ||
          actualSummary.collectionCards != expectedSummary.collectionCards) {
        throw StateError(
          'cloud_backup_restore_verification_failed:${entry.key}:'
          'expected=${expectedSummary.collections}/${expectedSummary.collectionCards} '
          'actual=${actualSummary.collections}/${actualSummary.collectionCards}',
        );
      }
    }
  }

  Future<Map<String, int>> _restoreSingleGamePayload(
    Map<String, dynamic> payload,
  ) async {
    final game = _inferLegacyPayloadGame(payload);
    if (game == null) {
      return ScryfallDatabase.instance.restoreCollectionsBackupPayload(
        payload,
        replaceExisting: true,
      );
    }
    final definition = GameRegistry.instance.definitionForSettingsGame(game);
    if (definition == null) {
      throw const FormatException('cloud_backup_unknown_game');
    }
    final previousDbFileName = ScryfallDatabase.instance.databaseFileName;
    try {
      return await ScryfallDatabase.instance.runWithDatabaseFileName(
        definition.dbFileName,
        () => ScryfallDatabase.instance.restoreCollectionsBackupPayload(
          payload,
          replaceExisting: true,
        ),
      );
    } finally {
      await ScryfallDatabase.instance.setDatabaseFileName(previousDbFileName);
    }
  }

  AppTcgGame? _inferLegacyPayloadGame(Map<String, dynamic> payload) {
    final metadata = payload['metadata'];
    if (metadata is Map) {
      final rawGame = metadata['game']?.toString().trim().toLowerCase() ?? '';
      if (rawGame == 'pokemon') {
        return AppTcgGame.pokemon;
      }
      if (rawGame == 'mtg' || rawGame == 'magic') {
        return AppTcgGame.mtg;
      }
    }

    final collectionCards = payload['collectionCards'];
    if (collectionCards is List) {
      for (final item in collectionCards) {
        if (item is! Map) {
          continue;
        }
        final printingId =
            item['printingId']?.toString().trim().toLowerCase() ?? '';
        if (printingId.startsWith('pokemon:')) {
          return AppTcgGame.pokemon;
        }
      }
    }

    final cards = payload['cards'];
    if (cards is List) {
      for (final item in cards) {
        if (item is! Map) {
          continue;
        }
        final id = item['id']?.toString().trim().toLowerCase() ?? '';
        final cardJson = item['cardJson']?.toString().trim().toLowerCase() ?? '';
        if (id.startsWith('pokemon:') || cardJson.contains('"pokemon"')) {
          return AppTcgGame.pokemon;
        }
      }
    }
    return AppTcgGame.mtg;
  }

  String _cloudGameKey(AppTcgGame game) =>
      game == AppTcgGame.pokemon ? 'pokemon' : 'mtg';

  CloudBackupSnapshotInfo _snapshotInfoFromMetadata(FullMetadata metadata) {
    final custom = metadata.customMetadata ?? const <String, String>{};
    return CloudBackupSnapshotInfo(
      path: metadata.fullPath,
      updatedAt: metadata.updated,
      sizeBytes: metadata.size,
      hash: custom['payloadHash']?.trim(),
      automatic: custom['automatic']?.trim().toLowerCase() == 'true',
      appVersion: custom['appVersion']?.trim(),
      reason: custom['reason']?.trim(),
      collections: int.tryParse(custom['collections']?.trim() ?? ''),
      collectionCards: int.tryParse(custom['collectionCards']?.trim() ?? ''),
      cards: int.tryParse(custom['cards']?.trim() ?? ''),
    );
  }
}

class _BackupGameSummary {
  const _BackupGameSummary({
    required this.collections,
    required this.collectionCards,
    required this.cards,
    required this.present,
  });

  const _BackupGameSummary.empty()
    : collections = 0,
      collectionCards = 0,
      cards = 0,
      present = false;

  final int collections;
  final int collectionCards;
  final int cards;
  final bool present;
}
