import '../domain/domain_models.dart';
import '../models.dart';

class SearchPageRequest {
  const SearchPageRequest({
    this.searchQuery,
    this.languages = const [],
    this.limit = 200,
    this.offset,
  });

  final String? searchQuery;
  final List<String> languages;
  final int limit;
  final int? offset;
}

abstract class SearchRepository {
  Future<List<CardSearchResult>> fetchCardsForFilters({
    TcgGameId? gameId,
    Set<String> setCodes = const {},
    Set<String> rarities = const {},
    Set<String> types = const {},
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  });

  Future<List<CardSearchResult>> searchCardsByName(
    String query, {
    TcgGameId? gameId,
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  });

  Future<List<CardSearchResult>> fetchCardsForAdvancedFilters(
    CollectionFilter filter, {
    TcgGameId? gameId,
    String? searchQuery,
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  });

  Future<int> countCardsForFilter(
    CollectionFilter filter, {
    TcgGameId? gameId,
  });

  Future<int> countCardsForFilterWithSearch(
    CollectionFilter filter, {
    TcgGameId? gameId,
    String? searchQuery,
    List<String> languages = const [],
  });
}
