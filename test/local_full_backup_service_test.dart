import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcg_tracker/db/app_database.dart';
import 'package:tcg_tracker/services/local_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'local_full_backup_service_test_',
    );
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );
    debugAppDatabaseDirectoryOverride = tempDir.path;
    await ScryfallDatabase.instance.setDatabaseFileName('scryfall.db');
  });

  tearDown(() async {
    await ScryfallDatabase.instance.close();
    debugAppDatabaseDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  test('full backup export and import restores mtg and pokemon databases', () async {
    await ScryfallDatabase.instance.runWithDatabaseFileName('scryfall.db', () async {
      final db = await ScryfallDatabase.instance.open();
      await db.into(db.cards).insert(
        CardsCompanion.insert(id: 'mtg-card-1', name: 'Lightning Bolt'),
      );
      final collectionId = await db.into(db.collections).insert(
        CollectionsCompanion.insert(name: 'Magic Main', type: const Value('custom')),
      );
      await db.customStatement(
        '''
        INSERT INTO collection_cards(collection_id, card_id, quantity, foil, alt_art)
        VALUES (?, ?, ?, ?, ?)
        ''',
        <Object?>[collectionId, 'mtg-card-1', 2, 0, 0],
      );
    });

    await ScryfallDatabase.instance.runWithDatabaseFileName('pokemon.db', () async {
      final db = await ScryfallDatabase.instance.open();
      await db.into(db.cards).insert(
        CardsCompanion.insert(id: 'pokemon-card-1', name: 'Pikachu'),
      );
      final collectionId = await db.into(db.collections).insert(
        CollectionsCompanion.insert(name: 'Pokemon Main', type: const Value('custom')),
      );
      await db.customStatement(
        '''
        INSERT INTO collection_cards(collection_id, card_id, quantity, foil, alt_art, printing_id)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        <Object?>[
          collectionId,
          'pokemon-card-1',
          1,
          0,
          0,
          'pokemon:printing:test:pokemon-card-1:it',
        ],
      );
    });

    final exported = await LocalBackupService.instance.exportFullBackup(
      filePrefix: 'test_full_backup',
    );
    expect(exported != null, isTrue);
    expect(exported!.collections, equals(2));
    expect(exported.collectionCards, equals(2));

    await ScryfallDatabase.instance.runWithDatabaseFileName('scryfall.db', () async {
      final db = await ScryfallDatabase.instance.open();
      await db.delete(db.collectionCards).go();
      await db.delete(db.collections).go();
    });
    await ScryfallDatabase.instance.runWithDatabaseFileName('pokemon.db', () async {
      final db = await ScryfallDatabase.instance.open();
      await db.delete(db.collectionCards).go();
      await db.delete(db.collections).go();
    });

    final stats = await LocalBackupService.instance.importCollectionsBackupFromFile(
      exported.file,
    );
    expect(stats['collections'], equals(2));
    expect(stats['collectionCards'], equals(2));

    await ScryfallDatabase.instance.runWithDatabaseFileName('scryfall.db', () async {
      final db = await ScryfallDatabase.instance.open();
      final collections = await db.select(db.collections).get();
      expect(collections, hasLength(1));
      expect(collections.first.name, equals('Magic Main'));
    });
    await ScryfallDatabase.instance.runWithDatabaseFileName('pokemon.db', () async {
      final db = await ScryfallDatabase.instance.open();
      final collections = await db.select(db.collections).get();
      expect(collections, hasLength(1));
      expect(collections.first.name, equals('Pokemon Main'));
      final rows = await db.customSelect(
        'SELECT printing_id AS printing_id FROM collection_cards',
      ).get();
      expect(rows, hasLength(1));
      expect(
        rows.first.readNullable<String>('printing_id'),
        equals('pokemon:printing:test:pokemon-card-1:it'),
      );
    });
  });
}
