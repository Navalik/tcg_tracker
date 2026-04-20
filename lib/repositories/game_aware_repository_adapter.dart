import 'dart:isolate';

import '../db/canonical_catalog_store.dart';
import '../domain/domain_models.dart';
import '../models.dart';
import '../services/app_settings.dart';
import '../services/tcg_environment.dart';
import 'legacy_repository_adapter.dart';
import 'repository_registry.dart';
import 'search_repository.dart';
import 'set_repository.dart';

class _CanonicalSetsRequest {
  const _CanonicalSetsRequest({
    required this.databasePath,
    required this.gameId,
    required this.preferredLanguages,
  });

  final String databasePath;
  final TcgGameId gameId;
  final List<String> preferredLanguages;
}

class _CanonicalSetNamesRequest {
  const _CanonicalSetNamesRequest({
    required this.databasePath,
    required this.gameId,
    required this.setCodes,
    required this.preferredLanguages,
  });

  final String databasePath;
  final TcgGameId gameId;
  final List<String> setCodes;
  final List<String> preferredLanguages;
}

class _CanonicalSearchRequest {
  const _CanonicalSearchRequest({
    required this.databasePath,
    required this.gameId,
    required this.filter,
    required this.searchQuery,
    required this.preferredLanguages,
    required this.limit,
    required this.offset,
  });

  final String databasePath;
  final TcgGameId gameId;
  final CollectionFilter filter;
  final String? searchQuery;
  final List<String> preferredLanguages;
  final int limit;
  final int? offset;
}

class _CanonicalCountRequest {
  const _CanonicalCountRequest({
    required this.databasePath,
    required this.gameId,
    required this.filter,
    required this.searchQuery,
    required this.preferredLanguages,
  });

  final String databasePath;
  final TcgGameId gameId;
  final CollectionFilter filter;
  final String? searchQuery;
  final List<String> preferredLanguages;
}

Future<T?> _withCanonicalStoreInBackground<T>(
  String databasePath,
  TcgGameId gameId,
  T Function(CanonicalCatalogStore store) action,
) async {
  final store = await CanonicalCatalogStore.openAtPath(databasePath);
  try {
    if (!store.hasCatalogForGame(gameId)) {
      return null;
    }
    return action(store);
  } finally {
    store.dispose();
  }
}

Future<List<SetInfo>?> _fetchCanonicalSetsInBackground(
  _CanonicalSetsRequest request,
) {
  return _withCanonicalStoreInBackground(
    request.databasePath,
    request.gameId,
    (store) => store.fetchSetsForGame(
      gameId: request.gameId,
      preferredLanguages: request.preferredLanguages,
    ),
  );
}

Future<Map<String, String>?> _fetchCanonicalSetNamesInBackground(
  _CanonicalSetNamesRequest request,
) {
  return _withCanonicalStoreInBackground(
    request.databasePath,
    request.gameId,
    (store) => store.fetchSetNamesForCodesForGame(
      request.gameId,
      request.setCodes,
      preferredLanguages: request.preferredLanguages,
    ),
  );
}

Future<List<CardSearchResult>?> _searchCanonicalCardsInBackground(
  _CanonicalSearchRequest request,
) {
  return _withCanonicalStoreInBackground(
    request.databasePath,
    request.gameId,
    (store) => store.searchCardsForGame(
      gameId: request.gameId,
      filter: request.filter,
      searchQuery: request.searchQuery,
      preferredLanguages: request.preferredLanguages,
      limit: request.limit,
      offset: request.offset,
    ),
  );
}

Future<int?> _countCanonicalCardsInBackground(_CanonicalCountRequest request) {
  return _withCanonicalStoreInBackground(
    request.databasePath,
    request.gameId,
    (store) => store.countCardsForGame(
      gameId: request.gameId,
      filter: request.filter,
      searchQuery: request.searchQuery,
      preferredLanguages: request.preferredLanguages,
    ),
  );
}

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
  Future<List<SetInfo>> fetchAvailableSets({
    TcgGameId? gameId,
    List<String> preferredLanguages = const [],
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.onePiece) {
      final databasePath = await CanonicalCatalogStore.defaultDatabasePath();
      final resolvedLanguages = preferredLanguages.isNotEmpty
          ? _normalizedLanguages(preferredLanguages)
          : await _uiPreferredLanguagesForGame(resolvedGame);
      final canonical = await Isolate.run(
        () => _fetchCanonicalSetsInBackground(
          _CanonicalSetsRequest(
            databasePath: databasePath,
            gameId: resolvedGame,
            preferredLanguages: resolvedLanguages,
          ),
        ),
      );
      if (canonical != null) {
        return canonical;
      }
    }
    return _legacy.fetchAvailableSets(
      gameId: resolvedGame,
      preferredLanguages: preferredLanguages,
    );
  }

  @override
  Future<Map<String, String>> fetchSetNamesForCodes(
    List<String> setCodes, {
    TcgGameId? gameId,
    List<String> preferredLanguages = const [],
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.onePiece) {
      final databasePath = await CanonicalCatalogStore.defaultDatabasePath();
      final resolvedLanguages = preferredLanguages.isNotEmpty
          ? _normalizedLanguages(preferredLanguages)
          : await _uiPreferredLanguagesForGame(resolvedGame);
      final canonical = await Isolate.run(
        () => _fetchCanonicalSetNamesInBackground(
          _CanonicalSetNamesRequest(
            databasePath: databasePath,
            gameId: resolvedGame,
            setCodes: setCodes,
            preferredLanguages: resolvedLanguages,
          ),
        ),
      );
      if (canonical != null) {
        return canonical;
      }
    }
    return _legacy.fetchSetNamesForCodes(
      setCodes,
      gameId: resolvedGame,
      preferredLanguages: preferredLanguages,
    );
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
    if (resolvedGame == TcgGameId.pokemon) {
      return _legacy.fetchCardsForAdvancedFilters(
        CollectionFilter(sets: setCodes, rarities: rarities, types: types),
        gameId: resolvedGame,
        languages: languages,
        limit: limit,
        offset: offset,
      );
    }
    if (resolvedGame != TcgGameId.onePiece) {
      final databasePath = await CanonicalCatalogStore.defaultDatabasePath();
      final resolvedLanguages = await _effectiveLanguages(
        languages,
        resolvedGame,
      );
      final canonical = await Isolate.run(
        () => _searchCanonicalCardsInBackground(
          _CanonicalSearchRequest(
            databasePath: databasePath,
            gameId: resolvedGame,
            filter: CollectionFilter(
              sets: setCodes,
              rarities: rarities,
              types: types,
            ),
            searchQuery: null,
            preferredLanguages: resolvedLanguages,
            limit: limit,
            offset: offset,
          ),
        ),
      );
      if (canonical != null) {
        return canonical;
      }
    }
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

  @override
  Future<List<CardSearchResult>> searchCardsByName(
    String query, {
    TcgGameId? gameId,
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame != TcgGameId.onePiece) {
      final databasePath = await CanonicalCatalogStore.defaultDatabasePath();
      final resolvedLanguages = await _effectiveLanguages(
        languages,
        resolvedGame,
      );
      final canonical = await Isolate.run(
        () => _searchCanonicalCardsInBackground(
          _CanonicalSearchRequest(
            databasePath: databasePath,
            gameId: resolvedGame,
            filter: const CollectionFilter(),
            searchQuery: query,
            preferredLanguages: resolvedLanguages,
            limit: limit,
            offset: offset,
          ),
        ),
      );
      if (canonical != null) {
        return canonical;
      }
    }
    return _legacy.searchCardsByName(
      query,
      gameId: resolvedGame,
      languages: languages,
      limit: limit,
      offset: offset,
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
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame == TcgGameId.pokemon) {
      return _legacy.fetchCardsForAdvancedFilters(
        filter,
        gameId: resolvedGame,
        searchQuery: searchQuery,
        languages: languages,
        limit: limit,
        offset: offset,
      );
    }
    if (resolvedGame != TcgGameId.onePiece) {
      final databasePath = await CanonicalCatalogStore.defaultDatabasePath();
      final resolvedLanguages = await _effectiveLanguages(
        languages,
        resolvedGame,
      );
      final canonical = await Isolate.run(
        () => _searchCanonicalCardsInBackground(
          _CanonicalSearchRequest(
            databasePath: databasePath,
            gameId: resolvedGame,
            filter: filter,
            searchQuery: searchQuery,
            preferredLanguages: resolvedLanguages,
            limit: limit,
            offset: offset,
          ),
        ),
      );
      if (canonical != null) {
        return canonical;
      }
    }
    return _legacy.fetchCardsForAdvancedFilters(
      filter,
      gameId: resolvedGame,
      searchQuery: searchQuery,
      languages: languages,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<int> countCardsForFilter(
    CollectionFilter filter, {
    TcgGameId? gameId,
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame == TcgGameId.pokemon) {
      return _legacy.countCardsForFilter(filter, gameId: resolvedGame);
    }
    if (resolvedGame != TcgGameId.onePiece) {
      final databasePath = await CanonicalCatalogStore.defaultDatabasePath();
      final resolvedLanguages = await _preferredLanguagesForGame(resolvedGame);
      final canonical = await Isolate.run(
        () => _countCanonicalCardsInBackground(
          _CanonicalCountRequest(
            databasePath: databasePath,
            gameId: resolvedGame,
            filter: filter,
            searchQuery: null,
            preferredLanguages: resolvedLanguages,
          ),
        ),
      );
      if (canonical != null) {
        return canonical;
      }
    }
    return _legacy.countCardsForFilter(filter, gameId: resolvedGame);
  }

  @override
  Future<int> countCardsForFilterWithSearch(
    CollectionFilter filter, {
    TcgGameId? gameId,
    String? searchQuery,
    List<String> languages = const [],
  }) async {
    final resolvedGame = _resolvedGameId(gameId);
    if (resolvedGame == TcgGameId.pokemon) {
      return _legacy.countCardsForFilterWithSearch(
        filter,
        gameId: resolvedGame,
        searchQuery: searchQuery,
        languages: languages,
      );
    }
    if (resolvedGame != TcgGameId.onePiece) {
      final databasePath = await CanonicalCatalogStore.defaultDatabasePath();
      final resolvedLanguages = await _effectiveLanguages(
        languages,
        resolvedGame,
      );
      final canonical = await Isolate.run(
        () => _countCanonicalCardsInBackground(
          _CanonicalCountRequest(
            databasePath: databasePath,
            gameId: resolvedGame,
            filter: filter,
            searchQuery: searchQuery,
            preferredLanguages: resolvedLanguages,
          ),
        ),
      );
      if (canonical != null) {
        return canonical;
      }
    }
    return _legacy.countCardsForFilterWithSearch(
      filter,
      gameId: resolvedGame,
      searchQuery: searchQuery,
      languages: languages,
    );
  }

  TcgGameId _resolvedGameId(TcgGameId? gameId) {
    return gameId ?? TcgEnvironmentController.instance.currentGameId;
  }

  Future<List<String>> _preferredLanguagesForGame(TcgGameId gameId) async {
    if (gameId == TcgGameId.onePiece) {
      return const <String>['en'];
    }
    final settingsGame = gameId == TcgGameId.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    final configured = await AppSettings.loadCardLanguagesForGame(settingsGame);
    final normalized = _normalizedLanguages(configured);
    final appLocale = await AppSettings.loadAppLocale();
    final preferredPrimary = appLocale.trim().toLowerCase().startsWith('it')
        ? 'it'
        : 'en';
    final ordered = <String>[];
    if (normalized.contains(preferredPrimary)) {
      ordered.add(preferredPrimary);
    }
    for (final language in normalized) {
      if (!ordered.contains(language)) {
        ordered.add(language);
      }
    }
    if (!ordered.contains('en')) {
      ordered.add('en');
    }
    return ordered;
  }

  Future<List<String>> _uiPreferredLanguagesForGame(TcgGameId gameId) async {
    if (gameId == TcgGameId.onePiece) {
      return const <String>['en'];
    }
    final appLocale = await AppSettings.loadAppLocale();
    if (appLocale.trim().toLowerCase().startsWith('it')) {
      return const <String>['it', 'en'];
    }
    return const <String>['en'];
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
