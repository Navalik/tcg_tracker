import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import '../db/app_database.dart';

enum TcgGame { mtg, pokemon }

class TcgConfig {
  const TcgConfig({
    required this.game,
    required this.displayName,
    required this.dbFileName,
    required this.requiresPurchase,
    this.iapProductId,
  });

  final TcgGame game;
  final String displayName;
  final String dbFileName;
  final bool requiresPurchase;
  final String? iapProductId;
}

class TcgEnvironmentController extends ChangeNotifier {
  TcgEnvironmentController._();

  static final TcgEnvironmentController instance = TcgEnvironmentController._();

  static const TcgConfig mtgConfig = TcgConfig(
    game: TcgGame.mtg,
    displayName: 'Magic',
    dbFileName: 'scryfall.db',
    requiresPurchase: false,
  );

  static const TcgConfig pokemonConfig = TcgConfig(
    game: TcgGame.pokemon,
    displayName: 'Pokemon',
    dbFileName: 'pokemon.db',
    requiresPurchase: true,
    iapProductId: 'unlock_pokemon',
  );

  static const Map<TcgGame, TcgConfig> _configs = {
    TcgGame.mtg: mtgConfig,
    TcgGame.pokemon: pokemonConfig,
  };

  TcgGame _currentGame = TcgGame.mtg;
  bool _initialized = false;

  TcgGame get currentGame => _currentGame;
  bool get initialized => _initialized;
  TcgConfig get currentConfig => _configs[_currentGame] ?? mtgConfig;

  TcgConfig configFor(TcgGame game) => _configs[game] ?? mtgConfig;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    final stored = await AppSettings.loadSelectedTcgGame();
    _currentGame = stored == AppTcgGame.pokemon ? TcgGame.pokemon : TcgGame.mtg;
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
    await AppSettings.saveSelectedTcgGame(
      game == TcgGame.pokemon ? AppTcgGame.pokemon : AppTcgGame.mtg,
    );
    await ScryfallDatabase.instance.setDatabaseFileName(currentConfig.dbFileName);
    notifyListeners();
  }
}
