import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/domain_models.dart';

class CanonicalCatalogImportBatch {
  const CanonicalCatalogImportBatch({
    required this.cards,
    required this.sets,
    required this.printings,
    required this.cardLocalizations,
    required this.setLocalizations,
    required this.providerMappings,
    required this.priceSnapshots,
  });

  final List<CatalogCard> cards;
  final List<CatalogSet> sets;
  final List<CardPrintingRef> printings;
  final List<LocalizedCardData> cardLocalizations;
  final List<LocalizedSetData> setLocalizations;
  final List<ProviderMappingRecord> providerMappings;
  final List<PriceSnapshot> priceSnapshots;
}

class ProviderMappingRecord {
  const ProviderMappingRecord({
    required this.mapping,
    this.cardId,
    this.printingId,
    this.setId,
  });

  final ProviderMapping mapping;
  final String? cardId;
  final String? printingId;
  final String? setId;
}

class CanonicalCatalogStore {
  CanonicalCatalogStore._(this._database, {required this.databasePath});

  static const String defaultFileName = 'catalog_canonical.db';

  final Database _database;
  final String databasePath;

  static Future<CanonicalCatalogStore> openDefault() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, defaultFileName);
    return openAtPath(path);
  }

  static Future<CanonicalCatalogStore> openAtPath(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    final database = sqlite3.open(path);
    final store = CanonicalCatalogStore._(database, databasePath: path);
    store._initialize();
    return store;
  }

  static CanonicalCatalogStore openInMemory() {
    final database = sqlite3.openInMemory();
    final store = CanonicalCatalogStore._(database, databasePath: ':memory:');
    store._initialize();
    return store;
  }

  void dispose() {
    _database.dispose();
  }

  void replacePokemonCatalog(CanonicalCatalogImportBatch batch) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      _database.execute("DELETE FROM price_snapshots WHERE printing_id LIKE 'pokemon:%'");
      _database.execute("DELETE FROM provider_mappings WHERE game_id = 'pokemon'");
      _database.execute("DELETE FROM pokemon_printing_metadata WHERE printing_id LIKE 'pokemon:%'");
      _database.execute("DELETE FROM catalog_card_localizations WHERE card_id LIKE 'pokemon:%'");
      _database.execute("DELETE FROM catalog_set_localizations WHERE set_id LIKE 'pokemon:%'");
      _database.execute("DELETE FROM card_printings WHERE game_id = 'pokemon'");
      _database.execute("DELETE FROM catalog_cards WHERE game_id = 'pokemon'");
      _database.execute("DELETE FROM catalog_sets WHERE game_id = 'pokemon'");

      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final insertSet = _database.prepare(
        '''
        INSERT INTO catalog_sets (
          id, game_id, code, canonical_name, series_id, release_date, metadata_json, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
      );
      for (final set in batch.sets) {
        insertSet.execute([
          set.setId,
          set.gameId.value,
          set.code,
          set.canonicalName,
          set.seriesId,
          set.releaseDate?.toIso8601String(),
          jsonEncode(set.metadata),
          nowMs,
          nowMs,
        ]);
      }
      insertSet.dispose();

      final insertCard = _database.prepare(
        '''
        INSERT INTO catalog_cards (
          id, game_id, canonical_name, sort_name, default_language, metadata_json, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
      );
      for (final card in batch.cards) {
        insertCard.execute([
          card.cardId,
          card.gameId.value,
          card.canonicalName,
          card.sortName,
          card.defaultLocalizedData?.language.code,
          jsonEncode(_cardMetadata(card)),
          nowMs,
          nowMs,
        ]);
      }
      insertCard.dispose();

      final insertPrinting = _database.prepare(
        '''
        INSERT INTO card_printings (
          id, game_id, card_id, set_id, collector_number, rarity, release_date, image_uris_json, finish_keys_json, metadata_json, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
      );
      final insertPokemonMetadata = _database.prepare(
        '''
        INSERT INTO pokemon_printing_metadata (
          printing_id, category, hp, stage, evolves_from, regulation_mark, retreat_cost, illustrator, types_json, subtypes_json, weaknesses_json, resistances_json, attacks_json, abilities_json, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
      );
      for (final printing in batch.printings) {
        insertPrinting.execute([
          printing.printingId,
          printing.gameId.value,
          printing.cardId,
          printing.setId,
          printing.collectorNumber,
          printing.rarity,
          printing.releaseDate?.toIso8601String(),
          jsonEncode(printing.imageUris),
          jsonEncode(printing.finishKeys.toList(growable: false)),
          jsonEncode(printing.metadata),
          nowMs,
          nowMs,
        ]);
        final pokemon = batch.cards
            .firstWhere((card) => card.cardId == printing.cardId)
            .pokemon;
        if (pokemon != null) {
          insertPokemonMetadata.execute([
            printing.printingId,
            pokemon.category,
            pokemon.hp,
            pokemon.stage,
            pokemon.evolvesFrom,
            pokemon.regulationMark,
            pokemon.retreatCost,
            pokemon.illustrator,
            jsonEncode(pokemon.types),
            jsonEncode(pokemon.subtypes),
            jsonEncode(
              pokemon.weaknesses
                  .map((value) => <String, Object?>{'type': value.type, 'value': value.value})
                  .toList(growable: false),
            ),
            jsonEncode(
              pokemon.resistances
                  .map((value) => <String, Object?>{'type': value.type, 'value': value.value})
                  .toList(growable: false),
            ),
            jsonEncode(
              pokemon.attacks
                  .map(
                    (value) => <String, Object?>{
                      'name': value.name,
                      'text': value.text,
                      'damage': value.damage,
                      'energy_cost': value.energyCost,
                      'converted_energy_cost': value.convertedEnergyCost,
                    },
                  )
                  .toList(growable: false),
            ),
            jsonEncode(
              pokemon.abilities
                  .map(
                    (value) => <String, Object?>{
                      'name': value.name,
                      'type': value.type,
                      'text': value.text,
                    },
                  )
                  .toList(growable: false),
            ),
            nowMs,
          ]);
        }
      }
      insertPrinting.dispose();
      insertPokemonMetadata.dispose();

      final insertCardLocalization = _database.prepare(
        '''
        INSERT INTO catalog_card_localizations (
          card_id, language_code, name, subtype_line, rules_text, flavor_text, search_aliases_json, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
      );
      for (final localized in batch.cardLocalizations) {
        insertCardLocalization.execute([
          localized.cardId,
          localized.language.code,
          localized.name,
          localized.subtypeLine,
          localized.rulesText,
          localized.flavorText,
          jsonEncode(localized.searchAliases),
          nowMs,
        ]);
      }
      insertCardLocalization.dispose();

      final insertSetLocalization = _database.prepare(
        '''
        INSERT INTO catalog_set_localizations (
          set_id, language_code, name, series_name, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?)
        ''',
      );
      for (final localized in batch.setLocalizations) {
        insertSetLocalization.execute([
          localized.setId,
          localized.language.code,
          localized.name,
          localized.seriesName,
          nowMs,
        ]);
      }
      insertSetLocalization.dispose();

      final insertProviderMapping = _database.prepare(
        '''
        INSERT INTO provider_mappings (
          game_id, provider_id, object_type, provider_object_id, provider_object_version, card_id, printing_id, set_id, mapping_confidence, mapping_source, payload_hash, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
      );
      for (final record in batch.providerMappings) {
        insertProviderMapping.execute([
          TcgGameId.pokemon.value,
          record.mapping.providerId.value,
          record.mapping.objectType,
          record.mapping.providerObjectId,
          record.mapping.providerObjectVersion,
          record.cardId,
          record.printingId,
          record.setId,
          record.mapping.mappingConfidence,
          'tcgdex_import',
          null,
          nowMs,
          nowMs,
        ]);
      }
      insertProviderMapping.dispose();

      final insertPrice = _database.prepare(
        '''
        INSERT INTO price_snapshots (
          printing_id, source_id, currency_code, amount, finish_key, captured_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
      );
      for (final snapshot in batch.priceSnapshots) {
        insertPrice.execute([
          snapshot.printingId,
          snapshot.sourceId.value,
          snapshot.currencyCode,
          snapshot.amount,
          snapshot.finishKey,
          snapshot.capturedAt.toUtc().millisecondsSinceEpoch,
        ]);
      }
      insertPrice.dispose();

      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  int countTableRows(String tableName) {
    final result = _database.select('SELECT COUNT(*) AS c FROM $tableName');
    return (result.first['c'] as int?) ?? 0;
  }

  void _initialize() {
    _database.execute(
      '''
      CREATE TABLE IF NOT EXISTS catalog_cards (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        canonical_name TEXT NOT NULL,
        sort_name TEXT,
        default_language TEXT,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
      ''',
    );
    _database.execute(
      '''
      CREATE TABLE IF NOT EXISTS catalog_sets (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        code TEXT NOT NULL,
        canonical_name TEXT NOT NULL,
        series_id TEXT,
        release_date TEXT,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
      ''',
    );
    _database.execute(
      '''
      CREATE TABLE IF NOT EXISTS card_printings (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        card_id TEXT NOT NULL,
        set_id TEXT NOT NULL,
        collector_number TEXT NOT NULL,
        rarity TEXT,
        release_date TEXT,
        image_uris_json TEXT NOT NULL DEFAULT '{}',
        finish_keys_json TEXT NOT NULL DEFAULT '[]',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
      ''',
    );
    _database.execute(
      '''
      CREATE TABLE IF NOT EXISTS catalog_card_localizations (
        card_id TEXT NOT NULL,
        language_code TEXT NOT NULL,
        name TEXT NOT NULL,
        subtype_line TEXT,
        rules_text TEXT,
        flavor_text TEXT,
        search_aliases_json TEXT NOT NULL DEFAULT '[]',
        updated_at_ms INTEGER NOT NULL,
        PRIMARY KEY (card_id, language_code)
      )
      ''',
    );
    _database.execute(
      '''
      CREATE TABLE IF NOT EXISTS catalog_set_localizations (
        set_id TEXT NOT NULL,
        language_code TEXT NOT NULL,
        name TEXT NOT NULL,
        series_name TEXT,
        updated_at_ms INTEGER NOT NULL,
        PRIMARY KEY (set_id, language_code)
      )
      ''',
    );
    _database.execute(
      '''
      CREATE TABLE IF NOT EXISTS provider_mappings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id TEXT NOT NULL,
        provider_id TEXT NOT NULL,
        object_type TEXT NOT NULL,
        provider_object_id TEXT NOT NULL,
        provider_object_version TEXT,
        card_id TEXT,
        printing_id TEXT,
        set_id TEXT,
        mapping_confidence REAL NOT NULL DEFAULT 1.0,
        mapping_source TEXT,
        payload_hash TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
      ''',
    );
    _database.execute(
      '''
      CREATE TABLE IF NOT EXISTS pokemon_printing_metadata (
        printing_id TEXT PRIMARY KEY,
        category TEXT,
        hp INTEGER,
        stage TEXT,
        evolves_from TEXT,
        regulation_mark TEXT,
        retreat_cost INTEGER,
        illustrator TEXT,
        types_json TEXT NOT NULL DEFAULT '[]',
        subtypes_json TEXT NOT NULL DEFAULT '[]',
        weaknesses_json TEXT NOT NULL DEFAULT '[]',
        resistances_json TEXT NOT NULL DEFAULT '[]',
        attacks_json TEXT NOT NULL DEFAULT '[]',
        abilities_json TEXT NOT NULL DEFAULT '[]',
        updated_at_ms INTEGER NOT NULL
      )
      ''',
    );
    _database.execute(
      '''
      CREATE TABLE IF NOT EXISTS price_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        printing_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        amount REAL NOT NULL,
        finish_key TEXT,
        captured_at_ms INTEGER NOT NULL
      )
      ''',
    );
  }

  Map<String, Object?> _cardMetadata(CatalogCard card) {
    final metadata = <String, Object?>{}..addAll(card.metadata);
    final pokemon = card.pokemon;
    if (pokemon != null) {
      metadata['pokemon'] = <String, Object?>{
        'category': pokemon.category,
        'hp': pokemon.hp,
        'stage': pokemon.stage,
        'evolves_from': pokemon.evolvesFrom,
        'regulation_mark': pokemon.regulationMark,
        'retreat_cost': pokemon.retreatCost,
        'illustrator': pokemon.illustrator,
        'types': pokemon.types,
        'subtypes': pokemon.subtypes,
      };
    }
    return metadata;
  }
}
