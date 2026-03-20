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
}
