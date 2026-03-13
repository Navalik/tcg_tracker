import '../domain/domain_models.dart';
import '../db/app_database.dart';
import '../services/price_provider.dart';

abstract class PriceRepository {
  Future<CardPriceSnapshot?> fetchCardPriceSnapshot(
    String cardId, {
    TcgGameId? gameId,
  });

  Future<void> updateCardPrices(
    String cardId,
    CardPrices prices, {
    TcgGameId? gameId,
    int? updatedAt,
  });

  Future<void> ensurePricesFresh(
    String cardId, {
    TcgGameId? gameId,
  });
}
