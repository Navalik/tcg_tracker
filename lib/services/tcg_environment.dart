import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import '../db/app_database.dart';
import '../domain/domain_models.dart';
import '../providers/provider_registry.dart';
import 'game_types.dart';
import 'game_registry.dart';
export 'game_types.dart';

class TcgEnvironmentController extends ChangeNotifier {
  TcgEnvironmentController._();

  static final TcgEnvironmentController instance = TcgEnvironmentController._();

  TcgGame _currentGame = TcgGame.mtg;
  bool _initialized = false;

  TcgGame get currentGame => _currentGame;
  bool get initialized => _initialized;
  GameDefinition get currentDefinition =>
      GameRegistry.instance.definitionForRuntimeGame(_currentGame) ??
      GameRegistry.instance.defaultDefinition();
  TcgConfig get currentConfig => _configFromDefinition(currentDefinition);
  TcgGameId get currentGameId => currentDefinition.gameId;
  GameCapabilities get currentCapabilities => currentDefinition.capabilities;
  GameProviderBundle? get currentProviders => currentDefinition.providers;

  TcgConfig configFor(TcgGame game) {
    final definition =
        GameRegistry.instance.definitionForRuntimeGame(game) ??
        GameRegistry.instance.defaultDefinition();
    return _configFromDefinition(definition);
  }

  GameDefinition definitionFor(TcgGame game) =>
      GameRegistry.instance.definitionForRuntimeGame(game) ??
      GameRegistry.instance.defaultDefinition();

  GameCapabilities capabilitiesFor(TcgGame game) =>
      definitionFor(game).capabilities;

  GameProviderBundle? providersFor(TcgGame game) => definitionFor(game).providers;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    final stored = await AppSettings.loadSelectedTcgGame();
    final definition =
        GameRegistry.instance.definitionForSettingsGame(stored) ??
        GameRegistry.instance.defaultDefinition();
    _currentGame = definition.runtimeGame ?? TcgGame.mtg;
    await ScryfallDatabase.instance.setDatabaseFileName(currentConfig.dbFileName);
    _initialized = true;
    notifyListeners();
  }

  Future<void> setGame(TcgGame game) async {
    await init();
    if (_currentGame == game) {
      return;
    }
    _currentGame = game;
    await AppSettings.saveSelectedTcgGame(definitionFor(game).appSettingsGame ?? AppTcgGame.mtg);
    await ScryfallDatabase.instance.setDatabaseFileName(currentConfig.dbFileName);
    notifyListeners();
  }

  TcgConfig _configFromDefinition(GameDefinition definition) {
    return TcgConfig(
      game: definition.runtimeGame ?? TcgGame.mtg,
      displayName: definition.displayName,
      dbFileName: definition.dbFileName,
      requiresPurchase: definition.requiresPurchase,
      iapProductId: definition.iapProductId,
    );
  }
}
