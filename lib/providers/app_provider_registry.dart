import '../domain/domain_models.dart';
import 'provider_registry.dart';
import 'scryfall_mtg_provider_adapter.dart';

const _scryfallMtgProvider = ScryfallMtgProviderAdapter();

final ProviderRegistry appProviderRegistry = ProviderRegistry({
  TcgGameId.mtg: const GameProviderBundle(
    gameId: TcgGameId.mtg,
    catalog: _scryfallMtgProvider,
    catalogSync: _scryfallMtgProvider,
    search: _scryfallMtgProvider,
    sets: _scryfallMtgProvider,
    deckRules: _scryfallMtgProvider,
    prices: _scryfallMtgProvider,
  ),
  TcgGameId.pokemon: const GameProviderBundle(gameId: TcgGameId.pokemon),
});
