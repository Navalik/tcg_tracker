import '../domain/domain_models.dart';
import 'provider_contracts.dart';

class GameProviderBundle {
  const GameProviderBundle({
    required this.gameId,
    this.catalog,
    this.catalogSync,
    this.search,
    this.sets,
    this.deckRules,
    this.prices,
  });

  final TcgGameId gameId;
  final CatalogProvider? catalog;
  final CatalogSyncService? catalogSync;
  final SearchProvider? search;
  final SetProvider? sets;
  final DeckRulesProvider? deckRules;
  final PriceProvider? prices;
}

class ProviderRegistry {
  const ProviderRegistry(this._bundles);

  final Map<TcgGameId, GameProviderBundle> _bundles;

  GameProviderBundle? bundleFor(TcgGameId gameId) => _bundles[gameId];

  CatalogProvider? catalogFor(TcgGameId gameId) => _bundles[gameId]?.catalog;

  CatalogSyncService? catalogSyncFor(TcgGameId gameId) =>
      _bundles[gameId]?.catalogSync;

  SearchProvider? searchFor(TcgGameId gameId) => _bundles[gameId]?.search;

  SetProvider? setProviderFor(TcgGameId gameId) => _bundles[gameId]?.sets;

  DeckRulesProvider? deckRulesFor(TcgGameId gameId) =>
      _bundles[gameId]?.deckRules;

  PriceProvider? priceProviderFor(TcgGameId gameId) =>
      _bundles[gameId]?.prices;
}
