import '../domain/domain_models.dart';
import 'provider_registry.dart';
import 'scryfall_mtg_provider_adapter.dart';
import 'tcgdex_pokemon_provider.dart';

const _scryfallMtgProvider = ScryfallMtgProviderAdapter();
final _tcgdexPokemonProvider = TcgdexPokemonProvider();

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
  TcgGameId.pokemon: GameProviderBundle(
    gameId: TcgGameId.pokemon,
    catalog: _tcgdexPokemonProvider,
    catalogSync: _tcgdexPokemonProvider,
    search: _tcgdexPokemonProvider,
    sets: _tcgdexPokemonProvider,
    prices: _tcgdexPokemonProvider,
  ),
});
