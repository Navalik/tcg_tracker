import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tcg_tracker/db/app_database.dart';

void main() {
  group('migration safety', () {
    test(
      'upgrades schema v8 to v9 with legacy backups and collection cleanup',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'tcg_tracker_migration_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final dbPath = p.join(tempDir.path, 'legacy_v8.db');
        _seedLegacyV8Database(dbPath);

        final database = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
        addTearDown(() async {
          await database.close();
        });

        await database
            .customSelect('SELECT COUNT(*) AS total FROM collections')
            .get();

        final allCollections = await database.customSelect('''
        SELECT id, name, type
        FROM collections
        WHERE type = 'all'
        ORDER BY id
        ''').get();
        expect(allCollections, hasLength(1));
        expect(allCollections.first.read<String>('id'), '1');

        final allCardRows = await database.customSelect('''
        SELECT collection_id, card_id, quantity, foil, alt_art
        FROM collection_cards
        WHERE collection_id = 1 AND card_id = 'card_a'
        ''').get();
        expect(allCardRows, hasLength(1));
        expect(allCardRows.first.read<int>('quantity'), 5);
        expect(allCardRows.first.read<int>('foil'), 1);
        expect(allCardRows.first.read<int>('alt_art'), 0);

        final deckRows = await database.customSelect('''
        SELECT card_id, quantity, foil, alt_art
        FROM collection_cards
        WHERE collection_id = 7
        ''').get();
        expect(deckRows, hasLength(1));
        expect(deckRows.first.read<String>('card_id'), 'card_f');
        expect(deckRows.first.read<int>('quantity'), 2);
        expect(deckRows.first.read<int>('foil'), 1);

        final wishlistRows = await database.customSelect('''
        SELECT quantity, foil, alt_art
        FROM collection_cards
        WHERE collection_id = 5 AND card_id = 'card_d'
        ''').get();
        expect(wishlistRows, hasLength(1));
        expect(wishlistRows.first.read<int>('quantity'), 0);
        expect(wishlistRows.first.read<int>('foil'), 0);
        expect(wishlistRows.first.read<int>('alt_art'), 0);

        final wishlistFilter = await database
            .customSelect("SELECT filter_json FROM collections WHERE id = 5")
            .getSingle();
        expect(wishlistFilter.readNullable<String>('filter_json'), isNull);

        final smartRows = await database
            .customSelect(
              "SELECT COUNT(*) AS total FROM collection_cards WHERE collection_id = 4",
            )
            .getSingle();
        expect(smartRows.read<int>('total'), 0);

        final setRows = await database
            .customSelect(
              "SELECT COUNT(*) AS total FROM collection_cards WHERE collection_id = 6",
            )
            .getSingle();
        expect(setRows.read<int>('total'), 0);

        final collectionBackupCount = await database
            .customSelect(
              'SELECT COUNT(*) AS total FROM migration_legacy_collections_backup',
            )
            .getSingle();
        expect(collectionBackupCount.read<int>('total'), greaterThan(0));

        final collectionCardsBackupCount = await database
            .customSelect(
              'SELECT COUNT(*) AS total FROM migration_legacy_collection_cards_backup',
            )
            .getSingle();
        expect(collectionCardsBackupCount.read<int>('total'), greaterThan(0));

        final auditCount = await database.customSelect('''
        SELECT COUNT(*) AS total
        FROM migration_legacy_audit
        WHERE key IN (
          'cleanup_v9_done_at',
          'cleanup_v9_all_count',
          'cleanup_v9_wishlist_with_filter'
        )
        ''').getSingle();
        expect(auditCount.read<int>('total'), 3);
      },
    );

    test(
      'preserves collection count and owned quantity totals across migration',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'tcg_tracker_migration_totals_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final dbPath = p.join(tempDir.path, 'legacy_v8_totals.db');
        _seedLegacyV8Database(dbPath);

        final legacyDb = sqlite.sqlite3.open(dbPath);
        final preCollectionCount =
            legacyDb
                    .select('SELECT COUNT(*) AS total FROM collections')
                    .first['total']
                as int;
        final preOwnedTotal =
            legacyDb.select('''
            SELECT COALESCE(SUM(quantity), 0) AS total
            FROM collection_cards
            WHERE collection_id IN (
              SELECT id
              FROM collections
              WHERE type IN ('all', 'deck')
            )
            ''').first['total']
                as int;
        legacyDb.close();

        final database = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
        addTearDown(() async {
          await database.close();
        });

        await database
            .customSelect('SELECT COUNT(*) AS total FROM collections')
            .get();

        final postCollectionCount =
            (await database
                    .customSelect('SELECT COUNT(*) AS total FROM collections')
                    .getSingle())
                .read<int>('total');
        expect(postCollectionCount, equals(preCollectionCount - 1));

        final postOwnedTotal = (await database.customSelect('''
        SELECT COALESCE(SUM(quantity), 0) AS total
        FROM collection_cards
        WHERE collection_id IN (
          SELECT id
          FROM collections
          WHERE type IN ('all', 'deck')
        )
        ''').getSingle()).read<int>('total');
        expect(postOwnedTotal, equals(preOwnedTotal));

        final backupOwnedTotal = (await database.customSelect('''
        SELECT COALESCE(SUM(quantity), 0) AS total
        FROM migration_legacy_collection_cards_backup
        WHERE collection_id IN (1, 2, 7)
        ''').getSingle()).read<int>('total');
        expect(backupOwnedTotal, equals(preOwnedTotal));
      },
    );
  });
}

void _seedLegacyV8Database(String dbPath) {
  final db = sqlite.sqlite3.open(dbPath);
  try {
    db.execute('PRAGMA user_version = 8;');

    db.execute('''
      CREATE TABLE cards (
        id TEXT PRIMARY KEY NOT NULL,
        oracle_id TEXT,
        name TEXT NOT NULL,
        set_code TEXT,
        set_name TEXT,
        set_total INTEGER,
        collector_number TEXT,
        rarity TEXT,
        type_line TEXT,
        mana_cost TEXT,
        oracle_text TEXT,
        cmc REAL,
        colors TEXT,
        color_identity TEXT,
        artist TEXT,
        power TEXT,
        toughness TEXT,
        loyalty TEXT,
        lang TEXT,
        released_at TEXT,
        image_uris TEXT,
        card_faces TEXT,
        card_json TEXT,
        price_usd TEXT,
        price_usd_foil TEXT,
        price_usd_etched TEXT,
        price_eur TEXT,
        price_eur_foil TEXT,
        price_tix TEXT,
        prices_updated_at INTEGER
      );
    ''');

    db.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'custom',
        filter_json TEXT
      );
    ''');

    db.execute('''
      CREATE TABLE collection_cards (
        collection_id INTEGER NOT NULL,
        card_id TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        foil INTEGER NOT NULL DEFAULT 0,
        alt_art INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (collection_id, card_id)
      );
    ''');

    db.execute("""
      INSERT INTO cards (id, name, set_code, collector_number, lang) VALUES
      ('card_a', 'Card A', 'seta', '1', 'en'),
      ('card_b', 'Card B', 'setb', '2', 'en'),
      ('card_c', 'Card C', 'setc', '3', 'en'),
      ('card_d', 'Card D', 'setd', '4', 'en'),
      ('card_e', 'Card E', 'sete', '5', 'en'),
      ('card_f', 'Card F', 'setf', '6', 'en');
    """);

    db.execute("""
      INSERT INTO collections (id, name, type, filter_json) VALUES
      (1, 'All cards', 'all', NULL),
      (2, 'All cards duplicate', 'all', NULL),
      (3, 'My Custom', 'custom', NULL),
      (4, 'Smart Alpha', 'smart', '{"name":"alpha"}'),
      (5, 'Wishlist Alpha', 'wishlist', '{"name":"beta"}'),
      (6, 'Set: Test', 'set', NULL),
      (7, 'Deck Alpha', 'deck', NULL);
    """);

    db.execute("""
      INSERT INTO collection_cards (collection_id, card_id, quantity, foil, alt_art) VALUES
      (1, 'card_a', 2, 0, 0),
      (2, ' card_a ', 3, 1, 0),
      (3, ' card_b ', 1, 0, 0),
      (4, 'card_c', 1, 0, 0),
      (5, 'card_d', 4, 1, 1),
      (6, 'card_e', 1, 0, 0),
      (7, ' card_f ', 2, 1, 0);
    """);
  } finally {
    db.close();
  }
}
