import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  test('selects language bundles with required dependencies first', () {
    final manifest = CatalogBundleService.parseManifest('''
      {
        "bundle": "pokemon",
        "version": "v",
        "schema_version": 2,
        "compatibility_version": 2,
        "bundles": [
          {
            "id": "delta_it",
            "kind": "delta",
            "schema_version": 2,
            "compatibility_version": 2,
            "languages": ["it"],
            "requires": ["base_en"],
            "artifacts": []
          },
          {
            "id": "base_en",
            "kind": "base",
            "schema_version": 2,
            "compatibility_version": 2,
            "languages": ["en"],
            "requires": [],
            "artifacts": []
          }
        ]
      }
      ''', expectedGame: 'pokemon');

    final selected = CatalogBundleService.selectBundlesForLanguages(
      bundles: manifest.bundles,
      requiredLanguages: const <String>{'it'},
      minCompatibilityVersion: 2,
    );

    expect(selected, isNotNull);
    expect(
      selected!.map((bundle) => bundle.id),
      orderedEquals(const <String>['base_en', 'delta_it']),
    );
  });

  test('returns null when a required dependency is missing', () {
    final selected = CatalogBundleService.selectBundlesForLanguages(
      bundles: const <CatalogBundle>[
        CatalogBundle(
          id: 'delta_it',
          kind: 'delta',
          schemaVersion: 2,
          compatibilityVersion: 2,
          languages: <String>['it'],
          requires: <String>['base_en'],
          artifacts: <CatalogBundleArtifact>[],
          raw: <String, dynamic>{},
        ),
      ],
      requiredLanguages: const <String>{'it'},
      minCompatibilityVersion: 2,
    );

    expect(selected, isNull);
  });

  test('downloads artifact bytes when sha256 matches', () async {
    final bytes = utf8.encode('pokemon catalog payload');
    final client = MockClient((request) async {
      expect(request.url.toString(), contains('catalog%2Fpokemon%2F'));
      return http.Response.bytes(bytes, 200);
    });

    final downloaded = await CatalogBundleService.downloadArtifactBytes(
      artifact: CatalogBundleArtifact(
        name: 'canonical_catalog_snapshot_en.json.gz',
        path:
            'catalog/pokemon/releases/v/canonical_catalog_snapshot_en.json.gz',
        sizeBytes: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      ),
      bucket: CatalogBundleService.defaultFirebaseBucket,
      game: 'pokemon',
      client: client,
      onProgress: (_) {},
    );

    expect(downloaded, bytes);
  });

  test('rejects artifact bytes when sha256 mismatches', () async {
    final bytes = utf8.encode('pokemon catalog payload');
    final client = MockClient((request) async {
      return http.Response.bytes(bytes, 200);
    });

    expect(
      () => CatalogBundleService.downloadArtifactBytes(
        artifact: CatalogBundleArtifact(
          name: 'canonical_catalog_snapshot_en.json.gz',
          path:
              'catalog/pokemon/releases/v/canonical_catalog_snapshot_en.json.gz',
          sizeBytes: bytes.length,
          sha256: ''.padLeft(64, '0'),
        ),
        bucket: CatalogBundleService.defaultFirebaseBucket,
        game: 'pokemon',
        client: client,
        onProgress: (_) {},
      ),
      throwsA(
        isA<HttpException>().having(
          (error) => error.message,
          'message',
          'catalog_artifact_sha256_mismatch',
        ),
      ),
    );
  });

  test('rejects artifact bytes when size_bytes mismatches', () async {
    final bytes = utf8.encode('pokemon catalog payload');
    final client = MockClient((request) async {
      return http.Response.bytes(bytes, 200);
    });

    expect(
      () => CatalogBundleService.downloadArtifactBytes(
        artifact: CatalogBundleArtifact(
          name: 'canonical_catalog_snapshot_en.json.gz',
          path:
              'catalog/pokemon/releases/v/canonical_catalog_snapshot_en.json.gz',
          sizeBytes: bytes.length + 1,
          sha256: sha256.convert(bytes).toString(),
        ),
        bucket: CatalogBundleService.defaultFirebaseBucket,
        game: 'pokemon',
        client: client,
        onProgress: (_) {},
      ),
      throwsA(
        isA<HttpException>().having(
          (error) => error.message,
          'message',
          'catalog_artifact_size_mismatch',
        ),
      ),
    );
  });

  test('rejects artifact URLs outside catalog game prefix', () async {
    final client = MockClient((request) async {
      fail('Downloader should reject the URL before sending a request');
    });

    expect(
      () => CatalogBundleService.downloadArtifactBytes(
        artifact: const CatalogBundleArtifact(
          name: 'backup.json.gz',
          downloadUrl:
              'https://firebasestorage.googleapis.com/v0/b/bindervault.firebasestorage.app/o/users%2Fabc%2Fbackup.json.gz?alt=media',
        ),
        bucket: CatalogBundleService.defaultFirebaseBucket,
        game: 'pokemon',
        client: client,
        onProgress: (_) {},
      ),
      throwsA(
        isA<HttpException>().having(
          (error) => error.message,
          'message',
          'catalog_artifact_url_not_allowed',
        ),
      ),
    );
  });
}
