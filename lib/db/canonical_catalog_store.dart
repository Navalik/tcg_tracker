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

Map<String, Object?> canonicalCatalogBatchToJson(
  CanonicalCatalogImportBatch batch,
) {
  return <String, Object?>{
    'cards': batch.cards.map(_catalogCardToJson).toList(growable: false),
    'sets': batch.sets.map(_catalogSetToJson).toList(growable: false),
    'printings': batch.printings
        .map(_cardPrintingRefToJson)
        .toList(growable: false),
    'card_localizations': batch.cardLocalizations
        .map(_localizedCardDataToJson)
        .toList(growable: false),
    'set_localizations': batch.setLocalizations
        .map(_localizedSetDataToJson)
        .toList(growable: false),
    'provider_mappings': batch.providerMappings
        .map(_providerMappingRecordToJson)
        .toList(growable: false),
    'price_snapshots': batch.priceSnapshots
        .map(_priceSnapshotToJson)
        .toList(growable: false),
  };
}

CanonicalCatalogImportBatch canonicalCatalogBatchFromJson(
  Map<String, dynamic> json,
) {
  List<T> parseList<T>(
    String key,
    T Function(Map<String, dynamic> value) parser,
  ) {
    final values = json[key];
    if (values is! List) {
      return <T>[];
    }
    return values
        .whereType<Map>()
        .map((value) => parser(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  return CanonicalCatalogImportBatch(
    cards: parseList('cards', _catalogCardFromJson),
    sets: parseList('sets', _catalogSetFromJson),
    printings: parseList('printings', _cardPrintingRefFromJson),
    cardLocalizations: parseList(
      'card_localizations',
      _localizedCardDataFromJson,
    ),
    setLocalizations: parseList('set_localizations', _localizedSetDataFromJson),
    providerMappings: parseList(
      'provider_mappings',
      _providerMappingRecordFromJson,
    ),
    priceSnapshots: parseList('price_snapshots', _priceSnapshotFromJson),
  );
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

Map<String, Object?> _catalogCardToJson(CatalogCard card) {
  return <String, Object?>{
    'card_id': card.cardId,
    'game_id': card.gameId.value,
    'canonical_name': card.canonicalName,
    'sort_name': card.sortName,
    'default_localized_data': card.defaultLocalizedData == null
        ? null
        : _localizedCardDataToJson(card.defaultLocalizedData!),
    'localized_data': card.localizedData
        .map(_localizedCardDataToJson)
        .toList(growable: false),
    'metadata': card.metadata,
    'pokemon': card.pokemon == null
        ? null
        : _pokemonCardMetadataToJson(card.pokemon!),
  };
}

CatalogCard _catalogCardFromJson(Map<String, dynamic> json) {
  final defaultLocalized = json['default_localized_data'];
  return CatalogCard(
    cardId: (json['card_id'] as String?) ?? '',
    gameId: _tcgGameIdFromValue(json['game_id'] as String?),
    canonicalName: (json['canonical_name'] as String?) ?? '',
    sortName: json['sort_name'] as String?,
    defaultLocalizedData: defaultLocalized is Map
        ? _localizedCardDataFromJson(
            Map<String, dynamic>.from(defaultLocalized),
          )
        : null,
    localizedData:
        (json['localized_data'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (value) =>
                  _localizedCardDataFromJson(Map<String, dynamic>.from(value)),
            )
            .toList(growable: false),
    metadata: _mapToJsonObjectMap(json['metadata']),
    pokemon: json['pokemon'] is Map
        ? _pokemonCardMetadataFromJson(
            Map<String, dynamic>.from(json['pokemon'] as Map),
          )
        : null,
  );
}

Map<String, Object?> _catalogSetToJson(CatalogSet set) {
  return <String, Object?>{
    'set_id': set.setId,
    'game_id': set.gameId.value,
    'code': set.code,
    'canonical_name': set.canonicalName,
    'series_id': set.seriesId,
    'release_date': set.releaseDate?.toIso8601String(),
    'default_localized_data': set.defaultLocalizedData == null
        ? null
        : _localizedSetDataToJson(set.defaultLocalizedData!),
    'localized_data': set.localizedData
        .map(_localizedSetDataToJson)
        .toList(growable: false),
    'metadata': set.metadata,
  };
}

CatalogSet _catalogSetFromJson(Map<String, dynamic> json) {
  final defaultLocalized = json['default_localized_data'];
  return CatalogSet(
    setId: (json['set_id'] as String?) ?? '',
    gameId: _tcgGameIdFromValue(json['game_id'] as String?),
    code: (json['code'] as String?) ?? '',
    canonicalName: (json['canonical_name'] as String?) ?? '',
    seriesId: json['series_id'] as String?,
    releaseDate: _dateTimeFromIsoString(json['release_date'] as String?),
    defaultLocalizedData: defaultLocalized is Map
        ? _localizedSetDataFromJson(Map<String, dynamic>.from(defaultLocalized))
        : null,
    localizedData:
        (json['localized_data'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (value) =>
                  _localizedSetDataFromJson(Map<String, dynamic>.from(value)),
            )
            .toList(growable: false),
    metadata: _mapToJsonObjectMap(json['metadata']),
  );
}

Map<String, Object?> _cardPrintingRefToJson(CardPrintingRef printing) {
  return <String, Object?>{
    'printing_id': printing.printingId,
    'card_id': printing.cardId,
    'set_id': printing.setId,
    'game_id': printing.gameId.value,
    'collector_number': printing.collectorNumber,
    'provider_mappings': printing.providerMappings
        .map(_providerMappingToJson)
        .toList(growable: false),
    'rarity': printing.rarity,
    'release_date': printing.releaseDate?.toIso8601String(),
    'image_uris': printing.imageUris,
    'finish_keys': printing.finishKeys.toList(growable: false),
    'metadata': printing.metadata,
  };
}

CardPrintingRef _cardPrintingRefFromJson(Map<String, dynamic> json) {
  return CardPrintingRef(
    printingId: (json['printing_id'] as String?) ?? '',
    cardId: (json['card_id'] as String?) ?? '',
    setId: (json['set_id'] as String?) ?? '',
    gameId: _tcgGameIdFromValue(json['game_id'] as String?),
    collectorNumber: (json['collector_number'] as String?) ?? '',
    providerMappings:
        (json['provider_mappings'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (value) =>
                  _providerMappingFromJson(Map<String, dynamic>.from(value)),
            )
            .toList(growable: false),
    rarity: json['rarity'] as String?,
    releaseDate: _dateTimeFromIsoString(json['release_date'] as String?),
    imageUris: _mapToStringMap(json['image_uris']),
    finishKeys: ((json['finish_keys'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toSet()),
    metadata: _mapToJsonObjectMap(json['metadata']),
  );
}

Map<String, Object?> _localizedCardDataToJson(LocalizedCardData localized) {
  return <String, Object?>{
    'card_id': localized.cardId,
    'language': localized.language.code,
    'name': localized.name,
    'subtype_line': localized.subtypeLine,
    'rules_text': localized.rulesText,
    'flavor_text': localized.flavorText,
    'search_aliases': localized.searchAliases,
  };
}

LocalizedCardData _localizedCardDataFromJson(Map<String, dynamic> json) {
  return LocalizedCardData(
    cardId: (json['card_id'] as String?) ?? '',
    language: _languageFromCode(json['language'] as String?),
    name: (json['name'] as String?) ?? '',
    subtypeLine: json['subtype_line'] as String?,
    rulesText: json['rules_text'] as String?,
    flavorText: json['flavor_text'] as String?,
    searchAliases:
        (json['search_aliases'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false),
  );
}

Map<String, Object?> _localizedSetDataToJson(LocalizedSetData localized) {
  return <String, Object?>{
    'set_id': localized.setId,
    'language': localized.language.code,
    'name': localized.name,
    'series_name': localized.seriesName,
  };
}

LocalizedSetData _localizedSetDataFromJson(Map<String, dynamic> json) {
  return LocalizedSetData(
    setId: (json['set_id'] as String?) ?? '',
    language: _languageFromCode(json['language'] as String?),
    name: (json['name'] as String?) ?? '',
    seriesName: json['series_name'] as String?,
  );
}

Map<String, Object?> _priceSnapshotToJson(PriceSnapshot snapshot) {
  return <String, Object?>{
    'printing_id': snapshot.printingId,
    'source_id': snapshot.sourceId.value,
    'currency_code': snapshot.currencyCode,
    'amount': snapshot.amount,
    'captured_at': snapshot.capturedAt.toUtc().toIso8601String(),
    'finish_key': snapshot.finishKey,
  };
}

PriceSnapshot _priceSnapshotFromJson(Map<String, dynamic> json) {
  return PriceSnapshot(
    printingId: (json['printing_id'] as String?) ?? '',
    sourceId: _priceSourceIdFromValue(json['source_id'] as String?),
    currencyCode: (json['currency_code'] as String?) ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    capturedAt:
        _dateTimeFromIsoString(json['captured_at'] as String?) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    finishKey: json['finish_key'] as String?,
  );
}

Map<String, Object?> _providerMappingToJson(ProviderMapping mapping) {
  return <String, Object?>{
    'provider_id': mapping.providerId.value,
    'object_type': mapping.objectType,
    'provider_object_id': mapping.providerObjectId,
    'provider_object_version': mapping.providerObjectVersion,
    'mapping_confidence': mapping.mappingConfidence,
  };
}

ProviderMapping _providerMappingFromJson(Map<String, dynamic> json) {
  return ProviderMapping(
    providerId: _catalogProviderIdFromValue(json['provider_id'] as String?),
    objectType: (json['object_type'] as String?) ?? '',
    providerObjectId: (json['provider_object_id'] as String?) ?? '',
    providerObjectVersion: json['provider_object_version'] as String?,
    mappingConfidence: (json['mapping_confidence'] as num?)?.toDouble() ?? 1.0,
  );
}

Map<String, Object?> _providerMappingRecordToJson(
  ProviderMappingRecord record,
) {
  return <String, Object?>{
    'mapping': _providerMappingToJson(record.mapping),
    'card_id': record.cardId,
    'printing_id': record.printingId,
    'set_id': record.setId,
  };
}

ProviderMappingRecord _providerMappingRecordFromJson(
  Map<String, dynamic> json,
) {
  final mappingJson = json['mapping'];
  return ProviderMappingRecord(
    mapping: mappingJson is Map
        ? _providerMappingFromJson(Map<String, dynamic>.from(mappingJson))
        : const ProviderMapping(
            providerId: CatalogProviderId.unknown,
            objectType: '',
            providerObjectId: '',
          ),
    cardId: json['card_id'] as String?,
    printingId: json['printing_id'] as String?,
    setId: json['set_id'] as String?,
  );
}

Map<String, Object?> _pokemonCardMetadataToJson(PokemonCardMetadata pokemon) {
  return <String, Object?>{
    'category': pokemon.category,
    'hp': pokemon.hp,
    'types': pokemon.types,
    'subtypes': pokemon.subtypes,
    'stage': pokemon.stage,
    'evolves_from': pokemon.evolvesFrom,
    'regulation_mark': pokemon.regulationMark,
    'retreat_cost': pokemon.retreatCost,
    'weaknesses': pokemon.weaknesses
        .map(_pokemonTypedValueToJson)
        .toList(growable: false),
    'resistances': pokemon.resistances
        .map(_pokemonTypedValueToJson)
        .toList(growable: false),
    'attacks': pokemon.attacks
        .map(_pokemonAttackToJson)
        .toList(growable: false),
    'abilities': pokemon.abilities
        .map(_pokemonAbilityToJson)
        .toList(growable: false),
    'illustrator': pokemon.illustrator,
  };
}

PokemonCardMetadata _pokemonCardMetadataFromJson(Map<String, dynamic> json) {
  return PokemonCardMetadata(
    category: json['category'] as String?,
    hp: (json['hp'] as num?)?.toInt(),
    types: (json['types'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    subtypes: (json['subtypes'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    stage: json['stage'] as String?,
    evolvesFrom: json['evolves_from'] as String?,
    regulationMark: json['regulation_mark'] as String?,
    retreatCost: (json['retreat_cost'] as num?)?.toInt(),
    weaknesses: (json['weaknesses'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (value) => _pokemonWeaknessFromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false),
    resistances: (json['resistances'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (value) =>
              _pokemonResistanceFromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false),
    attacks: (json['attacks'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (value) => _pokemonAttackFromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false),
    abilities: (json['abilities'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (value) => _pokemonAbilityFromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false),
    illustrator: json['illustrator'] as String?,
  );
}

Map<String, Object?> _pokemonTypedValueToJson(dynamic value) {
  if (value is PokemonWeakness) {
    return <String, Object?>{'type': value.type, 'value': value.value};
  }
  if (value is PokemonResistance) {
    return <String, Object?>{'type': value.type, 'value': value.value};
  }
  return const <String, Object?>{};
}

PokemonWeakness _pokemonWeaknessFromJson(Map<String, dynamic> json) {
  return PokemonWeakness(
    type: (json['type'] as String?) ?? '',
    value: json['value'] as String?,
  );
}

PokemonResistance _pokemonResistanceFromJson(Map<String, dynamic> json) {
  return PokemonResistance(
    type: (json['type'] as String?) ?? '',
    value: json['value'] as String?,
  );
}

Map<String, Object?> _pokemonAttackToJson(PokemonAttack attack) {
  return <String, Object?>{
    'name': attack.name,
    'text': attack.text,
    'damage': attack.damage,
    'energy_cost': attack.energyCost,
    'converted_energy_cost': attack.convertedEnergyCost,
  };
}

PokemonAttack _pokemonAttackFromJson(Map<String, dynamic> json) {
  return PokemonAttack(
    name: (json['name'] as String?) ?? '',
    text: json['text'] as String?,
    damage: json['damage'] as String?,
    energyCost: (json['energy_cost'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    convertedEnergyCost: (json['converted_energy_cost'] as num?)?.toInt(),
  );
}

Map<String, Object?> _pokemonAbilityToJson(PokemonAbility ability) {
  return <String, Object?>{
    'name': ability.name,
    'type': ability.type,
    'text': ability.text,
  };
}

PokemonAbility _pokemonAbilityFromJson(Map<String, dynamic> json) {
  return PokemonAbility(
    name: (json['name'] as String?) ?? '',
    type: (json['type'] as String?) ?? '',
    text: json['text'] as String?,
  );
}

TcgGameId _tcgGameIdFromValue(String? value) {
  for (final item in TcgGameId.values) {
    if (item.value == value) {
      return item;
    }
  }
  return TcgGameId.pokemon;
}

TcgCardLanguage _languageFromCode(String? code) {
  for (final item in TcgCardLanguage.values) {
    if (item.code == code) {
      return item;
    }
  }
  return TcgCardLanguage.en;
}

PriceSourceId _priceSourceIdFromValue(String? value) {
  for (final item in PriceSourceId.values) {
    if (item.value == value) {
      return item;
    }
  }
  return PriceSourceId.unknown;
}

CatalogProviderId _catalogProviderIdFromValue(String? value) {
  for (final item in CatalogProviderId.values) {
    if (item.value == value) {
      return item;
    }
  }
  return CatalogProviderId.unknown;
}

DateTime? _dateTimeFromIsoString(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return DateTime.tryParse(normalized)?.toUtc();
}

Map<String, Object?> _mapToJsonObjectMap(dynamic value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return value.map((key, item) => MapEntry(key.toString(), item as Object?));
}

Map<String, String> _mapToStringMap(dynamic value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  return value.map(
    (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
  );
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
      _database.execute(
        "DELETE FROM price_snapshots WHERE printing_id LIKE 'pokemon:%'",
      );
      _database.execute(
        "DELETE FROM provider_mappings WHERE game_id = 'pokemon'",
      );
      _database.execute(
        "DELETE FROM pokemon_printing_metadata WHERE printing_id LIKE 'pokemon:%'",
      );
      _database.execute(
        "DELETE FROM catalog_card_localizations WHERE card_id LIKE 'pokemon:%'",
      );
      _database.execute(
        "DELETE FROM catalog_set_localizations WHERE set_id LIKE 'pokemon:%'",
      );
      _database.execute("DELETE FROM card_printings WHERE game_id = 'pokemon'");
      _database.execute("DELETE FROM catalog_cards WHERE game_id = 'pokemon'");
      _database.execute("DELETE FROM catalog_sets WHERE game_id = 'pokemon'");

      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final insertSet = _database.prepare('''
        INSERT INTO catalog_sets (
          id, game_id, code, canonical_name, series_id, release_date, metadata_json, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''');
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

      final insertCard = _database.prepare('''
        INSERT INTO catalog_cards (
          id, game_id, canonical_name, sort_name, default_language, metadata_json, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''');
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

      final insertPrinting = _database.prepare('''
        INSERT INTO card_printings (
          id, game_id, card_id, set_id, collector_number, rarity, release_date, image_uris_json, finish_keys_json, metadata_json, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''');
      final insertPokemonMetadata = _database.prepare('''
        INSERT INTO pokemon_printing_metadata (
          printing_id, category, hp, stage, evolves_from, regulation_mark, retreat_cost, illustrator, types_json, subtypes_json, weaknesses_json, resistances_json, attacks_json, abilities_json, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''');
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
                  .map(
                    (value) => <String, Object?>{
                      'type': value.type,
                      'value': value.value,
                    },
                  )
                  .toList(growable: false),
            ),
            jsonEncode(
              pokemon.resistances
                  .map(
                    (value) => <String, Object?>{
                      'type': value.type,
                      'value': value.value,
                    },
                  )
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

      final insertCardLocalization = _database.prepare('''
        INSERT INTO catalog_card_localizations (
          card_id, language_code, name, subtype_line, rules_text, flavor_text, search_aliases_json, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''');
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

      final insertSetLocalization = _database.prepare('''
        INSERT INTO catalog_set_localizations (
          set_id, language_code, name, series_name, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?)
        ''');
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

      final insertProviderMapping = _database.prepare('''
        INSERT INTO provider_mappings (
          game_id, provider_id, object_type, provider_object_id, provider_object_version, card_id, printing_id, set_id, mapping_confidence, mapping_source, payload_hash, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''');
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

      final insertPrice = _database.prepare('''
        INSERT INTO price_snapshots (
          printing_id, source_id, currency_code, amount, finish_key, captured_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''');
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
    _database.execute('''
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
      ''');
    _database.execute('''
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
      ''');
    _database.execute('''
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
      ''');
    _database.execute('''
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
      ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS catalog_set_localizations (
        set_id TEXT NOT NULL,
        language_code TEXT NOT NULL,
        name TEXT NOT NULL,
        series_name TEXT,
        updated_at_ms INTEGER NOT NULL,
        PRIMARY KEY (set_id, language_code)
      )
      ''');
    _database.execute('''
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
      ''');
    _database.execute('''
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
      ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS price_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        printing_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        amount REAL NOT NULL,
        finish_key TEXT,
        captured_at_ms INTEGER NOT NULL
      )
      ''');
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
