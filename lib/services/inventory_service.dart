import '../db/app_database.dart';

class InventoryService {
  InventoryService._();

  static final InventoryService instance = InventoryService._();

  Future<int> addToInventory(
    String cardId, {
    String? printingId,
    String? gameId,
    int deltaQty = 1,
  }) async {
    if (deltaQty <= 0) {
      return currentInventoryQty(
        cardId,
        printingId: printingId,
        gameId: gameId,
      );
    }
    final current = await currentInventoryQty(
      cardId,
      printingId: printingId,
      gameId: gameId,
    );
    final next = current + deltaQty;
    return setInventoryQty(
      cardId,
      next,
      printingId: printingId,
      gameId: gameId,
    );
  }

  Future<int> removeFromInventory(
    String cardId, {
    String? printingId,
    String? gameId,
    int deltaQty = 1,
  }) async {
    if (deltaQty <= 0) {
      return currentInventoryQty(
        cardId,
        printingId: printingId,
        gameId: gameId,
      );
    }
    final current = await currentInventoryQty(
      cardId,
      printingId: printingId,
      gameId: gameId,
    );
    final next = current - deltaQty;
    return setInventoryQty(
      cardId,
      next,
      printingId: printingId,
      gameId: gameId,
    );
  }

  Future<int> setInventoryQty(
    String cardId,
    int qty, {
    String? printingId,
    String? gameId,
  }) async {
    _touchGameScope(gameId);
    final normalizedId = cardId.trim();
    final normalizedPrintingId = printingId?.trim();
    if (normalizedId.isEmpty) {
      return 0;
    }
    final db = ScryfallDatabase.instance;
    final allCardsId = await db.ensureAllCardsCollectionId();
    final current = await db.fetchOwnedQuantityInAllCards(
      normalizedId,
      printingId: normalizedPrintingId,
    );
    final normalizedQty = qty < 0 ? 0 : qty;

    if (normalizedQty <= 0) {
      await db.deleteCollectionCard(
        allCardsId,
        normalizedId,
        printingId: normalizedPrintingId,
      );
      if (current > 0) {
        await db.removeCardFromDirectCustomCollections(
          normalizedId,
          printingId: normalizedPrintingId,
        );
      }
      return 0;
    }

    await db.upsertCollectionCard(
      allCardsId,
      normalizedId,
      printingId: normalizedPrintingId,
      quantity: normalizedQty,
      foil: false,
      altArt: false,
    );
    if (current <= 0) {
      await db.removeCardFromWishlists(
        normalizedId,
        printingId: normalizedPrintingId,
      );
    }
    return normalizedQty;
  }

  Future<int> currentInventoryQty(
    String cardId, {
    String? printingId,
    String? gameId,
  }) async {
    _touchGameScope(gameId);
    return ScryfallDatabase.instance.fetchOwnedQuantityInAllCards(
      cardId,
      printingId: printingId,
    );
  }

  void _touchGameScope(String? gameId) {
    if (gameId == null || gameId.isEmpty) {
      return;
    }
  }
}
