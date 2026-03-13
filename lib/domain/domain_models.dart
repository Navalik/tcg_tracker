enum TcgGameId {
  mtg('mtg'),
  pokemon('pokemon');

  const TcgGameId(this.value);

  final String value;
}

enum TcgCardLanguage {
  en('en'),
  it('it');

  const TcgCardLanguage(this.code);

  final String code;
}

enum PriceSourceId {
  scryfall('scryfall'),
  mtgJson('mtgjson'),
  justTcg('justtcg'),
  unknown('unknown');

  const PriceSourceId(this.value);

  final String value;
}

enum CatalogProviderId {
  scryfall('scryfall'),
  pokemonTcgApi('pokemon_tcg_api'),
  tcgdex('tcgdex'),
  unknown('unknown');

  const CatalogProviderId(this.value);

  final String value;
}

class GameCapabilities {
  const GameCapabilities({
    required this.supportsCatalogInstall,
    required this.supportsCatalogReimport,
    required this.supportsUpdateCheck,
    required this.supportsLocalizedSearch,
    required this.supportsAdvancedFilters,
    required this.supportsDecks,
    required this.supportsSideboard,
    required this.supportsPricing,
    required this.supportsScanner,
    required this.supportedUiLanguages,
    required this.supportedCardLanguages,
    required this.filterKeys,
    required this.metadataKeys,
  });

  final bool supportsCatalogInstall;
  final bool supportsCatalogReimport;
  final bool supportsUpdateCheck;
  final bool supportsLocalizedSearch;
  final bool supportsAdvancedFilters;
  final bool supportsDecks;
  final bool supportsSideboard;
  final bool supportsPricing;
  final bool supportsScanner;
  final Set<TcgCardLanguage> supportedUiLanguages;
  final Set<TcgCardLanguage> supportedCardLanguages;
  final Set<String> filterKeys;
  final Set<String> metadataKeys;
}

class CatalogCard {
  const CatalogCard({
    required this.cardId,
    required this.gameId,
    required this.canonicalName,
    this.sortName,
    this.defaultLocalizedData,
    this.localizedData = const [],
    this.metadata = const <String, Object?>{},
    this.pokemon,
  });

  final String cardId;
  final TcgGameId gameId;
  final String canonicalName;
  final String? sortName;
  final LocalizedCardData? defaultLocalizedData;
  final List<LocalizedCardData> localizedData;
  final Map<String, Object?> metadata;
  final PokemonCardMetadata? pokemon;
}

class CatalogSet {
  const CatalogSet({
    required this.setId,
    required this.gameId,
    required this.code,
    required this.canonicalName,
    this.seriesId,
    this.releaseDate,
    this.defaultLocalizedData,
    this.localizedData = const [],
    this.metadata = const <String, Object?>{},
  });

  final String setId;
  final TcgGameId gameId;
  final String code;
  final String canonicalName;
  final String? seriesId;
  final DateTime? releaseDate;
  final LocalizedSetData? defaultLocalizedData;
  final List<LocalizedSetData> localizedData;
  final Map<String, Object?> metadata;
}

class CardPrintingRef {
  const CardPrintingRef({
    required this.printingId,
    required this.cardId,
    required this.setId,
    required this.gameId,
    required this.collectorNumber,
    this.providerMappings = const [],
    this.rarity,
    this.releaseDate,
    this.imageUris = const <String, String>{},
    this.finishKeys = const <String>{},
    this.metadata = const <String, Object?>{},
  });

  final String printingId;
  final String cardId;
  final String setId;
  final TcgGameId gameId;
  final String collectorNumber;
  final List<ProviderMapping> providerMappings;
  final String? rarity;
  final DateTime? releaseDate;
  final Map<String, String> imageUris;
  final Set<String> finishKeys;
  final Map<String, Object?> metadata;
}

class LocalizedCardData {
  const LocalizedCardData({
    required this.cardId,
    required this.language,
    required this.name,
    this.subtypeLine,
    this.rulesText,
    this.flavorText,
    this.searchAliases = const [],
  });

  final String cardId;
  final TcgCardLanguage language;
  final String name;
  final String? subtypeLine;
  final String? rulesText;
  final String? flavorText;
  final List<String> searchAliases;
}

class LocalizedSetData {
  const LocalizedSetData({
    required this.setId,
    required this.language,
    required this.name,
    this.seriesName,
  });

  final String setId;
  final TcgCardLanguage language;
  final String name;
  final String? seriesName;
}

class PriceSnapshot {
  const PriceSnapshot({
    required this.printingId,
    required this.sourceId,
    required this.currencyCode,
    required this.amount,
    required this.capturedAt,
    this.finishKey,
  });

  final String printingId;
  final PriceSourceId sourceId;
  final String currencyCode;
  final double amount;
  final DateTime capturedAt;
  final String? finishKey;
}

class ProviderMapping {
  const ProviderMapping({
    required this.providerId,
    required this.objectType,
    required this.providerObjectId,
    this.providerObjectVersion,
    this.mappingConfidence = 1.0,
  });

  final CatalogProviderId providerId;
  final String objectType;
  final String providerObjectId;
  final String? providerObjectVersion;
  final double mappingConfidence;
}

class PokemonCardMetadata {
  const PokemonCardMetadata({
    this.category,
    this.hp,
    this.types = const [],
    this.subtypes = const [],
    this.stage,
    this.evolvesFrom,
    this.regulationMark,
    this.retreatCost,
    this.weaknesses = const [],
    this.resistances = const [],
    this.attacks = const [],
    this.abilities = const [],
    this.illustrator,
  });

  final String? category;
  final int? hp;
  final List<String> types;
  final List<String> subtypes;
  final String? stage;
  final String? evolvesFrom;
  final String? regulationMark;
  final int? retreatCost;
  final List<PokemonWeakness> weaknesses;
  final List<PokemonResistance> resistances;
  final List<PokemonAttack> attacks;
  final List<PokemonAbility> abilities;
  final String? illustrator;
}

class PokemonAttack {
  const PokemonAttack({
    required this.name,
    this.text,
    this.damage,
    this.energyCost = const [],
    this.convertedEnergyCost,
  });

  final String name;
  final String? text;
  final String? damage;
  final List<String> energyCost;
  final int? convertedEnergyCost;
}

class PokemonAbility {
  const PokemonAbility({
    required this.name,
    required this.type,
    this.text,
  });

  final String name;
  final String type;
  final String? text;
}

class PokemonWeakness {
  const PokemonWeakness({
    required this.type,
    this.value,
  });

  final String type;
  final String? value;
}

class PokemonResistance {
  const PokemonResistance({
    required this.type,
    this.value,
  });

  final String type;
  final String? value;
}

class CoreCardFilter {
  const CoreCardFilter({
    this.query,
    this.languages = const {},
    this.setIds = const {},
    this.rarities = const {},
    this.collectorNumber,
    this.artist,
    this.sortBy,
  });

  final String? query;
  final Set<TcgCardLanguage> languages;
  final Set<String> setIds;
  final Set<String> rarities;
  final String? collectorNumber;
  final String? artist;
  final String? sortBy;
}

class PokemonCardFilter {
  const PokemonCardFilter({
    this.category,
    this.types = const {},
    this.subtypes = const {},
    this.regulationMarks = const {},
    this.energyTypes = const {},
    this.hpMin,
    this.hpMax,
    this.stage,
    this.illustrator,
  });

  final String? category;
  final Set<String> types;
  final Set<String> subtypes;
  final Set<String> regulationMarks;
  final Set<String> energyTypes;
  final int? hpMin;
  final int? hpMax;
  final String? stage;
  final String? illustrator;
}
