import '../db/app_database.dart';

class InventoryService {
  InventoryService._();

  static final InventoryService instance = InventoryService._();

  Future<int> addToInventory(
    String cardId, {
    String? gameId,
    int deltaQty = 1,
  }) async {
    if (deltaQty <= 0) {
      return currentInventoryQty(cardId, gameId: gameId);
    }
    final current = await currentInventoryQty(cardId, gameId: gameId);
    final next = current + deltaQty;
    return setInventoryQty(cardId, next, gameId: gameId);
  }

  Future<int> removeFromInventory(
    String cardId, {
    String? gameId,
    int deltaQty = 1,
  }) async {
    if (deltaQty <= 0) {
      return currentInventoryQty(cardId, gameId: gameId);
    }
    final current = await currentInventoryQty(cardId, gameId: gameId);
    final next = current - deltaQty;
    return setInventoryQty(cardId, next, gameId: gameId);
  }

  Future<int> setInventoryQty(String cardId, int qty, {String? gameId}) async {
    _touchGameScope(gameId);
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      return 0;
    }
    final db = ScryfallDatabase.instance;
    final allCardsId = await db.ensureAllCardsCollectionId();
    final current = await db.fetchOwnedQuantityInAllCards(normalizedId);
    final normalizedQty = qty < 0 ? 0 : qty;

    if (normalizedQty <= 0) {
      await db.deleteCollectionCard(allCardsId, normalizedId);
      if (current > 0) {
        await db.removeCardFromDirectCustomCollections(normalizedId);
      }
      return 0;
    }

    await db.upsertCollectionCard(
      allCardsId,
      normalizedId,
      quantity: normalizedQty,
      foil: false,
      altArt: false,
    );
    if (current <= 0) {
      await db.removeCardFromWishlists(normalizedId);
    }
    return normalizedQty;
  }

  Future<int> currentInventoryQty(String cardId, {String? gameId}) async {
    _touchGameScope(gameId);
    return ScryfallDatabase.instance.fetchOwnedQuantityInAllCards(cardId);
  }
}
  void _touchGameScope(String? gameId) {
    // Game scope is handled by the active TCG DB selected in TcgEnvironment.
    if (gameId == null || gameId.isEmpty) {
      return;
    }
  }
