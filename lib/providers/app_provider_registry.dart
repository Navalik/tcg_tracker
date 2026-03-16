import '../domain/domain_models.dart';
import 'one_piece_pilot_provider.dart';
import 'provider_registry.dart';
import 'scryfall_mtg_price_provider_adapter.dart';
import 'scryfall_mtg_provider_adapter.dart';

const _onePiecePilotProvider = OnePiecePilotProvider();
const _scryfallMtgProvider = ScryfallMtgProviderAdapter();
const _scryfallMtgPriceProvider = ScryfallMtgPriceProviderAdapter();

final ProviderRegistry appProviderRegistry = ProviderRegistry({
  TcgGameId.mtg: const GameProviderBundle(
    gameId: TcgGameId.mtg,
    catalog: _scryfallMtgProvider,
    catalogSync: _scryfallMtgProvider,
    search: _scryfallMtgProvider,
    sets: _scryfallMtgProvider,
    deckRules: _scryfallMtgProvider,
    prices: _scryfallMtgPriceProvider,
  ),
  TcgGameId.pokemon: const GameProviderBundle(gameId: TcgGameId.pokemon),
  TcgGameId.onePiece: const GameProviderBundle(
    gameId: TcgGameId.onePiece,
    catalog: _onePiecePilotProvider,
    catalogSync: _onePiecePilotProvider,
    search: _onePiecePilotProvider,
    sets: _onePiecePilotProvider,
  ),
});
