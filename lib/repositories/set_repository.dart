import '../domain/domain_models.dart';
import '../models.dart';

abstract class SetRepository {
  Future<List<SetInfo>> fetchAvailableSets({
    TcgGameId? gameId,
  });

  Future<Map<String, String>> fetchSetNamesForCodes(
    List<String> setCodes, {
    TcgGameId? gameId,
  });
}
