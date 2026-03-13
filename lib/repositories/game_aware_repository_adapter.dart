import '../db/canonical_catalog_store.dart';
import '../domain/domain_models.dart';
import '../models.dart';
import '../services/app_settings.dart';
import '../services/tcg_environment.dart';
import 'legacy_repository_adapter.dart';
import 'repository_registry.dart';
import 'search_repository.dart';
import 'set_repository.dart';

class GameAwareRepositoryAdapter implements SearchRepository, SetRepository {
  GameAwareRepositoryAdapter({LegacyScryfallRepositoryAdapter? legacy})
    : _legacy = legacy ?? LegacyScryfallRepositoryAdapter();

  final LegacyScryfallRepositoryAdapter _legacy;

  static RepositoryRegistry createRegistry({
    LegacyScryfallRepositoryAdapter? legacy,
  }) {
    final gameAware = GameAwareRepositoryAdapter(legacy: legacy);
    final base = legacy ?? LegacyScryfallRepositoryAdapter();
    return RepositoryRegistry(
      catalog: base,
      sets: gameAware,
      search: gameAware,
      collections: base,
      prices: base,
    );
  }

  @override
  Future<List<SetInfo>> fetchAvailableSets({TcgGameId? gameId}) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.pokemon) {
      return _legacy.fetchAvailableSets(gameId: resolvedGame);
    }
    final store = await CanonicalCatalogStore.openDefault();
    try {
      return store.fetchPokemonSets(
        preferredLanguages: await _preferredLanguagesForGame(resolvedGame),
      );
    } finally {
      store.dispose();
    }
  }

  @override
  Future<Map<String, String>> fetchSetNamesForCodes(
    List<String> setCodes, {
    TcgGameId? gameId,
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.pokemon) {
      return _legacy.fetchSetNamesForCodes(setCodes, gameId: resolvedGame);
    }
    final store = await CanonicalCatalogStore.openDefault();
    try {
      return store.fetchPokemonSetNamesForCodes(
        setCodes,
        preferredLanguages: await _preferredLanguagesForGame(resolvedGame),
      );
    } finally {
      store.dispose();
    }
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
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.pokemon) {
      return _legacy.fetchCardsForFilters(
        gameId: resolvedGame,
        setCodes: setCodes,
        rarities: rarities,
        types: types,
        languages: languages,
        limit: limit,
        offset: offset,
      );
    }
    return fetchCardsForAdvancedFilters(
      CollectionFilter(sets: setCodes, rarities: rarities, types: types),
      gameId: resolvedGame,
      languages: languages,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<CardSearchResult>> searchCardsByName(
    String query, {
    TcgGameId? gameId,
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.pokemon) {
      return _legacy.searchCardsByName(
        query,
        gameId: resolvedGame,
        languages: languages,
        limit: limit,
        offset: offset,
      );
    }
    final store = await CanonicalCatalogStore.openDefault();
    try {
      return store.searchPokemonCards(
        filter: const CollectionFilter(),
        searchQuery: query,
        preferredLanguages: await _effectiveLanguages(languages, resolvedGame),
        limit: limit,
        offset: offset,
      );
    } finally {
      store.dispose();
    }
  }

  @override
  Future<List<CardSearchResult>> fetchCardsForAdvancedFilters(
    CollectionFilter filter, {
    TcgGameId? gameId,
    String? searchQuery,
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.pokemon) {
      return _legacy.fetchCardsForAdvancedFilters(
        filter,
        gameId: resolvedGame,
        searchQuery: searchQuery,
        languages: languages,
        limit: limit,
        offset: offset,
      );
    }
    final store = await CanonicalCatalogStore.openDefault();
    try {
      return store.searchPokemonCards(
        filter: filter,
        searchQuery: searchQuery,
        preferredLanguages: await _effectiveLanguages(languages, resolvedGame),
        limit: limit,
        offset: offset,
      );
    } finally {
      store.dispose();
    }
  }

  @override
  Future<int> countCardsForFilter(
    CollectionFilter filter, {
    TcgGameId? gameId,
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.pokemon) {
      return _legacy.countCardsForFilter(filter, gameId: resolvedGame);
    }
    final store = await CanonicalCatalogStore.openDefault();
    try {
      return store.countPokemonCards(
        filter: filter,
        preferredLanguages: await _preferredLanguagesForGame(resolvedGame),
      );
    } finally {
      store.dispose();
    }
  }

  @override
  Future<int> countCardsForFilterWithSearch(
    CollectionFilter filter, {
    TcgGameId? gameId,
    String? searchQuery,
    List<String> languages = const [],
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.pokemon) {
      return _legacy.countCardsForFilterWithSearch(
        filter,
        gameId: resolvedGame,
        searchQuery: searchQuery,
        languages: languages,
      );
    }
    final store = await CanonicalCatalogStore.openDefault();
    try {
      return store.countPokemonCards(
        filter: filter,
        searchQuery: searchQuery,
        preferredLanguages: await _effectiveLanguages(languages, resolvedGame),
      );
    } finally {
      store.dispose();
    }
  }

  TcgGameId _resolvedGameId(TcgGameId? gameId) {
    return gameId ?? TcgEnvironmentController.instance.currentGameId;
  }

  Future<List<String>> _preferredLanguagesForGame(TcgGameId gameId) async {
    final settingsGame = gameId == TcgGameId.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    final configured = await AppSettings.loadCardLanguagesForGame(settingsGame);
    return _normalizedLanguages(configured);
  }

  Future<List<String>> _effectiveLanguages(
    List<String> requested,
    TcgGameId gameId,
  ) async {
    if (requested.isNotEmpty) {
      return _normalizedLanguages(requested);
    }
    return _preferredLanguagesForGame(gameId);
  }

  List<String> _normalizedLanguages(List<String> values) {
    final normalized = values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <String>['en'];
    }
    if (normalized.contains('en')) {
      return normalized;
    }
    return <String>[...normalized, 'en'];
  }
}
