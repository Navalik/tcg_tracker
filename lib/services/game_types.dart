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
