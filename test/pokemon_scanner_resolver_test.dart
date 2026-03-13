import 'package:flutter_test/flutter_test.dart';
import 'package:tcg_tracker/domain/domain_models.dart';
import 'package:tcg_tracker/models.dart';
import 'package:tcg_tracker/repositories/search_repository.dart';
import 'package:tcg_tracker/services/pokemon_scanner_resolver.dart';

void main() {
  group('PokemonScannerResolver', () {
    test('parses scanner payload with language, foil, set and collector', () {
      const rawPayload =
          '__SCAN_PAYLOAD__{"raw":"Alakazam\\nBASE1 1/102","lockedName":"Alakazam","lockedSet":"BASE1 1","selectedLanguageCode":"it","foil":true}';

      final seed = PokemonScannerResolver.parseSeed(
        rawPayload,
        knownSetCodes: const <String>{'base1'},
      );

      expect(seed, isNotNull);
      expect(seed!.cardName, 'Alakazam');
      expect(seed.setCode, 'base1');
      expect(seed.collectorNumber, '1');
      expect(seed.scannerLanguageCode, 'it');
      expect(seed.isFoil, isTrue);
    });

    test(
      'ranks exact set and collector above ambiguous same-name printings',
      () async {
        final repository = _FakeSearchRepository(
          searchByNameResults: <CardSearchResult>[
            _card(name: 'Alakazam', setCode: 'base2', collectorNumber: '1'),
            _card(name: 'Alakazam', setCode: 'base1', collectorNumber: '2'),
            _card(name: 'Alakazam', setCode: 'base1', collectorNumber: '1'),
          ],
        );

        final resolution = await PokemonScannerResolver.resolve(
          seed: const ScannerOcrSeed(
            query: '1',
            cardName: 'Alakazam',
            setCode: 'base1',
            collectorNumber: '1',
            scannerLanguageCode: 'en',
          ),
          searchRepository: repository,
        );

        expect(resolution.candidates, isNotEmpty);
        expect(resolution.candidates.first.setCode, 'base1');
        expect(resolution.candidates.first.collectorNumber, '1');
        expect(resolution.metrics.exactNameMatches, 3);
        expect(resolution.metrics.exactSetMatches, 2);
        expect(resolution.metrics.exactCollectorMatches, 2);
      },
    );

    test('uses scanner language first and keeps english fallback', () async {
      final repository = _FakeSearchRepository(
        advancedFilterResults: <CardSearchResult>[
          _card(name: 'Alakazam IT', setCode: 'base1', collectorNumber: '1'),
        ],
      );

      await PokemonScannerResolver.resolve(
        seed: const ScannerOcrSeed(
          query: 'Alakazam',
          cardName: 'Alakazam',
          setCode: 'base1',
          collectorNumber: '1',
          scannerLanguageCode: 'it',
        ),
        searchRepository: repository,
      );

      expect(repository.lastLanguages, const <String>['it', 'en']);
      expect(repository.lastGameId, TcgGameId.pokemon);
    });
  });
}

CardSearchResult _card({
  required String name,
  required String setCode,
  required String collectorNumber,
}) {
  return CardSearchResult(
    id: '$setCode-$collectorNumber-$name',
    name: name,
    setCode: setCode,
    setName: setCode.toUpperCase(),
    collectorNumber: collectorNumber,
    rarity: 'rare',
    typeLine: 'Pokemon',
    colors: 'P',
    colorIdentity: 'P',
    imageUri: 'https://example.invalid/$setCode/$collectorNumber.png',
  );
}

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({
    this.searchByNameResults = const <CardSearchResult>[],
    this.advancedFilterResults = const <CardSearchResult>[],
  });

  final List<CardSearchResult> searchByNameResults;
  final List<CardSearchResult> advancedFilterResults;

  List<String> lastLanguages = const <String>[];
  TcgGameId? lastGameId;

  @override
  Future<int> countCardsForFilter(
    CollectionFilter filter, {
    TcgGameId? gameId,
  }) async {
    return 0;
  }

  @override
  Future<int> countCardsForFilterWithSearch(
    CollectionFilter filter, {
    TcgGameId? gameId,
    String? searchQuery,
    List<String> languages = const [],
  }) async {
    return 0;
  }

  @override
  Future<List<CardSearchResult>> fetchCardsForAdvancedFilters(
    CollectionFilter filter, {
    TcgGameId? gameId,
    String? searchQuery,
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) async {
    lastLanguages = languages;
    lastGameId = gameId;
    return advancedFilterResults;
  }

  @override
  Future<List<CardSearchResult>> fetchCardsForFilters({
    TcgGameId? gameId,
    Set<String> setCodes = const {},
    Set<String> rarities = const {},
    Set<String> types = const {},
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) async {
    lastLanguages = languages;
    lastGameId = gameId;
    return const <CardSearchResult>[];
  }

  @override
  Future<List<CardSearchResult>> searchCardsByName(
    String query, {
    TcgGameId? gameId,
    List<String> languages = const [],
    int limit = 200,
    int? offset,
  }) async {
    lastLanguages = languages;
    lastGameId = gameId;
    return searchByNameResults;
  }
}
