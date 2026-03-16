import '../domain/domain_models.dart';
import '../models.dart';

abstract class SetRepository {
  Future<List<SetInfo>> fetchAvailableSets({
    TcgGameId? gameId,
    List<String> preferredLanguages = const [],
  });

  Future<Map<String, String>> fetchSetNamesForCodes(
    List<String> setCodes, {
    TcgGameId? gameId,
    List<String> preferredLanguages = const [],
  });
}
