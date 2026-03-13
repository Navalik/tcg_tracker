import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcg_tracker/db/app_database.dart';
import 'package:tcg_tracker/services/app_settings.dart';
import 'package:tcg_tracker/services/tcg_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('environment switches runtime game and db file coherently', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'selected_tcg': 'mtg',
    });

    await ScryfallDatabase.instance.close();
    await TcgEnvironmentController.instance.init();

    expect(TcgEnvironmentController.instance.currentGame, equals(TcgGame.mtg));
    expect(
      TcgEnvironmentController.instance.currentConfig.dbFileName,
      equals('scryfall.db'),
    );
    expect(ScryfallDatabase.instance.databaseFileName, equals('scryfall.db'));

    await TcgEnvironmentController.instance.setGame(TcgGame.pokemon);

    expect(
      TcgEnvironmentController.instance.currentGame,
      equals(TcgGame.pokemon),
    );
    expect(
      TcgEnvironmentController.instance.currentConfig.dbFileName,
      equals('pokemon.db'),
    );
    expect(ScryfallDatabase.instance.databaseFileName, equals('pokemon.db'));
    expect(await AppSettings.loadSelectedTcgGame(), equals(AppTcgGame.pokemon));
  });
}
