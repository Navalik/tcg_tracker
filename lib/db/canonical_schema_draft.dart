import 'package:drift/drift.dart';

// Draft canonical schema for the 0.5.x refactor.
// This file is intentionally not wired into the runtime database yet.

class GamesDraft extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get capabilitiesJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogCardsDraft extends Table {
  TextColumn get id => text()();
  TextColumn get gameId => text()();
  TextColumn get canonicalName => text()();
  TextColumn get sortName => text().nullable()();
  TextColumn get defaultLanguage => text().nullable()();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogSetsDraft extends Table {
  TextColumn get id => text()();
  TextColumn get gameId => text()();
  TextColumn get code => text()();
  TextColumn get canonicalName => text()();
  TextColumn get seriesId => text().nullable()();
  TextColumn get releaseDate => text().nullable()();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class CardPrintingsDraft extends Table {
  TextColumn get id => text()();
  TextColumn get gameId => text()();
  TextColumn get cardId => text()();
  TextColumn get setId => text()();
  TextColumn get collectorNumber => text()();
  TextColumn get rarity => text().nullable()();
  TextColumn get releaseDate => text().nullable()();
  TextColumn get imageUrisJson => text().withDefault(const Constant('{}'))();
  TextColumn get finishKeysJson => text().withDefault(const Constant('[]'))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogCardLocalizationsDraft extends Table {
  TextColumn get cardId => text()();
  TextColumn get languageCode => text()();
  TextColumn get name => text()();
  TextColumn get subtypeLine => text().nullable()();
  TextColumn get rulesText => text().nullable()();
  TextColumn get flavorText => text().nullable()();
  TextColumn get searchAliasesJson => text().withDefault(const Constant('[]'))();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {cardId, languageCode};
}

class CatalogSetLocalizationsDraft extends Table {
  TextColumn get setId => text()();
  TextColumn get languageCode => text()();
  TextColumn get name => text()();
  TextColumn get seriesName => text().nullable()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {setId, languageCode};
}

class ProviderMappingsDraft extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get gameId => text()();
  TextColumn get providerId => text()();
  TextColumn get objectType => text()();
  TextColumn get providerObjectId => text()();
  TextColumn get providerObjectVersion => text().nullable()();
  TextColumn get cardId => text().nullable()();
  TextColumn get printingId => text().nullable()();
  TextColumn get setId => text().nullable()();
  RealColumn get mappingConfidence => real().withDefault(const Constant(1.0))();
  TextColumn get mappingSource => text().nullable()();
  TextColumn get payloadHash => text().nullable()();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();
}

class PokemonPrintingMetadataDraft extends Table {
  TextColumn get printingId => text()();
  TextColumn get category => text().nullable()();
  IntColumn get hp => integer().nullable()();
  TextColumn get stage => text().nullable()();
  TextColumn get evolvesFrom => text().nullable()();
  TextColumn get regulationMark => text().nullable()();
  IntColumn get retreatCost => integer().nullable()();
  TextColumn get illustrator => text().nullable()();
  TextColumn get typesJson => text().withDefault(const Constant('[]'))();
  TextColumn get subtypesJson => text().withDefault(const Constant('[]'))();
  TextColumn get weaknessesJson => text().withDefault(const Constant('[]'))();
  TextColumn get resistancesJson => text().withDefault(const Constant('[]'))();
  TextColumn get attacksJson => text().withDefault(const Constant('[]'))();
  TextColumn get abilitiesJson => text().withDefault(const Constant('[]'))();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {printingId};
}

class CardSearchDocumentsDraft extends Table {
  TextColumn get printingId => text()();
  TextColumn get gameId => text()();
  TextColumn get languageCode => text()();
  TextColumn get cardName => text()();
  TextColumn get setName => text().nullable()();
  TextColumn get collectorNumber => text().nullable()();
  TextColumn get searchText => text()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {printingId, languageCode};
}

class PriceSnapshotsDraft extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get printingId => text()();
  TextColumn get sourceId => text()();
  TextColumn get currencyCode => text()();
  RealColumn get amount => real()();
  TextColumn get finishKey => text().nullable()();
  IntColumn get capturedAtMs => integer()();
}

class CollectionsDraft extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get gameId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get filterJson => text().nullable()();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();
}

class CollectionMembershipsDraft extends Table {
  IntColumn get collectionId => integer()();
  TextColumn get printingId => text()();
  IntColumn get addedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {collectionId, printingId};
}

class CollectionInventoryDraft extends Table {
  IntColumn get collectionId => integer()();
  TextColumn get printingId => text()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  BoolColumn get foil => boolean().withDefault(const Constant(false))();
  BoolColumn get altArt => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {collectionId, printingId};
}
