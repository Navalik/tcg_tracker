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
  });

  final String path;
  final DateTime? updatedAt;
  final int? sizeBytes;
  final String? hash;
  final bool automatic;
  final String? appVersion;
  final String? reason;
}

class CloudBackupUploadResult {
  const CloudBackupUploadResult({
    required this.snapshot,
    required this.skipped,
  });

  final CloudBackupSnapshotInfo snapshot;
  final bool skipped;
}

class CloudBackupService {
  CloudBackupService._();

  static final CloudBackupService instance = CloudBackupService._();
  static const int backupSchemaVersion = 1;
  static const String _latestObjectName = 'latest.json.gz';

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
    final payload = await ScryfallDatabase.instance
        .exportCollectionsBackupPayload(
          metadata: <String, Object?>{
            'cloudBackupSchemaVersion': backupSchemaVersion,
            'automatic': automatic,
            'reason': reason,
            'appVersion': packageInfo.version,
            'uid': user.uid,
          },
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
    final gzipBytes = gzip.encode(payloadBytes);
    final collections = (payload['collections'] as List?)?.length ?? 0;
    final collectionCards = (payload['collectionCards'] as List?)?.length ?? 0;
    final cards = (payload['cards'] as List?)?.length ?? 0;
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
    final task = await ref.putData(Uint8List.fromList(gzipBytes), metadata);
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
      final metadata = await _latestRef(user.uid).getMetadata();
      final snapshot = _snapshotInfoFromMetadata(metadata);
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

  Future<Map<String, int>> restoreLatestBackup() async {
    final eligibility = await checkEligibility();
    if (!eligibility.canAccess) {
      throw StateError('cloud_backup_unavailable');
    }
    final user = FirebaseAuth.instance.currentUser!;
    final data = await _latestRef(user.uid).getData();
    if (data == null || data.isEmpty) {
      throw const FormatException('cloud_backup_empty');
    }
    final decodedText = _decodeBackupPayloadText(data);
    final payload = jsonDecode(decodedText);
    if (payload is! Map) {
      throw const FormatException('cloud_backup_invalid');
    }
    final normalized = <String, dynamic>{};
    for (final entry in payload.entries) {
      normalized[entry.key.toString()] = entry.value;
    }
    final stats = await ScryfallDatabase.instance
        .restoreCollectionsBackupPayload(normalized, replaceExisting: true);
    final remote = await fetchLatestSnapshotInfo();
    await AppSettings.saveCloudBackupLastHash(remote?.hash);
    await AppSettings.saveCloudBackupLastUploadedAtMs(
      remote?.updatedAt?.millisecondsSinceEpoch,
    );
    await AppSettings.saveCloudBackupLastError(null);
    return stats;
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

  Reference _latestRef(String uid) {
    return FirebaseStorage.instance.ref(
      'users/$uid/cloud-backup/$_latestObjectName',
    );
  }

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
    );
  }
}
