import 'package:flutter_test/flutter_test.dart';
import 'package:tcg_tracker/services/pokemon_bulk_service.dart';

void main() {
  test(
    'hosted Pokemon bundle selection includes required base dependencies',
    () {
      final selected = PokemonBulkService.instance
          .selectHostedBundlesForMissingLanguagesForTesting(
            bundles: const <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'base_en',
                'kind': 'base',
                'compatibility_version': 2,
                'profile': 'full',
                'languages': <String>['en'],
                'requires': <String>[],
                'artifacts': <Map<String, String>>[
                  <String, String>{
                    'name': 'canonical_catalog_snapshot_en.json.gz',
                    'path': 'canonical_catalog_snapshot_en.json.gz',
                  },
                ],
              },
              <String, dynamic>{
                'id': 'delta_it',
                'kind': 'delta',
                'compatibility_version': 2,
                'profile': 'full',
                'languages': <String>['it'],
                'requires': <String>['base_en'],
                'artifacts': <Map<String, String>>[
                  <String, String>{
                    'name': 'canonical_catalog_snapshot_it.json.gz',
                    'path': 'canonical_catalog_snapshot_it.json.gz',
                  },
                ],
              },
            ],
            profile: 'full',
            requiredLanguages: const <String>{'it'},
          );

      expect(selected, isNotNull);
      expect(
        selected!.map((bundle) => bundle['id']),
        orderedEquals(const <String>['base_en', 'delta_it']),
      );
    },
  );

  test('hosted Pokemon bundle resolves Firebase download_url artifacts', () {
    final uri = PokemonBulkService.instance
        .resolveCanonicalSnapshotAssetUriFromBundleForTesting(const <
          String,
          dynamic
        >{
          'id': 'base_en',
          'artifacts': <Map<String, String>>[
            <String, String>{
              'name': 'canonical_catalog_snapshot_en.json.gz',
              'path':
                  'catalog/pokemon/releases/20260417/canonical_catalog_snapshot_en.json.gz',
              'download_url':
                  'https://firebasestorage.googleapis.com/v0/b/bindervault.firebasestorage.app/o/catalog%2Fpokemon%2Freleases%2F20260417%2Fcanonical_catalog_snapshot_en.json.gz?alt=media',
            },
          ],
        });

    expect(uri, isNotNull);
    expect(uri!.host, equals('firebasestorage.googleapis.com'));
    expect(
      PokemonBulkService.instance.isAllowedDownloadUriForTesting(
        uri.toString(),
      ),
      isTrue,
    );
  });

  test('hosted Pokemon bundle rejects Firebase URLs outside catalog bucket', () {
    expect(
      PokemonBulkService.instance.isAllowedDownloadUriForTesting(
        'https://firebasestorage.googleapis.com/v0/b/other.appspot.com/o/catalog%2Fpokemon%2Flatest%2Fmanifest.json?alt=media',
      ),
      isFalse,
    );
    expect(
      PokemonBulkService.instance.isAllowedDownloadUriForTesting(
        'https://firebasestorage.googleapis.com/v0/b/bindervault.firebasestorage.app/o/users%2Fabc%2Fcloud-backup%2Flatest.json.gz?alt=media',
      ),
      isFalse,
    );
  });
}
