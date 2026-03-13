import '../domain/domain_models.dart';
import '../providers/app_provider_registry.dart';
import '../providers/provider_registry.dart';
import 'app_settings.dart';
import 'game_types.dart';

class GameDefinition {
  const GameDefinition({
    required this.gameId,
    required this.displayName,
    required this.dbFileName,
    required this.requiresPurchase,
    required this.isEnabled,
    required this.capabilities,
    this.runtimeGame,
    this.appSettingsGame,
    this.iapProductId,
    this.providers,
  });

  final TcgGameId gameId;
  final TcgGame? runtimeGame;
  final AppTcgGame? appSettingsGame;
  final String displayName;
  final String dbFileName;
  final bool requiresPurchase;
  final String? iapProductId;
  final bool isEnabled;
  final GameCapabilities capabilities;
  final GameProviderBundle? providers;
}

class GameRegistry {
  GameRegistry._();

  static final GameRegistry instance = GameRegistry._();

  late final Map<TcgGameId, GameDefinition> _definitions =
      <TcgGameId, GameDefinition>{
        TcgGameId.mtg: GameDefinition(
          gameId: TcgGameId.mtg,
          runtimeGame: TcgGame.mtg,
          appSettingsGame: AppTcgGame.mtg,
          displayName: 'Magic',
          dbFileName: 'scryfall.db',
          requiresPurchase: false,
          isEnabled: true,
          capabilities: const GameCapabilities(
            supportsCatalogInstall: true,
            supportsCatalogReimport: true,
            supportsUpdateCheck: true,
            supportsLocalizedSearch: true,
            supportsAdvancedFilters: true,
            supportsDecks: true,
            supportsSideboard: true,
            supportsPricing: true,
            supportsScanner: true,
            supportedUiLanguages: {TcgCardLanguage.en, TcgCardLanguage.it},
            supportedCardLanguages: {TcgCardLanguage.en, TcgCardLanguage.it},
            filterKeys: {
              'query',
              'artist',
              'sets',
              'rarities',
              'colors',
              'types',
              'collector_number',
              'format',
              'languages',
            },
            metadataKeys: {
              'mana_cost',
              'type_line',
              'colors',
              'color_identity',
              'artist',
              'power',
              'toughness',
              'loyalty',
              'legalities',
            },
          ),
          providers: appProviderRegistry.bundleFor(TcgGameId.mtg),
        ),
        TcgGameId.pokemon: GameDefinition(
          gameId: TcgGameId.pokemon,
          runtimeGame: TcgGame.pokemon,
          appSettingsGame: AppTcgGame.pokemon,
          displayName: 'Pokemon',
          dbFileName: 'pokemon.db',
          requiresPurchase: true,
          iapProductId: 'unlock_pokemon',
          isEnabled: true,
          capabilities: const GameCapabilities(
            supportsCatalogInstall: true,
            supportsCatalogReimport: true,
            supportsUpdateCheck: true,
            supportsLocalizedSearch: true,
            supportsAdvancedFilters: true,
            supportsDecks: true,
            supportsSideboard: false,
            supportsPricing: false,
            supportsScanner: true,
            supportedUiLanguages: {TcgCardLanguage.en, TcgCardLanguage.it},
            supportedCardLanguages: {TcgCardLanguage.en, TcgCardLanguage.it},
            filterKeys: {
              'query',
              'sets',
              'rarities',
              'types',
              'collector_number',
              'languages',
              'pokemon.category',
              'pokemon.subtypes',
              'pokemon.regulation_mark',
              'pokemon.stage',
              'hp',
              'artist',
              'colors',
            },
            metadataKeys: {
              'category',
              'types',
              'subtypes',
              'illustrator',
              'attacks',
            },
          ),
          providers: appProviderRegistry.bundleFor(TcgGameId.pokemon),
        ),
        TcgGameId.onePiece: GameDefinition(
          gameId: TcgGameId.onePiece,
          displayName: 'One Piece',
          dbFileName: 'one_piece.db',
          requiresPurchase: true,
          isEnabled: false,
          capabilities: _placeholderCapabilities,
        ),
        TcgGameId.yugioh: GameDefinition(
          gameId: TcgGameId.yugioh,
          displayName: 'Yu-Gi-Oh!',
          dbFileName: 'yugioh.db',
          requiresPurchase: true,
          isEnabled: false,
          capabilities: _placeholderCapabilities,
        ),
        TcgGameId.lorcana: GameDefinition(
          gameId: TcgGameId.lorcana,
          displayName: 'Lorcana',
          dbFileName: 'lorcana.db',
          requiresPurchase: true,
          isEnabled: false,
          capabilities: _placeholderCapabilities,
        ),
      };

  static const GameCapabilities _placeholderCapabilities = GameCapabilities(
    supportsCatalogInstall: false,
    supportsCatalogReimport: false,
    supportsUpdateCheck: false,
    supportsLocalizedSearch: false,
    supportsAdvancedFilters: false,
    supportsDecks: false,
    supportsSideboard: false,
    supportsPricing: false,
    supportsScanner: false,
    supportedUiLanguages: {TcgCardLanguage.en, TcgCardLanguage.it},
    supportedCardLanguages: {TcgCardLanguage.en},
    filterKeys: {},
    metadataKeys: {},
  );

  List<GameDefinition> get allDefinitions =>
      _definitions.values.toList(growable: false);

  List<GameDefinition> get enabledDefinitions => _definitions.values
      .where((definition) => definition.isEnabled)
      .toList(growable: false);

  List<GameDefinition> get enabledRuntimeDefinitions => _definitions.values
      .where(
        (definition) => definition.isEnabled && definition.runtimeGame != null,
      )
      .toList(growable: false);

  GameDefinition defaultDefinition() =>
      definitionForId(TcgGameId.mtg) ?? enabledRuntimeDefinitions.first;

  GameDefinition? definitionForId(TcgGameId gameId) => _definitions[gameId];

  GameDefinition? definitionForRuntimeGame(TcgGame game) {
    for (final definition in _definitions.values) {
      if (definition.runtimeGame == game) {
        return definition;
      }
    }
    return null;
  }

  GameDefinition? definitionForSettingsGame(AppTcgGame game) {
    for (final definition in _definitions.values) {
      if (definition.appSettingsGame == game) {
        return definition;
      }
    }
    return null;
  }

  TcgGameId gameIdForRuntimeGame(TcgGame game) =>
      definitionForRuntimeGame(game)?.gameId ?? TcgGameId.mtg;

  TcgGame runtimeGameForId(TcgGameId gameId) =>
      definitionForId(gameId)?.runtimeGame ?? TcgGame.mtg;

  AppTcgGame appSettingsGameForId(TcgGameId gameId) =>
      definitionForId(gameId)?.appSettingsGame ?? AppTcgGame.mtg;

  String displayNameForRuntimeGame(TcgGame game) =>
      definitionForRuntimeGame(game)?.displayName ??
      defaultDefinition().displayName;

  bool requiresPurchaseForRuntimeGame(TcgGame game) =>
      definitionForRuntimeGame(game)?.requiresPurchase ??
      defaultDefinition().requiresPurchase;

  GameCapabilities capabilitiesForRuntimeGame(TcgGame game) =>
      definitionForRuntimeGame(game)?.capabilities ??
      defaultDefinition().capabilities;

  GameProviderBundle? providersForRuntimeGame(TcgGame game) =>
      definitionForRuntimeGame(game)?.providers;
}
