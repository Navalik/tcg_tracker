import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: unused_import
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../models.dart';
import '../services/price_provider.dart';

part 'app_database.g.dart';

class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get oracleId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get setCode => text().nullable()();
  TextColumn get setName => text().nullable()();
  IntColumn get setTotal => integer().nullable()();
  TextColumn get collectorNumber => text().nullable()();
  TextColumn get rarity => text().nullable()();
  TextColumn get typeLine => text().nullable()();
  TextColumn get manaCost => text().nullable()();
  TextColumn get oracleText => text().nullable()();
  RealColumn get cmc => real().nullable()();
  TextColumn get colors => text().nullable()();
  TextColumn get colorIdentity => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get power => text().nullable()();
  TextColumn get toughness => text().nullable()();
  TextColumn get loyalty => text().nullable()();
  TextColumn get lang => text().nullable()();
  TextColumn get releasedAt => text().nullable()();
  TextColumn get imageUris => text().nullable()();
  TextColumn get cardFaces => text().nullable()();
  TextColumn get cardJson => text().nullable()();
  TextColumn get priceUsd => text().nullable()();
  TextColumn get priceUsdFoil => text().nullable()();
  TextColumn get priceUsdEtched => text().nullable()();
  TextColumn get priceEur => text().nullable()();
  TextColumn get priceEurFoil => text().nullable()();
  TextColumn get priceTix => text().nullable()();
  IntColumn get pricesUpdatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('custom'))();
  TextColumn get filterJson => text().nullable()();
}

class CollectionCards extends Table {
  IntColumn get collectionId => integer()();
  TextColumn get cardId => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  BoolColumn get foil => boolean().withDefault(const Constant(false))();
  BoolColumn get altArt => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {collectionId, cardId};
}

String? debugAppDatabaseDirectoryOverride;

LazyDatabase _openConnection(String fileName) {
  return LazyDatabase(() async {
    final directory = debugAppDatabaseDirectoryOverride == null
        ? await getApplicationDocumentsDirectory()
        : Directory(debugAppDatabaseDirectoryOverride!);
    final dbFile = File(path.join(directory.path, fileName));
    return NativeDatabase(
      dbFile,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA synchronous=NORMAL');
        db.execute('PRAGMA busy_timeout=5000');
      },
    );
  });
}

@DriftDatabase(tables: [Cards, Collections, CollectionCards])
class AppDatabase extends _$AppDatabase {
  AppDatabase({required String fileName}) : super(_openConnection(fileName));
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
      await _createFts();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(
          "ALTER TABLE collections ADD COLUMN type TEXT NOT NULL DEFAULT 'custom'",
        );
        await customStatement(
          'ALTER TABLE collections ADD COLUMN filter_json TEXT',
        );
        await customStatement(
          "UPDATE collections SET type = 'all' WHERE lower(name) = 'all cards'",
        );
        await customStatement(
          "UPDATE collections SET type = 'set' WHERE lower(name) LIKE 'set: %'",
        );
      }
      if (from < 3) {
        await customStatement('ALTER TABLE cards ADD COLUMN set_name TEXT');
        await customStatement('ALTER TABLE cards ADD COLUMN set_total INTEGER');
        await customStatement('ALTER TABLE cards ADD COLUMN cmc REAL');
        await customStatement('ALTER TABLE cards ADD COLUMN oracle_text TEXT');
        await customStatement('ALTER TABLE cards ADD COLUMN colors TEXT');
        await customStatement(
          'ALTER TABLE cards ADD COLUMN color_identity TEXT',
        );
        await customStatement('ALTER TABLE cards ADD COLUMN artist TEXT');
        await customStatement('ALTER TABLE cards ADD COLUMN power TEXT');
        await customStatement('ALTER TABLE cards ADD COLUMN toughness TEXT');
        await customStatement('ALTER TABLE cards ADD COLUMN loyalty TEXT');
      }
      if (from < 4) {
        await customStatement('ALTER TABLE cards ADD COLUMN price_usd TEXT');
        await customStatement(
          'ALTER TABLE cards ADD COLUMN price_usd_foil TEXT',
        );
        await customStatement(
          'ALTER TABLE cards ADD COLUMN price_usd_etched TEXT',
        );
        await customStatement('ALTER TABLE cards ADD COLUMN price_eur TEXT');
        await customStatement(
          'ALTER TABLE cards ADD COLUMN price_eur_foil TEXT',
        );
        await customStatement('ALTER TABLE cards ADD COLUMN price_tix TEXT');
        await customStatement(
          'ALTER TABLE cards ADD COLUMN prices_updated_at INTEGER',
        );
      }
      if (from < 5) {
        await customStatement('''
          UPDATE collections
          SET type = 'smart'
          WHERE type = 'custom'
            AND filter_json IS NOT NULL
            AND TRIM(filter_json) != ''
          ''');
        await customStatement('''
          UPDATE collection_cards
          SET quantity = 0, foil = 0, alt_art = 0
          WHERE collection_id IN (
            SELECT id
            FROM collections
            WHERE type = 'wishlist'
               OR (type = 'custom' AND name NOT LIKE '__deck_side__:%')
          )
          ''');
      }
      if (from < 6) {
        await customStatement('''
          CREATE TEMP TABLE IF NOT EXISTS _legacy_filtered_wishlist_ids AS
          SELECT id
          FROM collections
          WHERE type = 'wishlist'
            AND filter_json IS NOT NULL
            AND TRIM(filter_json) != ''
          ''');
        await customStatement('''
          DELETE FROM collection_cards
          WHERE collection_id IN (
            SELECT id FROM _legacy_filtered_wishlist_ids
          )
          ''');
        await customStatement('''
          UPDATE collections
          SET filter_json = NULL
          WHERE id IN (
            SELECT id FROM _legacy_filtered_wishlist_ids
          )
          ''');
        await customStatement(
          'DROP TABLE IF EXISTS _legacy_filtered_wishlist_ids',
        );
      }
      if (from < 7) {
        await customStatement('''
          UPDATE collection_cards
          SET quantity = 0, foil = 0, alt_art = 0
          WHERE collection_id IN (
            SELECT id
            FROM collections
            WHERE type = 'wishlist'
          )
          ''');
      }
      if (from < 8) {
        // Lightweight normalization only. Full publish-safe cleanup runs in v9.
        await customStatement('''
          UPDATE collections
          SET type = 'all'
          WHERE lower(trim(name)) IN ('all cards', 'tutte le carte', 'my collection')
          ''');
        await customStatement('''
          UPDATE collections
          SET type = 'set'
          WHERE type = 'custom' AND lower(name) LIKE 'set: %'
          ''');
        await customStatement('''
          UPDATE collections
          SET type = 'smart'
          WHERE type = 'custom'
            AND filter_json IS NOT NULL
            AND trim(filter_json) != ''
          ''');
      }
      if (from < 9) {
        // Publish-safe backup tables before destructive legacy cleanup.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS migration_legacy_collections_backup (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            backup_at INTEGER NOT NULL,
            collection_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            type TEXT,
            filter_json TEXT
          )
          ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS migration_legacy_collection_cards_backup (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            backup_at INTEGER NOT NULL,
            collection_id INTEGER NOT NULL,
            card_id TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            foil INTEGER NOT NULL,
            alt_art INTEGER NOT NULL
          )
          ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS migration_legacy_audit (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
          ''');
        await customStatement('''
          INSERT INTO migration_legacy_collections_backup(
            backup_at, collection_id, name, type, filter_json
          )
          SELECT
            CAST(strftime('%s','now') AS INTEGER) * 1000,
            id, name, type, filter_json
          FROM collections
          WHERE NOT EXISTS (
            SELECT 1 FROM migration_legacy_collections_backup
          )
          ''');
        await customStatement('''
          INSERT INTO migration_legacy_collection_cards_backup(
            backup_at, collection_id, card_id, quantity, foil, alt_art
          )
          SELECT
            CAST(strftime('%s','now') AS INTEGER) * 1000,
            collection_id, card_id,
            COALESCE(quantity, 0),
            COALESCE(CAST(foil AS INTEGER), 0),
            COALESCE(CAST(alt_art AS INTEGER), 0)
          FROM collection_cards
          WHERE NOT EXISTS (
            SELECT 1 FROM migration_legacy_collection_cards_backup
          )
          ''');

        // Normalize collection types.
        await customStatement('''
          UPDATE collections
          SET type = 'all'
          WHERE lower(trim(name)) IN ('all cards', 'tutte le carte', 'my collection')
          ''');
        await customStatement('''
          UPDATE collections
          SET type = 'set'
          WHERE type = 'custom' AND lower(name) LIKE 'set: %'
          ''');
        await customStatement('''
          UPDATE collections
          SET type = 'smart'
          WHERE type = 'custom'
            AND filter_json IS NOT NULL
            AND trim(filter_json) != ''
          ''');
        await customStatement('''
          INSERT INTO collections(name, type, filter_json)
          SELECT 'All cards', 'all', NULL
          WHERE NOT EXISTS (
            SELECT 1 FROM collections WHERE type = 'all'
          )
          ''');

        // Merge duplicate "all cards" collections into the oldest one.
        await customStatement('''
          CREATE TEMP TABLE IF NOT EXISTS _all_ids AS
          SELECT id FROM collections WHERE type = 'all' ORDER BY id
          ''');
        await customStatement('''
          UPDATE collection_cards
          SET collection_id = (SELECT MIN(id) FROM _all_ids)
          WHERE collection_id IN (
            SELECT id FROM _all_ids
            WHERE id != (SELECT MIN(id) FROM _all_ids)
          )
            AND EXISTS (SELECT 1 FROM _all_ids)
          ''');
        await customStatement('''
          DELETE FROM collections
          WHERE id IN (
            SELECT id FROM _all_ids
            WHERE id != (SELECT MIN(id) FROM _all_ids)
          )
          ''');
        await customStatement('DROP TABLE IF EXISTS _all_ids');

        // Normalize card ids and de-duplicate rows after trim.
        await customStatement('''
          CREATE TEMP TABLE IF NOT EXISTS _cc_norm AS
          SELECT
            collection_id AS collection_id,
            trim(card_id) AS card_id,
            SUM(CASE WHEN COALESCE(quantity, 0) < 0 THEN 0 ELSE COALESCE(quantity, 0) END) AS quantity,
            MAX(CAST(COALESCE(foil, 0) AS INTEGER)) AS foil,
            MAX(CAST(COALESCE(alt_art, 0) AS INTEGER)) AS alt_art
          FROM collection_cards
          WHERE trim(card_id) != ''
          GROUP BY collection_id, trim(card_id)
          ''');
        await customStatement('DELETE FROM collection_cards');
        await customStatement('''
          INSERT INTO collection_cards(collection_id, card_id, quantity, foil, alt_art)
          SELECT collection_id, card_id, quantity, foil, alt_art
          FROM _cc_norm
          ''');
        await customStatement('DROP TABLE IF EXISTS _cc_norm');

        // Derived collections are computed and must not persist memberships.
        await customStatement('''
          DELETE FROM collection_cards
          WHERE collection_id IN (
            SELECT id FROM collections
            WHERE type IN ('set', 'smart')
          )
          ''');

        // Wishlist: membership-only desired list.
        await customStatement('''
          UPDATE collections
          SET filter_json = NULL
          WHERE type = 'wishlist'
          ''');
        await customStatement('''
          UPDATE collection_cards
          SET quantity = 0, foil = 0, alt_art = 0
          WHERE collection_id IN (
            SELECT id FROM collections
            WHERE type = 'wishlist'
          )
          ''');

        // Direct custom collections: membership-only list.
        await customStatement('''
          UPDATE collection_cards
          SET quantity = 0, foil = 0, alt_art = 0
          WHERE collection_id IN (
            SELECT id FROM collections
            WHERE type = 'custom'
              AND (filter_json IS NULL OR trim(filter_json) = '')
              AND name NOT LIKE '__deck_side__:%'
          )
          ''');

        // Minimal sanity markers for post-release diagnostics.
        await customStatement('''
          INSERT OR REPLACE INTO migration_legacy_audit(key, value)
          VALUES ('cleanup_v9_done_at', CAST(CAST(strftime('%s','now') AS INTEGER) * 1000 AS TEXT))
          ''');
        await customStatement('''
          INSERT OR REPLACE INTO migration_legacy_audit(key, value)
          SELECT 'cleanup_v9_all_count', CAST(COUNT(*) AS TEXT)
          FROM collections
          WHERE type = 'all'
          ''');
        await customStatement('''
          INSERT OR REPLACE INTO migration_legacy_audit(key, value)
          SELECT 'cleanup_v9_wishlist_with_filter', CAST(COUNT(*) AS TEXT)
          FROM collections
          WHERE type = 'wishlist'
            AND filter_json IS NOT NULL
            AND trim(filter_json) != ''
          ''');
      }
      await _createIndexes();
      await _createFts();
    },
    beforeOpen: (details) async {},
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS cards_name_idx ON cards(name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS cards_set_idx ON cards(set_code)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS cards_number_idx ON cards(collector_number)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS cards_oracle_idx ON cards(oracle_id)',
    );
  }

  Future<void> _createFts() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS cards_fts
      USING fts5(
        name,
        lang,
        content='cards',
        content_rowid='rowid'
      )
    ''');
  }

  Future<void> rebuildFts() async {
    await customStatement("INSERT INTO cards_fts(cards_fts) VALUES('rebuild')");
  }
}

class _FilterQuery {
  const _FilterQuery(this.whereClauses, this.variables);

  final List<String> whereClauses;
  final List<Variable> variables;
}

class CardPriceSnapshot {
  const CardPriceSnapshot({
    required this.cardId,
    required this.pricesUpdatedAt,
  });

  final String cardId;
  final int? pricesUpdatedAt;
}

class _DbAppMigration {
  const _DbAppMigration({required this.version, required this.run});

  final int version;
  final Future<void> Function(AppDatabase db) run;
}

class ScryfallDatabase {
  ScryfallDatabase._();

  static final ScryfallDatabase instance = ScryfallDatabase._();

  static const _prefsKeyRegenerated = 'db_regenerated_v1';
  static const _prefsKeyAvailableLanguages = 'available_languages';
  static const _basicLandsCollectionInternalName = '__basic_lands__';
  static const _deckSideboardCollectionPrefix = '__deck_side__:';
  static const _defaultDbFileName = 'scryfall.db';
  static const _appMetaTable = 'app_meta';
  static const _appDbVersionKey = 'app_db_version';
  static const _appDbLastMigrationVersionKey = 'app_db_last_migration_version';
  static const _appDbLastMigrationAtKey = 'app_db_last_migration_at_ms';
  static const _appDbMigrationHistoryKey = 'app_db_migration_history_json';
  static const int _targetAppDbVersion = 1;
  static const int _migrationHistoryLimit = 40;
  // Add new steps here:
  // _DbAppMigration(version: 2, run: _runAppDbMigrationV2),
  static final List<_DbAppMigration> _appDbMigrations = <_DbAppMigration>[
    _DbAppMigration(version: 1, run: _runAppDbMigrationV1),
  ];

  AppDatabase? _db;
  String _dbFileName = _defaultDbFileName;
  bool _schemaCompatibilityEnsured = false;
  Future<void>? _schemaCompatibilityTask;
  bool _appMigrationsEnsured = false;
  Future<void>? _appMigrationsTask;
  bool _printedNameIndexSelfHealTried = false;

  String get databaseFileName => _dbFileName;

  Future<AppDatabase> open() async {
    var db = _db;
    if (db == null) {
      await _ensureRegenerated();
      db = AppDatabase(fileName: _dbFileName);
      _db = db;
    }
    await _ensureSchemaCompatibility(db);
    await _ensureAppMigrations(db);
    return db;
  }

  Future<void> setDatabaseFileName(String fileName) async {
    final next = fileName.trim();
    final resolved = next.isEmpty ? _defaultDbFileName : next;
    if (_dbFileName == resolved) {
      return;
    }
    await close();
    _dbFileName = resolved;
    _schemaCompatibilityEnsured = false;
    _schemaCompatibilityTask = null;
    _appMigrationsEnsured = false;
    _appMigrationsTask = null;
    _printedNameIndexSelfHealTried = false;
  }

  Future<T> runWithDatabaseFileName<T>(
    String fileName,
    Future<T> Function() action,
  ) async {
    final next = fileName.trim();
    final resolved = next.isEmpty ? _defaultDbFileName : next;
    final previous = _dbFileName;
    if (previous == resolved) {
      return action();
    }
    await setDatabaseFileName(resolved);
    try {
      return await action();
    } finally {
      await setDatabaseFileName(previous);
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      return;
    }
    await db.close();
    _db = null;
    _schemaCompatibilityEnsured = false;
    _schemaCompatibilityTask = null;
    _appMigrationsEnsured = false;
    _appMigrationsTask = null;
    _printedNameIndexSelfHealTried = false;
  }

  Future<void> _ensureSchemaCompatibility(AppDatabase db) async {
    if (_schemaCompatibilityEnsured) {
      return;
    }
    final pending = _schemaCompatibilityTask;
    if (pending != null) {
      await pending;
      return;
    }
    final task = _ensureSchemaCompatibilityInternal(db);
    _schemaCompatibilityTask = task;
    try {
      await task;
      _schemaCompatibilityEnsured = true;
    } finally {
      _schemaCompatibilityTask = null;
    }
  }

  Future<void> _ensureSchemaCompatibilityInternal(AppDatabase db) async {
    await _ensureTableColumns(db, 'cards', const <String, String>{
      'set_name': 'TEXT',
      'set_total': 'INTEGER',
      'cmc': 'REAL',
      'oracle_text': 'TEXT',
      'colors': 'TEXT',
      'color_identity': 'TEXT',
      'artist': 'TEXT',
      'power': 'TEXT',
      'toughness': 'TEXT',
      'loyalty': 'TEXT',
      'price_usd': 'TEXT',
      'price_usd_foil': 'TEXT',
      'price_usd_etched': 'TEXT',
      'price_eur': 'TEXT',
      'price_eur_foil': 'TEXT',
      'price_tix': 'TEXT',
      'prices_updated_at': 'INTEGER',
    });

    await _ensureTableColumns(db, 'collections', const <String, String>{
      'type': "TEXT NOT NULL DEFAULT 'custom'",
      'filter_json': 'TEXT',
    });

    await _ensureTableColumns(db, 'collection_cards', const <String, String>{
      'quantity': 'INTEGER NOT NULL DEFAULT 1',
      'foil': 'INTEGER NOT NULL DEFAULT 0',
      'alt_art': 'INTEGER NOT NULL DEFAULT 0',
    });

    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS cards_name_idx ON cards(name)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS cards_set_idx ON cards(set_code)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS cards_number_idx ON cards(collector_number)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS cards_oracle_idx ON cards(oracle_id)',
    );
    await _ensurePrintedNameSearchIndex(db);

    await db.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS cards_fts
      USING fts5(
        name,
        lang,
        content='cards',
        content_rowid='rowid'
      )
    ''');

    final cardsCountRow = await db
        .customSelect('SELECT COUNT(*) AS c FROM cards')
        .getSingle();
    final cardsCount = cardsCountRow.read<int>('c');
    if (cardsCount <= 0) {
      return;
    }
    final hasFtsRows =
        await db
            .customSelect('SELECT rowid AS rowid FROM cards_fts LIMIT 1')
            .getSingleOrNull() !=
        null;
    if (!hasFtsRows) {
      await db.rebuildFts();
    }
  }

  Future<void> _ensurePrintedNameSearchIndex(AppDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS cards_printed_search (
        card_id TEXT PRIMARY KEY,
        lang TEXT NOT NULL,
        display_name TEXT NOT NULL,
        folded_name TEXT NOT NULL
      )
    ''');
    await db.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS cards_printed_fts
      USING fts5(
        display_name,
        card_id UNINDEXED,
        lang UNINDEXED,
        tokenize = "unicode61 remove_diacritics 2"
      )
    ''');
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS cards_printed_search_lang_folded_idx ON cards_printed_search(lang, folded_name)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS cards_printed_search_folded_idx ON cards_printed_search(folded_name)',
    );
    final cardsCount =
        (await db.customSelect('SELECT COUNT(*) AS c FROM cards').getSingle())
            .read<int>('c');
    final indexCount =
        (await db
                .customSelect('SELECT COUNT(*) AS c FROM cards_printed_search')
                .getSingle())
            .read<int>('c');
    final hasPrintedFtsRows =
        await db
            .customSelect(
              'SELECT rowid AS rowid FROM cards_printed_fts LIMIT 1',
            )
            .getSingleOrNull() !=
        null;
    if (cardsCount == indexCount && (cardsCount == 0 || hasPrintedFtsRows)) {
      return;
    }
    await _rebuildPrintedNameSearchIndex(db);
  }

  Future<void> _rebuildPrintedNameSearchIndex(AppDatabase db) async {
    const displayExpr =
        "COALESCE(NULLIF(TRIM(json_extract(card_json, '\$.printed_name')), ''), name)";
    const foldedExpr =
        "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER($displayExpr), ',', ''), ' ', ''), '-', ''), CHAR(39), ''), CHAR(8217), ''), CHAR(34), '')";
    await db.customStatement('DELETE FROM cards_printed_search');
    await db.customStatement('''
      INSERT OR REPLACE INTO cards_printed_search(card_id, lang, display_name, folded_name)
      SELECT
        id,
        LOWER(COALESCE(NULLIF(TRIM(lang), ''), 'en')),
        $displayExpr,
        $foldedExpr
      FROM cards
    ''');
    await db.customStatement('DELETE FROM cards_printed_fts');
    await db.customStatement('''
      INSERT INTO cards_printed_fts(display_name, card_id, lang)
      SELECT display_name, card_id, lang
      FROM cards_printed_search
    ''');
  }

  Future<void> rebuildPrintedNameSearchIndex() async {
    final db = await open();
    await _rebuildPrintedNameSearchIndex(db);
  }

  Future<void> _ensureTableColumns(
    AppDatabase db,
    String tableName,
    Map<String, String> requiredColumns,
  ) async {
    final rows = await db.customSelect('PRAGMA table_info($tableName)').get();
    final existing = rows
        .map((row) => (row.readNullable<String>('name') ?? '').trim())
        .where((name) => name.isNotEmpty)
        .map((name) => name.toLowerCase())
        .toSet();
    for (final entry in requiredColumns.entries) {
      final columnName = entry.key.trim().toLowerCase();
      if (existing.contains(columnName)) {
        continue;
      }
      await db.customStatement(
        'ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}',
      );
    }
  }

  Future<void> _ensureAppMigrations(AppDatabase db) async {
    if (_appMigrationsEnsured) {
      return;
    }
    final pending = _appMigrationsTask;
    if (pending != null) {
      await pending;
      return;
    }
    final task = _ensureAppMigrationsInternal(db);
    _appMigrationsTask = task;
    try {
      await task;
      _appMigrationsEnsured = true;
    } finally {
      _appMigrationsTask = null;
    }
  }

  Future<void> _ensureAppMigrationsInternal(AppDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS $_appMetaTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    final currentVersion = await _loadAppDbVersion(db);
    if (currentVersion >= _targetAppDbVersion) {
      return;
    }

    final sortedMigrations = [..._appDbMigrations]
      ..sort((a, b) => a.version.compareTo(b.version));
    for (final migration in sortedMigrations) {
      if (migration.version <= currentVersion) {
        continue;
      }
      await db.transaction(() async {
        await migration.run(db);
        await _saveAppDbVersion(db, migration.version);
        await _recordAppliedMigration(db, migration.version);
      });
    }
  }

  Future<int> _loadAppDbVersion(AppDatabase db) async {
    final row = await db
        .customSelect(
          'SELECT value AS value FROM $_appMetaTable WHERE key = ? LIMIT 1',
          variables: [Variable.withString(_appDbVersionKey)],
        )
        .getSingleOrNull();
    if (row == null) {
      return 0;
    }
    final raw = row.readNullable<String>('value')?.trim() ?? '';
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  Future<void> _saveAppDbVersion(AppDatabase db, int version) async {
    await db.customStatement(
      '''
      INSERT INTO $_appMetaTable(key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [_appDbVersionKey, '$version'],
    );
  }

  Future<void> _recordAppliedMigration(AppDatabase db, int version) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _saveAppMetaValue(db, _appDbLastMigrationVersionKey, '$version');
    await _saveAppMetaValue(db, _appDbLastMigrationAtKey, '$nowMs');

    final existing = await _loadAppMetaValue(db, _appDbMigrationHistoryKey);
    final parsedHistory = <Map<String, dynamic>>[];
    if (existing != null && existing.trim().isNotEmpty) {
      try {
        final raw = jsonDecode(existing);
        if (raw is List) {
          for (final entry in raw) {
            if (entry is Map) {
              final value = <String, dynamic>{};
              final appliedAt = entry['appliedAtMs'];
              final migratedVersion = entry['version'];
              if (appliedAt is int || appliedAt is double) {
                value['appliedAtMs'] = (appliedAt as num).toInt();
              }
              if (migratedVersion is int || migratedVersion is double) {
                value['version'] = (migratedVersion as num).toInt();
              }
              if (value.isNotEmpty) {
                parsedHistory.add(value);
              }
            }
          }
        }
      } catch (_) {
        // Best effort: discard malformed history and overwrite with fresh values.
      }
    }

    parsedHistory.add({'version': version, 'appliedAtMs': nowMs});
    final trimmed = parsedHistory.length > _migrationHistoryLimit
        ? parsedHistory.sublist(parsedHistory.length - _migrationHistoryLimit)
        : parsedHistory;
    await _saveAppMetaValue(db, _appDbMigrationHistoryKey, jsonEncode(trimmed));
  }

  Future<String?> _loadAppMetaValue(AppDatabase db, String key) async {
    final row = await db
        .customSelect(
          'SELECT value AS value FROM $_appMetaTable WHERE key = ? LIMIT 1',
          variables: [Variable.withString(key)],
        )
        .getSingleOrNull();
    final value = row?.readNullable<String>('value')?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> _saveAppMetaValue(
    AppDatabase db,
    String key,
    String value,
  ) async {
    await db.customStatement(
      '''
      INSERT INTO $_appMetaTable(key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [key, value],
    );
  }

  Future<Map<String, String>> loadAppDbMigrationDiagnostics() async {
    final db = await open();
    final appDbVersion = await _loadAppDbVersion(db);
    final lastMigrationVersion =
        await _loadAppMetaValue(db, _appDbLastMigrationVersionKey) ?? '';
    final lastMigrationAtMs =
        await _loadAppMetaValue(db, _appDbLastMigrationAtKey) ?? '';
    final historyJson =
        await _loadAppMetaValue(db, _appDbMigrationHistoryKey) ?? '[]';
    final schemaRow = await db
        .customSelect('PRAGMA user_version')
        .getSingleOrNull();
    String sqliteSchemaVersion = '';
    if (schemaRow != null) {
      sqliteSchemaVersion =
          schemaRow.readNullable<int>('user_version')?.toString() ??
          (schemaRow.data.values.isNotEmpty
              ? schemaRow.data.values.first.toString()
              : '');
    }

    return <String, String>{
      'app_db_version': '$appDbVersion',
      'app_db_target_version': '$_targetAppDbVersion',
      'sqlite_schema_version': sqliteSchemaVersion,
      'last_migration_version': lastMigrationVersion,
      'last_migration_at_ms': lastMigrationAtMs,
      'migration_history_json': historyJson,
      'db_file': _dbFileName,
    };
  }

  static Future<void> _runAppDbMigrationV1(AppDatabase db) async {
    await db.customStatement('''
      UPDATE cards
      SET lang = lower(trim(lang))
      WHERE lang IS NOT NULL
        AND trim(lang) != ''
        AND lang != lower(trim(lang))
      ''');
    await db.customStatement('''
      UPDATE cards
      SET set_code = lower(trim(set_code))
      WHERE set_code IS NOT NULL
        AND trim(set_code) != ''
        AND set_code != lower(trim(set_code))
      ''');
    await db.rebuildFts();
  }

  Future<int?> fetchAllCardsCollectionId() async {
    final db = await open();
    final row =
        await (db.select(db.collections)
              ..where((tbl) => tbl.type.equals('all'))
              ..limit(1))
            .getSingleOrNull();
    if (row != null) {
      return row.id;
    }
    final fallback = await db
        .customSelect(
          'SELECT id AS id FROM collections WHERE lower(name) = ? LIMIT 1',
          variables: [Variable.withString('all cards')],
        )
        .getSingleOrNull();
    return fallback?.read<int>('id');
  }

  Future<int> ensureAllCardsCollectionId() async {
    final existingId = await fetchAllCardsCollectionId();
    if (existingId != null) {
      final db = await open();
      await (db.update(
        db.collections,
      )..where((tbl) => tbl.id.equals(existingId))).write(
        CollectionsCompanion(
          type: Value(collectionTypeToDb(CollectionType.all)),
        ),
      );
      return existingId;
    }
    final db = await open();
    final legacy = await db
        .customSelect(
          '''
          SELECT id AS id
          FROM collections
          WHERE lower(trim(name)) IN (?, ?, ?)
          LIMIT 1
          ''',
          variables: [
            Variable.withString('all cards'),
            Variable.withString('tutte le carte'),
            Variable.withString('my collection'),
          ],
        )
        .getSingleOrNull();
    if (legacy != null) {
      final legacyId = legacy.read<int>('id');
      await (db.update(
        db.collections,
      )..where((tbl) => tbl.id.equals(legacyId))).write(
        CollectionsCompanion(
          type: Value(collectionTypeToDb(CollectionType.all)),
        ),
      );
      return legacyId;
    }
    return addCollection('All cards', type: CollectionType.all);
  }

  Future<int?> fetchBasicLandsCollectionId() async {
    final db = await open();
    final typed =
        await (db.select(db.collections)
              ..where((tbl) => tbl.type.equals('basic_lands'))
              ..limit(1))
            .getSingleOrNull();
    if (typed != null) {
      return typed.id;
    }
    final fallback = await db
        .customSelect(
          '''
          SELECT id AS id
          FROM collections
          WHERE lower(name) IN (?, ?, ?)
          LIMIT 1
          ''',
          variables: [
            Variable.withString(_basicLandsCollectionInternalName),
            Variable.withString('terre base'),
            Variable.withString('basic lands'),
          ],
        )
        .getSingleOrNull();
    return fallback?.read<int>('id');
  }

  String deckSideboardCollectionName(int deckCollectionId) {
    return '$_deckSideboardCollectionPrefix$deckCollectionId';
  }

  Future<int?> fetchDeckSideboardCollectionId(int deckCollectionId) async {
    final db = await open();
    final row =
        await (db.select(db.collections)
              ..where(
                (tbl) => tbl.name.equals(
                  deckSideboardCollectionName(deckCollectionId),
                ),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  Future<int> ensureDeckSideboardCollectionId(int deckCollectionId) async {
    final existing = await fetchDeckSideboardCollectionId(deckCollectionId);
    if (existing != null) {
      return existing;
    }
    return addCollection(
      deckSideboardCollectionName(deckCollectionId),
      type: CollectionType.custom,
    );
  }

  Future<void> deleteDeckSideboardCollection(int deckCollectionId) async {
    final existing = await fetchDeckSideboardCollectionId(deckCollectionId);
    if (existing == null) {
      return;
    }
    await deleteCollection(existing);
  }

  Future<int> ensureBasicLandsCollectionId() async {
    final existingId = await fetchBasicLandsCollectionId();
    if (existingId != null) {
      final db = await open();
      await (db.update(
        db.collections,
      )..where((tbl) => tbl.id.equals(existingId))).write(
        CollectionsCompanion(
          name: Value(_basicLandsCollectionInternalName),
          type: Value(collectionTypeToDb(CollectionType.basicLands)),
        ),
      );
      return existingId;
    }
    return addCollection(
      _basicLandsCollectionInternalName,
      type: CollectionType.basicLands,
    );
  }

  Future<void> hardReset() async {
    await close();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyRegenerated, true);
    final db = await open();
    await db.transaction(() async {
      await deleteAllCards(db);
    });
    await db.rebuildFts();
    await prefs.remove(_prefsKeyAvailableLanguages);
  }

  Future<void> _ensureRegenerated() async {
    final prefs = await SharedPreferences.getInstance();
    final regenerated = prefs.getBool(_prefsKeyRegenerated) ?? false;
    if (regenerated) {
      return;
    }
    // Legacy safety flag migration: never delete the full DB here.
    await prefs.setBool(_prefsKeyRegenerated, true);
  }

  Future<List<CollectionInfo>> fetchCollections() async {
    final db = await open();
    final rows = await (db.select(
      db.collections,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.id)])).get();
    final allCardsId = _resolveAllCardsId(rows);
    final counts = await _fetchOwnedCountsByCollection(db, rows, allCardsId);
    return rows
        .map(
          (row) => CollectionInfo(
            id: row.id,
            name: row.name,
            cardCount: counts[row.id] ?? 0,
            type: collectionTypeFromDb(row.type),
            filter: row.filterJson == null
                ? null
                : CollectionFilter.fromJson(
                    jsonDecode(row.filterJson!) as Map<String, dynamic>,
                  ),
          ),
        )
        .toList();
  }

  int? _resolveAllCardsId(List<Collection> rows) {
    for (final row in rows) {
      if (collectionTypeFromDb(row.type) == CollectionType.all) {
        return row.id;
      }
    }
    for (final row in rows) {
      if (row.name.trim().toLowerCase() == 'all cards') {
        return row.id;
      }
    }
    for (final row in rows) {
      final normalized = row.name.trim().toLowerCase();
      if (normalized == 'tutte le carte' || normalized == 'my collection') {
        return row.id;
      }
    }
    return null;
  }

  Future<Map<int, int>> _fetchOwnedCountsByCollection(
    AppDatabase db,
    List<Collection> rows,
    int? allCardsId,
  ) async {
    final counts = <int, int>{};
    final groupedRows = await db.customSelect('''
      SELECT
        collection_id AS collection_id,
        COALESCE(SUM(quantity), 0) AS qty_sum,
        COUNT(*) AS row_count,
        COALESCE(SUM(CASE WHEN quantity = 0 THEN 1 ELSE 0 END), 0) AS zero_count
      FROM collection_cards
      GROUP BY collection_id
    ''').get();
    final qtyByCollection = <int, int>{};
    final rowCountByCollection = <int, int>{};
    final zeroCountByCollection = <int, int>{};
    for (final grouped in groupedRows) {
      final id = grouped.read<int>('collection_id');
      qtyByCollection[id] = grouped.read<int>('qty_sum');
      rowCountByCollection[id] = grouped.read<int>('row_count');
      zeroCountByCollection[id] = grouped.read<int>('zero_count');
    }
    if (allCardsId == null) {
      for (final row in rows) {
        counts[row.id] = 0;
      }
      return counts;
    }
    counts[allCardsId] = qtyByCollection[allCardsId] ?? 0;
    for (final row in rows) {
      if (row.id == allCardsId) {
        continue;
      }
      final type = collectionTypeFromDb(row.type);
      if (type == CollectionType.wishlist) {
        counts[row.id] = zeroCountByCollection[row.id] ?? 0;
        continue;
      }
      if (type == CollectionType.deck || type == CollectionType.basicLands) {
        counts[row.id] = qtyByCollection[row.id] ?? 0;
        continue;
      }
      final filter = row.filterJson == null
          ? null
          : CollectionFilter.fromJson(
              jsonDecode(row.filterJson!) as Map<String, dynamic>,
            );
      if (filter == null) {
        if (type == CollectionType.custom) {
          counts[row.id] = rowCountByCollection[row.id] ?? 0;
        } else {
          counts[row.id] = 0;
        }
        continue;
      }
      try {
        counts[row.id] = await _countOwnedCardsForFilter(
          db,
          filter,
          allCardsId,
        ).timeout(const Duration(seconds: 4));
      } on TimeoutException {
        counts[row.id] = 0;
      }
    }
    return counts;
  }

  Future<int> addCollection(
    String name, {
    CollectionType type = CollectionType.custom,
    CollectionFilter? filter,
  }) async {
    if (type == CollectionType.basicLands) {
      final existing = await fetchBasicLandsCollectionId();
      if (existing != null) {
        return existing;
      }
    }
    final db = await open();
    return db
        .into(db.collections)
        .insert(
          CollectionsCompanion.insert(
            name: name,
            type: Value(collectionTypeToDb(type)),
            filterJson: Value(
              filter == null ? null : jsonEncode(filter.toJson()),
            ),
          ),
        );
  }

  Future<void> renameCollection(int id, String name) async {
    final db = await open();
    await (db.update(db.collections)..where((tbl) => tbl.id.equals(id))).write(
      CollectionsCompanion(name: Value(name)),
    );
  }

  Future<void> updateCollectionFilter(
    int id, {
    CollectionFilter? filter,
  }) async {
    final db = await open();
    await (db.update(db.collections)..where((tbl) => tbl.id.equals(id))).write(
      CollectionsCompanion(
        filterJson: Value(filter == null ? null : jsonEncode(filter.toJson())),
      ),
    );
  }

  Future<CollectionType?> fetchCollectionTypeById(int id) async {
    final db = await open();
    final row =
        await (db.select(db.collections)
              ..where((tbl) => tbl.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return collectionTypeFromDb(row.type);
  }

  Future<void> deleteCollection(int id) async {
    final db = await open();
    await db.transaction(() async {
      await (db.delete(
        db.collectionCards,
      )..where((tbl) => tbl.collectionId.equals(id))).go();
      await (db.delete(db.collections)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  Future<Map<String, dynamic>> exportCollectionsBackupPayload() async {
    final db = await open();
    final collectionRows = await (db.select(
      db.collections,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.id)])).get();
    final collectionCardRows =
        await (db.select(db.collectionCards)..orderBy([
              (tbl) => OrderingTerm.asc(tbl.collectionId),
              (tbl) => OrderingTerm.asc(tbl.cardId),
            ]))
            .get();

    final cardIds = collectionCardRows
        .map((row) => row.cardId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final cardRows = <Card>[];
    const chunkSize = 400;
    for (var i = 0; i < cardIds.length; i += chunkSize) {
      final end = (i + chunkSize < cardIds.length)
          ? i + chunkSize
          : cardIds.length;
      final chunk = cardIds.sublist(i, end);
      final rows = await (db.select(
        db.cards,
      )..where((tbl) => tbl.id.isIn(chunk))).get();
      cardRows.addAll(rows);
    }

    return <String, dynamic>{
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'collections': collectionRows
          .map(
            (row) => <String, dynamic>{
              'id': row.id,
              'name': row.name,
              'type': row.type,
              'filterJson': row.filterJson,
            },
          )
          .toList(growable: false),
      'collectionCards': collectionCardRows
          .map(
            (row) => <String, dynamic>{
              'collectionId': row.collectionId,
              'cardId': row.cardId,
              'quantity': row.quantity,
              'foil': row.foil,
              'altArt': row.altArt,
            },
          )
          .toList(growable: false),
      'cards': cardRows.map(_cardToBackupJson).toList(growable: false),
    };
  }

  Future<Map<String, int>> restoreCollectionsBackupPayload(
    Map<String, dynamic> payload, {
    bool replaceExisting = true,
  }) async {
    final db = await open();
    final collectionsRaw = payload['collections'];
    final collectionCardsRaw = payload['collectionCards'];
    final cardsRaw = payload['cards'];
    if (collectionsRaw is! List ||
        collectionCardsRaw is! List ||
        cardsRaw is! List) {
      throw const FormatException('invalid_backup_payload');
    }

    var upsertedCards = 0;
    var insertedCollections = 0;
    var insertedCollectionCards = 0;

    await db.transaction(() async {
      for (final cardRaw in cardsRaw) {
        if (cardRaw is! Map) {
          continue;
        }
        final normalized = _normalizeStringDynamicMap(cardRaw);
        final companion = _cardCompanionFromBackupJson(normalized);
        if (companion == null) {
          continue;
        }
        await db.into(db.cards).insertOnConflictUpdate(companion);
        upsertedCards += 1;
      }

      if (replaceExisting) {
        await db.delete(db.collectionCards).go();
        await db.delete(db.collections).go();
      }

      final collectionIdMap = <int, int>{};
      final collectionTypeById = <int, String>{};
      for (final collectionRaw in collectionsRaw) {
        if (collectionRaw is! Map) {
          continue;
        }
        final normalized = _normalizeStringDynamicMap(collectionRaw);
        final oldId = _asInt(normalized['id']);
        final name = _asString(normalized['name']).trim();
        if (oldId == null || name.isEmpty) {
          continue;
        }
        var type = _asString(normalized['type']).trim().toLowerCase();
        final filterJson = normalized['filterJson'];
        final hasFilter = filterJson is String && filterJson.trim().isNotEmpty;
        if (type == 'custom' && hasFilter) {
          type = 'smart';
        }
        if (type.isEmpty) {
          type = 'custom';
        }
        final insertedId = await db
            .into(db.collections)
            .insert(
              CollectionsCompanion.insert(
                name: name,
                type: Value(type),
                filterJson: Value(filterJson is String ? filterJson : null),
              ),
            );
        collectionIdMap[oldId] = insertedId;
        collectionTypeById[insertedId] = type;
        insertedCollections += 1;
      }

      for (final relationRaw in collectionCardsRaw) {
        if (relationRaw is! Map) {
          continue;
        }
        final normalized = _normalizeStringDynamicMap(relationRaw);
        final oldCollectionId = _asInt(normalized['collectionId']);
        final mappedCollectionId = oldCollectionId == null
            ? null
            : collectionIdMap[oldCollectionId];
        final cardId = _asString(normalized['cardId']).trim();
        if (mappedCollectionId == null || cardId.isEmpty) {
          continue;
        }
        final mappedCollectionType =
            collectionTypeById[mappedCollectionId] ?? '';
        if (mappedCollectionType == 'smart') {
          continue;
        }
        final isMembershipOnly =
            mappedCollectionType == 'custom' ||
            mappedCollectionType == 'wishlist';
        final quantity = isMembershipOnly
            ? 0
            : (_asInt(normalized['quantity']) ?? 1);
        await db
            .into(db.collectionCards)
            .insertOnConflictUpdate(
              CollectionCardsCompanion.insert(
                collectionId: mappedCollectionId,
                cardId: cardId,
                quantity: Value(quantity),
                foil: Value(
                  isMembershipOnly ? false : _asBool(normalized['foil']),
                ),
                altArt: Value(
                  isMembershipOnly ? false : _asBool(normalized['altArt']),
                ),
              ),
            );
        insertedCollectionCards += 1;
      }
    });

    return <String, int>{
      'cards': upsertedCards,
      'collections': insertedCollections,
      'collectionCards': insertedCollectionCards,
    };
  }

  Map<String, dynamic> _cardToBackupJson(Card row) {
    return <String, dynamic>{
      'id': row.id,
      'oracleId': row.oracleId,
      'name': row.name,
      'setCode': row.setCode,
      'setName': row.setName,
      'setTotal': row.setTotal,
      'collectorNumber': row.collectorNumber,
      'rarity': row.rarity,
      'typeLine': row.typeLine,
      'manaCost': row.manaCost,
      'oracleText': row.oracleText,
      'cmc': row.cmc,
      'colors': row.colors,
      'colorIdentity': row.colorIdentity,
      'artist': row.artist,
      'power': row.power,
      'toughness': row.toughness,
      'loyalty': row.loyalty,
      'lang': row.lang,
      'releasedAt': row.releasedAt,
      'imageUris': row.imageUris,
      'cardFaces': row.cardFaces,
      'cardJson': row.cardJson,
      'priceUsd': row.priceUsd,
      'priceUsdFoil': row.priceUsdFoil,
      'priceUsdEtched': row.priceUsdEtched,
      'priceEur': row.priceEur,
      'priceEurFoil': row.priceEurFoil,
      'priceTix': row.priceTix,
      'pricesUpdatedAt': row.pricesUpdatedAt,
    };
  }

  CardsCompanion? _cardCompanionFromBackupJson(Map<String, dynamic> json) {
    final id = _asString(json['id']).trim();
    final name = _asString(json['name']).trim();
    if (id.isEmpty || name.isEmpty) {
      return null;
    }
    return CardsCompanion.insert(
      id: id,
      name: name,
      oracleId: Value(_asNullableString(json['oracleId'])),
      setCode: Value(_asNullableString(json['setCode'])),
      setName: Value(_asNullableString(json['setName'])),
      setTotal: Value(_asInt(json['setTotal'])),
      collectorNumber: Value(_asNullableString(json['collectorNumber'])),
      rarity: Value(_asNullableString(json['rarity'])),
      typeLine: Value(_asNullableString(json['typeLine'])),
      manaCost: Value(_asNullableString(json['manaCost'])),
      oracleText: Value(_asNullableString(json['oracleText'])),
      cmc: Value(_asDouble(json['cmc'])),
      colors: Value(_asNullableString(json['colors'])),
      colorIdentity: Value(_asNullableString(json['colorIdentity'])),
      artist: Value(_asNullableString(json['artist'])),
      power: Value(_asNullableString(json['power'])),
      toughness: Value(_asNullableString(json['toughness'])),
      loyalty: Value(_asNullableString(json['loyalty'])),
      lang: Value(_asNullableString(json['lang'])),
      releasedAt: Value(_asNullableString(json['releasedAt'])),
      imageUris: Value(_asNullableString(json['imageUris'])),
      cardFaces: Value(_asNullableString(json['cardFaces'])),
      cardJson: Value(_asNullableString(json['cardJson'])),
      priceUsd: Value(_asNullableString(json['priceUsd'])),
      priceUsdFoil: Value(_asNullableString(json['priceUsdFoil'])),
      priceUsdEtched: Value(_asNullableString(json['priceUsdEtched'])),
      priceEur: Value(_asNullableString(json['priceEur'])),
      priceEurFoil: Value(_asNullableString(json['priceEurFoil'])),
      priceTix: Value(_asNullableString(json['priceTix'])),
      pricesUpdatedAt: Value(_asInt(json['pricesUpdatedAt'])),
    );
  }

  Map<String, dynamic> _normalizeStringDynamicMap(Map raw) {
    final mapped = <String, dynamic>{};
    for (final entry in raw.entries) {
      mapped[entry.key.toString()] = entry.value;
    }
    return mapped;
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  String? _asNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true' || normalized == 'yes';
    }
    return false;
  }

  _FilterQuery _buildFilterQuery(CollectionFilter filter) {
    final whereClauses = <String>[];
    final variables = <Variable>[];

    final name = filter.name?.trim();
    if (name != null && name.isNotEmpty) {
      whereClauses.add('LOWER(cards.name) LIKE ?');
      variables.add(Variable.withString('%${name.toLowerCase()}%'));
    }

    if (filter.sets.isNotEmpty) {
      final normalized = filter.sets
          .map((code) => code.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        whereClauses.add(
          'LOWER(cards.set_code) IN (${List.filled(normalized.length, '?').join(', ')})',
        );
        variables.addAll(normalized.map((code) => Variable.withString(code)));
      }
    }

    if (filter.rarities.isNotEmpty) {
      final normalized = filter.rarities
          .map((rarity) => rarity.trim().toLowerCase())
          .where((rarity) => rarity.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        whereClauses.add(
          'LOWER(cards.rarity) IN (${List.filled(normalized.length, '?').join(', ')})',
        );
        variables.addAll(
          normalized.map((rarity) => Variable.withString(rarity)),
        );
      }
    }

    if (filter.types.isNotEmpty) {
      final normalized = filter.types
          .map((type) => type.trim().toLowerCase())
          .where((type) => type.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        final typeClauses = normalized
            .map((_) => 'LOWER(cards.type_line) LIKE ?')
            .join(' OR ');
        whereClauses.add('($typeClauses)');
        variables.addAll(
          normalized.map((type) => Variable.withString('%$type%')),
        );
      }
    }

    if (filter.colors.isNotEmpty) {
      final normalized = filter.colors
          .map((color) => color.trim().toUpperCase())
          .where((color) => color.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        final colorClauses = <String>[];
        for (final color in normalized) {
          colorClauses.add(
            r'(cards.colors LIKE ? OR cards.color_identity LIKE ?)',
          );
          final normalizedLike = '%$color%';
          variables.addAll([
            Variable.withString(normalizedLike),
            Variable.withString(normalizedLike),
          ]);
        }
        // Compatibility fallback:
        // - MTG colorless cards may be stored without explicit color codes.
        // - Legacy Pokemon "none" cards may have empty colors.
        if (normalized.contains('C') || normalized.contains('N')) {
          colorClauses.add('''
            (
              COALESCE(cards.colors, '') = ''
              AND COALESCE(cards.color_identity, '') = ''
            )
            ''');
        }
        if (colorClauses.isNotEmpty) {
          whereClauses.add('(${colorClauses.join(' OR ')})');
        }
      }
    }

    final artist = filter.artist?.trim();
    if (artist != null && artist.isNotEmpty) {
      whereClauses.add('''
        LOWER(
          TRIM(
            COALESCE(
              NULLIF(cards.artist, ''),
              json_extract(cards.card_json, '\$.artist'),
              ''
            )
          )
        ) LIKE ?
      ''');
      final like = '%${artist.toLowerCase()}%';
      variables.add(Variable.withString(like));
    }

    if (filter.manaMin != null) {
      whereClauses.add('COALESCE(cards.cmc, 0) >= ?');
      variables.add(Variable.withReal(filter.manaMin!.toDouble()));
    }
    if (filter.manaMax != null) {
      whereClauses.add('COALESCE(cards.cmc, 0) <= ?');
      variables.add(Variable.withReal(filter.manaMax!.toDouble()));
    }

    final format = filter.format?.trim().toLowerCase();
    if (format != null && format.isNotEmpty) {
      whereClauses.add('''
        (
          LOWER(COALESCE(json_extract(cards.card_json, ?), '')) IN (?, ?)
          OR COALESCE(json_extract(cards.card_json, ?), '') = ''
        )
        ''');
      variables.addAll([
        Variable.withString(r'$.legalities.' + format),
        Variable.withString('legal'),
        Variable.withString('restricted'),
        Variable.withString(r'$.legalities.' + format),
      ]);
    }

    if (filter.languages.isNotEmpty) {
      final normalized = filter.languages
          .map((lang) => lang.trim().toLowerCase())
          .where((lang) => lang.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        whereClauses.add(
          "LOWER(COALESCE(NULLIF(TRIM(cards.lang), ''), 'en')) IN (${List.filled(normalized.length, '?').join(', ')})",
        );
        variables.addAll(normalized.map((lang) => Variable.withString(lang)));
      }
    }

    return _FilterQuery(whereClauses, variables);
  }

  Future<int> _countOwnedCardsForFilter(
    AppDatabase db,
    CollectionFilter filter,
    int allCardsId,
  ) async {
    final filterQuery = _buildFilterQuery(filter);
    final whereClauses = [...filterQuery.whereClauses];
    whereClauses.add('COALESCE(collection_cards.quantity, 0) > 0');
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final rows = await db
        .customSelect(
          '''
      SELECT COUNT(*) AS total
      FROM cards
      LEFT JOIN collection_cards
        ON collection_cards.card_id = cards.id
        AND collection_cards.collection_id = ?
      $whereSql
      ''',
          variables: [Variable.withInt(allCardsId), ...filterQuery.variables],
        )
        .getSingle();
    return rows.read<int>('total');
  }

  Future<List<CollectionCardEntry>> fetchCollectionCards(
    int collectionId, {
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    final db = await open();
    var resolvedLimit = limit;
    if (offset != null && resolvedLimit == null) {
      resolvedLimit = -1;
    }
    final variables = <Variable>[Variable.withInt(collectionId)];
    final whereClauses = <String>['collection_cards.collection_id = ?'];
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final sql = StringBuffer('''
      SELECT
        collection_cards.card_id AS card_id,
        collection_cards.quantity AS quantity,
        collection_cards.foil AS foil,
        collection_cards.alt_art AS alt_art,
        cards.name AS name,
        COALESCE(cards.set_code, '') AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.mana_cost AS mana_cost,
        cards.oracle_text AS oracle_text,
        cards.oracle_text AS oracle_text,
        cards.cmc AS cmc,
        cards.lang AS lang,
        cards.released_at AS released_at,
        cards.artist AS artist,
        cards.power AS power,
        cards.toughness AS toughness,
        cards.loyalty AS loyalty,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_usd_etched AS price_usd_etched,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.price_tix AS price_tix,
        cards.prices_updated_at AS prices_updated_at,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM collection_cards
      JOIN cards ON cards.id = collection_cards.card_id
      $whereSql
      ORDER BY cards.name ASC
      ''');
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      variables.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db
        .customSelect(sql.toString(), variables: variables)
        .get();

    return rows
        .map(
          (row) => CollectionCardEntry(
            cardId: row.read<String>('card_id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            manaCost: row.readNullable<String>('mana_cost') ?? '',
            oracleText: row.readNullable<String>('oracle_text') ?? '',
            manaValue: row.readNullable<double>('cmc'),
            lang: row.readNullable<String>('lang') ?? '',
            releasedAt: row.readNullable<String>('released_at') ?? '',
            artist: row.readNullable<String>('artist') ?? '',
            power: row.readNullable<String>('power') ?? '',
            toughness: row.readNullable<String>('toughness') ?? '',
            loyalty: row.readNullable<String>('loyalty') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            quantity: row.read<int>('quantity'),
            foil: row.read<int>('foil') == 1,
            altArt: row.read<int>('alt_art') == 1,
            priceUsd: _readOptionalPrice(row, 'price_usd'),
            priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
            priceUsdEtched: _readOptionalPrice(row, 'price_usd_etched'),
            priceEur: _readOptionalPrice(row, 'price_eur'),
            priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
            priceTix: _readOptionalPrice(row, 'price_tix'),
            pricesUpdatedAt: row.readNullable<int>('prices_updated_at'),
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<List<CardSearchResult>> fetchRecentOwnedCardPreviews(
    int collectionId, {
    int limit = 10,
  }) async {
    final db = await open();
    final resolvedLimit = limit <= 0 ? 10 : limit;
    final rows = await db
        .customSelect(
          '''
      SELECT
        cards.id AS id,
        cards.name AS name,
        COALESCE(cards.set_code, '') AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM collection_cards
      JOIN cards ON cards.id = collection_cards.card_id
      WHERE collection_cards.collection_id = ?
        AND collection_cards.quantity > 0
      ORDER BY collection_cards.rowid DESC
      LIMIT ?
      ''',
          variables: [
            Variable.withInt(collectionId),
            Variable.withInt(resolvedLimit),
          ],
        )
        .get();

    return rows
        .map(
          (row) => CardSearchResult(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            priceUsd: _readOptionalPrice(row, 'price_usd'),
            priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
            priceEur: _readOptionalPrice(row, 'price_eur'),
            priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<List<CollectionCardEntry>> fetchCustomCollectionOwnedCards(
    int collectionId, {
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    final db = await open();
    final allCardsId = await ensureAllCardsCollectionId();
    var resolvedLimit = limit;
    if (offset != null && resolvedLimit == null) {
      resolvedLimit = -1;
    }
    final variables = <Variable>[
      Variable.withInt(collectionId),
      Variable.withInt(allCardsId),
    ];
    final whereClauses = <String>[
      'membership.collection_id = ?',
      'COALESCE(inventory.quantity, 0) > 0',
    ];
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final sql = StringBuffer('''
      SELECT
        membership.card_id AS card_id,
        inventory.quantity AS quantity,
        COALESCE(inventory.foil, 0) AS foil,
        COALESCE(inventory.alt_art, 0) AS alt_art,
        cards.name AS name,
        COALESCE(cards.set_code, '') AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.mana_cost AS mana_cost,
        cards.oracle_text AS oracle_text,
        cards.cmc AS cmc,
        cards.lang AS lang,
        cards.released_at AS released_at,
        cards.artist AS artist,
        cards.power AS power,
        cards.toughness AS toughness,
        cards.loyalty AS loyalty,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_usd_etched AS price_usd_etched,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.price_tix AS price_tix,
        cards.prices_updated_at AS prices_updated_at,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM collection_cards membership
      LEFT JOIN collection_cards inventory
        ON inventory.card_id = membership.card_id
        AND inventory.collection_id = ?
      JOIN cards ON cards.id = membership.card_id
      $whereSql
      ORDER BY cards.name ASC
      ''');
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      variables.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db
        .customSelect(sql.toString(), variables: variables)
        .get();

    return rows
        .map(
          (row) => CollectionCardEntry(
            cardId: row.read<String>('card_id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            manaCost: row.readNullable<String>('mana_cost') ?? '',
            oracleText: row.readNullable<String>('oracle_text') ?? '',
            manaValue: row.readNullable<double>('cmc'),
            lang: row.readNullable<String>('lang') ?? '',
            releasedAt: row.readNullable<String>('released_at') ?? '',
            artist: row.readNullable<String>('artist') ?? '',
            power: row.readNullable<String>('power') ?? '',
            toughness: row.readNullable<String>('toughness') ?? '',
            loyalty: row.readNullable<String>('loyalty') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            quantity: row.read<int>('quantity'),
            foil: row.read<int>('foil') == 1,
            altArt: row.read<int>('alt_art') == 1,
            priceUsd: _readOptionalPrice(row, 'price_usd'),
            priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
            priceUsdEtched: _readOptionalPrice(row, 'price_usd_etched'),
            priceEur: _readOptionalPrice(row, 'price_eur'),
            priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
            priceTix: _readOptionalPrice(row, 'price_tix'),
            pricesUpdatedAt: row.readNullable<int>('prices_updated_at'),
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<List<CollectionCardEntry>> fetchWishlistCardsWithOwnedQuantities(
    int collectionId, {
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    final db = await open();
    final allCardsId = await ensureAllCardsCollectionId();
    var resolvedLimit = limit;
    if (offset != null && resolvedLimit == null) {
      resolvedLimit = -1;
    }
    final variables = <Variable>[
      Variable.withInt(collectionId),
      Variable.withInt(allCardsId),
    ];
    final whereClauses = <String>['wishlist.card_id IS NOT NULL'];
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final sql = StringBuffer('''
      SELECT
        wishlist.card_id AS card_id,
        COALESCE(inventory.quantity, 0) AS quantity,
        COALESCE(inventory.foil, 0) AS foil,
        COALESCE(inventory.alt_art, 0) AS alt_art,
        cards.name AS name,
        COALESCE(cards.set_code, '') AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.mana_cost AS mana_cost,
        cards.oracle_text AS oracle_text,
        cards.cmc AS cmc,
        cards.lang AS lang,
        cards.released_at AS released_at,
        cards.artist AS artist,
        cards.power AS power,
        cards.toughness AS toughness,
        cards.loyalty AS loyalty,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_usd_etched AS price_usd_etched,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.price_tix AS price_tix,
        cards.prices_updated_at AS prices_updated_at,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM (
        SELECT TRIM(card_id) AS card_id
        FROM collection_cards
        WHERE collection_id = ? AND quantity = 0
      ) wishlist
      LEFT JOIN collection_cards inventory
        ON inventory.card_id = wishlist.card_id
        AND inventory.collection_id = ?
      JOIN cards ON cards.id = wishlist.card_id
      $whereSql
      ORDER BY cards.name ASC
      ''');
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      variables.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db
        .customSelect(sql.toString(), variables: variables)
        .get();

    return rows
        .map(
          (row) => CollectionCardEntry(
            cardId: row.read<String>('card_id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            manaCost: row.readNullable<String>('mana_cost') ?? '',
            oracleText: row.readNullable<String>('oracle_text') ?? '',
            manaValue: row.readNullable<double>('cmc'),
            lang: row.readNullable<String>('lang') ?? '',
            releasedAt: row.readNullable<String>('released_at') ?? '',
            artist: row.readNullable<String>('artist') ?? '',
            power: row.readNullable<String>('power') ?? '',
            toughness: row.readNullable<String>('toughness') ?? '',
            loyalty: row.readNullable<String>('loyalty') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            quantity: row.read<int>('quantity'),
            foil: row.read<int>('foil') == 1,
            altArt: row.read<int>('alt_art') == 1,
            priceUsd: _readOptionalPrice(row, 'price_usd'),
            priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
            priceUsdEtched: _readOptionalPrice(row, 'price_usd_etched'),
            priceEur: _readOptionalPrice(row, 'price_eur'),
            priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
            priceTix: _readOptionalPrice(row, 'price_tix'),
            pricesUpdatedAt: row.readNullable<int>('prices_updated_at'),
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<int> countCustomCollectionOwnedCards(
    int collectionId, {
    String? searchQuery,
  }) async {
    final db = await open();
    final allCardsId = await ensureAllCardsCollectionId();
    final variables = <Variable>[
      Variable.withInt(collectionId),
      Variable.withInt(allCardsId),
    ];
    final whereClauses = <String>[
      'membership.collection_id = ?',
      'COALESCE(inventory.quantity, 0) > 0',
    ];
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final row = await db.customSelect('''
      SELECT COUNT(*) AS total
      FROM collection_cards membership
      LEFT JOIN collection_cards inventory
        ON inventory.card_id = membership.card_id
        AND inventory.collection_id = ?
      JOIN cards ON cards.id = membership.card_id
      $whereSql
      ''', variables: variables).getSingle();
    return row.read<int>('total');
  }

  Future<List<CollectionCardEntry>> fetchOwnedCards({
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final db = await open();
    final allCardsId = await fetchAllCardsCollectionId();
    if (allCardsId == null) {
      return [];
    }
    var resolvedLimit = limit;
    if (offset != null && resolvedLimit == null) {
      resolvedLimit = -1;
    }
    final variables = <Variable>[Variable.withInt(allCardsId)];
    final whereClauses = <String>['collection_cards.collection_id = ?'];
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final sql = StringBuffer('''
      SELECT
        collection_cards.card_id AS card_id,
        collection_cards.quantity AS quantity,
        collection_cards.foil AS foil,
        collection_cards.alt_art AS alt_art,
        cards.name AS name,
        COALESCE(cards.set_code, '') AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.mana_cost AS mana_cost,
        cards.oracle_text AS oracle_text,
        cards.cmc AS cmc,
        cards.lang AS lang,
        cards.released_at AS released_at,
        cards.artist AS artist,
        cards.power AS power,
        cards.toughness AS toughness,
        cards.loyalty AS loyalty,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM collection_cards
      JOIN cards ON cards.id = collection_cards.card_id
      $whereSql
      ORDER BY cards.name ASC
      ''');
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      variables.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db
        .customSelect(sql.toString(), variables: variables)
        .get();

    return rows
        .map(
          (row) => CollectionCardEntry(
            cardId: row.read<String>('card_id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            manaCost: row.readNullable<String>('mana_cost') ?? '',
            oracleText: row.readNullable<String>('oracle_text') ?? '',
            manaValue: row.readNullable<double>('cmc'),
            lang: row.readNullable<String>('lang') ?? '',
            releasedAt: row.readNullable<String>('released_at') ?? '',
            artist: row.readNullable<String>('artist') ?? '',
            power: row.readNullable<String>('power') ?? '',
            toughness: row.readNullable<String>('toughness') ?? '',
            loyalty: row.readNullable<String>('loyalty') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            quantity: row.read<int>('quantity'),
            foil: row.read<int>('foil') == 1,
            altArt: row.read<int>('alt_art') == 1,
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<List<CollectionCardEntry>> fetchSetCollectionCards(
    int collectionId,
    String setCode, {
    int? limit,
    int? offset,
  }) async {
    final db = await open();
    var resolvedLimit = limit;
    if (offset != null && resolvedLimit == null) {
      resolvedLimit = -1;
    }
    final variables = <Variable>[
      Variable.withInt(collectionId),
      Variable.withString(setCode),
    ];
    final sql = StringBuffer('''
      SELECT
        cards.id AS card_id,
        COALESCE(collection_cards.quantity, 0) AS quantity,
        COALESCE(collection_cards.foil, 0) AS foil,
        COALESCE(collection_cards.alt_art, 0) AS alt_art,
        cards.name AS name,
        cards.set_code AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.mana_cost AS mana_cost,
        cards.oracle_text AS oracle_text,
        cards.cmc AS cmc,
        cards.lang AS lang,
        cards.released_at AS released_at,
        cards.artist AS artist,
        cards.power AS power,
        cards.toughness AS toughness,
        cards.loyalty AS loyalty,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_usd_etched AS price_usd_etched,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.price_tix AS price_tix,
        cards.prices_updated_at AS prices_updated_at,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      LEFT JOIN collection_cards
        ON collection_cards.card_id = cards.id
        AND collection_cards.collection_id = ?
      WHERE cards.set_code = ?
      ORDER BY cards.name ASC
      ''');
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      variables.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db
        .customSelect(sql.toString(), variables: variables)
        .get();

    return rows
        .map(
          (row) => CollectionCardEntry(
            cardId: row.read<String>('card_id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            manaCost: row.readNullable<String>('mana_cost') ?? '',
            oracleText: row.readNullable<String>('oracle_text') ?? '',
            manaValue: row.readNullable<double>('cmc'),
            lang: row.readNullable<String>('lang') ?? '',
            releasedAt: row.readNullable<String>('released_at') ?? '',
            artist: row.readNullable<String>('artist') ?? '',
            power: row.readNullable<String>('power') ?? '',
            toughness: row.readNullable<String>('toughness') ?? '',
            loyalty: row.readNullable<String>('loyalty') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            quantity: row.read<int>('quantity'),
            foil: row.read<int>('foil') == 1,
            altArt: row.read<int>('alt_art') == 1,
            priceUsd: _readOptionalPrice(row, 'price_usd'),
            priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
            priceUsdEtched: _readOptionalPrice(row, 'price_usd_etched'),
            priceEur: _readOptionalPrice(row, 'price_eur'),
            priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
            priceTix: _readOptionalPrice(row, 'price_tix'),
            pricesUpdatedAt: row.readNullable<int>('prices_updated_at'),
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<List<CollectionCardEntry>> fetchFilteredCollectionCards(
    CollectionFilter filter, {
    String? searchQuery,
    bool ownedOnly = false,
    bool missingOnly = false,
    int? limit,
    int? offset,
  }) async {
    final db = await open();
    final allCardsId = await fetchAllCardsCollectionId();
    if (allCardsId == null) {
      return [];
    }
    var resolvedLimit = limit;
    if (offset != null && resolvedLimit == null) {
      resolvedLimit = -1;
    }
    final filterQuery = _buildFilterQuery(filter);
    final whereClauses = [...filterQuery.whereClauses];
    final variables = <Variable>[...filterQuery.variables];
    if (ownedOnly) {
      whereClauses.add('COALESCE(collection_cards.quantity, 0) > 0');
    } else if (missingOnly) {
      whereClauses.add('COALESCE(collection_cards.quantity, 0) = 0');
    }
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final bound = <Variable>[Variable.withInt(allCardsId), ...variables];
    final boundWithPaging = <Variable>[...bound];
    final sql = StringBuffer('''
      SELECT
        cards.id AS card_id,
        COALESCE(collection_cards.quantity, 0) AS quantity,
        COALESCE(collection_cards.foil, 0) AS foil,
        COALESCE(collection_cards.alt_art, 0) AS alt_art,
        cards.name AS name,
        COALESCE(cards.set_code, '') AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.mana_cost AS mana_cost,
        cards.oracle_text AS oracle_text,
        cards.cmc AS cmc,
        cards.lang AS lang,
        cards.released_at AS released_at,
        cards.artist AS artist,
        cards.power AS power,
        cards.toughness AS toughness,
        cards.loyalty AS loyalty,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_usd_etched AS price_usd_etched,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.price_tix AS price_tix,
        cards.prices_updated_at AS prices_updated_at,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      LEFT JOIN collection_cards
        ON collection_cards.card_id = cards.id
        AND collection_cards.collection_id = ?
      $whereSql
      ORDER BY cards.name ASC
      ''');
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      boundWithPaging.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      boundWithPaging.add(Variable.withInt(offset));
    }
    final rows = await db
        .customSelect(sql.toString(), variables: boundWithPaging)
        .get();

    return rows
        .map(
          (row) => CollectionCardEntry(
            cardId: row.read<String>('card_id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            manaCost: row.readNullable<String>('mana_cost') ?? '',
            oracleText: row.readNullable<String>('oracle_text') ?? '',
            manaValue: row.readNullable<double>('cmc'),
            lang: row.readNullable<String>('lang') ?? '',
            releasedAt: row.readNullable<String>('released_at') ?? '',
            artist: row.readNullable<String>('artist') ?? '',
            power: row.readNullable<String>('power') ?? '',
            toughness: row.readNullable<String>('toughness') ?? '',
            loyalty: row.readNullable<String>('loyalty') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            quantity: row.read<int>('quantity'),
            foil: row.read<int>('foil') == 1,
            altArt: row.read<int>('alt_art') == 1,
            priceUsd: _readOptionalPrice(row, 'price_usd'),
            priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
            priceUsdEtched: _readOptionalPrice(row, 'price_usd_etched'),
            priceEur: _readOptionalPrice(row, 'price_eur'),
            priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
            priceTix: _readOptionalPrice(row, 'price_tix'),
            pricesUpdatedAt: row.readNullable<int>('prices_updated_at'),
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<int> countOwnedCardsForFilter(CollectionFilter filter) async {
    final db = await open();
    final allCardsId = await fetchAllCardsCollectionId();
    if (allCardsId == null) {
      return 0;
    }
    return _countOwnedCardsForFilter(db, filter, allCardsId);
  }

  Future<int> countOwnedCardsForFilterWithSearch(
    CollectionFilter filter, {
    String? searchQuery,
  }) async {
    final db = await open();
    final allCardsId = await fetchAllCardsCollectionId();
    if (allCardsId == null) {
      return 0;
    }
    final filterQuery = _buildFilterQuery(filter);
    final whereClauses = [...filterQuery.whereClauses];
    final variables = <Variable>[...filterQuery.variables];
    whereClauses.add('COALESCE(collection_cards.quantity, 0) > 0');
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final row = await db
        .customSelect(
          '''
      SELECT COUNT(*) AS total
      FROM cards
      LEFT JOIN collection_cards
        ON collection_cards.card_id = cards.id
        AND collection_cards.collection_id = ?
      $whereSql
      ''',
          variables: [Variable.withInt(allCardsId), ...variables],
        )
        .getSingle();
    return row.read<int>('total');
  }

  Future<int> countCardsForFilter(CollectionFilter filter) async {
    final db = await open();
    final filterQuery = _buildFilterQuery(filter);
    final whereSql = filterQuery.whereClauses.isEmpty
        ? ''
        : 'WHERE ${filterQuery.whereClauses.join(' AND ')}';
    final row = await db.customSelect('''
      SELECT COUNT(*) AS total
      FROM cards
      $whereSql
      ''', variables: filterQuery.variables).getSingle();
    return row.read<int>('total');
  }

  Future<int> countCardsForFilterWithSearch(
    CollectionFilter filter, {
    String? searchQuery,
  }) async {
    final db = await open();
    final filterQuery = _buildFilterQuery(filter);
    final whereClauses = [...filterQuery.whereClauses];
    final variables = <Variable>[...filterQuery.variables];
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final row = await db.customSelect('''
      SELECT COUNT(*) AS total
      FROM cards
      $whereSql
      ''', variables: variables).getSingle();
    return row.read<int>('total');
  }

  Future<int> countCollectionCards(
    int collectionId, {
    String? searchQuery,
  }) async {
    final db = await open();
    final whereClauses = <String>['collection_cards.collection_id = ?'];
    final variables = <Variable>[Variable.withInt(collectionId)];
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final row = await db.customSelect('''
      SELECT COUNT(*) AS total
      FROM collection_cards
      JOIN cards ON cards.id = collection_cards.card_id
      $whereSql
      ''', variables: variables).getSingle();
    return row.read<int>('total');
  }

  Future<int> countCollectionQuantity(int collectionId) async {
    final db = await open();
    final row = await db
        .customSelect(
          'SELECT COALESCE(SUM(quantity), 0) AS total FROM collection_cards WHERE collection_id = ?',
          variables: [Variable.withInt(collectionId)],
        )
        .getSingle();
    return row.read<int>('total');
  }

  Future<List<CardSearchResult>> fetchFilteredCardPreviews(
    CollectionFilter filter, {
    int limit = 40,
    int? offset,
  }) async {
    final db = await open();
    final filterQuery = _buildFilterQuery(filter);
    final whereSql = filterQuery.whereClauses.isEmpty
        ? ''
        : 'WHERE ${filterQuery.whereClauses.join(' AND ')}';
    final variables = <Variable>[
      ...filterQuery.variables,
      Variable.withInt(limit),
    ];
    final sql = StringBuffer('''
      SELECT
        cards.id AS id,
        cards.name AS name,
        COALESCE(cards.set_code, '') AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      $whereSql
      ORDER BY cards.name ASC
      LIMIT ?
      ''');
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db
        .customSelect(sql.toString(), variables: variables)
        .get();

    return rows
        .map(
          (row) => CardSearchResult(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            priceUsd: _readOptionalPrice(row, 'price_usd'),
            priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
            priceEur: _readOptionalPrice(row, 'price_eur'),
            priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<List<String>> fetchAvailableArtists({
    String? query,
    int limit = 40,
  }) async {
    final db = await open();
    const artistExpr = '''
      TRIM(
        COALESCE(
          NULLIF(cards.artist, ''),
          json_extract(cards.card_json, '\$.artist'),
          ''
        )
      )
    ''';
    final where = <String>['$artistExpr != \'\''];
    final variables = <Variable>[];
    final resolvedQuery = query?.trim().toLowerCase();
    if (resolvedQuery != null && resolvedQuery.isNotEmpty) {
      where.add('LOWER($artistExpr) LIKE ?');
      variables.add(Variable.withString('%$resolvedQuery%'));
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db
        .customSelect(
          '''
      SELECT DISTINCT $artistExpr AS artist
      FROM cards
      $whereSql
      ORDER BY artist ASC
      LIMIT ?
      ''',
          variables: [...variables, Variable.withInt(limit)],
        )
        .get();
    return rows
        .map((row) => row.read<String>('artist').trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<void> addCardToCollection(int collectionId, String cardId) async {
    final db = await open();
    await db.transaction(() async {
      final existing =
          await (db.select(db.collectionCards)
                ..where(
                  (tbl) =>
                      tbl.collectionId.equals(collectionId) &
                      tbl.cardId.equals(cardId),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        final updated = existing.quantity + 1;
        await (db.update(db.collectionCards)..where(
              (tbl) =>
                  tbl.collectionId.equals(collectionId) &
                  tbl.cardId.equals(cardId),
            ))
            .write(CollectionCardsCompanion(quantity: Value(updated)));
      } else {
        await db
            .into(db.collectionCards)
            .insert(
              CollectionCardsCompanion.insert(
                collectionId: collectionId,
                cardId: cardId,
                quantity: const Value(1),
                foil: const Value(false),
                altArt: const Value(false),
              ),
            );
      }
    });
  }

  Future<void> addCardToCollectionAsMissing(
    int collectionId,
    String cardId,
  ) async {
    await upsertCollectionMembership(collectionId, cardId);
  }

  Future<void> claimCardFromWishlist({
    required int wishlistCollectionId,
    required int ownedCollectionId,
    required String cardId,
  }) async {
    final db = await open();
    await db.transaction(() async {
      final ownedExisting =
          await (db.select(db.collectionCards)
                ..where(
                  (tbl) =>
                      tbl.collectionId.equals(ownedCollectionId) &
                      tbl.cardId.equals(cardId),
                )
                ..limit(1))
              .getSingleOrNull();
      if (ownedExisting != null) {
        await (db.update(db.collectionCards)..where(
              (tbl) =>
                  tbl.collectionId.equals(ownedCollectionId) &
                  tbl.cardId.equals(cardId),
            ))
            .write(
              CollectionCardsCompanion(
                quantity: Value(ownedExisting.quantity + 1),
              ),
            );
      } else {
        await db
            .into(db.collectionCards)
            .insert(
              CollectionCardsCompanion.insert(
                collectionId: ownedCollectionId,
                cardId: cardId,
                quantity: const Value(1),
                foil: const Value(false),
                altArt: const Value(false),
              ),
            );
      }
      await (db.delete(db.collectionCards)..where(
            (tbl) =>
                tbl.collectionId.equals(wishlistCollectionId) &
                tbl.cardId.equals(cardId),
          ))
          .go();
    });
  }

  Future<void> addCardsToCollection(
    int collectionId,
    List<String> cardIds,
  ) async {
    if (cardIds.isEmpty) {
      return;
    }
    final uniqueIds = cardIds.toSet().toList();
    final db = await open();
    await db.transaction(() async {
      final placeholders = List.filled(uniqueIds.length, '?').join(', ');
      final rows = await db
          .customSelect(
            '''
        SELECT card_id AS card_id, quantity AS quantity
        FROM collection_cards
        WHERE collection_id = ? AND card_id IN ($placeholders)
        ''',
            variables: [
              Variable.withInt(collectionId),
              ...uniqueIds.map(Variable.withString),
            ],
          )
          .get();
      final existing = <String, int>{};
      for (final row in rows) {
        existing[row.read<String>('card_id')] = row.read<int>('quantity');
      }
      for (final cardId in uniqueIds) {
        final current = existing[cardId];
        if (current != null) {
          await (db.update(db.collectionCards)..where(
                (tbl) =>
                    tbl.collectionId.equals(collectionId) &
                    tbl.cardId.equals(cardId),
              ))
              .write(CollectionCardsCompanion(quantity: Value(current + 1)));
        } else {
          await db
              .into(db.collectionCards)
              .insert(
                CollectionCardsCompanion.insert(
                  collectionId: collectionId,
                  cardId: cardId,
                  quantity: const Value(1),
                  foil: const Value(false),
                  altArt: const Value(false),
                ),
              );
        }
      }
    });
  }

  Future<Map<String, String>> fetchSetCodesForCardIds(
    List<String> cardIds,
  ) async {
    if (cardIds.isEmpty) {
      return {};
    }
    final uniqueIds = cardIds.toSet().toList();
    final db = await open();
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final rows = await db.customSelect('''
      SELECT id AS card_id, set_code AS set_code
      FROM cards
      WHERE id IN ($placeholders)
      ''', variables: uniqueIds.map(Variable.withString).toList()).get();
    return {
      for (final row in rows)
        row.read<String>('card_id'): row.read<String>('set_code'),
    };
  }

  Future<Map<String, int>> fetchCollectionQuantities(
    int collectionId,
    List<String> cardIds,
  ) async {
    if (cardIds.isEmpty) {
      return {};
    }
    final uniqueIds = cardIds.toSet().toList();
    final db = await open();
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final rows = await db
        .customSelect(
          '''
      SELECT card_id AS card_id, quantity AS quantity
      FROM collection_cards
      WHERE collection_id = ? AND card_id IN ($placeholders)
      ''',
          variables: [
            Variable.withInt(collectionId),
            ...uniqueIds.map(Variable.withString),
          ],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('card_id'): row.read<int>('quantity'),
    };
  }

  Future<CollectionCardEntry?> fetchCardEntryById(
    String cardId, {
    int? collectionId,
  }) async {
    final db = await open();
    final rows = await db
        .customSelect(
          '''
      SELECT
        cards.id AS card_id,
        COALESCE(collection_cards.quantity, 0) AS quantity,
        COALESCE(collection_cards.foil, 0) AS foil,
        COALESCE(collection_cards.alt_art, 0) AS alt_art,
        cards.name AS name,
        COALESCE(cards.set_code, '') AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.mana_cost AS mana_cost,
        cards.oracle_text AS oracle_text,
        cards.cmc AS cmc,
        cards.lang AS lang,
        cards.released_at AS released_at,
        cards.artist AS artist,
        cards.power AS power,
        cards.toughness AS toughness,
        cards.loyalty AS loyalty,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_usd_etched AS price_usd_etched,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.price_tix AS price_tix,
        cards.prices_updated_at AS prices_updated_at,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      LEFT JOIN collection_cards
        ON collection_cards.card_id = cards.id
        AND collection_cards.collection_id = ?
      WHERE cards.id = ?
      LIMIT 1
      ''',
          variables: [
            Variable.withInt(collectionId ?? -1),
            Variable.withString(cardId),
          ],
        )
        .get();

    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return CollectionCardEntry(
      cardId: row.read<String>('card_id'),
      name: row.read<String>('name'),
      setCode: row.read<String>('set_code'),
      setName: row.readNullable<String>('set_name') ?? '',
      setTotal: row.readNullable<int>('set_total'),
      collectorNumber: row.read<String>('collector_number'),
      rarity: row.readNullable<String>('rarity') ?? '',
      typeLine: row.readNullable<String>('type_line') ?? '',
      manaCost: row.readNullable<String>('mana_cost') ?? '',
      oracleText: row.readNullable<String>('oracle_text') ?? '',
      manaValue: row.readNullable<double>('cmc'),
      lang: row.readNullable<String>('lang') ?? '',
      releasedAt: row.readNullable<String>('released_at') ?? '',
      artist: row.readNullable<String>('artist') ?? '',
      power: row.readNullable<String>('power') ?? '',
      toughness: row.readNullable<String>('toughness') ?? '',
      loyalty: row.readNullable<String>('loyalty') ?? '',
      colors: row.readNullable<String>('colors') ?? '',
      colorIdentity: row.readNullable<String>('color_identity') ?? '',
      quantity: row.read<int>('quantity'),
      foil: row.read<int>('foil') == 1,
      altArt: row.read<int>('alt_art') == 1,
      priceUsd: _readOptionalPrice(row, 'price_usd'),
      priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
      priceUsdEtched: _readOptionalPrice(row, 'price_usd_etched'),
      priceEur: _readOptionalPrice(row, 'price_eur'),
      priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
      priceTix: _readOptionalPrice(row, 'price_tix'),
      pricesUpdatedAt: row.readNullable<int>('prices_updated_at'),
      imageUri: _extractImageUrl(
        row.readNullable<String>('image_uris'),
        row.readNullable<String>('card_faces'),
      ),
    );
  }

  Future<CardPriceSnapshot?> fetchCardPriceSnapshot(String cardId) async {
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }
    final db = await open();
    final row = await db
        .customSelect(
          '''
      SELECT id AS card_id, prices_updated_at AS prices_updated_at
      FROM cards
      WHERE id = ?
      LIMIT 1
      ''',
          variables: [Variable.withString(normalizedId)],
        )
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return CardPriceSnapshot(
      cardId: row.read<String>('card_id'),
      pricesUpdatedAt: row.readNullable<int>('prices_updated_at'),
    );
  }

  Future<String?> fetchPreferredCardIdByExactName(String cardName) async {
    final normalizedName = cardName.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      return null;
    }
    final db = await open();
    final rows = await db
        .customSelect(
          '''
      SELECT id AS id
      FROM cards
      WHERE LOWER(name) = ?
      ORDER BY
        CASE WHEN LOWER(COALESCE(lang, '')) = 'en' THEN 0 ELSE 1 END,
        COALESCE(released_at, '') DESC,
        COALESCE(set_code, '') ASC,
        CASE WHEN COALESCE(collector_number, '') GLOB '[0-9]*' THEN 0 ELSE 1 END,
        CASE
          WHEN COALESCE(collector_number, '') GLOB '[0-9]*'
          THEN CAST(collector_number AS INTEGER)
          ELSE 999999
        END ASC
      LIMIT 1
      ''',
          variables: [Variable.withString(normalizedName)],
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }
    return rows.first.read<String>('id');
  }

  Future<String?> fetchPreferredBasicLandCardId(String mana) async {
    final normalizedMana = mana.trim().toUpperCase();
    const namesByMana = {
      'W': 'plains',
      'U': 'island',
      'B': 'swamp',
      'R': 'mountain',
      'G': 'forest',
    };
    final basicName = namesByMana[normalizedMana];
    if (basicName == null) {
      return null;
    }
    final db = await open();
    final strictRows = await db
        .customSelect(
          '''
      SELECT id AS id
      FROM cards
      WHERE
        LOWER(name) = ?
        AND LOWER(COALESCE(type_line, '')) LIKE '%basic land%'
        AND LOWER(COALESCE(rarity, '')) = 'common'
        AND LOWER(COALESCE(lang, '')) = 'en'
        AND LOWER(COALESCE(set_code, '')) != 'sld'
      ORDER BY
        COALESCE(released_at, '') DESC,
        CASE WHEN COALESCE(collector_number, '') GLOB '[0-9]*' THEN 0 ELSE 1 END,
        CASE
          WHEN COALESCE(collector_number, '') GLOB '[0-9]*'
          THEN CAST(collector_number AS INTEGER)
          ELSE 999999
        END ASC,
        COALESCE(set_code, '') ASC
      LIMIT 1
      ''',
          variables: [Variable.withString(basicName)],
        )
        .get();
    if (strictRows.isNotEmpty) {
      return strictRows.first.read<String>('id');
    }

    final fallbackRows = await db
        .customSelect(
          '''
      SELECT id AS id
      FROM cards
      WHERE
        LOWER(name) = ?
        AND LOWER(COALESCE(type_line, '')) LIKE '%basic land%'
      ORDER BY
        COALESCE(released_at, '') DESC,
        CASE WHEN LOWER(COALESCE(set_code, '')) = 'sld' THEN 1 ELSE 0 END,
        CASE WHEN LOWER(COALESCE(lang, '')) = 'en' THEN 0 ELSE 1 END,
        CASE WHEN COALESCE(collector_number, '') GLOB '[0-9]*' THEN 0 ELSE 1 END,
        CASE
          WHEN COALESCE(collector_number, '') GLOB '[0-9]*'
          THEN CAST(collector_number AS INTEGER)
          ELSE 999999
        END ASC
      LIMIT 1
      ''',
          variables: [Variable.withString(basicName)],
        )
        .get();
    if (fallbackRows.isEmpty) {
      return null;
    }
    return fallbackRows.first.read<String>('id');
  }

  Future<CollectionCardEntry?> fetchFirstBasicLandEntryForCollection(
    int collectionId,
    String mana,
  ) async {
    final normalizedMana = mana.trim().toUpperCase();
    const namesByMana = {
      'W': 'plains',
      'U': 'island',
      'B': 'swamp',
      'R': 'mountain',
      'G': 'forest',
    };
    final basicName = namesByMana[normalizedMana];
    if (basicName == null) {
      return null;
    }
    final db = await open();
    final rows = await db
        .customSelect(
          '''
      SELECT collection_cards.card_id AS card_id
      FROM collection_cards
      JOIN cards ON cards.id = collection_cards.card_id
      WHERE
        collection_cards.collection_id = ?
        AND collection_cards.quantity > 0
        AND (
          LOWER(cards.name) = ?
          OR (
            COALESCE(cards.color_identity, '') = ?
            AND LOWER(COALESCE(cards.type_line, '')) LIKE '%basic land%'
          )
        )
      ORDER BY
        collection_cards.quantity DESC,
        CASE WHEN LOWER(cards.name) = ? THEN 0 ELSE 1 END,
        CASE WHEN LOWER(COALESCE(cards.lang, '')) = 'en' THEN 0 ELSE 1 END,
        COALESCE(cards.released_at, '') DESC
      LIMIT 1
      ''',
          variables: [
            Variable.withInt(collectionId),
            Variable.withString(basicName),
            Variable.withString('["$normalizedMana"]'),
            Variable.withString(basicName),
          ],
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }
    final cardId = rows.first.read<String>('card_id');
    return fetchCardEntryById(cardId, collectionId: collectionId);
  }

  Future<List<String>> fetchCardLegalFormats(String cardId) async {
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      return const [];
    }
    final db = await open();
    final row = await db
        .customSelect(
          '''
      SELECT card_json AS card_json
      FROM cards
      WHERE id = ?
      LIMIT 1
      ''',
          variables: [Variable.withString(normalizedId)],
        )
        .getSingleOrNull();
    if (row == null) {
      return const [];
    }
    final rawCardJson = row.readNullable<String>('card_json');
    if (rawCardJson == null || rawCardJson.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(rawCardJson);
      if (decoded is! Map) {
        return const [];
      }
      final legalitiesRaw = decoded['legalities'];
      if (legalitiesRaw is! Map) {
        return const [];
      }
      final legalFormats = <String>[];
      for (final entry in legalitiesRaw.entries) {
        final key = entry.key.toString().trim().toLowerCase();
        final value = entry.value?.toString().trim().toLowerCase() ?? '';
        if (key.isEmpty) {
          continue;
        }
        if (value == 'legal' || value == 'restricted') {
          legalFormats.add(key);
        }
      }
      legalFormats.sort();
      return legalFormats;
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, bool>> fetchCardLegalityForFormat(
    List<String> cardIds, {
    required String format,
  }) async {
    final normalizedFormat = format.trim().toLowerCase();
    if (normalizedFormat.isEmpty || cardIds.isEmpty) {
      return const {};
    }
    final uniqueIds = cardIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniqueIds.isEmpty) {
      return const {};
    }
    final db = await open();
    final path = r'$.legalities.' + normalizedFormat;
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final rows = await db
        .customSelect(
          '''
      SELECT
        id AS card_id,
        LOWER(COALESCE(json_extract(card_json, ?), '')) AS legality
      FROM cards
      WHERE id IN ($placeholders)
      ''',
          variables: [
            Variable.withString(path),
            ...uniqueIds.map(Variable.withString),
          ],
        )
        .get();
    final result = <String, bool>{};
    for (final row in rows) {
      final cardId = row.read<String>('card_id');
      final legality = row.read<String>('legality');
      result[cardId] = legality == 'legal' || legality == 'restricted';
    }
    return result;
  }

  Future<void> updateCardPrices(
    String cardId,
    CardPrices prices, {
    required int updatedAt,
  }) async {
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    final db = await open();
    await db.transaction(() async {
      await (db.update(
        db.cards,
      )..where((tbl) => tbl.id.equals(normalizedId))).write(
        CardsCompanion(
          priceUsd: Value(prices.usd),
          priceUsdFoil: Value(prices.usdFoil),
          priceUsdEtched: Value(prices.usdEtched),
          priceEur: Value(prices.eur),
          priceEurFoil: Value(prices.eurFoil),
          priceTix: Value(prices.tix),
          pricesUpdatedAt: Value(updatedAt),
        ),
      );
    });
  }

  Future<Map<String, List<int>>> fetchCollectionIdsForCardIds(
    List<String> cardIds,
  ) async {
    if (cardIds.isEmpty) {
      return {};
    }
    final uniqueIds = cardIds.toSet().toList();
    final db = await open();
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final rows = await db.customSelect('''
      SELECT card_id AS card_id, collection_id AS collection_id
      FROM collection_cards
      WHERE card_id IN ($placeholders)
      ''', variables: uniqueIds.map(Variable.withString).toList()).get();
    final result = <String, List<int>>{};
    for (final row in rows) {
      final cardId = row.read<String>('card_id');
      final collectionId = row.read<int>('collection_id');
      (result[cardId] ??= []).add(collectionId);
    }
    return result;
  }

  Future<void> upsertCollectionCard(
    int collectionId,
    String cardId, {
    required int quantity,
    required bool foil,
    required bool altArt,
  }) async {
    final db = await open();
    if (quantity <= 0) {
      await deleteCollectionCard(collectionId, cardId);
      return;
    }
    await db
        .into(db.collectionCards)
        .insert(
          CollectionCardsCompanion.insert(
            collectionId: collectionId,
            cardId: cardId,
            quantity: Value(quantity),
            foil: Value(foil),
            altArt: Value(altArt),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> upsertCollectionMembership(
    int collectionId,
    String cardId,
  ) async {
    final db = await open();
    await db
        .into(db.collectionCards)
        .insert(
          CollectionCardsCompanion.insert(
            collectionId: collectionId,
            cardId: cardId,
            quantity: const Value(0),
            foil: const Value(false),
            altArt: const Value(false),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<int> fetchOwnedQuantityInAllCards(String cardId) async {
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      return 0;
    }
    final db = await open();
    final allCardsId = await ensureAllCardsCollectionId();
    final row = await db
        .customSelect(
          '''
      SELECT COALESCE(quantity, 0) AS qty
      FROM collection_cards
      WHERE collection_id = ? AND card_id = ?
      LIMIT 1
      ''',
          variables: [
            Variable.withInt(allCardsId),
            Variable.withString(normalizedId),
          ],
        )
        .getSingleOrNull();
    return row?.read<int>('qty') ?? 0;
  }

  Future<void> removeCardFromDirectCustomCollections(String cardId) async {
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    final db = await open();
    await db.customStatement(
      '''
      DELETE FROM collection_cards
      WHERE card_id = ?
        AND collection_id IN (
          SELECT id FROM collections
          WHERE type = 'custom'
            AND (filter_json IS NULL OR TRIM(filter_json) = '')
            AND name NOT LIKE '__deck_side__:%'
        )
      ''',
      [normalizedId],
    );
  }

  Future<void> removeCardFromWishlists(String cardId) async {
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    final db = await open();
    await db.customStatement(
      '''
      DELETE FROM collection_cards
      WHERE card_id = ?
        AND collection_id IN (
          SELECT id FROM collections
          WHERE type = 'wishlist'
        )
      ''',
      [normalizedId],
    );
  }

  Future<void> updateCollectionCard(
    int collectionId,
    String cardId, {
    int? quantity,
    bool? foil,
    bool? altArt,
  }) async {
    final db = await open();
    final values = CollectionCardsCompanion(
      quantity: quantity == null ? const Value.absent() : Value(quantity),
      foil: foil == null ? const Value.absent() : Value(foil),
      altArt: altArt == null ? const Value.absent() : Value(altArt),
    );
    await (db.update(db.collectionCards)..where(
          (tbl) =>
              tbl.collectionId.equals(collectionId) & tbl.cardId.equals(cardId),
        ))
        .write(values);
  }

  Future<void> deleteCollectionCard(int collectionId, String cardId) async {
    final db = await open();
    await (db.delete(db.collectionCards)..where(
          (tbl) =>
              tbl.collectionId.equals(collectionId) & tbl.cardId.equals(cardId),
        ))
        .go();
  }

  Future<void> rebuildCardsFts() async {
    final db = await open();
    await db.rebuildFts();
  }

  Future<int> countCards() async {
    final db = await open();
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        final row = await db
            .customSelect('SELECT COUNT(*) AS count FROM cards')
            .getSingle();
        return row.read<int>('count');
      } catch (_) {
        if (attempt == 2) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    return 0;
  }

  Future<bool> needsLightReimport() async {
    final db = await open();
    final row = await db.customSelect('''
      SELECT 1 AS missing
      FROM cards
      WHERE set_name IS NULL OR set_name = ''
      LIMIT 1
      ''').getSingleOrNull();
    return row != null;
  }

  Future<int> countOwnedCards() async {
    final db = await open();
    final allCardsId = await fetchAllCardsCollectionId();
    if (allCardsId == null) {
      return 0;
    }
    final row = await db
        .customSelect(
          'SELECT COALESCE(SUM(quantity), 0) AS total FROM collection_cards WHERE collection_id = ?',
          variables: [Variable.withInt(allCardsId)],
        )
        .getSingle();
    return row.read<int>('total');
  }

  Future<int> countWishlistCards(
    int collectionId, {
    String? searchQuery,
  }) async {
    final db = await open();
    final whereClauses = <String>['wishlist.card_id IS NOT NULL'];
    final variables = <Variable>[Variable.withInt(collectionId)];
    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }
    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final row = await db.customSelect('''
      SELECT COUNT(*) AS total
      FROM (
        SELECT TRIM(card_id) AS card_id
        FROM collection_cards
        WHERE collection_id = ? AND quantity = 0
      ) wishlist
      JOIN cards ON cards.id = wishlist.card_id
      $whereSql
      ''', variables: variables).getSingle();
    return row.read<int>('total');
  }

  Future<int> repairAllCardsCoherenceFromCustomCollections() async {
    final db = await open();
    var repairedEntries = 0;
    await db.transaction(() async {
      Future<int> readChanges() async {
        final row = await db
            .customSelect('SELECT changes() AS count')
            .getSingleOrNull();
        return row?.read<int>('count') ?? 0;
      }

      // Type normalization (legacy names/patterns).
      await db.customStatement('''
        UPDATE collections
        SET type = 'all'
        WHERE lower(trim(name)) IN ('all cards', 'tutte le carte', 'my collection')
          AND type != 'all'
        ''');
      repairedEntries += await readChanges();
      await db.customStatement('''
        UPDATE collections
        SET type = 'set'
        WHERE type = 'custom' AND lower(name) LIKE 'set: %'
        ''');
      repairedEntries += await readChanges();
      await db.customStatement('''
        UPDATE collections
        SET type = 'smart'
        WHERE type != 'smart'
          AND filter_json IS NOT NULL
          AND trim(filter_json) != ''
        ''');
      repairedEntries += await readChanges();

      // Ensure canonical all-cards exists and merge duplicates.
      await db.customStatement('''
        INSERT INTO collections(name, type, filter_json)
        SELECT 'All cards', 'all', NULL
        WHERE NOT EXISTS (
          SELECT 1 FROM collections WHERE type = 'all'
        )
        ''');
      repairedEntries += await readChanges();
      await db.customStatement('''
        CREATE TEMP TABLE IF NOT EXISTS _coh_all_ids AS
        SELECT id FROM collections WHERE type = 'all' ORDER BY id
        ''');
      await db.customStatement('''
        UPDATE collection_cards
        SET collection_id = (SELECT MIN(id) FROM _coh_all_ids)
        WHERE collection_id IN (
          SELECT id FROM _coh_all_ids
          WHERE id != (SELECT MIN(id) FROM _coh_all_ids)
        )
          AND EXISTS (SELECT 1 FROM _coh_all_ids)
        ''');
      repairedEntries += await readChanges();
      await db.customStatement('''
        DELETE FROM collections
        WHERE id IN (
          SELECT id FROM _coh_all_ids
          WHERE id != (SELECT MIN(id) FROM _coh_all_ids)
        )
        ''');
      repairedEntries += await readChanges();
      await db.customStatement('DROP TABLE IF EXISTS _coh_all_ids');

      // Normalize/trims card ids and deduplicate by (collection_id, card_id).
      final beforeNorm = await db
          .customSelect('SELECT COUNT(*) AS total FROM collection_cards')
          .getSingle();
      final beforeNormCount = beforeNorm.read<int>('total');
      await db.customStatement('''
        CREATE TEMP TABLE IF NOT EXISTS _coh_cc_norm AS
        SELECT
          collection_id AS collection_id,
          trim(card_id) AS card_id,
          SUM(CASE WHEN COALESCE(quantity, 0) < 0 THEN 0 ELSE COALESCE(quantity, 0) END) AS quantity,
          MAX(CAST(COALESCE(foil, 0) AS INTEGER)) AS foil,
          MAX(CAST(COALESCE(alt_art, 0) AS INTEGER)) AS alt_art
        FROM collection_cards
        WHERE trim(card_id) != ''
        GROUP BY collection_id, trim(card_id)
        ''');
      await db.customStatement('DELETE FROM collection_cards');
      await db.customStatement('''
        INSERT INTO collection_cards(collection_id, card_id, quantity, foil, alt_art)
        SELECT collection_id, card_id, quantity, foil, alt_art
        FROM _coh_cc_norm
        ''');
      await db.customStatement('DROP TABLE IF EXISTS _coh_cc_norm');
      final afterNorm = await db
          .customSelect('SELECT COUNT(*) AS total FROM collection_cards')
          .getSingle();
      final afterNormCount = afterNorm.read<int>('total');
      repairedEntries += (beforeNormCount - afterNormCount).abs();

      // Remove orphan rows (card ids not in catalog).
      await db.customStatement('''
        DELETE FROM collection_cards
        WHERE card_id NOT IN (SELECT id FROM cards)
        ''');
      repairedEntries += await readChanges();

      // Derived collections must not persist memberships.
      await db.customStatement('''
        DELETE FROM collection_cards
        WHERE collection_id IN (
          SELECT id FROM collections
          WHERE type IN ('set', 'smart')
        )
        ''');
      repairedEntries += await readChanges();

      // Wishlist must be membership-only desired list.
      await db.customStatement('''
        UPDATE collections
        SET filter_json = NULL
        WHERE type = 'wishlist'
          AND filter_json IS NOT NULL
        ''');
      repairedEntries += await readChanges();
      await db.customStatement('''
        UPDATE collection_cards
        SET quantity = 0, foil = 0, alt_art = 0
        WHERE collection_id IN (
          SELECT id FROM collections
          WHERE type = 'wishlist'
        )
          AND (
            COALESCE(quantity, 0) != 0 OR
            COALESCE(foil, 0) != 0 OR
            COALESCE(alt_art, 0) != 0
          )
        ''');
      repairedEntries += await readChanges();

      // Direct custom collections are membership-only lists.
      await db.customStatement('''
        UPDATE collection_cards
        SET quantity = 0, foil = 0, alt_art = 0
        WHERE collection_id IN (
          SELECT id FROM collections
          WHERE type = 'custom'
            AND (filter_json IS NULL OR trim(filter_json) = '')
            AND name NOT LIKE '__deck_side__:%'
        )
          AND (
            COALESCE(quantity, 0) != 0 OR
            COALESCE(foil, 0) != 0 OR
            COALESCE(alt_art, 0) != 0
          )
        ''');
      repairedEntries += await readChanges();
    });
    return repairedEntries;
  }

  Future<void> deleteAllCards(AppDatabase db) async {
    await db.customStatement('DELETE FROM cards');
    await db.customStatement('DELETE FROM cards_printed_search');
    await db.customStatement('DELETE FROM cards_printed_fts');
  }

  Future<int> repairMissingSetCodesFromCardIds() async {
    final db = await open();
    await db.customStatement('''
      UPDATE cards
      SET set_code = LOWER(SUBSTR(id, 1, INSTR(id, '-') - 1))
      WHERE (set_code IS NULL OR TRIM(set_code) = '')
        AND INSTR(id, '-') > 1
    ''');
    final row = await db
        .customSelect('SELECT changes() AS count')
        .getSingleOrNull();
    return row?.read<int>('count') ?? 0;
  }

  Future<int> backfillSetNames(Map<String, String> setNamesByCode) async {
    if (setNamesByCode.isEmpty) {
      return 0;
    }
    final db = await open();
    var updated = 0;
    await db.transaction(() async {
      for (final entry in setNamesByCode.entries) {
        final code = entry.key.trim().toLowerCase();
        final name = entry.value.trim();
        if (code.isEmpty || name.isEmpty) {
          continue;
        }
        await db.customStatement(
          '''
          UPDATE cards
          SET set_name = ?
          WHERE LOWER(COALESCE(set_code, '')) = ?
            AND (set_name IS NULL OR TRIM(set_name) = '')
          ''',
          [name, code],
        );
        final row = await db
            .customSelect('SELECT changes() AS count')
            .getSingleOrNull();
        updated += row?.read<int>('count') ?? 0;
      }
    });
    return updated;
  }

  Future<int> repairMissingColorsFromTypeLine() async {
    final db = await open();
    final rows = await db.customSelect('''
      SELECT id AS id, type_line AS type_line
      FROM cards
      WHERE (colors IS NULL OR TRIM(colors) = '')
        AND (type_line IS NOT NULL AND TRIM(type_line) != '')
      ''').get();
    if (rows.isEmpty) {
      return 0;
    }
    var updated = 0;
    await db.transaction(() async {
      for (final row in rows) {
        final id = row.read<String>('id');
        final typeLine = row.readNullable<String>('type_line') ?? '';
        final inferred = _inferColorCodesFromTypeLine(typeLine);
        if (inferred.isEmpty) {
          continue;
        }
        final encoded = _encodeColorList(inferred);
        if (encoded == null || encoded.isEmpty) {
          continue;
        }
        await db.customStatement(
          '''
          UPDATE cards
          SET colors = ?, color_identity = COALESCE(NULLIF(color_identity, ''), ?)
          WHERE id = ?
          ''',
          [encoded, encoded, id],
        );
        final changed = await db
            .customSelect('SELECT changes() AS count')
            .getSingleOrNull();
        updated += changed?.read<int>('count') ?? 0;
      }
    });
    return updated;
  }

  Future<int> normalizePokemonLightningColors() async {
    final db = await open();
    await db.customStatement('''
      UPDATE cards
      SET
        colors = CASE
          WHEN colors IS NULL OR TRIM(colors) = '' THEN 'L'
          ELSE REPLACE(UPPER(colors), 'R', 'L')
        END,
        color_identity = CASE
          WHEN color_identity IS NULL OR TRIM(color_identity) = '' THEN 'L'
          ELSE REPLACE(UPPER(color_identity), 'R', 'L')
        END
      WHERE (
        LOWER(COALESCE(type_line, '')) LIKE '%lightning%' OR
        LOWER(COALESCE(type_line, '')) LIKE '%electric%'
      )
        AND (
          UPPER(COALESCE(colors, '')) LIKE '%R%' OR
          UPPER(COALESCE(color_identity, '')) LIKE '%R%'
        )
    ''');
    final row = await db
        .customSelect('SELECT changes() AS count')
        .getSingleOrNull();
    return row?.read<int>('count') ?? 0;
  }

  Future<int> backfillArtistsFromCardJson() async {
    final db = await open();
    await db.customStatement('''
      UPDATE cards
      SET artist = TRIM(json_extract(card_json, '\$.artist'))
      WHERE (artist IS NULL OR TRIM(artist) = '')
        AND TRIM(COALESCE(json_extract(card_json, '\$.artist'), '')) != ''
    ''');
    final row = await db
        .customSelect('SELECT changes() AS count')
        .getSingleOrNull();
    return row?.read<int>('count') ?? 0;
  }

  Future<void> insertCardsBatch(
    AppDatabase db,
    List<Map<String, dynamic>> items,
  ) async {
    final companions = items.map(_mapCardCompanion).toList();
    await db.batch((batch) {
      batch.insertAll(db.cards, companions, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> insertPokemonCardsBatch(
    AppDatabase db,
    List<Map<String, dynamic>> items,
  ) async {
    final companions = items.map(_mapPokemonCardCompanion).toList();
    await db.batch((batch) {
      batch.insertAll(db.cards, companions, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> upsertCardFromScryfall(Map<String, dynamic> card) async {
    final db = await open();
    await db
        .into(db.cards)
        .insert(_mapCardCompanion(card), mode: InsertMode.insertOrReplace);
  }

  Future<List<SetInfo>> fetchAvailableSets() async {
    final db = await open();
    final rows = await db.customSelect('''
      SELECT set_code AS set_code, set_name AS set_name
      FROM cards
      WHERE set_code IS NOT NULL AND set_code != ''
      GROUP BY set_code
      ORDER BY set_code ASC
      ''').get();

    final results = <SetInfo>[];
    for (final row in rows) {
      final code = row.read<String>('set_code');
      final setName = row.readNullable<String>('set_name') ?? '';
      results.add(SetInfo(code: code, name: setName.isEmpty ? code : setName));
    }
    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  Future<Map<String, String>> fetchSetNamesForCodes(
    List<String> setCodes,
  ) async {
    if (setCodes.isEmpty) {
      return {};
    }
    final db = await open();
    final placeholders = List.filled(setCodes.length, '?').join(', ');
    final rows = await db.customSelect('''
      SELECT set_code AS set_code, set_name AS set_name
      FROM cards
      WHERE set_code IN ($placeholders)
      GROUP BY set_code
      ''', variables: setCodes.map(Variable.withString).toList()).get();

    final result = <String, String>{};
    for (final row in rows) {
      final code = row.read<String>('set_code');
      final setName = row.readNullable<String>('set_name') ?? '';
      result[code] = setName.isEmpty ? code : setName;
    }
    return result;
  }

  Future<List<CardSearchResult>> searchCardsByName(
    String query, {
    int limit = 80,
    int? offset,
    List<String>? languages,
  }) async {
    final db = await open();
    final foldedQuery = _normalizeSearchTextForNameLookup(query);
    final ftsQuery = _buildPrintedNameFtsQuery(query);
    if (foldedQuery.isEmpty || ftsQuery.isEmpty) {
      return const [];
    }

    Future<List<CardSearchResult>> runSearchWithLanguages(
      List<String>? activeLanguages,
    ) async {
      final preferredLang = (activeLanguages ?? const <String>[])
          .map((item) => item.trim().toLowerCase())
          .firstWhere(
            (item) => item.isNotEmpty && item != 'en',
            orElse: () => 'en',
          );
      final whereClauses = <String>['cards_printed_fts MATCH ?'];
      final args = <Variable>[Variable.withString(ftsQuery)];
      if (activeLanguages != null && activeLanguages.isNotEmpty) {
        final placeholders = List.filled(
          activeLanguages.length,
          '?',
        ).join(', ');
        whereClauses.add('cards_printed_fts.lang IN ($placeholders)');
        args.addAll(
          activeLanguages.map(
            (lang) => Variable.withString(lang.trim().toLowerCase()),
          ),
        );
      }
      final fullWhere = whereClauses.join(' AND ');
      final sql = StringBuffer('''
      SELECT
        cards.id AS id,
        search.display_name AS name,
        cards.set_code AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards_printed_fts
      JOIN cards_printed_search search ON search.card_id = cards_printed_fts.card_id
      JOIN cards ON cards.id = search.card_id
      WHERE $fullWhere
      ORDER BY
        CASE
          WHEN search.folded_name = ? THEN 0
          WHEN search.folded_name LIKE ? THEN 1
          ELSE 4
        END ASC,
        CASE
          WHEN cards_printed_fts.lang = ? THEN 0
          WHEN search.lang = 'en' THEN 2
          ELSE 1
        END ASC,
        search.display_name ASC,
        LOWER(cards.set_code) ASC,
        LOWER(cards.collector_number) ASC
      LIMIT ?
      ''');
      args
        ..add(Variable.withString(foldedQuery))
        ..add(Variable.withString('$foldedQuery%'))
        ..add(Variable.withString(preferredLang))
        ..add(Variable.withInt(limit));
      if (offset != null && offset > 0) {
        sql.write(' OFFSET ?');
        args.add(Variable.withInt(offset));
      }
      final rows = await db.customSelect(sql.toString(), variables: args).get();
      return rows
          .map(
            (row) => CardSearchResult(
              id: row.read<String>('id'),
              name: row.read<String>('name'),
              setCode: row.read<String>('set_code'),
              setName: row.readNullable<String>('set_name') ?? '',
              setTotal: row.readNullable<int>('set_total'),
              collectorNumber: row.read<String>('collector_number'),
              rarity: row.readNullable<String>('rarity') ?? '',
              typeLine: row.readNullable<String>('type_line') ?? '',
              colors: row.readNullable<String>('colors') ?? '',
              colorIdentity: row.readNullable<String>('color_identity') ?? '',
              priceUsd: _readOptionalPrice(row, 'price_usd'),
              priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
              priceEur: _readOptionalPrice(row, 'price_eur'),
              priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
              imageUri: _extractImageUrl(
                row.readNullable<String>('image_uris'),
                row.readNullable<String>('card_faces'),
              ),
            ),
          )
          .toList(growable: false);
    }

    final primary = await runSearchWithLanguages(languages);
    if (primary.isNotEmpty || languages == null || languages.isEmpty) {
      return primary;
    }
    final fallback = await runSearchWithLanguages(null);
    if (fallback.isNotEmpty) {
      return fallback;
    }
    final shouldTrySelfHeal =
        (offset == null || offset <= 0) && !_printedNameIndexSelfHealTried;
    if (!shouldTrySelfHeal) {
      return fallback;
    }
    _printedNameIndexSelfHealTried = true;
    await _rebuildPrintedNameSearchIndex(db);
    final healedPrimary = await runSearchWithLanguages(languages);
    if (healedPrimary.isNotEmpty) {
      return healedPrimary;
    }
    return runSearchWithLanguages(null);
  }

  Future<List<String>> fetchAvailableLanguages() async {
    final db = await open();
    final rows = await db
        .customSelect(
          'SELECT DISTINCT lang FROM cards WHERE lang IS NOT NULL ORDER BY lang ASC',
        )
        .get();
    return rows
        .map((row) => row.read<String>('lang'))
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<Map<String, int>> fetchCardCountsByLanguage() async {
    final db = await open();
    final rows = await db.customSelect('''
      SELECT
        LOWER(COALESCE(NULLIF(TRIM(lang), ''), 'en')) AS lang_code,
        COUNT(*) AS total
      FROM cards
      GROUP BY LOWER(COALESCE(NULLIF(TRIM(lang), ''), 'en'))
      ORDER BY total DESC, lang_code ASC
    ''').get();
    final result = <String, int>{};
    for (final row in rows) {
      final code = row.read<String>('lang_code').trim().toLowerCase();
      final total = row.read<int>('total');
      if (code.isEmpty || total <= 0) {
        continue;
      }
      result[code] = total;
    }
    return result;
  }

  Future<List<CardSearchResult>> fetchCardsForFilters({
    List<String> setCodes = const [],
    List<String> rarities = const [],
    List<String> types = const [],
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) async {
    final db = await open();
    final whereClauses = <String>[];
    final variables = <Variable>[];

    if (setCodes.isNotEmpty) {
      final normalized = setCodes
          .map((code) => code.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        whereClauses.add(
          'LOWER(cards.set_code) IN (${List.filled(normalized.length, '?').join(', ')})',
        );
        variables.addAll(normalized.map((code) => Variable.withString(code)));
      }
    }

    if (rarities.isNotEmpty) {
      final normalized = rarities
          .map((rarity) => rarity.trim().toLowerCase())
          .where((rarity) => rarity.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        whereClauses.add(
          'LOWER(cards.rarity) IN (${List.filled(normalized.length, '?').join(', ')})',
        );
        variables.addAll(
          normalized.map((rarity) => Variable.withString(rarity)),
        );
      }
    }

    if (types.isNotEmpty) {
      final normalized = types
          .map((type) => type.trim().toLowerCase())
          .where((type) => type.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        final typeClauses = normalized
            .map((_) => 'LOWER(cards.type_line) LIKE ?')
            .join(' OR ');
        whereClauses.add('($typeClauses)');
        variables.addAll(
          normalized.map((type) => Variable.withString('%$type%')),
        );
      }
    }

    if (languages.isNotEmpty) {
      final normalized = languages
          .map((lang) => lang.trim().toLowerCase())
          .where((lang) => lang.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        whereClauses.add(
          'LOWER(cards.lang) IN (${List.filled(normalized.length, '?').join(', ')})',
        );
        variables.addAll(normalized.map((lang) => Variable.withString(lang)));
      }
    }

    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';

    final sql = StringBuffer('''
      SELECT
        cards.id AS id,
        cards.name AS name,
        cards.set_code AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      $whereSql
      ORDER BY cards.name ASC
      LIMIT ?
      ''');
    variables.add(Variable.withInt(limit));
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db
        .customSelect(sql.toString(), variables: variables)
        .get();

    return rows
        .map(
          (row) => CardSearchResult(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            priceUsd: _readOptionalPrice(row, 'price_usd'),
            priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
            priceEur: _readOptionalPrice(row, 'price_eur'),
            priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<List<CardSearchResult>> fetchCardsForAdvancedFilters(
    CollectionFilter filter, {
    String? searchQuery,
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) async {
    final db = await open();
    final filterQuery = _buildFilterQuery(filter);
    final whereClauses = [...filterQuery.whereClauses];
    final variables = <Variable>[...filterQuery.variables];

    final query = searchQuery?.trim();
    if (query != null && query.isNotEmpty) {
      whereClauses.add(
        '(LOWER(cards.name) LIKE ? OR LOWER(cards.collector_number) LIKE ?)',
      );
      final like = '%${query.toLowerCase()}%';
      variables.add(Variable.withString(like));
      variables.add(Variable.withString(like));
    }

    if (languages.isNotEmpty) {
      final normalized = languages
          .map((lang) => lang.trim().toLowerCase())
          .where((lang) => lang.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        whereClauses.add(
          'LOWER(cards.lang) IN (${List.filled(normalized.length, '?').join(', ')})',
        );
        variables.addAll(normalized.map((lang) => Variable.withString(lang)));
      }
    }

    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final sql = StringBuffer('''
      SELECT
        cards.id AS id,
        cards.name AS name,
        cards.set_code AS set_code,
        cards.set_name AS set_name,
        cards.set_total AS set_total,
        cards.collector_number AS collector_number,
        cards.rarity AS rarity,
        cards.type_line AS type_line,
        cards.colors AS colors,
        cards.color_identity AS color_identity,
        cards.price_usd AS price_usd,
        cards.price_usd_foil AS price_usd_foil,
        cards.price_eur AS price_eur,
        cards.price_eur_foil AS price_eur_foil,
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      $whereSql
      ORDER BY cards.name ASC
      LIMIT ?
      ''');
    variables.add(Variable.withInt(limit));
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db
        .customSelect(sql.toString(), variables: variables)
        .get();

    return rows
        .map(
          (row) => CardSearchResult(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            setCode: row.read<String>('set_code'),
            setName: row.readNullable<String>('set_name') ?? '',
            setTotal: row.readNullable<int>('set_total'),
            collectorNumber: row.read<String>('collector_number'),
            rarity: row.readNullable<String>('rarity') ?? '',
            typeLine: row.readNullable<String>('type_line') ?? '',
            colors: row.readNullable<String>('colors') ?? '',
            colorIdentity: row.readNullable<String>('color_identity') ?? '',
            priceUsd: _readOptionalPrice(row, 'price_usd'),
            priceUsdFoil: _readOptionalPrice(row, 'price_usd_foil'),
            priceEur: _readOptionalPrice(row, 'price_eur'),
            priceEurFoil: _readOptionalPrice(row, 'price_eur_foil'),
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<Map<String, int>> fetchSetTotalsForCodes(List<String> setCodes) async {
    if (setCodes.isEmpty) {
      return {};
    }
    final db = await open();
    final placeholders = List.filled(setCodes.length, '?').join(', ');
    final rows = await db.customSelect('''
      SELECT set_code AS set_code, COUNT(*) AS total
      FROM cards
      WHERE set_code IN ($placeholders)
      GROUP BY set_code
      ''', variables: setCodes.map(Variable.withString).toList()).get();
    final result = <String, int>{};
    for (final row in rows) {
      final code = row.read<String>('set_code').trim().toLowerCase();
      final total = row.read<int>('total');
      if (code.isNotEmpty && total > 0) {
        result[code] = total;
      }
    }
    return result;
  }

  CardsCompanion _mapCardCompanion(Map<String, dynamic> card) {
    final colors = _extractColorList(card, 'colors');
    final colorIdentity = _extractColorList(card, 'color_identity');
    final prices = _extractPrices(card);
    return CardsCompanion.insert(
      id: card['id'] as String? ?? '',
      name: card['name'] as String? ?? '',
      oracleId: Value(card['oracle_id'] as String?),
      setCode: Value(card['set'] as String?),
      setName: Value(card['set_name'] as String?),
      setTotal: Value(_extractSetTotal(card)),
      collectorNumber: Value(card['collector_number'] as String?),
      rarity: Value(card['rarity'] as String?),
      typeLine: Value(card['type_line'] as String?),
      manaCost: Value(card['mana_cost'] as String?),
      oracleText: Value(_extractOracleText(card)),
      cmc: Value(_extractCmc(card)),
      colors: Value(_encodeColorList(colors)),
      colorIdentity: Value(_encodeColorList(colorIdentity)),
      artist: Value(_extractArtist(card)),
      power: Value(_extractStat(card, 'power')),
      toughness: Value(_extractStat(card, 'toughness')),
      loyalty: Value(_extractStat(card, 'loyalty')),
      lang: Value(card['lang'] as String?),
      releasedAt: Value(card['released_at'] as String?),
      imageUris: Value(_encodeJsonField(card['image_uris'])),
      cardFaces: Value(_encodeJsonField(card['card_faces'])),
      priceUsd: Value(prices?.usd),
      priceUsdFoil: Value(prices?.usdFoil),
      priceUsdEtched: Value(prices?.usdEtched),
      priceEur: Value(prices?.eur),
      priceEurFoil: Value(prices?.eurFoil),
      priceTix: Value(prices?.tix),
      pricesUpdatedAt: Value(
        prices?.hasAnyValue == true
            ? DateTime.now().millisecondsSinceEpoch
            : null,
      ),
      cardJson: Value(_encodeCardLegalitiesField(card)),
    );
  }

  CardsCompanion _mapPokemonCardCompanion(Map<String, dynamic> card) {
    final id = (card['id'] as String?)?.trim() ?? '';
    final name = (card['name'] as String?)?.trim() ?? '';
    final setCode = (card['set_code'] as String?)?.trim().toLowerCase() ?? '';
    final setName = (card['set_name'] as String?)?.trim() ?? '';
    final setTotal = (card['set_total'] as num?)?.toInt();
    final collectorNumber = (card['collector_number'] as String?)?.trim() ?? '';
    final rarity = (card['rarity'] as String?)?.trim() ?? '';
    final typeLine = (card['type_line'] as String?)?.trim() ?? '';
    final releasedAt = (card['released_at'] as String?)?.trim() ?? '';
    final manaValueRaw = card['mana_value'];
    double? manaValue;
    if (manaValueRaw is num) {
      manaValue = manaValueRaw.toDouble();
    } else if (manaValueRaw is String) {
      manaValue = double.tryParse(manaValueRaw.trim());
    }
    final imageSmall = (card['image_small'] as String?)?.trim() ?? '';
    final imageLarge = (card['image_large'] as String?)?.trim() ?? '';
    final artist = (card['artist'] as String?)?.trim() ?? '';
    final colors = _readPokemonColorCodes(card['colors']);
    final colorIdentity = _readPokemonColorCodes(card['color_identity']);
    final imageUris = <String, String>{};
    if (imageSmall.isNotEmpty) {
      imageUris['small'] = imageSmall;
    }
    if (imageLarge.isNotEmpty) {
      imageUris['normal'] = imageLarge;
    }
    final normalizedId = id.isEmpty ? '${setCode}_$collectorNumber' : id;
    final normalizedName = name.isEmpty ? normalizedId : name;
    return CardsCompanion(
      id: Value(normalizedId),
      oracleId: const Value(null),
      name: Value(normalizedName),
      setCode: Value(setCode),
      setName: Value(setName),
      setTotal: Value(setTotal),
      collectorNumber: Value(collectorNumber),
      rarity: Value(rarity),
      typeLine: Value(typeLine),
      manaCost: const Value(''),
      oracleText: const Value(''),
      cmc: Value(manaValue),
      colors: Value(_encodeColorList(colors)),
      colorIdentity: Value(_encodeColorList(colorIdentity)),
      artist: Value(artist),
      power: const Value(''),
      toughness: const Value(''),
      loyalty: const Value(''),
      lang: const Value('en'),
      releasedAt: Value(releasedAt),
      imageUris: Value(imageUris.isEmpty ? null : jsonEncode(imageUris)),
      cardFaces: const Value(null),
      cardJson: Value(jsonEncode(card)),
      priceUsd: const Value(null),
      priceUsdFoil: const Value(null),
      priceUsdEtched: const Value(null),
      priceEur: const Value(null),
      priceEurFoil: const Value(null),
      priceTix: const Value(null),
      pricesUpdatedAt: const Value(null),
    );
  }
}

String? _encodeJsonField(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  return jsonEncode(value);
}

String? _encodeCardLegalitiesField(Map<String, dynamic> card) {
  final payload = <String, dynamic>{};

  final printedName = (card['printed_name'] as String?)?.trim();
  if (printedName != null && printedName.isNotEmpty) {
    payload['printed_name'] = printedName;
  }

  final legalitiesRaw = card['legalities'];
  if (legalitiesRaw is Map) {
    final legalities = <String, String>{};
    for (final entry in legalitiesRaw.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      final value = entry.value?.toString().trim().toLowerCase() ?? '';
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      legalities[key] = value;
    }
    if (legalities.isNotEmpty) {
      payload['legalities'] = legalities;
    }
  }
  if (payload.isEmpty) {
    return null;
  }
  return jsonEncode(payload);
}

String? _readOptionalPrice(QueryRow row, String column) {
  final value = row.readNullable<String>(column)?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

CardPrices? _extractPrices(Map<String, dynamic> card) {
  final prices = card['prices'];
  if (prices is! Map<String, dynamic>) {
    return null;
  }
  return CardPrices(
    usd: _asPriceString(prices['usd']),
    usdFoil: _asPriceString(prices['usd_foil']),
    usdEtched: _asPriceString(prices['usd_etched']),
    eur: _asPriceString(prices['eur']),
    eurFoil: _asPriceString(prices['eur_foil']),
    tix: _asPriceString(prices['tix']),
  );
}

String? _asPriceString(dynamic value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

List<String> _extractColorList(Map<String, dynamic> card, String key) {
  final direct = (card[key] as List?)?.whereType<String>().toList() ?? [];
  if (direct.isNotEmpty) {
    return _normalizeColorList(direct);
  }
  final faces = card['card_faces'];
  if (faces is List) {
    final merged = <String>{};
    for (final face in faces) {
      if (face is Map<String, dynamic>) {
        final list = (face[key] as List?)?.whereType<String>().toList() ?? [];
        merged.addAll(list);
      }
    }
    if (merged.isNotEmpty) {
      return _normalizeColorList(merged.toList());
    }
  }
  return const [];
}

List<String> _normalizeColorList(List<String> colors) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final color in colors) {
    final value = color.trim().toUpperCase();
    if (value.isEmpty || seen.contains(value)) {
      continue;
    }
    seen.add(value);
    normalized.add(value);
  }
  return normalized;
}

String _normalizeSearchTextForNameLookup(String input) {
  final lowered = _foldLatinToAsciiLower(input.trim());
  if (lowered.isEmpty) {
    return '';
  }
  return lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String _buildPrintedNameFtsQuery(String input) {
  final lowered = _foldLatinToAsciiLower(input.trim());
  if (lowered.isEmpty) {
    return '';
  }
  final normalized = lowered
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) {
    return '';
  }
  final tokens = normalized
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) {
    return '';
  }
  return tokens.map((token) => '$token*').join(' ');
}

String _foldLatinToAsciiLower(String value) {
  if (value.isEmpty) {
    return '';
  }
  const replacements = <String, String>{
    '\u00E0': 'a',
    '\u00E1': 'a',
    '\u00E2': 'a',
    '\u00E3': 'a',
    '\u00E4': 'a',
    '\u00E5': 'a',
    '\u00E8': 'e',
    '\u00E9': 'e',
    '\u00EA': 'e',
    '\u00EB': 'e',
    '\u00EC': 'i',
    '\u00ED': 'i',
    '\u00EE': 'i',
    '\u00EF': 'i',
    '\u00F2': 'o',
    '\u00F3': 'o',
    '\u00F4': 'o',
    '\u00F5': 'o',
    '\u00F6': 'o',
    '\u00F9': 'u',
    '\u00FA': 'u',
    '\u00FB': 'u',
    '\u00FC': 'u',
    '\u00E7': 'c',
    '\u00F1': 'n',
    '\u00FD': 'y',
    '\u00FF': 'y',
  };
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

List<String> _readPokemonColorCodes(dynamic raw) {
  if (raw is List) {
    return _normalizeColorList(raw.whereType<String>().toList());
  }
  if (raw is String) {
    final parts = raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return _normalizeColorList(parts);
  }
  return const [];
}

List<String> _inferColorCodesFromTypeLine(String typeLine) {
  final value = typeLine.trim().toLowerCase();
  if (value.isEmpty) {
    return const [];
  }
  final tokens = value
      .split(RegExp(r'[^a-z]+'))
      .map((it) => it.trim())
      .where((it) => it.isNotEmpty)
      .toSet();
  final codes = <String>{};
  for (final token in tokens) {
    switch (token) {
      case 'grass':
        codes.add('G');
        break;
      case 'fire':
        codes.add('R');
        break;
      case 'fighting':
        codes.add('F');
        break;
      case 'dragon':
        codes.add('D');
        break;
      case 'lightning':
      case 'electric':
        codes.add('L');
        break;
      case 'water':
      case 'ice':
        codes.add('U');
        break;
      case 'psychic':
      case 'darkness':
      case 'dark':
      case 'ghost':
        codes.add('B');
        break;
      case 'fairy':
      case 'white':
        codes.add('W');
        break;
      case 'metal':
      case 'steel':
        codes.add('M');
        break;
      case 'colorless':
        codes.add('C');
        break;
    }
  }
  if (codes.isEmpty) {
    return const [];
  }
  return codes.toList(growable: false);
}

String? _encodeColorList(List<String> colors) {
  if (colors.isEmpty) {
    return null;
  }
  return colors.join(',');
}

double? _extractCmc(Map<String, dynamic> card) {
  final value = card['cmc'];
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

String? _extractArtist(Map<String, dynamic> card) {
  final artist = card['artist'];
  if (artist is String && artist.trim().isNotEmpty) {
    return artist.trim();
  }
  final faces = card['card_faces'];
  if (faces is List) {
    final merged = <String>{};
    for (final face in faces) {
      if (face is Map<String, dynamic>) {
        final faceArtist = face['artist'];
        if (faceArtist is String && faceArtist.trim().isNotEmpty) {
          merged.add(faceArtist.trim());
        }
      }
    }
    if (merged.isNotEmpty) {
      return merged.join(' // ');
    }
  }
  return null;
}

String? _extractStat(Map<String, dynamic> card, String key) {
  final value = card[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  final faces = card['card_faces'];
  if (faces is List) {
    for (final face in faces) {
      if (face is Map<String, dynamic>) {
        final faceValue = face[key];
        if (faceValue is String && faceValue.trim().isNotEmpty) {
          return faceValue.trim();
        }
      }
    }
  }
  return null;
}

String? _extractOracleText(Map<String, dynamic> card) {
  final value = card['oracle_text'];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  final faces = card['card_faces'];
  if (faces is List) {
    final texts = <String>[];
    for (final face in faces) {
      if (face is Map<String, dynamic>) {
        final faceText = face['oracle_text'];
        if (faceText is String && faceText.trim().isNotEmpty) {
          texts.add(faceText.trim());
        }
      }
    }
    if (texts.isNotEmpty) {
      return texts.join('\n\n');
    }
  }
  return null;
}

int? _extractSetTotal(Map<String, dynamic> card) {
  final direct = card['printed_total'] ?? card['set_total'];
  if (direct is num) {
    return direct.toInt();
  }
  if (direct is String) {
    return int.tryParse(direct.trim());
  }
  final setData = card['set'];
  if (setData is Map<String, dynamic>) {
    final nested = setData['printed_total'] ?? setData['set_total'];
    if (nested is num) {
      return nested.toInt();
    }
    if (nested is String) {
      return int.tryParse(nested.trim());
    }
  }
  return null;
}

String? _extractImageUrl(String? imageUrisJson, String? cardFacesJson) {
  if (imageUrisJson != null && imageUrisJson.isNotEmpty) {
    final data = _tryDecodeJson(imageUrisJson);
    if (data is Map<String, dynamic>) {
      return _pickImageUri(data);
    }
  }
  if (cardFacesJson != null && cardFacesJson.isNotEmpty) {
    final data = _tryDecodeJson(cardFacesJson);
    if (data is List) {
      for (final face in data) {
        if (face is Map<String, dynamic>) {
          final imageUris = face['image_uris'];
          if (imageUris is Map<String, dynamic>) {
            final picked = _pickImageUri(imageUris);
            if (picked != null) {
              return picked;
            }
          }
        }
      }
    }
  }
  return null;
}

dynamic _tryDecodeJson(String value) {
  try {
    return jsonDecode(value);
  } catch (_) {
    return null;
  }
}

String? _pickImageUri(Map<String, dynamic> imageUris) {
  const preferredKeys = ['large', 'normal', 'small', 'png', 'art_crop'];
  for (final key in preferredKeys) {
    final value = imageUris[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}
