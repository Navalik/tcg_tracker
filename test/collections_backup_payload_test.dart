import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcg_tracker/db/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'collections_backup_payload_test_',
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

  test('backup payload preserves metadata and collection printing ids', () async {
    final db = await ScryfallDatabase.instance.open();
    await db.into(db.cards).insert(
      CardsCompanion.insert(
        id: 'base1-1',
        name: 'Alakazam',
      ),
    );
    final collectionId = await db.into(db.collections).insert(
      CollectionsCompanion.insert(
        name: 'All cards',
        type: const Value('all'),
      ),
    );
    await db.customStatement(
      '''
      INSERT INTO collection_cards(
        collection_id,
        card_id,
        quantity,
        foil,
        alt_art,
        printing_id
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        collectionId,
        'base1-1',
        3,
        0,
        0,
        'pokemon:printing:tcgdex:base1-1:it',
      ],
    );

    final payload = await ScryfallDatabase.instance.exportCollectionsBackupPayload(
      metadata: const <String, Object?>{
        'game': 'pokemon',
        'reason': 'test',
      },
    );

    expect(payload['schemaVersion'], equals(2));
    expect(payload['metadata'], isA<Map<String, Object?>>());
    expect(
      ((payload['metadata'] as Map<String, Object?>)['game']),
      equals('pokemon'),
    );
    final collectionCards = payload['collectionCards'] as List<dynamic>;
    expect(collectionCards, hasLength(1));
    expect(
      (collectionCards.first as Map<String, dynamic>)['printingId'],
      equals('pokemon:printing:tcgdex:base1-1:it'),
    );

    await db.delete(db.collectionCards).go();
    await db.delete(db.collections).go();

    final stats = await ScryfallDatabase.instance.restoreCollectionsBackupPayload(
      payload,
    );
    expect(stats['collections'], equals(1));
    expect(stats['collectionCards'], equals(1));

    final rows = await db.customSelect(
      '''
      SELECT card_id AS card_id, printing_id AS printing_id, quantity AS quantity
      FROM collection_cards
      ''',
    ).get();
    expect(rows, hasLength(1));
    expect(rows.first.read<String>('card_id'), equals('base1-1'));
    expect(
      rows.first.readNullable<String>('printing_id'),
      equals('pokemon:printing:tcgdex:base1-1:it'),
    );
    expect(rows.first.read<int>('quantity'), equals(3));
  });

  test('restore rejects payload exported for a different game', () async {
    final payload = <String, dynamic>{
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'metadata': const <String, Object?>{'game': 'mtg'},
      'collections': const <Object>[],
      'collectionCards': const <Object>[],
      'cards': const <Object>[],
    };

    expect(
      () => ScryfallDatabase.instance.restoreCollectionsBackupPayload(payload),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('backup_game_mismatch'),
        ),
      ),
    );
  });
}
