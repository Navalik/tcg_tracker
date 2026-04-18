import 'package:flutter_test/flutter_test.dart';
import 'package:tcg_tracker/services/catalog_bundle_service.dart';

void main() {
  test('parses base plus delta catalog manifest', () {
    final manifest = CatalogBundleService.parseManifest('''
      {
        "bundle": "mtg",
        "version": "20260417T0920027840000-full-base-delta-compat1",
        "schema_version": 1,
        "compatibility_version": 1,
        "languages": ["en", "it"],
        "bundles": [
          {
            "id": "base_en",
            "kind": "base",
            "schema_version": 1,
            "compatibility_version": 1,
            "language": "en",
            "requires": [],
            "artifacts": [
              {
                "name": "mtg_base_en.json.gz",
                "path": "catalog/mtg/releases/v/mtg_base_en.json.gz",
                "download_url": "https://firebasestorage.googleapis.com/v0/b/bindervault.firebasestorage.app/o/catalog%2Fmtg%2Freleases%2Fv%2Fmtg_base_en.json.gz?alt=media",
                "size_bytes": 123,
                "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
              }
            ]
          },
          {
            "id": "delta_it",
            "kind": "delta",
            "schema_version": 1,
            "compatibility_version": 1,
            "language": "it",
            "requires": ["base_en"],
            "artifacts": []
          }
        ]
      }
      ''', expectedGame: 'mtg');

    expect(manifest.game, 'mtg');
    expect(manifest.version, contains('compat1'));
    expect(manifest.languages, orderedEquals(const <String>['en', 'it']));
    expect(manifest.bundles.map((bundle) => bundle.id), [
      'base_en',
      'delta_it',
    ]);
    expect(manifest.bundles.first.artifacts.single.sizeBytes, 123);
  });

  test('rejects manifest for another game', () {
    expect(
      () => CatalogBundleService.parseManifest('''
        {
          "bundle": "pokemon",
          "version": "v",
          "schema_version": 2,
          "compatibility_version": 2,
          "bundles": []
        }
        ''', expectedGame: 'mtg'),
      throwsFormatException,
    );
  });

  test('validates Firebase catalog URLs by bucket and game prefix', () {
    expect(
      CatalogBundleService.isAllowedFirebaseCatalogUri(
        'https://firebasestorage.googleapis.com/v0/b/bindervault.firebasestorage.app/o/catalog%2Fpokemon%2Flatest%2Fmanifest.json?alt=media',
        bucket: CatalogBundleService.defaultFirebaseBucket,
        game: 'pokemon',
      ),
      isTrue,
    );
    expect(
      CatalogBundleService.isAllowedFirebaseCatalogUri(
        'https://firebasestorage.googleapis.com/v0/b/bindervault.firebasestorage.app/o/users%2Fabc%2Fbackup.json.gz?alt=media',
        bucket: CatalogBundleService.defaultFirebaseBucket,
        game: 'pokemon',
      ),
      isFalse,
    );
    expect(
      CatalogBundleService.isAllowedFirebaseCatalogUri(
        'https://firebasestorage.googleapis.com/v0/b/other.appspot.com/o/catalog%2Fpokemon%2Flatest%2Fmanifest.json?alt=media',
        bucket: CatalogBundleService.defaultFirebaseBucket,
        game: 'pokemon',
      ),
      isFalse,
    );
  });

  test('resolves artifact paths to Firebase media URLs', () {
    final uri = CatalogBundleService.resolveArtifactUri(
      const CatalogBundleArtifact(
        name: 'canonical_catalog_snapshot_en.json.gz',
        path:
            'catalog/pokemon/releases/v/canonical_catalog_snapshot_en.json.gz',
      ),
      bucket: CatalogBundleService.defaultFirebaseBucket,
      game: 'pokemon',
    );

    expect(uri, isNotNull);
    expect(uri!.host, CatalogBundleService.firebaseStorageHost);
    expect(
      Uri.decodeComponent(uri.pathSegments.last),
      contains('catalog/pokemon/releases/v'),
    );
  });
}
