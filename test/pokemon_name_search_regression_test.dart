import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcg_tracker/db/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'pokemon_name_search_regression',
    );
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    debugAppDatabaseDirectoryOverride = tempDir.path;
    await ScryfallDatabase.instance.setDatabaseFileName('pokemon.db');
  });

  tearDown(() async {
    await ScryfallDatabase.instance.close();
    debugAppDatabaseDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'pokemon name search finds localized alias when primary name differs',
    () async {
      final database = await ScryfallDatabase.instance.open();
      await ScryfallDatabase.instance.insertPokemonCardsBatch(
        database,
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'pokemon:test:kieran',
            'name': 'Kieran',
            'lang': 'en',
            'set_code': 'sv',
            'set_name': 'Scarlet & Violet',
            'collector_number': '123',
            'rarity': 'rare',
            'type_line': 'Trainer',
            'card_json': <String, Object?>{'search_aliases_flat': 'Kissara'},
          },
        ],
      );
      await ScryfallDatabase.instance.rebuildPrintedNameSearchIndex();

      final results = await ScryfallDatabase.instance.searchCardsByName(
        'Kissara',
        languages: const <String>['it'],
      );

      expect(results, isNotEmpty);
      expect(results.first.id, equals('pokemon:test:kieran'));
      expect(results.first.name, equals('Kieran'));
    },
  );
}
