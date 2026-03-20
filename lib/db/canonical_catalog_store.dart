import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/domain_models.dart';
import '../models.dart';

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

class CanonicalPrintingViewData {
  const CanonicalPrintingViewData({
    required this.printingId,
    required this.name,
    required this.setCode,
    required this.setName,
    required this.collectorNumber,
    required this.rarity,
    required this.typeLine,
    required this.manaCost,
    required this.oracleText,
    required this.manaValue,
    required this.lang,
    required this.artist,
    required this.power,
    required this.toughness,
    required this.loyalty,
    required this.colors,
    required this.colorIdentity,
    required this.releasedAt,
    required this.setTotal,
    required this.imageUri,
  });

  final String printingId;
  final String name;
  final String setCode;
  final String setName;
  final String collectorNumber;
  final String rarity;
  final String typeLine;
  final String manaCost;
  final String oracleText;
  final double? manaValue;
  final String lang;
  final String artist;
  final String power;
  final String toughness;
  final String loyalty;
  final String colors;
  final String colorIdentity;
  final String releasedAt;
  final int? setTotal;
  final String? imageUri;
}

class CanonicalCollectionCardData {
  const CanonicalCollectionCardData({
    required this.cardId,
    required this.printingId,
    required this.name,
    required this.setCode,
    required this.setName,
    required this.setTotal,
    required this.collectorNumber,
    required this.rarity,
    required this.typeLine,
    required this.manaCost,
    required this.oracleText,
    required this.manaValue,
    required this.lang,
    required this.artist,
    required this.power,
    required this.toughness,
    required this.loyalty,
    required this.colors,
    required this.colorIdentity,
    required this.releasedAt,
    required this.quantity,
    required this.foil,
    required this.altArt,
    this.priceUsd,
    this.priceUsdFoil,
    this.priceUsdEtched,
    this.priceEur,
    this.priceEurFoil,
    this.priceTix,
    this.pricesUpdatedAt,
    this.imageUri,
  });

  final String cardId;
  final String printingId;
  final String name;
  final String setCode;
  final String setName;
  final int? setTotal;
  final String collectorNumber;
  final String rarity;
  final String typeLine;
  final String manaCost;
  final String oracleText;
  final double? manaValue;
  final String lang;
  final String artist;
  final String power;
  final String toughness;
  final String loyalty;
  final String colors;
  final String colorIdentity;
  final String releasedAt;
  final int quantity;
  final bool foil;
  final bool altArt;
  final String? priceUsd;
  final String? priceUsdFoil;
  final String? priceUsdEtched;
  final String? priceEur;
  final String? priceEurFoil;
  final String? priceTix;
  final int? pricesUpdatedAt;
  final String? imageUri;
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
    'language_code': printing.languageCode,
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
    languageCode: _languageFromCode(json['language_code'] as String?),
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
    'language': localized.languageCode,
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
    languageCode: _languageFromCode(json['language'] as String?),
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
    'language': localized.languageCode,
    'name': localized.name,
    'series_name': localized.seriesName,
  };
}

LocalizedSetData _localizedSetDataFromJson(Map<String, dynamic> json) {
  return LocalizedSetData(
    setId: (json['set_id'] as String?) ?? '',
    languageCode: _languageFromCode(json['language'] as String?),
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
    hp: _jsonIntValue(json['hp']),
    types: (json['types'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    subtypes: _jsonStringList(json['subtypes']),
    stage: json['stage'] as String?,
    evolvesFrom:
        (json['evolves_from'] as String?) ?? (json['evolvesFrom'] as String?),
    regulationMark:
        (json['regulation_mark'] as String?) ??
        (json['regulationMark'] as String?),
    retreatCost: _jsonIntValue(json['retreat_cost'] ?? json['retreat']),
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
    text: (json['text'] as String?) ?? (json['effect'] as String?),
    damage: _jsonStringValue(json['damage']),
    energyCost: _jsonStringList(json['energy_cost'] ?? json['cost']),
    convertedEnergyCost: _jsonIntValue(
      json['converted_energy_cost'] ?? json['convertedEnergyCost'],
    ),
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
    text: (json['text'] as String?) ?? (json['effect'] as String?),
  );
}

int? _jsonIntValue(Object? value) {
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

String? _jsonStringValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return '$value';
}

List<String> _jsonStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map(_jsonStringValue)
      .whereType<String>()
      .toList(growable: false);
}

TcgGameId _tcgGameIdFromValue(String? value) {
  for (final item in TcgGameId.values) {
    if (item.value == value) {
      return item;
    }
  }
  return TcgGameId.pokemon;
}

String _languageFromCode(String? code) {
  final normalized = code?.trim().toLowerCase() ?? '';
  if (normalized.isEmpty) {
    return TcgLanguageCodes.en;
  }
  return normalized;
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
  static String? debugDefaultPathOverride;

  final Database _database;
  final String databasePath;

  static Future<CanonicalCatalogStore> openDefault() async {
    final path = debugDefaultPathOverride == null
        ? p.join(
            (await getApplicationDocumentsDirectory()).path,
            defaultFileName,
          )
        : debugDefaultPathOverride!;
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

  Map<String, dynamic>? fetchPokemonMetadataForLegacyPrinting(String legacyId) {
    final normalizedId = legacyId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }
    final rows = _database.select(
      '''
      SELECT
        pm.category AS category,
        pm.hp AS hp,
        pm.stage AS stage,
        pm.evolves_from AS evolves_from,
        pm.regulation_mark AS regulation_mark,
        pm.retreat_cost AS retreat_cost,
        pm.illustrator AS illustrator,
        pm.types_json AS types_json,
        pm.subtypes_json AS subtypes_json,
        pm.weaknesses_json AS weaknesses_json,
        pm.resistances_json AS resistances_json,
        pm.attacks_json AS attacks_json,
        pm.abilities_json AS abilities_json
      FROM provider_mappings legacy
      INNER JOIN pokemon_printing_metadata pm ON pm.printing_id = legacy.printing_id
      WHERE legacy.provider_id = ?
        AND legacy.object_type = 'legacy_printing'
        AND legacy.provider_object_id = ?
      LIMIT 1
      ''',
      <Object?>[CatalogProviderId.pokemonTcgApi.value, normalizedId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return <String, dynamic>{
      'category': row['category'],
      'hp': row['hp'],
      'stage': row['stage'],
      'evolves_from': row['evolves_from'],
      'regulation_mark': row['regulation_mark'],
      'retreat_cost': row['retreat_cost'],
      'illustrator': row['illustrator'],
      'types': _parseJsonStringList((row['types_json'] as String?) ?? '[]'),
      'subtypes': _parseJsonStringList(
        (row['subtypes_json'] as String?) ?? '[]',
      ),
      'weaknesses': _parseJsonObjectList(
        (row['weaknesses_json'] as String?) ?? '[]',
      ),
      'resistances': _parseJsonObjectList(
        (row['resistances_json'] as String?) ?? '[]',
      ),
      'attacks': _parseJsonObjectList((row['attacks_json'] as String?) ?? '[]'),
      'abilities': _parseJsonObjectList(
        (row['abilities_json'] as String?) ?? '[]',
      ),
    };
  }

  void dispose() {
    _database.dispose();
  }

  void replaceCatalogForGame(
    TcgGameId gameId,
    CanonicalCatalogImportBatch batch,
  ) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      _database.execute(
        'DELETE FROM price_snapshots WHERE printing_id LIKE ?',
        <Object?>['${gameId.value}:%'],
      );
      _database.execute(
        'DELETE FROM provider_mappings WHERE game_id = ?',
        <Object?>[gameId.value],
      );
      if (gameId == TcgGameId.pokemon) {
        _database.execute('DELETE FROM pokemon_printing_metadata');
      }
      _database.execute(
        'DELETE FROM catalog_card_localizations WHERE card_id LIKE ?',
        <Object?>['${gameId.value}:%'],
      );
      _database.execute(
        'DELETE FROM catalog_set_localizations WHERE set_id LIKE ?',
        <Object?>['${gameId.value}:%'],
      );
      _database.execute(
        'DELETE FROM card_printings WHERE game_id = ?',
        <Object?>[gameId.value],
      );
      _database.execute(
        'DELETE FROM catalog_cards WHERE game_id = ?',
        <Object?>[gameId.value],
      );
      _database.execute('DELETE FROM catalog_sets WHERE game_id = ?', <Object?>[
        gameId.value,
      ]);

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
          card.defaultLocalizedData?.languageCode,
          jsonEncode(_cardMetadata(card)),
          nowMs,
          nowMs,
        ]);
      }
      insertCard.dispose();

      final insertPrinting = _database.prepare('''
        INSERT INTO card_printings (
          id, game_id, card_id, set_id, collector_number, language_code, rarity, release_date, image_uris_json, finish_keys_json, metadata_json, created_at_ms, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''');
      final insertPokemonMetadata = gameId == TcgGameId.pokemon
          ? _database.prepare('''
              INSERT OR REPLACE INTO pokemon_printing_metadata (
                printing_id, category, hp, stage, evolves_from, regulation_mark, retreat_cost, illustrator, types_json, subtypes_json, weaknesses_json, resistances_json, attacks_json, abilities_json, updated_at_ms
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ''')
          : null;
      for (final printing in batch.printings) {
        insertPrinting.execute([
          printing.printingId,
          printing.gameId.value,
          printing.cardId,
          printing.setId,
          printing.collectorNumber,
          printing.languageCode,
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
        if (pokemon != null && insertPokemonMetadata != null) {
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
      insertPokemonMetadata?.dispose();

      final insertCardLocalization = _database.prepare('''
        INSERT OR REPLACE INTO catalog_card_localizations (
          card_id, language_code, name, subtype_line, rules_text, flavor_text, search_aliases_json, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''');
      for (final localized in batch.cardLocalizations) {
        insertCardLocalization.execute([
          localized.cardId,
          localized.languageCode,
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
        INSERT OR REPLACE INTO catalog_set_localizations (
          set_id, language_code, name, series_name, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?)
        ''');
      for (final localized in batch.setLocalizations) {
        insertSetLocalization.execute([
          localized.setId,
          localized.languageCode,
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
          gameId.value,
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

  void replacePokemonCatalog(CanonicalCatalogImportBatch batch) {
    replaceCatalogForGame(TcgGameId.pokemon, batch);
  }

  int countTableRows(String tableName) {
    final result = _database.select('SELECT COUNT(*) AS c FROM $tableName');
    return (result.first['c'] as int?) ?? 0;
  }

  int countPrintingsForGame(TcgGameId gameId) {
    final rows = _database.select(
      '''
      SELECT COUNT(*) AS c
      FROM card_printings
      WHERE game_id = ?
      ''',
      <Object?>[gameId.value],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  bool hasCatalogForGame(TcgGameId gameId) {
    return countPrintingsForGame(gameId) > 0;
  }

  List<CanonicalCollectionCardData> fetchCollectionCardsForGame({
    required TcgGameId gameId,
    required CollectionFilter filter,
    required int ownedCollectionId,
    String? searchQuery,
    bool ownedOnly = false,
    bool missingOnly = false,
    List<String> preferredLanguages = const <String>['en'],
    int limit = 200,
    int? offset,
  }) {
    if (gameId == TcgGameId.pokemon) {
      return _fetchPokemonCollectionCards(
        filter: filter,
        ownedCollectionId: ownedCollectionId,
        searchQuery: searchQuery,
        ownedOnly: ownedOnly,
        missingOnly: missingOnly,
        preferredLanguages: preferredLanguages,
        limit: limit,
        offset: offset,
      );
    }
    return _fetchGenericCollectionCards(
      gameId: gameId,
      filter: filter,
      ownedCollectionId: ownedCollectionId,
      searchQuery: searchQuery,
      ownedOnly: ownedOnly,
      missingOnly: missingOnly,
      preferredLanguages: preferredLanguages,
      limit: limit,
      offset: offset,
    );
  }

  int countCollectionCardsForGame({
    required TcgGameId gameId,
    required CollectionFilter filter,
    required int ownedCollectionId,
    String? searchQuery,
    bool ownedOnly = false,
    bool missingOnly = false,
    List<String> preferredLanguages = const <String>['en'],
  }) {
    if (gameId == TcgGameId.pokemon) {
      return _countPokemonCollectionCards(
        filter: filter,
        ownedCollectionId: ownedCollectionId,
        searchQuery: searchQuery,
        ownedOnly: ownedOnly,
        missingOnly: missingOnly,
        preferredLanguages: preferredLanguages,
      );
    }
    return _countGenericCollectionCards(
      gameId: gameId,
      filter: filter,
      ownedCollectionId: ownedCollectionId,
      searchQuery: searchQuery,
      ownedOnly: ownedOnly,
      missingOnly: missingOnly,
      preferredLanguages: preferredLanguages,
    );
  }

  Map<String, CanonicalPrintingViewData> fetchPrintingViews(
    List<String> printingIds, {
    List<String> preferredLanguages = const <String>['en'],
  }) {
    final normalizedIds = printingIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return const <String, CanonicalPrintingViewData>{};
    }
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final cardNameParams = <Object?>[];
    final preferredCardNameSql = _localizedCardNameSql(
      normalizedLanguages,
      cardNameParams,
    );
    final setNameParams = <Object?>[];
    final preferredSetNameSql = _localizedSetNameSql(
      normalizedLanguages,
      setNameParams,
    );
    final subtypeParams = <Object?>[];
    final preferredSubtypeSql = _localizedCardSubtypeSql(
      normalizedLanguages,
      subtypeParams,
    );
    final localizedRulesSql = _localizedCardRulesTextSql(normalizedLanguages);
    final rows = _database.select(
      '''
      SELECT
        cp.id AS printing_id,
        COALESCE($preferredCardNameSql, cc.canonical_name) AS display_name,
        cs.code AS set_code,
        COALESCE($preferredSetNameSql, cs.canonical_name) AS set_name,
        cp.collector_number AS collector_number,
        COALESCE(cp.rarity, '') AS rarity,
        COALESCE(
          $preferredSubtypeSql,
          json_extract(cp.metadata_json, '\$.type_line'),
          json_extract(cc.metadata_json, '\$.type_line'),
          TRIM(
            COALESCE(pm.category, '') ||
            CASE
              WHEN pm.subtypes_json IS NOT NULL AND pm.subtypes_json <> '[]'
                THEN ' ' || REPLACE(REPLACE(REPLACE(pm.subtypes_json, '[', '('), ']', ')'), '"', '')
              ELSE ''
            END
          ),
          ''
        ) AS type_line,
        COALESCE(
          json_extract(cp.metadata_json, '\$.mana_cost'),
          json_extract(cc.metadata_json, '\$.mana_cost'),
          ''
        ) AS mana_cost,
        COALESCE(
          $localizedRulesSql,
          json_extract(cp.metadata_json, '\$.oracle_text'),
          json_extract(cc.metadata_json, '\$.oracle_text'),
          ''
        ) AS oracle_text,
        CAST(
          COALESCE(
            json_extract(cp.metadata_json, '\$.cmc'),
            json_extract(cc.metadata_json, '\$.cmc')
          ) AS REAL
        ) AS cmc,
        COALESCE(
          (SELECT ccl.language_code
             FROM catalog_card_localizations ccl
            WHERE ccl.card_id = cc.id
              AND ccl.language_code IN (${_inClause(normalizedLanguages.length)})
            ORDER BY CASE ccl.language_code ${_preferredLanguageCaseWhen(normalizedLanguages)} ELSE ${normalizedLanguages.length} END
            LIMIT 1),
          NULLIF(TRIM(cp.language_code), ''),
          cc.default_language,
          'en'
        ) AS lang,
        COALESCE(
          json_extract(cp.metadata_json, '\$.artist'),
          json_extract(cc.metadata_json, '\$.artist'),
          COALESCE(pm.illustrator, ''),
          ''
        ) AS artist,
        COALESCE(
          json_extract(cp.metadata_json, '\$.power'),
          json_extract(cc.metadata_json, '\$.power'),
          ''
        ) AS power,
        COALESCE(
          json_extract(cp.metadata_json, '\$.toughness'),
          json_extract(cc.metadata_json, '\$.toughness'),
          ''
        ) AS toughness,
        COALESCE(
          json_extract(cp.metadata_json, '\$.loyalty'),
          json_extract(cc.metadata_json, '\$.loyalty'),
          ''
        ) AS loyalty,
        COALESCE(
          json_extract(cp.metadata_json, '\$.colors_json'),
          json_extract(cc.metadata_json, '\$.colors_json'),
          pm.types_json,
          '[]'
        ) AS colors_json,
        COALESCE(
          json_extract(cp.metadata_json, '\$.color_identity_json'),
          json_extract(cc.metadata_json, '\$.color_identity_json'),
          pm.types_json,
          '[]'
        ) AS color_identity_json,
        COALESCE(cp.release_date, cs.release_date, '') AS released_at,
        COALESCE(
          json_extract(cs.metadata_json, '\$.official_total'),
          json_extract(cs.metadata_json, '\$.total')
        ) AS set_total,
        COALESCE(
          json_extract(cp.image_uris_json, '\$.high_res'),
          json_extract(cp.image_uris_json, '\$.normal'),
          json_extract(cp.image_uris_json, '\$.default'),
          json_extract(cp.image_uris_json, '\$.small')
        ) AS image_uri
      FROM card_printings cp
      INNER JOIN catalog_cards cc ON cc.id = cp.card_id
      INNER JOIN catalog_sets cs ON cs.id = cp.set_id
      LEFT JOIN pokemon_printing_metadata pm ON pm.printing_id = cp.id
      WHERE cp.id IN (${_inClause(normalizedIds.length)})
      ''',
      <Object?>[
        ...cardNameParams,
        ...setNameParams,
        ...subtypeParams,
        ...normalizedLanguages,
        ...normalizedIds,
      ],
    );
    return <String, CanonicalPrintingViewData>{
      for (final row in rows)
        ((row['printing_id'] as String? ?? '')
            .trim()): CanonicalPrintingViewData(
          printingId: (row['printing_id'] as String? ?? '').trim(),
          name: (row['display_name'] as String? ?? '').trim(),
          setCode: ((row['set_code'] as String? ?? '').trim().toLowerCase()),
          setName: (row['set_name'] as String? ?? '').trim(),
          collectorNumber: (row['collector_number'] as String? ?? '').trim(),
          rarity: (row['rarity'] as String? ?? '').trim(),
          typeLine: (row['type_line'] as String? ?? '').trim(),
          manaCost: (row['mana_cost'] as String? ?? '').trim(),
          oracleText: (row['oracle_text'] as String? ?? '').trim(),
          manaValue: (row['cmc'] as num?)?.toDouble(),
          lang: (row['lang'] as String? ?? '').trim(),
          artist: (row['artist'] as String? ?? '').trim(),
          power: (row['power'] as String? ?? '').trim(),
          toughness: (row['toughness'] as String? ?? '').trim(),
          loyalty: (row['loyalty'] as String? ?? '').trim(),
          colors: _jsonColorCodesToLegacyString(row['colors_json']),
          colorIdentity: _jsonColorCodesToLegacyString(
            row['color_identity_json'],
          ),
          releasedAt: (row['released_at'] as String? ?? '').trim(),
          setTotal: (row['set_total'] as num?)?.toInt(),
          imageUri: (row['image_uri'] as String?)?.trim(),
        ),
    };
  }

  String? resolvePrintingIdForLegacyCardId(String legacyId) {
    final normalizedId = legacyId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }
    final directRows = _database.select(
      '''
      SELECT id AS printing_id
      FROM card_printings
      WHERE id = ?
      LIMIT 1
      ''',
      <Object?>[normalizedId],
    );
    if (directRows.isNotEmpty) {
      final direct = (directRows.first['printing_id'] as String?)?.trim();
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }
    }
    final mappedRows = _database.select(
      '''
      SELECT printing_id AS printing_id
      FROM provider_mappings
      WHERE object_type = 'legacy_printing'
        AND provider_object_id = ?
        AND TRIM(COALESCE(printing_id, '')) <> ''
      LIMIT 1
      ''',
      <Object?>[normalizedId],
    );
    if (mappedRows.isEmpty) {
      return null;
    }
    final printingId = (mappedRows.first['printing_id'] as String?)?.trim();
    if (printingId == null || printingId.isEmpty) {
      return null;
    }
    return printingId;
  }

  List<SetInfo> fetchSetsForGame({
    required TcgGameId gameId,
    List<String> preferredLanguages = const <String>['en'],
    int limit = 500,
  }) {
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final setNameParams = <Object?>[];
    final preferredSetNameSql = _localizedSetNameSql(
      normalizedLanguages,
      setNameParams,
    );
    final rows = _database.select(
      '''
      SELECT
        cs.code AS code,
        COALESCE($preferredSetNameSql, cs.canonical_name) AS name
      FROM catalog_sets cs
      WHERE cs.game_id = ?
      ORDER BY LOWER(COALESCE($preferredSetNameSql, cs.canonical_name)), LOWER(cs.code)
      LIMIT ?
      ''',
      <Object?>[...setNameParams, gameId.value, ...setNameParams, limit],
    );
    return rows
        .map(
          (row) => SetInfo(
            code: (row['code'] as String? ?? '').trim().toLowerCase(),
            name: (row['name'] as String? ?? '').trim(),
          ),
        )
        .where((entry) => entry.code.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, String> fetchSetNamesForCodesForGame(
    TcgGameId gameId,
    List<String> setCodes, {
    List<String> preferredLanguages = const <String>['en'],
  }) {
    final normalizedCodes = setCodes
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedCodes.isEmpty) {
      return const <String, String>{};
    }
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final setNameParams = <Object?>[];
    final preferredSetNameSql = _localizedSetNameSql(
      normalizedLanguages,
      setNameParams,
    );
    final rows = _database.select(
      '''
      SELECT
        cs.code AS code,
        COALESCE($preferredSetNameSql, cs.canonical_name) AS name
      FROM catalog_sets cs
      WHERE cs.game_id = ?
        AND LOWER(cs.code) IN (${_inClause(normalizedCodes.length)})
      ''',
      <Object?>[...setNameParams, gameId.value, ...normalizedCodes],
    );
    return <String, String>{
      for (final row in rows)
        ((row['code'] as String? ?? '').trim().toLowerCase()):
            ((row['name'] as String? ?? '').trim()),
    };
  }

  List<SetInfo> fetchPokemonSets({
    List<String> preferredLanguages = const <String>['en'],
    int limit = 500,
  }) => fetchSetsForGame(
    gameId: TcgGameId.pokemon,
    preferredLanguages: preferredLanguages,
    limit: limit,
  );

  Map<String, String> fetchPokemonSetNamesForCodes(
    List<String> setCodes, {
    List<String> preferredLanguages = const <String>['en'],
  }) => fetchSetNamesForCodesForGame(
    TcgGameId.pokemon,
    setCodes,
    preferredLanguages: preferredLanguages,
  );

  List<CardSearchResult> searchCardsForGame({
    required TcgGameId gameId,
    required CollectionFilter filter,
    String? searchQuery,
    List<String> preferredLanguages = const <String>['en'],
    int limit = 200,
    int? offset,
  }) {
    if (gameId == TcgGameId.pokemon) {
      return searchPokemonCards(
        filter: filter,
        searchQuery: searchQuery,
        preferredLanguages: preferredLanguages,
        limit: limit,
        offset: offset,
      );
    }
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final whereClauses = <String>[];
    final params = <Object?>[];
    _appendGenericFilterQuery(
      filter: filter,
      searchQuery: searchQuery,
      preferredLanguages: normalizedLanguages,
      whereClauses: whereClauses,
      params: params,
    );

    final cardNameParams = <Object?>[];
    final preferredCardNameSql = _localizedCardNameSql(
      normalizedLanguages,
      cardNameParams,
    );
    final setNameParams = <Object?>[];
    final preferredSetNameSql = _localizedSetNameSql(
      normalizedLanguages,
      setNameParams,
    );
    final subtypeParams = <Object?>[];
    final preferredSubtypeSql = _localizedCardSubtypeSql(
      normalizedLanguages,
      subtypeParams,
    );
    final rows = _database.select(
      '''
      SELECT
        COALESCE(legacy.provider_object_id, cp.id) AS legacy_id,
        cp.id AS printing_id,
        COALESCE($preferredCardNameSql, cc.canonical_name) AS display_name,
        cs.code AS set_code,
        COALESCE($preferredSetNameSql, cs.canonical_name) AS set_name,
        cp.collector_number AS collector_number,
        cp.rarity AS rarity,
        COALESCE(
          $preferredSubtypeSql,
          json_extract(cp.metadata_json, '\$.type_line'),
          json_extract(cc.metadata_json, '\$.type_line'),
          ''
        ) AS type_line,
        COALESCE(
          json_extract(cp.metadata_json, '\$.colors_json'),
          json_extract(cc.metadata_json, '\$.colors_json'),
          '[]'
        ) AS colors_json,
        COALESCE(
          json_extract(cp.metadata_json, '\$.color_identity_json'),
          json_extract(cc.metadata_json, '\$.color_identity_json'),
          '[]'
        ) AS color_identity_json,
        COALESCE(
          json_extract(cs.metadata_json, '\$.official_total'),
          json_extract(cs.metadata_json, '\$.total')
        ) AS set_total,
        COALESCE(
          json_extract(cp.image_uris_json, '\$.high_res'),
          json_extract(cp.image_uris_json, '\$.normal'),
          json_extract(cp.image_uris_json, '\$.default')
        ) AS image_uri
      FROM card_printings cp
      INNER JOIN catalog_cards cc ON cc.id = cp.card_id
      INNER JOIN catalog_sets cs ON cs.id = cp.set_id
      LEFT JOIN provider_mappings legacy
        ON legacy.printing_id = cp.id
       AND legacy.object_type = 'legacy_printing'
      WHERE cp.game_id = ?
        ${whereClauses.isEmpty ? '' : 'AND ${whereClauses.join(' AND ')}'}
      ORDER BY LOWER(display_name), LOWER(cs.code), LOWER(cp.collector_number)
      LIMIT ? OFFSET ?
      ''',
      <Object?>[
        ...cardNameParams,
        ...setNameParams,
        ...subtypeParams,
        gameId.value,
        ...params,
        limit,
        offset ?? 0,
      ],
    );
    return rows
        .map(_genericSearchRowToResult)
        .where((entry) => entry.id.isNotEmpty)
        .toList(growable: false);
  }

  int countCardsForGame({
    required TcgGameId gameId,
    required CollectionFilter filter,
    String? searchQuery,
    List<String> preferredLanguages = const <String>['en'],
  }) {
    if (gameId == TcgGameId.pokemon) {
      return countPokemonCards(
        filter: filter,
        searchQuery: searchQuery,
        preferredLanguages: preferredLanguages,
      );
    }
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final whereClauses = <String>[];
    final params = <Object?>[];
    _appendGenericFilterQuery(
      filter: filter,
      searchQuery: searchQuery,
      preferredLanguages: normalizedLanguages,
      whereClauses: whereClauses,
      params: params,
    );
    final rows = _database.select(
      '''
      SELECT COUNT(*) AS c
      FROM card_printings cp
      INNER JOIN catalog_cards cc ON cc.id = cp.card_id
      INNER JOIN catalog_sets cs ON cs.id = cp.set_id
      WHERE cp.game_id = ?
        ${whereClauses.isEmpty ? '' : 'AND ${whereClauses.join(' AND ')}'}
      ''',
      <Object?>[gameId.value, ...params],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  List<String> fetchPokemonDistinctSubtypes({int limit = 80}) {
    final rows = _database.select(
      '''
      SELECT DISTINCT TRIM(value) AS subtype
      FROM pokemon_printing_metadata pm, json_each(pm.subtypes_json)
      WHERE TRIM(COALESCE(value, '')) <> ''
      ORDER BY LOWER(TRIM(value))
      LIMIT ?
      ''',
      <Object?>[limit],
    );
    return rows
        .map((row) => (row['subtype'] as String? ?? '').trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<CardSearchResult> searchPokemonCards({
    required CollectionFilter filter,
    String? searchQuery,
    List<String> preferredLanguages = const <String>['en'],
    int limit = 200,
    int? offset,
  }) {
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final whereClauses = <String>[];
    final params = <Object?>[];
    _appendPokemonFilterQuery(
      filter: filter,
      searchQuery: searchQuery,
      preferredLanguages: normalizedLanguages,
      whereClauses: whereClauses,
      params: params,
    );

    final cardNameParams = <Object?>[];
    final preferredCardNameSql = _localizedCardNameSql(
      normalizedLanguages,
      cardNameParams,
    );
    final setNameParams = <Object?>[];
    final preferredSetNameSql = _localizedSetNameSql(
      normalizedLanguages,
      setNameParams,
    );
    final subtypeParams = <Object?>[];
    final preferredSubtypeSql = _localizedCardSubtypeSql(
      normalizedLanguages,
      subtypeParams,
    );

    final rows = _database.select(
      '''
      SELECT
        COALESCE(legacy.provider_object_id, cp.id) AS legacy_id,
        cp.id AS printing_id,
        COALESCE($preferredCardNameSql, cc.canonical_name) AS display_name,
        cs.code AS set_code,
        COALESCE($preferredSetNameSql, cs.canonical_name) AS set_name,
        cp.collector_number AS collector_number,
        cp.rarity AS rarity,
        COALESCE(
          $preferredSubtypeSql,
          TRIM(
            COALESCE(pm.category, '') ||
            CASE
              WHEN pm.subtypes_json <> '[]'
                THEN ' ' || REPLACE(REPLACE(REPLACE(pm.subtypes_json, '[', '('), ']', ')'), '"', '')
              ELSE ''
            END
          )
        ) AS type_line,
        pm.types_json AS types_json,
        COALESCE(
          json_extract(cs.metadata_json, '\$.official_total'),
          json_extract(cs.metadata_json, '\$.total')
        ) AS set_total,
        COALESCE(
          json_extract(cp.image_uris_json, '\$.high_res'),
          json_extract(cp.image_uris_json, '\$.normal'),
          json_extract(cp.image_uris_json, '\$.default'),
          json_extract(cp.image_uris_json, '\$.small')
        ) AS image_uri
      FROM card_printings cp
      INNER JOIN catalog_cards cc ON cc.id = cp.card_id
      INNER JOIN catalog_sets cs ON cs.id = cp.set_id
      LEFT JOIN pokemon_printing_metadata pm ON pm.printing_id = cp.id
      LEFT JOIN provider_mappings legacy
        ON legacy.printing_id = cp.id
       AND legacy.provider_id = ?
       AND legacy.object_type = 'legacy_printing'
      WHERE cp.game_id = ?
        ${whereClauses.isEmpty ? '' : 'AND ${whereClauses.join(' AND ')}'}
      ORDER BY LOWER(display_name), LOWER(cs.code), LOWER(cp.collector_number)
      LIMIT ? OFFSET ?
      ''',
      <Object?>[
        ...cardNameParams,
        ...setNameParams,
        ...subtypeParams,
        CatalogProviderId.pokemonTcgApi.value,
        TcgGameId.pokemon.value,
        ...params,
        limit,
        offset ?? 0,
      ],
    );

    return rows
        .map(_pokemonSearchRowToResult)
        .where((entry) => entry.id.isNotEmpty)
        .toList(growable: false);
  }

  int countPokemonCards({
    required CollectionFilter filter,
    String? searchQuery,
    List<String> preferredLanguages = const <String>['en'],
  }) {
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final whereClauses = <String>[];
    final params = <Object?>[];
    _appendPokemonFilterQuery(
      filter: filter,
      searchQuery: searchQuery,
      preferredLanguages: normalizedLanguages,
      whereClauses: whereClauses,
      params: params,
    );
    final rows = _database.select(
      '''
      SELECT COUNT(*) AS c
      FROM card_printings cp
      INNER JOIN catalog_cards cc ON cc.id = cp.card_id
      INNER JOIN catalog_sets cs ON cs.id = cp.set_id
      LEFT JOIN pokemon_printing_metadata pm ON pm.printing_id = cp.id
      WHERE cp.game_id = ?
        ${whereClauses.isEmpty ? '' : 'AND ${whereClauses.join(' AND ')}'}
      ''',
      <Object?>[TcgGameId.pokemon.value, ...params],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  List<CanonicalCollectionCardData> _fetchGenericCollectionCards({
    required TcgGameId gameId,
    required CollectionFilter filter,
    required int ownedCollectionId,
    required String? searchQuery,
    required bool ownedOnly,
    required bool missingOnly,
    required List<String> preferredLanguages,
    required int limit,
    required int? offset,
  }) {
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final whereClauses = <String>[];
    final params = <Object?>[];
    _appendGenericFilterQuery(
      filter: filter,
      searchQuery: searchQuery,
      preferredLanguages: normalizedLanguages,
      whereClauses: whereClauses,
      params: params,
    );
    if (ownedOnly) {
      whereClauses.add('COALESCE(owned.quantity, 0) > 0');
    } else if (missingOnly) {
      whereClauses.add('COALESCE(owned.quantity, 0) = 0');
    }

    final cardNameParams = <Object?>[];
    final preferredCardNameSql = _localizedCardNameSql(
      normalizedLanguages,
      cardNameParams,
    );
    final setNameParams = <Object?>[];
    final preferredSetNameSql = _localizedSetNameSql(
      normalizedLanguages,
      setNameParams,
    );
    final subtypeParams = <Object?>[];
    final preferredSubtypeSql = _localizedCardSubtypeSql(
      normalizedLanguages,
      subtypeParams,
    );
    final localizedRulesSql = _localizedCardRulesTextSql(normalizedLanguages);

    final rows = _database.select(
      '''
      SELECT
        COALESCE(legacy.provider_object_id, cp.id) AS card_id,
        cp.id AS printing_id,
        COALESCE(owned.quantity, 0) AS quantity,
        COALESCE(owned.foil, 0) AS foil,
        COALESCE(owned.alt_art, 0) AS alt_art,
        COALESCE($preferredCardNameSql, cc.canonical_name) AS display_name,
        cs.code AS set_code,
        COALESCE($preferredSetNameSql, cs.canonical_name) AS set_name,
        COALESCE(
          json_extract(cs.metadata_json, '\$.official_total'),
          json_extract(cs.metadata_json, '\$.total')
        ) AS set_total,
        cp.collector_number AS collector_number,
        COALESCE(cp.rarity, '') AS rarity,
        COALESCE(
          $preferredSubtypeSql,
          json_extract(cp.metadata_json, '\$.type_line'),
          json_extract(cc.metadata_json, '\$.type_line'),
          ''
        ) AS type_line,
        COALESCE(
          json_extract(cp.metadata_json, '\$.mana_cost'),
          json_extract(cc.metadata_json, '\$.mana_cost'),
          ''
        ) AS mana_cost,
        COALESCE(
          $localizedRulesSql,
          json_extract(cp.metadata_json, '\$.oracle_text'),
          json_extract(cc.metadata_json, '\$.oracle_text'),
          ''
        ) AS oracle_text,
        CAST(
          COALESCE(
            json_extract(cp.metadata_json, '\$.cmc'),
            json_extract(cc.metadata_json, '\$.cmc')
          ) AS REAL
        ) AS cmc,
        COALESCE(
          (
            SELECT ccl.language_code
            FROM catalog_card_localizations ccl
            WHERE ccl.card_id = cc.id
              AND ccl.language_code IN (${_inClause(normalizedLanguages.length)})
            ORDER BY CASE ccl.language_code ${_preferredLanguageCaseWhen(normalizedLanguages)} ELSE ${normalizedLanguages.length} END
            LIMIT 1
          ),
          LOWER(
            COALESCE(
              NULLIF(TRIM(cp.language_code), ''),
              cc.default_language,
              'en'
            )
          )
        ) AS lang,
        COALESCE(
          json_extract(cp.metadata_json, '\$.artist'),
          json_extract(cc.metadata_json, '\$.artist'),
          ''
        ) AS artist,
        COALESCE(
          json_extract(cp.metadata_json, '\$.power'),
          json_extract(cc.metadata_json, '\$.power'),
          ''
        ) AS power,
        COALESCE(
          json_extract(cp.metadata_json, '\$.toughness'),
          json_extract(cc.metadata_json, '\$.toughness'),
          ''
        ) AS toughness,
        COALESCE(
          json_extract(cp.metadata_json, '\$.loyalty'),
          json_extract(cc.metadata_json, '\$.loyalty'),
          ''
        ) AS loyalty,
        COALESCE(
          json_extract(cp.metadata_json, '\$.colors_json'),
          json_extract(cc.metadata_json, '\$.colors_json'),
          '[]'
        ) AS colors_json,
        COALESCE(
          json_extract(cp.metadata_json, '\$.color_identity_json'),
          json_extract(cc.metadata_json, '\$.color_identity_json'),
          '[]'
        ) AS color_identity_json,
        COALESCE(cp.release_date, cs.release_date, '') AS released_at,
        NULL AS price_usd,
        NULL AS price_usd_foil,
        NULL AS price_usd_etched,
        NULL AS price_eur,
        NULL AS price_eur_foil,
        NULL AS price_tix,
        NULL AS prices_updated_at,
        COALESCE(
          json_extract(cp.image_uris_json, '\$.high_res'),
          json_extract(cp.image_uris_json, '\$.normal'),
          json_extract(cp.image_uris_json, '\$.default'),
          json_extract(cp.image_uris_json, '\$.small')
        ) AS image_uri
      FROM card_printings cp
      INNER JOIN catalog_cards cc ON cc.id = cp.card_id
      INNER JOIN catalog_sets cs ON cs.id = cp.set_id
      LEFT JOIN provider_mappings legacy
        ON legacy.printing_id = cp.id
       AND legacy.object_type = 'legacy_printing'
      LEFT JOIN collection_cards owned
        ON owned.collection_id = ?
       AND owned.printing_id = cp.id
      WHERE cp.game_id = ?
        ${whereClauses.isEmpty ? '' : 'AND ${whereClauses.join(' AND ')}'}
      ORDER BY LOWER(display_name), LOWER(cs.code), LOWER(cp.collector_number)
      LIMIT ? OFFSET ?
      ''',
      <Object?>[
        ...cardNameParams,
        ...setNameParams,
        ...subtypeParams,
        ownedCollectionId,
        gameId.value,
        ...params,
        limit,
        offset ?? 0,
      ],
    );
    return rows.map(_genericCollectionRowToData).toList(growable: false);
  }

  int _countGenericCollectionCards({
    required TcgGameId gameId,
    required CollectionFilter filter,
    required int ownedCollectionId,
    required String? searchQuery,
    required bool ownedOnly,
    required bool missingOnly,
    required List<String> preferredLanguages,
  }) {
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final whereClauses = <String>[];
    final params = <Object?>[];
    _appendGenericFilterQuery(
      filter: filter,
      searchQuery: searchQuery,
      preferredLanguages: normalizedLanguages,
      whereClauses: whereClauses,
      params: params,
    );
    if (ownedOnly) {
      whereClauses.add('COALESCE(owned.quantity, 0) > 0');
    } else if (missingOnly) {
      whereClauses.add('COALESCE(owned.quantity, 0) = 0');
    }
    final rows = _database.select(
      '''
      SELECT COUNT(*) AS c
      FROM card_printings cp
      INNER JOIN catalog_cards cc ON cc.id = cp.card_id
      INNER JOIN catalog_sets cs ON cs.id = cp.set_id
      LEFT JOIN collection_cards owned
        ON owned.collection_id = ?
       AND owned.printing_id = cp.id
      WHERE cp.game_id = ?
        ${whereClauses.isEmpty ? '' : 'AND ${whereClauses.join(' AND ')}'}
      ''',
      <Object?>[ownedCollectionId, gameId.value, ...params],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  List<CanonicalCollectionCardData> _fetchPokemonCollectionCards({
    required CollectionFilter filter,
    required int ownedCollectionId,
    required String? searchQuery,
    required bool ownedOnly,
    required bool missingOnly,
    required List<String> preferredLanguages,
    required int limit,
    required int? offset,
  }) {
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final whereClauses = <String>[];
    final params = <Object?>[];
    _appendPokemonFilterQuery(
      filter: filter,
      searchQuery: searchQuery,
      preferredLanguages: normalizedLanguages,
      whereClauses: whereClauses,
      params: params,
    );
    if (ownedOnly) {
      whereClauses.add('COALESCE(owned.quantity, 0) > 0');
    } else if (missingOnly) {
      whereClauses.add('COALESCE(owned.quantity, 0) = 0');
    }

    final cardNameParams = <Object?>[];
    final preferredCardNameSql = _localizedCardNameSql(
      normalizedLanguages,
      cardNameParams,
    );
    final setNameParams = <Object?>[];
    final preferredSetNameSql = _localizedSetNameSql(
      normalizedLanguages,
      setNameParams,
    );
    final subtypeParams = <Object?>[];
    final preferredSubtypeSql = _localizedCardSubtypeSql(
      normalizedLanguages,
      subtypeParams,
    );
    final localizedRulesSql = _localizedCardRulesTextSql(normalizedLanguages);

    final rows = _database.select(
      '''
      SELECT
        COALESCE(legacy.provider_object_id, cp.id) AS card_id,
        cp.id AS printing_id,
        COALESCE(owned.quantity, 0) AS quantity,
        COALESCE(owned.foil, 0) AS foil,
        COALESCE(owned.alt_art, 0) AS alt_art,
        COALESCE($preferredCardNameSql, cc.canonical_name) AS display_name,
        cs.code AS set_code,
        COALESCE($preferredSetNameSql, cs.canonical_name) AS set_name,
        COALESCE(
          json_extract(cs.metadata_json, '\$.official_total'),
          json_extract(cs.metadata_json, '\$.total')
        ) AS set_total,
        cp.collector_number AS collector_number,
        COALESCE(cp.rarity, '') AS rarity,
        COALESCE(
          $preferredSubtypeSql,
          TRIM(
            COALESCE(pm.category, '') ||
            CASE
              WHEN pm.subtypes_json <> '[]'
                THEN ' ' || REPLACE(REPLACE(REPLACE(pm.subtypes_json, '[', '('), ']', ')'), '"', '')
              ELSE ''
            END
          ),
          ''
        ) AS type_line,
        '' AS mana_cost,
        COALESCE(
          $localizedRulesSql,
          json_extract(cc.metadata_json, '\$.pokemon.abilities[0].effect'),
          ''
        ) AS oracle_text,
        NULL AS cmc,
        LOWER(
          COALESCE(
            NULLIF(TRIM(cp.language_code), ''),
            cc.default_language,
            'en'
          )
        ) AS lang,
        COALESCE(pm.illustrator, '') AS artist,
        '' AS power,
        '' AS toughness,
        '' AS loyalty,
        COALESCE(pm.types_json, '[]') AS colors_json,
        COALESCE(pm.types_json, '[]') AS color_identity_json,
        COALESCE(cp.release_date, cs.release_date, '') AS released_at,
        NULL AS price_usd,
        NULL AS price_usd_foil,
        NULL AS price_usd_etched,
        NULL AS price_eur,
        NULL AS price_eur_foil,
        NULL AS price_tix,
        NULL AS prices_updated_at,
        COALESCE(
          json_extract(cp.image_uris_json, '\$.high_res'),
          json_extract(cp.image_uris_json, '\$.normal'),
          json_extract(cp.image_uris_json, '\$.default'),
          json_extract(cp.image_uris_json, '\$.small')
        ) AS image_uri
      FROM card_printings cp
      INNER JOIN catalog_cards cc ON cc.id = cp.card_id
      INNER JOIN catalog_sets cs ON cs.id = cp.set_id
      LEFT JOIN pokemon_printing_metadata pm ON pm.printing_id = cp.id
      LEFT JOIN provider_mappings legacy
        ON legacy.printing_id = cp.id
       AND legacy.provider_id = ?
       AND legacy.object_type = 'legacy_printing'
      LEFT JOIN collection_cards owned
        ON owned.collection_id = ?
       AND owned.printing_id = cp.id
      WHERE cp.game_id = ?
        ${whereClauses.isEmpty ? '' : 'AND ${whereClauses.join(' AND ')}'}
      ORDER BY LOWER(display_name), LOWER(cs.code), LOWER(cp.collector_number)
      LIMIT ? OFFSET ?
      ''',
      <Object?>[
        ...cardNameParams,
        ...setNameParams,
        ...subtypeParams,
        CatalogProviderId.pokemonTcgApi.value,
        ownedCollectionId,
        TcgGameId.pokemon.value,
        ...params,
        limit,
        offset ?? 0,
      ],
    );
    return rows.map(_pokemonCollectionRowToData).toList(growable: false);
  }

  int _countPokemonCollectionCards({
    required CollectionFilter filter,
    required int ownedCollectionId,
    required String? searchQuery,
    required bool ownedOnly,
    required bool missingOnly,
    required List<String> preferredLanguages,
  }) {
    final normalizedLanguages = _normalizedLanguageOrder(preferredLanguages);
    final whereClauses = <String>[];
    final params = <Object?>[];
    _appendPokemonFilterQuery(
      filter: filter,
      searchQuery: searchQuery,
      preferredLanguages: normalizedLanguages,
      whereClauses: whereClauses,
      params: params,
    );
    if (ownedOnly) {
      whereClauses.add('COALESCE(owned.quantity, 0) > 0');
    } else if (missingOnly) {
      whereClauses.add('COALESCE(owned.quantity, 0) = 0');
    }
    final rows = _database.select(
      '''
      SELECT COUNT(*) AS c
      FROM card_printings cp
      INNER JOIN catalog_cards cc ON cc.id = cp.card_id
      INNER JOIN catalog_sets cs ON cs.id = cp.set_id
      LEFT JOIN pokemon_printing_metadata pm ON pm.printing_id = cp.id
      LEFT JOIN collection_cards owned
        ON owned.collection_id = ?
       AND owned.printing_id = cp.id
      WHERE cp.game_id = ?
        ${whereClauses.isEmpty ? '' : 'AND ${whereClauses.join(' AND ')}'}
      ''',
      <Object?>[ownedCollectionId, TcgGameId.pokemon.value, ...params],
    );
    return (rows.first['c'] as int?) ?? 0;
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
        language_code TEXT NOT NULL DEFAULT 'en',
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
    _database.execute('''
      CREATE TABLE IF NOT EXISTS collection_cards (
        collection_id INTEGER NOT NULL,
        card_id TEXT,
        printing_id TEXT,
        quantity INTEGER NOT NULL DEFAULT 0,
        foil INTEGER NOT NULL DEFAULT 0,
        alt_art INTEGER NOT NULL DEFAULT 0
      )
      ''');
    _database.execute(
      'CREATE INDEX IF NOT EXISTS idx_catalog_sets_game_code ON catalog_sets(game_id, code)',
    );
    _database.execute(
      'CREATE INDEX IF NOT EXISTS idx_card_printings_game_set ON card_printings(game_id, set_id, collector_number)',
    );
    _ensureCatalogCardsDefaultLanguageColumn();
    _ensureCardPrintingsLanguageCodeColumn();
    _database.execute(
      'CREATE INDEX IF NOT EXISTS idx_card_printings_game_rarity ON card_printings(game_id, rarity)',
    );
    _database.execute(
      'CREATE INDEX IF NOT EXISTS idx_catalog_card_localizations_language_name ON catalog_card_localizations(language_code, name COLLATE NOCASE)',
    );
    _database.execute(
      'CREATE INDEX IF NOT EXISTS idx_catalog_set_localizations_language_name ON catalog_set_localizations(language_code, name COLLATE NOCASE)',
    );
    _database.execute(
      'CREATE INDEX IF NOT EXISTS idx_provider_mappings_lookup ON provider_mappings(game_id, provider_id, object_type, provider_object_id)',
    );
    _database.execute(
      'CREATE INDEX IF NOT EXISTS idx_pokemon_metadata_core ON pokemon_printing_metadata(category, stage, regulation_mark, hp)',
    );
    _database.execute(
      'CREATE INDEX IF NOT EXISTS idx_pokemon_metadata_illustrator ON pokemon_printing_metadata(illustrator COLLATE NOCASE)',
    );
    _database.execute(
      'CREATE INDEX IF NOT EXISTS idx_collection_cards_lookup ON collection_cards(collection_id, printing_id)',
    );
  }

  void _ensureCatalogCardsDefaultLanguageColumn() {
    final rows = _database.select("PRAGMA table_info('catalog_cards')");
    final hasColumn = rows.any(
      (row) => ((row['name'] as String?) ?? '').trim() == 'default_language',
    );
    if (!hasColumn) {
      _database.execute(
        "ALTER TABLE catalog_cards ADD COLUMN default_language TEXT NOT NULL DEFAULT 'en'",
      );
    }
  }

  void _ensureCardPrintingsLanguageCodeColumn() {
    final rows = _database.select("PRAGMA table_info('card_printings')");
    final hasColumn = rows.any(
      (row) => ((row['name'] as String?) ?? '').trim() == 'language_code',
    );
    if (!hasColumn) {
      _database.execute(
        "ALTER TABLE card_printings ADD COLUMN language_code TEXT NOT NULL DEFAULT 'en'",
      );
    }
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
        'weaknesses': pokemon.weaknesses
            .map(
              (value) => <String, Object?>{
                'type': value.type,
                'value': value.value,
              },
            )
            .toList(growable: false),
        'resistances': pokemon.resistances
            .map(
              (value) => <String, Object?>{
                'type': value.type,
                'value': value.value,
              },
            )
            .toList(growable: false),
        'attacks': pokemon.attacks
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
        'abilities': pokemon.abilities
            .map(
              (value) => <String, Object?>{
                'name': value.name,
                'type': value.type,
                'text': value.text,
              },
            )
            .toList(growable: false),
      };
    }
    return metadata;
  }

  void _appendPokemonFilterQuery({
    required CollectionFilter filter,
    required String? searchQuery,
    required List<String> preferredLanguages,
    required List<String> whereClauses,
    required List<Object?> params,
  }) {
    final combinedQuery = <String>[
      if ((searchQuery ?? '').trim().isNotEmpty) searchQuery!.trim(),
      if ((filter.name ?? '').trim().isNotEmpty) filter.name!.trim(),
    ].join(' ').trim();

    for (final token in _tokenizeSearch(combinedQuery)) {
      final localizedExistsSql = _localizedCardNameExistsSql(
        preferredLanguages.length,
      );
      final localizedExistsAnyLanguageSql =
          _localizedCardNameExistsAnyLanguageSql();
      whereClauses.add('''
        (
          LOWER(cc.canonical_name) LIKE ?
          OR $localizedExistsSql
          OR $localizedExistsAnyLanguageSql
          OR LOWER(cp.collector_number) LIKE ?
        )
        ''');
      params.add('%$token%');
      params.addAll(preferredLanguages);
      params.add('%$token%');
      params.add('%$token%');
      params.add('%$token%');
    }

    final collectorNumber = filter.collectorNumber?.trim().toLowerCase();
    if (collectorNumber != null && collectorNumber.isNotEmpty) {
      whereClauses.add('LOWER(cp.collector_number) LIKE ?');
      params.add('%$collectorNumber%');
    }

    final illustrator = filter.artist?.trim().toLowerCase();
    if (illustrator != null && illustrator.isNotEmpty) {
      whereClauses.add('LOWER(COALESCE(pm.illustrator, \'\')) LIKE ?');
      params.add('%$illustrator%');
    }

    _appendInClause(
      whereClauses: whereClauses,
      params: params,
      sqlExpression: 'LOWER(cs.code)',
      values: filter.sets.map((value) => value.trim().toLowerCase()),
    );
    _appendInClause(
      whereClauses: whereClauses,
      params: params,
      sqlExpression: 'LOWER(COALESCE(cp.rarity, \'\'))',
      values: filter.rarities.map((value) => value.trim().toLowerCase()),
    );
    _appendInClause(
      whereClauses: whereClauses,
      params: params,
      sqlExpression: 'LOWER(COALESCE(pm.category, \'\'))',
      values: filter.pokemonCategories.map(
        (value) => value.trim().toLowerCase(),
      ),
    );
    _appendInClause(
      whereClauses: whereClauses,
      params: params,
      sqlExpression: 'LOWER(COALESCE(pm.regulation_mark, \'\'))',
      values: filter.pokemonRegulationMarks.map(
        (value) => value.trim().toLowerCase(),
      ),
    );
    _appendInClause(
      whereClauses: whereClauses,
      params: params,
      sqlExpression: 'LOWER(COALESCE(pm.stage, \'\'))',
      values: filter.pokemonStages.map((value) => value.trim().toLowerCase()),
    );

    _appendJsonContainsAny(
      whereClauses: whereClauses,
      params: params,
      column: 'pm.types_json',
      values: filter.types,
    );
    _appendJsonContainsAny(
      whereClauses: whereClauses,
      params: params,
      column: 'pm.subtypes_json',
      values: filter.pokemonSubtypes,
    );
    _appendJsonContainsAny(
      whereClauses: whereClauses,
      params: params,
      column: 'pm.types_json',
      values: filter.colors.expand(_pokemonEnergyCodeToNames),
    );

    final normalizedLanguages = filter.languages
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedLanguages.isNotEmpty) {
      final placeholders = _inClause(normalizedLanguages.length);
      whereClauses.add('''
        (
          LOWER(COALESCE(NULLIF(TRIM(cp.language_code), ''), cc.default_language, 'en')) IN ($placeholders)
          OR EXISTS (
            SELECT 1
            FROM catalog_card_localizations ccl_lang
            WHERE ccl_lang.card_id = cc.id
              AND LOWER(ccl_lang.language_code) IN ($placeholders)
          )
        )
      ''');
      params.addAll(normalizedLanguages);
      params.addAll(normalizedLanguages);
    }

    if (filter.hpMin != null) {
      whereClauses.add('COALESCE(pm.hp, 0) >= ?');
      params.add(filter.hpMin);
    }
    if (filter.hpMax != null) {
      whereClauses.add('COALESCE(pm.hp, 0) <= ?');
      params.add(filter.hpMax);
    }
    if (filter.manaMin != null) {
      whereClauses.add('''
        EXISTS (
          SELECT 1
          FROM json_each(json_extract(cc.metadata_json, '\$.pokemon.attacks')) attack
          WHERE CAST(json_extract(attack.value, '\$.converted_energy_cost') AS INTEGER) >= ?
        )
        ''');
      params.add(filter.manaMin);
    }
    if (filter.manaMax != null) {
      whereClauses.add('''
        EXISTS (
          SELECT 1
          FROM json_each(json_extract(cc.metadata_json, '\$.pokemon.attacks')) attack
          WHERE CAST(json_extract(attack.value, '\$.converted_energy_cost') AS INTEGER) <= ?
        )
        ''');
      params.add(filter.manaMax);
    }
  }

  void _appendGenericFilterQuery({
    required CollectionFilter filter,
    required String? searchQuery,
    required List<String> preferredLanguages,
    required List<String> whereClauses,
    required List<Object?> params,
  }) {
    final combinedQuery = <String>[
      if ((searchQuery ?? '').trim().isNotEmpty) searchQuery!.trim(),
      if ((filter.name ?? '').trim().isNotEmpty) filter.name!.trim(),
    ].join(' ').trim();

    for (final token in _tokenizeSearch(combinedQuery)) {
      final localizedExistsSql = _localizedCardNameExistsSql(
        preferredLanguages.length,
      );
      whereClauses.add('''
        (
          LOWER(cc.canonical_name) LIKE ?
          OR $localizedExistsSql
          OR LOWER(cp.collector_number) LIKE ?
          OR LOWER(COALESCE(json_extract(cp.metadata_json, '\$.type_line'), json_extract(cc.metadata_json, '\$.type_line'), '')) LIKE ?
        )
        ''');
      params.add('%$token%');
      params.addAll(preferredLanguages);
      params.add('%$token%');
      params.add('%$token%');
      params.add('%$token%');
    }

    final collectorNumber = filter.collectorNumber?.trim().toLowerCase();
    if (collectorNumber != null && collectorNumber.isNotEmpty) {
      whereClauses.add('LOWER(cp.collector_number) LIKE ?');
      params.add('%$collectorNumber%');
    }

    final artist = filter.artist?.trim().toLowerCase();
    if (artist != null && artist.isNotEmpty) {
      whereClauses.add(
        r"LOWER(COALESCE(json_extract(cp.metadata_json, '$.artist'), json_extract(cc.metadata_json, '$.artist'), '')) LIKE ?",
      );
      params.add('%$artist%');
    }

    _appendInClause(
      whereClauses: whereClauses,
      params: params,
      sqlExpression: 'LOWER(cs.code)',
      values: filter.sets.map((value) => value.trim().toLowerCase()),
    );
    _appendInClause(
      whereClauses: whereClauses,
      params: params,
      sqlExpression: 'LOWER(COALESCE(cp.rarity, \'\'))',
      values: filter.rarities.map((value) => value.trim().toLowerCase()),
    );
    _appendInClause(
      whereClauses: whereClauses,
      params: params,
      sqlExpression:
          r"LOWER(COALESCE(NULLIF(TRIM(cp.language_code), ''), cc.default_language, 'en'))",
      values: filter.languages.map((value) => value.trim().toLowerCase()),
    );

    final normalizedTypes = filter.types
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedTypes.isNotEmpty) {
      final clauses = <String>[];
      for (final value in normalizedTypes) {
        clauses.add(
          r"LOWER(COALESCE(json_extract(cp.metadata_json, '$.type_line'), json_extract(cc.metadata_json, '$.type_line'), '')) LIKE ?",
        );
        params.add('%$value%');
      }
      whereClauses.add('(${clauses.join(' OR ')})');
    }
  }

  String _localizedCardNameSql(List<String> languages, List<Object?> params) {
    final inClause = _inClause(languages.length);
    final orderCases = <String>[];
    for (var index = 0; index < languages.length; index += 1) {
      orderCases.add('WHEN ? THEN $index');
      params.add(languages[index]);
    }
    params.addAll(languages);
    return '''
      (
        SELECT ccl.name
        FROM catalog_card_localizations ccl
        WHERE ccl.card_id = cc.id
          AND ccl.language_code IN ($inClause)
        ORDER BY CASE ccl.language_code ${orderCases.join(' ')} ELSE 999 END
        LIMIT 1
      )
    ''';
  }

  String _localizedSetNameSql(List<String> languages, List<Object?> params) {
    final inClause = _inClause(languages.length);
    final orderCases = <String>[];
    for (var index = 0; index < languages.length; index += 1) {
      orderCases.add('WHEN ? THEN $index');
      params.add(languages[index]);
    }
    params.addAll(languages);
    return '''
      (
        SELECT csl.name
        FROM catalog_set_localizations csl
        WHERE csl.set_id = cs.id
          AND csl.language_code IN ($inClause)
        ORDER BY CASE csl.language_code ${orderCases.join(' ')} ELSE 999 END
        LIMIT 1
      )
    ''';
  }

  String _localizedCardSubtypeSql(
    List<String> languages,
    List<Object?> params,
  ) {
    final inClause = _inClause(languages.length);
    final orderCases = <String>[];
    for (var index = 0; index < languages.length; index += 1) {
      orderCases.add('WHEN ? THEN $index');
      params.add(languages[index]);
    }
    params.addAll(languages);
    return '''
      (
        SELECT ccl.subtype_line
        FROM catalog_card_localizations ccl
        WHERE ccl.card_id = cc.id
          AND ccl.language_code IN ($inClause)
          AND TRIM(COALESCE(ccl.subtype_line, '')) <> ''
        ORDER BY CASE ccl.language_code ${orderCases.join(' ')} ELSE 999 END
        LIMIT 1
      )
    ''';
  }

  String _localizedCardRulesTextSql(List<String> languages) {
    final orderCases = _preferredLanguageCaseWhen(languages);
    final literalLanguages = languages.map(_sqlStringLiteral).join(', ');
    return '''
      (
        SELECT ccl.rules_text
        FROM catalog_card_localizations ccl
        WHERE ccl.card_id = cc.id
          AND ccl.language_code IN ($literalLanguages)
          AND TRIM(COALESCE(ccl.rules_text, '')) <> ''
        ORDER BY CASE ccl.language_code $orderCases ELSE 999 END
        LIMIT 1
      )
    ''';
  }

  String _preferredLanguageCaseWhen(List<String> languages) {
    final cases = <String>[];
    for (var index = 0; index < languages.length; index += 1) {
      cases.add('WHEN ${_sqlStringLiteral(languages[index])} THEN $index');
    }
    return cases.join(' ');
  }

  String _sqlStringLiteral(String value) {
    final escaped = value.replaceAll("'", "''");
    return "'$escaped'";
  }

  String _localizedCardNameExistsSql(int languageCount) {
    return '''
      EXISTS (
        SELECT 1
        FROM catalog_card_localizations ccl
        WHERE ccl.card_id = cc.id
          AND ccl.language_code IN (${_inClause(languageCount)})
          AND LOWER(ccl.name) LIKE ?
      )
    ''';
  }

  String _localizedCardNameExistsAnyLanguageSql() {
    return '''
      EXISTS (
        SELECT 1
        FROM catalog_card_localizations ccl
        WHERE ccl.card_id = cc.id
          AND LOWER(ccl.name) LIKE ?
      )
    ''';
  }

  void _appendInClause({
    required List<String> whereClauses,
    required List<Object?> params,
    required String sqlExpression,
    required Iterable<String> values,
  }) {
    final normalized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return;
    }
    whereClauses.add('$sqlExpression IN (${_inClause(normalized.length)})');
    params.addAll(normalized);
  }

  void _appendJsonContainsAny({
    required List<String> whereClauses,
    required List<Object?> params,
    required String column,
    required Iterable<String> values,
  }) {
    final normalized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return;
    }
    final clauses = <String>[];
    for (final value in normalized) {
      clauses.add('$column LIKE ?');
      params.add('%"${value.replaceAll('"', '\\"')}"%');
    }
    whereClauses.add('(${clauses.join(' OR ')})');
  }

  CanonicalCollectionCardData _genericCollectionRowToData(
    Map<String, Object?> row,
  ) {
    return CanonicalCollectionCardData(
      cardId: (row['card_id'] as String? ?? '').trim(),
      printingId: (row['printing_id'] as String? ?? '').trim(),
      name: (row['display_name'] as String? ?? '').trim(),
      setCode: ((row['set_code'] as String? ?? '').trim().toLowerCase()),
      setName: (row['set_name'] as String? ?? '').trim(),
      setTotal: (row['set_total'] as num?)?.toInt(),
      collectorNumber: (row['collector_number'] as String? ?? '').trim(),
      rarity: (row['rarity'] as String? ?? '').trim(),
      typeLine: (row['type_line'] as String? ?? '').trim(),
      manaCost: (row['mana_cost'] as String? ?? '').trim(),
      oracleText: (row['oracle_text'] as String? ?? '').trim(),
      manaValue: (row['cmc'] as num?)?.toDouble(),
      lang: (row['lang'] as String? ?? '').trim(),
      artist: (row['artist'] as String? ?? '').trim(),
      power: (row['power'] as String? ?? '').trim(),
      toughness: (row['toughness'] as String? ?? '').trim(),
      loyalty: (row['loyalty'] as String? ?? '').trim(),
      colors: _jsonColorCodesToLegacyString(row['colors_json']),
      colorIdentity: _jsonColorCodesToLegacyString(row['color_identity_json']),
      releasedAt: (row['released_at'] as String? ?? '').trim(),
      quantity: ((row['quantity'] as num?) ?? 0).toInt(),
      foil: ((row['foil'] as num?) ?? 0).toInt() == 1,
      altArt: ((row['alt_art'] as num?) ?? 0).toInt() == 1,
      priceUsd: (row['price_usd'] as String?)?.trim(),
      priceUsdFoil: (row['price_usd_foil'] as String?)?.trim(),
      priceUsdEtched: (row['price_usd_etched'] as String?)?.trim(),
      priceEur: (row['price_eur'] as String?)?.trim(),
      priceEurFoil: (row['price_eur_foil'] as String?)?.trim(),
      priceTix: (row['price_tix'] as String?)?.trim(),
      pricesUpdatedAt: (row['prices_updated_at'] as num?)?.toInt(),
      imageUri: (row['image_uri'] as String?)?.trim(),
    );
  }

  CanonicalCollectionCardData _pokemonCollectionRowToData(
    Map<String, Object?> row,
  ) {
    return CanonicalCollectionCardData(
      cardId: (row['card_id'] as String? ?? '').trim(),
      printingId: (row['printing_id'] as String? ?? '').trim(),
      name: (row['display_name'] as String? ?? '').trim(),
      setCode: ((row['set_code'] as String? ?? '').trim().toLowerCase()),
      setName: (row['set_name'] as String? ?? '').trim(),
      setTotal: (row['set_total'] as num?)?.toInt(),
      collectorNumber: (row['collector_number'] as String? ?? '').trim(),
      rarity: (row['rarity'] as String? ?? '').trim(),
      typeLine: (row['type_line'] as String? ?? '').trim(),
      manaCost: (row['mana_cost'] as String? ?? '').trim(),
      oracleText: (row['oracle_text'] as String? ?? '').trim(),
      manaValue: (row['cmc'] as num?)?.toDouble(),
      lang: (row['lang'] as String? ?? '').trim(),
      artist: (row['artist'] as String? ?? '').trim(),
      power: (row['power'] as String? ?? '').trim(),
      toughness: (row['toughness'] as String? ?? '').trim(),
      loyalty: (row['loyalty'] as String? ?? '').trim(),
      colors: _pokemonTypesJsonToLegacyColorCode(row['colors_json']),
      colorIdentity: _pokemonTypesJsonToLegacyColorCode(
        row['color_identity_json'],
      ),
      releasedAt: (row['released_at'] as String? ?? '').trim(),
      quantity: ((row['quantity'] as num?) ?? 0).toInt(),
      foil: ((row['foil'] as num?) ?? 0).toInt() == 1,
      altArt: ((row['alt_art'] as num?) ?? 0).toInt() == 1,
      priceUsd: (row['price_usd'] as String?)?.trim(),
      priceUsdFoil: (row['price_usd_foil'] as String?)?.trim(),
      priceUsdEtched: (row['price_usd_etched'] as String?)?.trim(),
      priceEur: (row['price_eur'] as String?)?.trim(),
      priceEurFoil: (row['price_eur_foil'] as String?)?.trim(),
      priceTix: (row['price_tix'] as String?)?.trim(),
      pricesUpdatedAt: (row['prices_updated_at'] as num?)?.toInt(),
      imageUri: (row['image_uri'] as String?)?.trim(),
    );
  }

  String _inClause(int count) => List<String>.filled(count, '?').join(', ');

  List<String> _normalizedLanguageOrder(List<String> preferredLanguages) {
    final normalized = preferredLanguages
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <String>['en'];
    }
    final unique = <String>[];
    final seen = <String>{};
    for (final value in normalized) {
      if (seen.add(value)) {
        unique.add(value);
      }
    }
    unique.sort((a, b) {
      if (a == 'en' && b != 'en') {
        return 1;
      }
      if (a != 'en' && b == 'en') {
        return -1;
      }
      return 0;
    });
    if (!unique.contains('en')) {
      unique.add('en');
    }
    return unique;
  }

  String _jsonColorCodesToLegacyString(Object? raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return '';
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .map((value) => value.trim().toUpperCase())
              .where((value) => value.isNotEmpty)
              .join(',');
        }
      } catch (_) {
        return trimmed;
      }
      return trimmed;
    }
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((value) => value.trim().toUpperCase())
          .where((value) => value.isNotEmpty)
          .join(',');
    }
    return '';
  }

  List<String> _tokenizeSearch(String raw) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    return normalized.split(' ');
  }

  CardSearchResult _pokemonSearchRowToResult(Row row) {
    final typeNames = _parseJsonStringList(
      (row['types_json'] as String?) ?? '[]',
    );
    final colorCodes = _pokemonTypeNamesToColorCodes(typeNames).join(',');
    return CardSearchResult(
      id: (row['legacy_id'] as String? ?? '').trim(),
      printingId: (row['printing_id'] as String?)?.trim(),
      name: (row['display_name'] as String? ?? '').trim(),
      setCode: (row['set_code'] as String? ?? '').trim().toLowerCase(),
      setName: (row['set_name'] as String? ?? '').trim(),
      collectorNumber: (row['collector_number'] as String? ?? '').trim(),
      setTotal: (row['set_total'] as num?)?.toInt(),
      rarity: (row['rarity'] as String? ?? '').trim(),
      typeLine: (row['type_line'] as String? ?? '').trim(),
      colors: colorCodes,
      colorIdentity: colorCodes,
      imageUri: (row['image_uri'] as String?)?.trim(),
    );
  }

  CardSearchResult _genericSearchRowToResult(Row row) {
    final colors = _parseJsonStringList(
      (row['colors_json'] as String?) ?? '[]',
    );
    final colorIdentity = _parseJsonStringList(
      (row['color_identity_json'] as String?) ?? '[]',
    );
    return CardSearchResult(
      id: (row['legacy_id'] as String? ?? '').trim(),
      printingId: (row['printing_id'] as String?)?.trim(),
      name: (row['display_name'] as String? ?? '').trim(),
      setCode: (row['set_code'] as String? ?? '').trim().toLowerCase(),
      setName: (row['set_name'] as String? ?? '').trim(),
      collectorNumber: (row['collector_number'] as String? ?? '').trim(),
      setTotal: (row['set_total'] as num?)?.toInt(),
      rarity: (row['rarity'] as String? ?? '').trim(),
      typeLine: (row['type_line'] as String? ?? '').trim(),
      colors: colors.join(','),
      colorIdentity: colorIdentity.join(','),
      imageUri: (row['image_uri'] as String?)?.trim(),
    );
  }

  List<String> _parseJsonStringList(String raw) {
    if (raw.trim().isEmpty) {
      return const <String>[];
    }
    final parsed = jsonDecode(raw);
    if (parsed is! List) {
      return const <String>[];
    }
    return parsed
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _parseJsonObjectList(String raw) {
    if (raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    final parsed = jsonDecode(raw);
    if (parsed is! List) {
      return const <Map<String, dynamic>>[];
    }
    return parsed
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }

  Iterable<String> _pokemonEnergyCodeToNames(String code) {
    switch (code.trim().toUpperCase()) {
      case 'G':
        return const <String>['Grass'];
      case 'R':
        return const <String>['Fire'];
      case 'U':
        return const <String>['Water'];
      case 'L':
        return const <String>['Lightning'];
      case 'B':
        return const <String>['Psychic', 'Darkness'];
      case 'F':
        return const <String>['Fighting'];
      case 'D':
        return const <String>['Dragon'];
      case 'W':
        return const <String>['Fairy'];
      case 'C':
        return const <String>['Colorless'];
      case 'M':
        return const <String>['Metal'];
      default:
        return const <String>[];
    }
  }

  List<String> _pokemonTypeNamesToColorCodes(List<String> types) {
    final result = <String>{};
    for (final raw in types) {
      switch (raw.trim().toLowerCase()) {
        case 'grass':
          result.add('G');
          break;
        case 'fire':
          result.add('R');
          break;
        case 'water':
          result.add('U');
          break;
        case 'lightning':
        case 'electric':
          result.add('L');
          break;
        case 'psychic':
        case 'darkness':
        case 'dark':
          result.add('B');
          break;
        case 'fighting':
          result.add('F');
          break;
        case 'dragon':
          result.add('D');
          break;
        case 'fairy':
          result.add('W');
          break;
        case 'metal':
        case 'steel':
          result.add('M');
          break;
        case 'colorless':
          result.add('C');
          break;
      }
    }
    if (result.isEmpty) {
      result.add('N');
    }
    return result.toList(growable: false);
  }

  String _pokemonTypesJsonToLegacyColorCode(Object? raw) {
    final json = (raw as String?) ?? '[]';
    final typeNames = _parseJsonStringList(json);
    return _pokemonTypeNamesToColorCodes(typeNames).join(',');
  }
}
