import '../db/app_database.dart';
import '../domain/domain_models.dart';
import '../models.dart';
import '../services/game_registry.dart';
import '../services/price_provider.dart';
import '../services/price_repository.dart' as legacy_prices;
import 'catalog_repository.dart';
import 'collection_repository.dart';
import 'price_repository.dart';
import 'repository_registry.dart';
import 'search_repository.dart';
import 'set_repository.dart';

class LegacyScryfallRepositoryAdapter
    implements
        CatalogRepository,
        SetRepository,
        SearchRepository,
        CollectionRepository,
        PriceRepository {
  LegacyScryfallRepositoryAdapter({
    ScryfallDatabase? database,
    legacy_prices.PriceRepository? priceRepository,
  }) : _database = database ?? ScryfallDatabase.instance,
       _priceRepository =
           priceRepository ?? legacy_prices.PriceRepository.instance;

  final ScryfallDatabase _database;
  final legacy_prices.PriceRepository _priceRepository;

  Future<T> _runForGame<T>(
    TcgGameId? gameId,
    Future<T> Function() action,
  ) async {
    if (gameId == null) {
      return action();
    }
    final definition = GameRegistry.instance.definitionForId(gameId);
    if (definition == null) {
      return action();
    }
    return _database.runWithDatabaseFileName(definition.dbFileName, action);
  }

  static RepositoryRegistry createRegistry({
    ScryfallDatabase? database,
    legacy_prices.PriceRepository? priceRepository,
  }) {
    final adapter = LegacyScryfallRepositoryAdapter(
      database: database,
      priceRepository: priceRepository,
    );
    return RepositoryRegistry(
      catalog: adapter,
      sets: adapter,
      search: adapter,
      collections: adapter,
      prices: adapter,
    );
  }

  @override
  Future<int> countCards({TcgGameId? gameId}) {
    return _runForGame(gameId, () => _database.countCards());
  }

  @override
  Future<List<SetInfo>> fetchAvailableSets({
    TcgGameId? gameId,
    List<String> preferredLanguages = const [],
  }) {
    return _runForGame(gameId, () => _database.fetchAvailableSets());
  }

  @override
  Future<Map<String, String>> fetchSetNamesForCodes(
    List<String> setCodes, {
    TcgGameId? gameId,
    List<String> preferredLanguages = const [],
  }) {
    return _runForGame(gameId, () => _database.fetchSetNamesForCodes(setCodes));
  }

  @override
  Future<List<CardSearchResult>> fetchCardsForFilters({
    TcgGameId? gameId,
    Set<String> setCodes = const {},
    Set<String> rarities = const {},
    Set<String> types = const {},
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) {
    return _runForGame(
      gameId,
      () => _database.fetchCardsForFilters(
        setCodes: setCodes.toList(growable: false),
        rarities: rarities.toList(growable: false),
        types: types.toList(growable: false),
        languages: languages,
        limit: limit,
        offset: offset,
      ),
    );
  }

  @override
  Future<List<CardSearchResult>> searchCardsByName(
    String query, {
    TcgGameId? gameId,
    List<String> languages = const [],
    int limit = 80,
    int? offset,
  }) {
    return _runForGame(
      gameId,
      () => _database.searchCardsByName(
        query,
        limit: limit,
        offset: offset,
        languages: languages,
      ),
    );
  }

  @override
  Future<List<CardSearchResult>> fetchCardsForAdvancedFilters(
    CollectionFilter filter, {
    TcgGameId? gameId,
    String? searchQuery,
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) {
    return _runForGame(
      gameId,
      () => _database.fetchCardsForAdvancedFilters(
        filter,
        searchQuery: searchQuery,
        languages: languages,
        limit: limit,
        offset: offset,
      ),
    );
  }

  @override
  Future<int> countCardsForFilter(
    CollectionFilter filter, {
    TcgGameId? gameId,
  }) {
    return _runForGame(gameId, () => _database.countCardsForFilter(filter));
  }

  @override
  Future<int> countCardsForFilterWithSearch(
    CollectionFilter filter, {
    TcgGameId? gameId,
    String? searchQuery,
    List<String> languages = const [],
  }) {
    return _runForGame(
      gameId,
      () => _database.countCardsForFilterWithSearch(
        filter,
        searchQuery: searchQuery,
        languages: languages,
      ),
    );
  }

  @override
  Future<List<CollectionInfo>> fetchCollections({TcgGameId? gameId}) {
    return _runForGame(gameId, () => _database.fetchCollections());
  }

  @override
  Future<int> addCollection(
    String name, {
    TcgGameId? gameId,
    CollectionType type = CollectionType.custom,
    CollectionFilter? filter,
  }) {
    return _runForGame(
      gameId,
      () => _database.addCollection(name, type: type, filter: filter),
    );
  }

  @override
  Future<void> renameCollection(int id, String name, {TcgGameId? gameId}) {
    return _runForGame(gameId, () => _database.renameCollection(id, name));
  }

  @override
  Future<void> updateCollectionFilter(
    int id, {
    TcgGameId? gameId,
    CollectionFilter? filter,
  }) {
    return _runForGame(
      gameId,
      () => _database.updateCollectionFilter(id, filter: filter),
    );
  }

  @override
  Future<CollectionType?> fetchCollectionTypeById(int id, {TcgGameId? gameId}) {
    return _runForGame(gameId, () => _database.fetchCollectionTypeById(id));
  }

  @override
  Future<void> deleteCollection(int id, {TcgGameId? gameId}) {
    return _runForGame(gameId, () => _database.deleteCollection(id));
  }

  @override
  Future<List<CollectionCardEntry>> fetchCollectionCards(
    int collectionId, {
    TcgGameId? gameId,
    int? limit,
    int? offset,
    String? searchQuery,
  }) {
    return _runForGame(
      gameId,
      () => _database.fetchCollectionCards(
        collectionId,
        limit: limit,
        offset: offset,
        searchQuery: searchQuery,
      ),
    );
  }

  @override
  Future<Map<String, int>> fetchCollectionQuantities(
    int collectionId,
    List<String> cardIds, {
    TcgGameId? gameId,
  }) {
    return _runForGame(
      gameId,
      () => _database.fetchCollectionQuantities(collectionId, cardIds),
    );
  }

  @override
  Future<void> upsertCollectionCard(
    int collectionId,
    String cardId, {
    TcgGameId? gameId,
    required int quantity,
    required bool foil,
    required bool altArt,
  }) {
    return _runForGame(
      gameId,
      () => _database.upsertCollectionCard(
        collectionId,
        cardId,
        quantity: quantity,
        foil: foil,
        altArt: altArt,
      ),
    );
  }

  @override
  Future<void> upsertCollectionMembership(
    int collectionId,
    String cardId, {
    TcgGameId? gameId,
  }) {
    return _runForGame(
      gameId,
      () => _database.upsertCollectionMembership(collectionId, cardId),
    );
  }

  @override
  Future<void> updateCollectionCard(
    int collectionId,
    String cardId, {
    TcgGameId? gameId,
    int? quantity,
    bool? foil,
    bool? altArt,
  }) {
    return _runForGame(
      gameId,
      () => _database.updateCollectionCard(
        collectionId,
        cardId,
        quantity: quantity,
        foil: foil,
        altArt: altArt,
      ),
    );
  }

  @override
  Future<void> deleteCollectionCard(
    int collectionId,
    String cardId, {
    TcgGameId? gameId,
  }) {
    return _runForGame(
      gameId,
      () => _database.deleteCollectionCard(collectionId, cardId),
    );
  }

  @override
  Future<CardPriceSnapshot?> fetchCardPriceSnapshot(
    String cardId, {
    TcgGameId? gameId,
  }) {
    return _runForGame(gameId, () => _database.fetchCardPriceSnapshot(cardId));
  }

  @override
  Future<void> updateCardPrices(
    String cardId,
    CardPrices prices, {
    TcgGameId? gameId,
    int? updatedAt,
  }) {
    return _runForGame(
      gameId,
      () => _database.updateCardPrices(
        cardId,
        prices,
        updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<void> ensurePricesFresh(String cardId, {TcgGameId? gameId}) {
    return _runForGame(
      gameId,
      () => _priceRepository.ensurePricesFresh(cardId),
    );
  }
}
