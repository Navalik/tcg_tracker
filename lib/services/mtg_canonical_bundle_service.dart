import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/canonical_catalog_store.dart';
import '../domain/domain_models.dart';
import 'catalog_bundle_service.dart';

class _MtgCanonicalInstallRequest {
  const _MtgCanonicalInstallRequest({
    required this.databasePath,
    required this.batchJson,
  });

  final String databasePath;
  final Map<String, Object?> batchJson;
}

Future<void> _installMtgCanonicalBatchInBackground(
  _MtgCanonicalInstallRequest request,
) async {
  final store = await CanonicalCatalogStore.openAtPath(request.databasePath);
  try {
    final batch = canonicalCatalogBatchFromJson(
      Map<String, dynamic>.from(request.batchJson),
    );
    store.replaceCatalogForGame(TcgGameId.mtg, batch);
  } finally {
    store.dispose();
  }
}

class MtgCanonicalBundleCheckResult {
  const MtgCanonicalBundleCheckResult({
    required this.updateAvailable,
    required this.version,
    required this.updatedAtRaw,
    required this.manifestUri,
    required this.bundles,
    this.updatedAt,
  });

  final bool updateAvailable;
  final String version;
  final String updatedAtRaw;
  final DateTime? updatedAt;
  final Uri manifestUri;
  final List<CatalogBundle> bundles;

  int get sizeBytes => bundles.fold<int>(
    0,
    (total, bundle) =>
        total +
        bundle.artifacts.fold<int>(
          0,
          (bundleTotal, artifact) => bundleTotal + (artifact.sizeBytes ?? 0),
        ),
  );
}

class MtgCanonicalBundleService {
  MtgCanonicalBundleService({http.Client? client})
    : _client = client ?? http.Client();

  static const _game = 'mtg';
  static const _profile = 'full';
  static const _installedVersionKey =
      'mtg_firebase_canonical_installed_version';
  static const _minCompatibilityVersion = 2;

  final http.Client _client;

  static Uri legacyManifestUri({
    String bucket = CatalogBundleService.defaultFirebaseBucket,
  }) {
    return CatalogBundleService.manifestUri(bucket: bucket, game: _game);
  }

  static Future<bool> hasInstalledCatalog() async {
    final store = await CanonicalCatalogStore.openDefault();
    try {
      return store.hasCatalogForGame(TcgGameId.mtg);
    } finally {
      store.dispose();
    }
  }

  Future<MtgCanonicalBundleCheckResult> checkForUpdate({
    required Set<String> languages,
    String bucket = CatalogBundleService.defaultFirebaseBucket,
  }) async {
    final legacyManifestRaw = await CatalogBundleService.fetchJsonWithRetry(
      client: _client,
      uri: legacyManifestUri(bucket: bucket),
      errorPrefix: 'mtg_legacy_manifest',
    );
    final legacyManifest = CatalogBundleService.parseManifest(
      legacyManifestRaw,
      expectedGame: _game,
    );
    final canonicalManifestUri =
        CatalogBundleService.firebaseDownloadUriForObjectPath(
          bucket: bucket,
          game: _game,
          objectPath:
              'catalog/$_game/releases/${legacyManifest.version}/manifest_canonical.json',
        );
    final canonicalManifestRaw = await CatalogBundleService.fetchJsonWithRetry(
      client: _client,
      uri: canonicalManifestUri,
      errorPrefix: 'mtg_canonical_manifest',
    );
    final manifest = CatalogBundleService.parseManifest(
      canonicalManifestRaw,
      expectedGame: _game,
    );
    final bundles = CatalogBundleService.selectBundlesForLanguages(
      bundles: manifest.bundles,
      requiredLanguages: _requiredLanguages(languages),
      profile: _profile,
      minCompatibilityVersion: _minCompatibilityVersion,
    );
    if (bundles == null || bundles.isEmpty) {
      throw const FormatException('mtg_canonical_manifest_missing_bundles');
    }
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString(_installedVersionKey);
    final updatedAtRaw =
        (manifest.source?['updated_at'] as String?)?.trim() ?? manifest.version;
    return MtgCanonicalBundleCheckResult(
      updateAvailable: installedVersion != manifest.version,
      version: manifest.version,
      updatedAtRaw: updatedAtRaw,
      updatedAt: DateTime.tryParse(updatedAtRaw),
      manifestUri: canonicalManifestUri,
      bundles: bundles,
    );
  }

  Future<CanonicalCatalogImportBatch> downloadImportBatch({
    required MtgCanonicalBundleCheckResult bundle,
    String bucket = CatalogBundleService.defaultFirebaseBucket,
    void Function(int receivedBytes, int totalBytes)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final totalBytes = bundle.sizeBytes;
    var receivedBytes = 0;
    var merged = const CanonicalCatalogImportBatch(
      cards: <CatalogCard>[],
      sets: <CatalogSet>[],
      printings: <CardPrintingRef>[],
      cardLocalizations: <LocalizedCardData>[],
      setLocalizations: <LocalizedSetData>[],
      providerMappings: <ProviderMappingRecord>[],
      priceSnapshots: <PriceSnapshot>[],
    );
    for (final selectedBundle in bundle.bundles) {
      for (final artifact in selectedBundle.artifacts) {
        onStatus?.call('Downloading ${artifact.name}');
        var artifactReportedBytes = 0;
        final bytes = await CatalogBundleService.downloadArtifactBytes(
          artifact: artifact,
          bucket: bucket,
          game: _game,
          client: _client,
          errorPrefix: 'mtg_canonical_artifact',
          onProgress: (fraction) {
            final size = artifact.sizeBytes ?? 0;
            final candidate = (size * fraction).round();
            final delta = candidate - artifactReportedBytes;
            if (delta <= 0) {
              return;
            }
            artifactReportedBytes = candidate;
            receivedBytes += delta;
            onProgress?.call(receivedBytes, totalBytes);
          },
        );
        if ((artifact.sizeBytes ?? 0) > artifactReportedBytes) {
          receivedBytes += (artifact.sizeBytes ?? 0) - artifactReportedBytes;
          onProgress?.call(receivedBytes, totalBytes);
        }
        onStatus?.call('Decoding ${artifact.name}');
        merged = _mergeBatches(merged, _decodeArtifactBatch(bytes));
        onStatus?.call('Merged ${artifact.name}');
      }
    }
    onProgress?.call(totalBytes, totalBytes);
    return merged;
  }

  Future<void> installBatch(CanonicalCatalogImportBatch batch) async {
    if (batch.cards.isEmpty && batch.printings.isEmpty) {
      throw const FormatException('mtg_canonical_batch_empty');
    }
    final databasePath = await CanonicalCatalogStore.defaultDatabasePath();
    final batchJson = canonicalCatalogBatchToJson(batch);
    await Isolate.run(
      () => _installMtgCanonicalBatchInBackground(
        _MtgCanonicalInstallRequest(
          databasePath: databasePath,
          batchJson: batchJson,
        ),
      ),
    );
  }

  Future<void> markInstalled(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_installedVersionKey, version);
  }

  void dispose() {
    _client.close();
  }

  static Set<String> _requiredLanguages(Set<String> languages) {
    final normalized = languages
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) {
      return const <String>{'en'};
    }
    if (normalized.contains('it')) {
      return const <String>{'en', 'it'};
    }
    return const <String>{'en'};
  }

  CanonicalCatalogImportBatch _decodeArtifactBatch(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('mtg_canonical_snapshot_empty');
    }
    final decompressed = gzip.decode(bytes);
    final parsed = jsonDecode(utf8.decode(decompressed));
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('mtg_canonical_snapshot_not_object');
    }
    final compatibilityVersion =
        (parsed['compatibility_version'] as num?)?.toInt() ?? 0;
    if (compatibilityVersion < _minCompatibilityVersion) {
      throw const FormatException(
        'mtg_canonical_snapshot_unsupported_compatibility',
      );
    }
    final batch = parsed['batch'];
    if (batch is! Map<String, dynamic>) {
      throw const FormatException('mtg_canonical_snapshot_missing_batch');
    }
    return canonicalCatalogBatchFromJson(batch);
  }

  CanonicalCatalogImportBatch _mergeBatches(
    CanonicalCatalogImportBatch current,
    CanonicalCatalogImportBatch next,
  ) {
    final cards = <String, CatalogCard>{
      for (final card in current.cards) card.cardId: card,
      for (final card in next.cards) card.cardId: card,
    };
    final sets = <String, CatalogSet>{
      for (final set in current.sets) set.setId: set,
      for (final set in next.sets) set.setId: set,
    };
    final printings = <String, CardPrintingRef>{
      for (final printing in current.printings) printing.printingId: printing,
      for (final printing in next.printings) printing.printingId: printing,
    };
    final cardLocalizations = <String, LocalizedCardData>{
      for (final item in current.cardLocalizations)
        '${item.cardId}:${item.languageCode}': item,
      for (final item in next.cardLocalizations)
        '${item.cardId}:${item.languageCode}': item,
    };
    final setLocalizations = <String, LocalizedSetData>{
      for (final item in current.setLocalizations)
        '${item.setId}:${item.languageCode}': item,
      for (final item in next.setLocalizations)
        '${item.setId}:${item.languageCode}': item,
    };
    final providerMappings = <String, ProviderMappingRecord>{
      for (final item in current.providerMappings)
        _providerMappingKey(item): item,
      for (final item in next.providerMappings) _providerMappingKey(item): item,
    };
    final priceSnapshots = <String, PriceSnapshot>{
      for (final item in current.priceSnapshots) _priceSnapshotKey(item): item,
      for (final item in next.priceSnapshots) _priceSnapshotKey(item): item,
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

  String _providerMappingKey(ProviderMappingRecord record) {
    final mapping = record.mapping;
    return [
      mapping.providerId.value,
      mapping.objectType,
      mapping.providerObjectId,
      record.cardId ?? '',
      record.printingId ?? '',
      record.setId ?? '',
    ].join('|');
  }

  String _priceSnapshotKey(PriceSnapshot snapshot) {
    return [
      snapshot.printingId,
      snapshot.sourceId.value,
      snapshot.currencyCode,
      snapshot.finishKey ?? '',
    ].join('|');
  }
}
