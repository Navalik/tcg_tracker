import '../domain/domain_models.dart';
import '../models.dart';

abstract class CollectionRepository {
  Future<List<CollectionInfo>> fetchCollections({
    TcgGameId? gameId,
  });

  Future<int> addCollection(
    String name, {
    TcgGameId? gameId,
    CollectionType type = CollectionType.custom,
    CollectionFilter? filter,
  });

  Future<void> renameCollection(int id, String name, {TcgGameId? gameId});

  Future<void> updateCollectionFilter(
    int id, {
    TcgGameId? gameId,
    CollectionFilter? filter,
  });

  Future<CollectionType?> fetchCollectionTypeById(
    int id, {
    TcgGameId? gameId,
  });

  Future<void> deleteCollection(int id, {TcgGameId? gameId});

  Future<List<CollectionCardEntry>> fetchCollectionCards(
    int collectionId, {
    TcgGameId? gameId,
    int? limit,
    int? offset,
    String? searchQuery,
  });

  Future<Map<String, int>> fetchCollectionQuantities(
    int collectionId,
    List<String> cardIds, {
    TcgGameId? gameId,
  });

  Future<void> upsertCollectionCard(
    int collectionId,
    String cardId, {
    TcgGameId? gameId,
    required int quantity,
    required bool foil,
    required bool altArt,
  });

  Future<void> upsertCollectionMembership(
    int collectionId,
    String cardId, {
    TcgGameId? gameId,
  });

  Future<void> updateCollectionCard(
    int collectionId,
    String cardId, {
    TcgGameId? gameId,
    int? quantity,
    bool? foil,
    bool? altArt,
  });

  Future<void> deleteCollectionCard(
    int collectionId,
    String cardId, {
    TcgGameId? gameId,
  });
}
