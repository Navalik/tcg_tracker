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

  @override
  Set<Column> get primaryKey => {id};
}

class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type =>
      text().withDefault(const Constant('custom'))();
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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbFile = File(path.join(directory.path, 'scryfall.db'));
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
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

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
            await customStatement(
              'ALTER TABLE cards ADD COLUMN set_name TEXT',
            );
            await customStatement(
              'ALTER TABLE cards ADD COLUMN set_total INTEGER',
            );
            await customStatement(
              'ALTER TABLE cards ADD COLUMN cmc REAL',
            );
            await customStatement(
              'ALTER TABLE cards ADD COLUMN oracle_text TEXT',
            );
            await customStatement(
              'ALTER TABLE cards ADD COLUMN colors TEXT',
            );
            await customStatement(
              'ALTER TABLE cards ADD COLUMN color_identity TEXT',
            );
            await customStatement(
              'ALTER TABLE cards ADD COLUMN artist TEXT',
            );
            await customStatement(
              'ALTER TABLE cards ADD COLUMN power TEXT',
            );
            await customStatement(
              'ALTER TABLE cards ADD COLUMN toughness TEXT',
            );
            await customStatement(
              'ALTER TABLE cards ADD COLUMN loyalty TEXT',
            );
          }
        },
        beforeOpen: (details) async {},
      );

  Future<void> _createIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS cards_name_idx ON cards(name)');
    await customStatement('CREATE INDEX IF NOT EXISTS cards_set_idx ON cards(set_code)');
    await customStatement('CREATE INDEX IF NOT EXISTS cards_number_idx ON cards(collector_number)');
    await customStatement('CREATE INDEX IF NOT EXISTS cards_oracle_idx ON cards(oracle_id)');
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

class ScryfallDatabase {
  ScryfallDatabase._();

  static final ScryfallDatabase instance = ScryfallDatabase._();

  static const _prefsKeyRegenerated = 'db_regenerated_v1';
  static const _prefsKeyAvailableLanguages = 'available_languages';

  AppDatabase? _db;

  Future<AppDatabase> open() async {
    if (_db != null) {
      return _db!;
    }
    await _ensureRegenerated();
    _db = AppDatabase();
    return _db!;
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      return;
    }
    await db.close();
    _db = null;
  }

  Future<int?> fetchAllCardsCollectionId() async {
    final db = await open();
    final row = await (db.select(db.collections)
          ..where((tbl) => tbl.type.equals('all'))
          ..limit(1))
        .getSingleOrNull();
    if (row != null) {
      return row.id;
    }
    final fallback = await db.customSelect(
      'SELECT id AS id FROM collections WHERE lower(name) = ? LIMIT 1',
      variables: [Variable.withString('all cards')],
    ).getSingleOrNull();
    return fallback?.read<int>('id');
  }

  Future<void> hardReset() async {
    await close();
    final prefs = await SharedPreferences.getInstance();
    final directory = await getApplicationDocumentsDirectory();
    final dbFile = File(path.join(directory.path, 'scryfall.db'));
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    await prefs.remove(_prefsKeyAvailableLanguages);
    await prefs.setBool(_prefsKeyRegenerated, false);
  }

  Future<void> _ensureRegenerated() async {
    final prefs = await SharedPreferences.getInstance();
    final regenerated = prefs.getBool(_prefsKeyRegenerated) ?? false;
    if (regenerated) {
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final dbFile = File(path.join(directory.path, 'scryfall.db'));
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    await prefs.remove(_prefsKeyAvailableLanguages);
    await prefs.setBool(_prefsKeyRegenerated, true);
  }

  Future<List<CollectionInfo>> fetchCollections() async {
    final db = await open();
    final rows = await (db.select(db.collections)
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)]))
        .get();
    final allCardsId = _resolveAllCardsId(rows);
    final counts = await _fetchOwnedCountsByCollection(
      db,
      rows,
      allCardsId,
    );
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
    return null;
  }

  Future<Map<int, int>> _fetchOwnedCountsByCollection(
    AppDatabase db,
    List<Collection> rows,
    int? allCardsId,
  ) async {
    final counts = <int, int>{};
    if (allCardsId == null) {
      for (final row in rows) {
        counts[row.id] = 0;
      }
      return counts;
    }
    final ownedRow = await db.customSelect(
      'SELECT COALESCE(SUM(quantity), 0) AS total FROM collection_cards WHERE collection_id = ?',
      variables: [Variable.withInt(allCardsId)],
    ).getSingle();
    counts[allCardsId] = ownedRow.read<int>('total');
    for (final row in rows) {
      if (row.id == allCardsId) {
        continue;
      }
      final filter = row.filterJson == null
          ? null
          : CollectionFilter.fromJson(
              jsonDecode(row.filterJson!) as Map<String, dynamic>,
            );
      if (filter == null) {
        counts[row.id] = 0;
        continue;
      }
      counts[row.id] = await _countOwnedCardsForFilter(
        db,
        filter,
        allCardsId,
      );
    }
    return counts;
  }

  Future<int> addCollection(
    String name, {
    CollectionType type = CollectionType.custom,
    CollectionFilter? filter,
  }) async {
    final db = await open();
    return db.into(db.collections).insert(
          CollectionsCompanion.insert(
            name: name,
            type: Value(collectionTypeToDb(type)),
            filterJson:
                Value(filter == null ? null : jsonEncode(filter.toJson())),
          ),
        );
  }

  Future<void> renameCollection(int id, String name) async {
    final db = await open();
    await (db.update(db.collections)..where((tbl) => tbl.id.equals(id)))
        .write(CollectionsCompanion(name: Value(name)));
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

  Future<void> deleteCollection(int id) async {
    final db = await open();
    await db.transaction(() async {
      await (db.delete(db.collectionCards)
            ..where((tbl) => tbl.collectionId.equals(id)))
          .go();
      await (db.delete(db.collections)..where((tbl) => tbl.id.equals(id))).go();
    });
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
        variables.addAll(
          normalized.map((code) => Variable.withString(code)),
        );
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
        final typeClauses =
            normalized.map((_) => 'LOWER(cards.type_line) LIKE ?').join(' OR ');
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
          if (color == 'C') {
            continue;
          }
          colorClauses.add(
            r'(cards.colors LIKE ? OR cards.color_identity LIKE ?)',
          );
          final normalizedLike = '%$color%';
          variables.addAll([
            Variable.withString(normalizedLike),
            Variable.withString(normalizedLike),
          ]);
        }
        if (normalized.contains('C')) {
          colorClauses.add(
            '''
            (
              COALESCE(cards.colors, '') = ''
              AND COALESCE(cards.color_identity, '') = ''
            )
            ''',
          );
        }
        if (colorClauses.isNotEmpty) {
          whereClauses.add('(${colorClauses.join(' OR ')})');
        }
      }
    }

    final artist = filter.artist?.trim();
    if (artist != null && artist.isNotEmpty) {
      whereClauses.add(
        'LOWER(COALESCE(cards.artist, \'\')) LIKE ?',
      );
      final like = '%${artist.toLowerCase()}%';
      variables.add(Variable.withString(like));
    }

    if (filter.manaMin != null) {
      whereClauses.add(
        'COALESCE(cards.cmc, 0) >= ?',
      );
      variables.add(Variable.withReal(filter.manaMin!.toDouble()));
    }
    if (filter.manaMax != null) {
      whereClauses.add(
        'COALESCE(cards.cmc, 0) <= ?',
      );
      variables.add(Variable.withReal(filter.manaMax!.toDouble()));
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
    final whereSql = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final rows = await db.customSelect(
      '''
      SELECT COUNT(*) AS total
      FROM cards
      LEFT JOIN collection_cards
        ON collection_cards.card_id = cards.id
        AND collection_cards.collection_id = ?
      $whereSql
      ''',
      variables: [
        Variable.withInt(allCardsId),
        ...filterQuery.variables,
      ],
    ).getSingle();
    return rows.read<int>('total');
  }

  Future<List<CollectionCardEntry>> fetchCollectionCards(
    int collectionId, {
    int? limit,
    int? offset,
  }) async {
    final db = await open();
    var resolvedLimit = limit;
    if (offset != null && resolvedLimit == null) {
      resolvedLimit = -1;
    }
    final variables = <Variable>[Variable.withInt(collectionId)];
    final sql = StringBuffer(
      '''
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
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM collection_cards
      JOIN cards ON cards.id = collection_cards.card_id
      WHERE collection_cards.collection_id = ?
      ORDER BY cards.name ASC
      ''',
    );
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      variables.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db.customSelect(
      sql.toString(),
      variables: variables,
    ).get();

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
    final whereSql = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final sql = StringBuffer(
      '''
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
      '''
    );
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      variables.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db.customSelect(
      sql.toString(),
      variables: variables,
    ).get();

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
    final sql = StringBuffer(
      '''
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
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      LEFT JOIN collection_cards
        ON collection_cards.card_id = cards.id
        AND collection_cards.collection_id = ?
      WHERE cards.set_code = ?
      ORDER BY cards.name ASC
      '''
    );
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      variables.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db.customSelect(
      sql.toString(),
      variables: variables,
    ).get();

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
    final whereSql =
        whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final bound = <Variable>[
      Variable.withInt(allCardsId),
      ...variables,
    ];
    final boundWithPaging = <Variable>[...bound];
    final sql = StringBuffer(
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
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      LEFT JOIN collection_cards
        ON collection_cards.card_id = cards.id
        AND collection_cards.collection_id = ?
      $whereSql
      ORDER BY cards.name ASC
      ''',
    );
    if (resolvedLimit != null) {
      sql.write(' LIMIT ?');
      boundWithPaging.add(Variable.withInt(resolvedLimit));
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      boundWithPaging.add(Variable.withInt(offset));
    }
    final rows = await db.customSelect(
      sql.toString(),
      variables: boundWithPaging,
    ).get();

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
    final whereSql =
        whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final row = await db.customSelect(
      '''
      SELECT COUNT(*) AS total
      FROM cards
      LEFT JOIN collection_cards
        ON collection_cards.card_id = cards.id
        AND collection_cards.collection_id = ?
      $whereSql
      ''',
      variables: [
        Variable.withInt(allCardsId),
        ...variables,
      ],
    ).getSingle();
    return row.read<int>('total');
  }

  Future<int> countCardsForFilter(CollectionFilter filter) async {
    final db = await open();
    final filterQuery = _buildFilterQuery(filter);
    final whereSql = filterQuery.whereClauses.isEmpty
        ? ''
        : 'WHERE ${filterQuery.whereClauses.join(' AND ')}';
    final row = await db.customSelect(
      '''
      SELECT COUNT(*) AS total
      FROM cards
      $whereSql
      ''',
      variables: filterQuery.variables,
    ).getSingle();
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
    final whereSql =
        whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final row = await db.customSelect(
      '''
      SELECT COUNT(*) AS total
      FROM cards
      $whereSql
      ''',
      variables: variables,
    ).getSingle();
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
    final whereSql =
        whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final row = await db.customSelect(
      '''
      SELECT COUNT(*) AS total
      FROM collection_cards
      JOIN cards ON cards.id = collection_cards.card_id
      $whereSql
      ''',
      variables: variables,
    ).getSingle();
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
    final variables = <Variable>[...filterQuery.variables, Variable.withInt(limit)];
    final sql = StringBuffer(
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
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      $whereSql
      ORDER BY cards.name ASC
      LIMIT ?
      ''',
    );
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db.customSelect(
      sql.toString(),
      variables: variables,
    ).get();

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
    final where = <String>[
      "artist IS NOT NULL",
      "artist != ''",
    ];
    final variables = <Variable>[];
    final resolvedQuery = query?.trim().toLowerCase();
    if (resolvedQuery != null && resolvedQuery.isNotEmpty) {
      where.add('LOWER(artist) LIKE ?');
      variables.add(Variable.withString('%$resolvedQuery%'));
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.customSelect(
      '''
      SELECT DISTINCT artist
      FROM cards
      $whereSql
      ORDER BY artist ASC
      LIMIT ?
      ''',
      variables: [...variables, Variable.withInt(limit)],
    ).get();
    return rows
        .map((row) => row.read<String>('artist').trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }


  Future<void> addCardToCollection(int collectionId, String cardId) async {
    final db = await open();
    await db.transaction(() async {
      final existing = await (db.select(db.collectionCards)
            ..where((tbl) =>
                tbl.collectionId.equals(collectionId) &
                tbl.cardId.equals(cardId))
            ..limit(1))
          .getSingleOrNull();
      if (existing != null) {
        final updated = existing.quantity + 1;
        await (db.update(db.collectionCards)
              ..where((tbl) =>
                  tbl.collectionId.equals(collectionId) &
                  tbl.cardId.equals(cardId)))
            .write(CollectionCardsCompanion(quantity: Value(updated)));
      } else {
        await db.into(db.collectionCards).insert(
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
      final rows = await db.customSelect(
        '''
        SELECT card_id AS card_id, quantity AS quantity
        FROM collection_cards
        WHERE collection_id = ? AND card_id IN ($placeholders)
        ''',
        variables: [
          Variable.withInt(collectionId),
          ...uniqueIds.map(Variable.withString),
        ],
      ).get();
      final existing = <String, int>{};
      for (final row in rows) {
        existing[row.read<String>('card_id')] = row.read<int>('quantity');
      }
      for (final cardId in uniqueIds) {
        final current = existing[cardId];
        if (current != null) {
          await (db.update(db.collectionCards)
                ..where((tbl) =>
                    tbl.collectionId.equals(collectionId) &
                    tbl.cardId.equals(cardId)))
              .write(CollectionCardsCompanion(quantity: Value(current + 1)));
        } else {
          await db.into(db.collectionCards).insert(
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
    final rows = await db.customSelect(
      '''
      SELECT id AS card_id, set_code AS set_code
      FROM cards
      WHERE id IN ($placeholders)
      ''',
      variables: uniqueIds.map(Variable.withString).toList(),
    ).get();
    return {
      for (final row in rows)
        row.read<String>('card_id'): row.read<String>('set_code')
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
    final rows = await db.customSelect(
      '''
      SELECT card_id AS card_id, quantity AS quantity
      FROM collection_cards
      WHERE collection_id = ? AND card_id IN ($placeholders)
      ''',
      variables: [
        Variable.withInt(collectionId),
        ...uniqueIds.map(Variable.withString),
      ],
    ).get();
    return {
      for (final row in rows)
        row.read<String>('card_id'): row.read<int>('quantity')
    };
  }

  Future<CollectionCardEntry?> fetchCardEntryById(
    String cardId, {
    int? collectionId,
  }) async {
    final db = await open();
    final rows = await db.customSelect(
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
    ).get();

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
      imageUri: _extractImageUrl(
        row.readNullable<String>('image_uris'),
        row.readNullable<String>('card_faces'),
      ),
    );
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
    final rows = await db.customSelect(
      '''
      SELECT card_id AS card_id, collection_id AS collection_id
      FROM collection_cards
      WHERE card_id IN ($placeholders)
      ''',
      variables: uniqueIds.map(Variable.withString).toList(),
    ).get();
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
    await db.into(db.collectionCards).insert(
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
    await (db.update(db.collectionCards)
          ..where((tbl) =>
              tbl.collectionId.equals(collectionId) &
              tbl.cardId.equals(cardId)))
        .write(values);
  }

  Future<void> deleteCollectionCard(int collectionId, String cardId) async {
    final db = await open();
    await (db.delete(db.collectionCards)
          ..where((tbl) =>
              tbl.collectionId.equals(collectionId) &
              tbl.cardId.equals(cardId)))
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
        final row = await db.customSelect(
          'SELECT COUNT(*) AS count FROM cards',
        ).getSingle();
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
    final row = await db.customSelect(
      '''
      SELECT 1 AS missing
      FROM cards
      WHERE set_name IS NULL OR set_name = ''
      LIMIT 1
      ''',
    ).getSingleOrNull();
    return row != null;
  }

  Future<int> countOwnedCards() async {
    final db = await open();
    final allCardsId = await fetchAllCardsCollectionId();
    if (allCardsId == null) {
      return 0;
    }
    final row = await db.customSelect(
      'SELECT COALESCE(SUM(quantity), 0) AS total FROM collection_cards WHERE collection_id = ?',
      variables: [Variable.withInt(allCardsId)],
    ).getSingle();
    return row.read<int>('total');
  }

  Future<void> deleteAllCards(AppDatabase db) async {
    await db.customStatement('DELETE FROM cards');
  }

  Future<void> insertCardsBatch(
    AppDatabase db,
    List<Map<String, dynamic>> items,
  ) async {
    final companions = items.map(_mapCardCompanion).toList();
    await db.batch((batch) {
      batch.insertAll(
        db.cards,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> upsertCardFromScryfall(Map<String, dynamic> card) async {
    final db = await open();
    await db.into(db.cards).insert(
          _mapCardCompanion(card),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<List<SetInfo>> fetchAvailableSets() async {
    final db = await open();
    final rows = await db.customSelect(
      '''
      SELECT set_code AS set_code, set_name AS set_name
      FROM cards
      WHERE set_code IS NOT NULL AND set_code != ''
      GROUP BY set_code
      ORDER BY set_code ASC
      ''',
    ).get();

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
    final rows = await db.customSelect(
      '''
      SELECT set_code AS set_code, set_name AS set_name
      FROM cards
      WHERE set_code IN ($placeholders)
      GROUP BY set_code
      ''',
      variables: setCodes.map(Variable.withString).toList(),
    ).get();

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
    final matchQuery = _buildFtsQuery(query);
    if (matchQuery.isEmpty) {
      return [];
    }
    final db = await open();
    final whereArgs = <Variable>[Variable.withString(matchQuery)];
    final where = StringBuffer('cards_fts MATCH ?');
    if (languages != null && languages.isNotEmpty) {
      final placeholders = List.filled(languages.length, '?').join(', ');
      where.write(' AND cards.lang IN ($placeholders)');
      whereArgs.addAll(languages.map(Variable.withString));
    }
    whereArgs.add(Variable.withInt(limit));
    final sql = StringBuffer(
      '''
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
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards_fts
      JOIN cards ON cards_fts.rowid = cards.rowid
      WHERE ${where.toString()}
      ORDER BY cards.name ASC, cards.set_code ASC, cards.collector_number ASC
      LIMIT ?
      ''',
    );
    if (offset != null) {
      sql.write(' OFFSET ?');
      whereArgs.add(Variable.withInt(offset));
    }

    final rows = await db.customSelect(
      sql.toString(),
      variables: whereArgs,
    ).get();
    if (rows.isNotEmpty) {
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
              imageUri: _extractImageUrl(
                row.readNullable<String>('image_uris'),
                row.readNullable<String>('card_faces'),
              ),
            ),
          )
          .toList();
    }

    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }
    final likeArgs = <Variable>[Variable.withString('%$normalized%')];
    final likeWhere = StringBuffer('LOWER(cards.name) LIKE ?');
    if (languages != null && languages.isNotEmpty) {
      final placeholders = List.filled(languages.length, '?').join(', ');
      likeWhere.write(' AND LOWER(cards.lang) IN ($placeholders)');
      likeArgs.addAll(
        languages.map(
          (lang) => Variable.withString(lang.trim().toLowerCase()),
        ),
      );
    }
    likeArgs.add(Variable.withInt(limit));
    final likeSql = StringBuffer(
      '''
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
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      WHERE ${likeWhere.toString()}
      ORDER BY cards.name ASC, cards.set_code ASC, cards.collector_number ASC
      LIMIT ?
      ''',
    );
    if (offset != null) {
      likeSql.write(' OFFSET ?');
      likeArgs.add(Variable.withInt(offset));
    }
    final likeRows = await db.customSelect(
      likeSql.toString(),
      variables: likeArgs,
    ).get();
    return likeRows
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
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<List<String>> fetchAvailableLanguages() async {
    final db = await open();
    final rows = await db.customSelect(
      'SELECT DISTINCT lang FROM cards WHERE lang IS NOT NULL ORDER BY lang ASC',
    ).get();
    return rows
        .map((row) => row.read<String>('lang'))
        .where((value) => value.isNotEmpty)
        .toList();
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
            'LOWER(cards.set_code) IN (${List.filled(normalized.length, '?').join(', ')})');
        variables.addAll(
            normalized.map((code) => Variable.withString(code)));
      }
    }

    if (rarities.isNotEmpty) {
      final normalized = rarities
          .map((rarity) => rarity.trim().toLowerCase())
          .where((rarity) => rarity.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        whereClauses.add(
            'LOWER(cards.rarity) IN (${List.filled(normalized.length, '?').join(', ')})');
        variables.addAll(
            normalized.map((rarity) => Variable.withString(rarity)));
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
            'LOWER(cards.lang) IN (${List.filled(normalized.length, '?').join(', ')})');
        variables.addAll(
            normalized.map((lang) => Variable.withString(lang)));
      }
    }

    final whereSql =
        whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';

    final sql = StringBuffer(
      '''
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
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      $whereSql
      ORDER BY cards.name ASC
      LIMIT ?
      ''',
    );
    variables.add(Variable.withInt(limit));
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db.customSelect(
      sql.toString(),
      variables: variables,
    ).get();

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
        variables.addAll(
          normalized.map((lang) => Variable.withString(lang)),
        );
      }
    }

    final whereSql =
        whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';
    final sql = StringBuffer(
      '''
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
        cards.image_uris AS image_uris,
        cards.card_faces AS card_faces
      FROM cards
      $whereSql
      ORDER BY cards.name ASC
      LIMIT ?
      ''',
    );
    variables.add(Variable.withInt(limit));
    if (offset != null) {
      sql.write(' OFFSET ?');
      variables.add(Variable.withInt(offset));
    }
    final rows = await db.customSelect(
      sql.toString(),
      variables: variables,
    ).get();

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
            imageUri: _extractImageUrl(
              row.readNullable<String>('image_uris'),
              row.readNullable<String>('card_faces'),
            ),
          ),
        )
        .toList();
  }

  Future<Map<String, int>> fetchSetTotalsForCodes(
    List<String> setCodes,
  ) async {
    if (setCodes.isEmpty) {
      return {};
    }
    final db = await open();
    final placeholders = List.filled(setCodes.length, '?').join(', ');
    final rows = await db.customSelect(
      '''
      SELECT set_code AS set_code, COUNT(*) AS total
      FROM cards
      WHERE set_code IN ($placeholders)
      GROUP BY set_code
      ''',
      variables: setCodes.map(Variable.withString).toList(),
    ).get();
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
      cardJson: const Value(null),
    );
  }
}

String _normalizeSearchQuery(String input) {
  final trimmed = input.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return '';
  }
  final stripped = trimmed.replaceAll(RegExp(r"[,:;'\-]"), ' ');
  return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _buildFtsQuery(String input) {
  final normalized = _normalizeSearchQuery(input);
  if (normalized.isEmpty) {
    return '';
  }
  final parts = normalized.split(' ').where((part) => part.isNotEmpty);
  return parts.map((part) => '$part*').join(' ');
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
  const preferredKeys = [
    'large',
    'normal',
    'small',
    'png',
    'art_crop',
  ];
  for (final key in preferredKeys) {
    final value = imageUris[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}
