import 'dart:async';

import 'pokemon_bulk_service.dart';
import 'purchase_manager.dart';
import 'tcg_environment.dart';

abstract class TcgDataSource {
  Future<void> ensureInstalled({
    required void Function(double progress) onProgress,
  });
}

class MagicDataSource implements TcgDataSource {
  const MagicDataSource();

  @override
  Future<void> ensureInstalled({
    required void Function(double progress) onProgress,
  }) async {
    onProgress(1);
  }
}

class PokemonDataSource implements TcgDataSource {
  const PokemonDataSource();

  @override
  Future<void> ensureInstalled({
    required void Function(double progress) onProgress,
  }) async {
    if (!PurchaseManager.instance.canAccessPokemon()) {
      throw StateError('pokemon_locked');
    }
    await PokemonBulkService.instance.ensureInstalled(onProgress: onProgress);
  }
}

class TcgScope {
  const TcgScope({required this.config, required this.dataSource});

  final TcgConfig config;
  final TcgDataSource dataSource;
}

class TcgScopeFactory {
  TcgScopeFactory._();

  static final TcgScopeFactory instance = TcgScopeFactory._();

  static const MagicDataSource _magicDataSource = MagicDataSource();
  static const PokemonDataSource _pokemonDataSource = PokemonDataSource();

  TcgScope scopeFor(TcgGame game) {
    final config = TcgEnvironmentController.instance.configFor(game);
    final dataSource = game == TcgGame.pokemon
        ? _pokemonDataSource
        : _magicDataSource;
    return TcgScope(config: config, dataSource: dataSource);
  }
}
