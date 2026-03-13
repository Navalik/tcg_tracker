import '../domain/domain_models.dart';
import '../models.dart';

abstract class CatalogRepository {
  Future<int> countCards({TcgGameId? gameId});

  Future<List<SetInfo>> fetchAvailableSets({
    TcgGameId? gameId,
  });

  Future<Map<String, String>> fetchSetNamesForCodes(
    List<String> setCodes, {
    TcgGameId? gameId,
  });
}
