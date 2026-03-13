import 'dart:convert';

import '../domain/domain_models.dart';
import '../services/price_provider.dart' as legacy_prices;
import '../services/scryfall_api_client.dart';
import 'provider_contracts.dart';

class ScryfallMtgProviderAdapter
    implements
        CatalogProvider,
        CatalogSyncService,
        SearchProvider,
        SetProvider,
        DeckRulesProvider,
        PriceProvider {
  const ScryfallMtgProviderAdapter();

  @override
  CatalogProviderId get providerId => CatalogProviderId.scryfall;

  @override
  TcgGameId get gameId => TcgGameId.mtg;

  @override
  Future<ProviderPrintingBundle?> fetchPrintingByProviderId(
    String providerObjectId,
  ) async {
    final id = providerObjectId.trim();
    if (id.isEmpty) {
      return null;
    }
    final payload = await _fetchJsonMap(Uri.parse('https://api.scryfall.com/cards/$id'));
    if (payload == null) {
      return null;
    }
    return _mapPrintingBundle(payload);
  }

  @override
  Future<CatalogSyncStatus> fetchLatestCatalogStatus({
    required String datasetKey,
  }) async {
    final normalizedKey = datasetKey.trim().toLowerCase();
    if (normalizedKey.isEmpty) {
      return CatalogSyncStatus(
        providerId: providerId,
        gameId: gameId,
        datasetKey: datasetKey,
        remoteAvailable: false,
      );
    }
    final payload = await _fetchJsonMap(
      Uri.parse('https://api.scryfall.com/bulk-data'),
    );
    if (payload == null) {
      return CatalogSyncStatus(
        providerId: providerId,
        gameId: gameId,
        datasetKey: normalizedKey,
        remoteAvailable: false,
      );
    }
    final data = payload['data'];
    if (data is! List) {
      return CatalogSyncStatus(
        providerId: providerId,
        gameId: gameId,
        datasetKey: normalizedKey,
        remoteAvailable: false,
      );
    }
    Map<String, dynamic>? match;
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final mapped = Map<String, dynamic>.from(item);
      final type = (mapped['type'] as String?)?.trim().toLowerCase();
      if (type == normalizedKey) {
        match = mapped;
        break;
      }
    }
    if (match == null) {
      return CatalogSyncStatus(
        providerId: providerId,
        gameId: gameId,
        datasetKey: normalizedKey,
        remoteAvailable: false,
      );
    }
    final downloadUriRaw = (match['download_uri'] as String?)?.trim();
    final updatedAtRaw = (match['updated_at'] as String?)?.trim();
    final sizeBytes = (match['size'] as num?)?.toInt();
    return CatalogSyncStatus(
      providerId: providerId,
      gameId: gameId,
      datasetKey: normalizedKey,
      remoteAvailable: true,
      downloadUri: downloadUriRaw == null || downloadUriRaw.isEmpty
          ? null
          : Uri.tryParse(downloadUriRaw),
      updatedAt: updatedAtRaw == null || updatedAtRaw.isEmpty
          ? null
          : DateTime.tryParse(updatedAtRaw)?.toUtc(),
      sizeBytes: sizeBytes,
    );
  }

  @override
  Future<List<ProviderPrintingBundle>> searchPrintingsByName(
    String query, {
    List<String> languages = const [],
    int limit = 40,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const [];
    }
    final searchQuery = '!"$normalized"';
    final uri = Uri.parse('https://api.scryfall.com/cards/search').replace(
      queryParameters: <String, String>{
        'q': searchQuery,
        'order': 'name',
        'unique': 'prints',
      },
    );
    final payload = await _fetchJsonMap(uri);
    if (payload == null) {
      return const [];
    }
    final data = payload['data'];
    if (data is! List) {
      return const [];
    }
    final normalizedLanguages = languages
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final bundles = <ProviderPrintingBundle>[];
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final mapped = Map<String, dynamic>.from(item);
      final lang = (mapped['lang'] as String?)?.trim().toLowerCase() ?? 'en';
      if (normalizedLanguages.isNotEmpty && !normalizedLanguages.contains(lang)) {
        continue;
      }
      final bundle = _mapPrintingBundle(mapped);
      if (bundle != null) {
        bundles.add(bundle);
      }
      if (bundles.length >= limit) {
        break;
      }
    }
    return bundles;
  }

  @override
  Future<List<CatalogSet>> fetchSets({int limit = 500}) async {
    final payload = await _fetchJsonMap(Uri.parse('https://api.scryfall.com/sets'));
    if (payload == null) {
      return const [];
    }
    final data = payload['data'];
    if (data is! List) {
      return const [];
    }
    final sets = <CatalogSet>[];
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final mapped = Map<String, dynamic>.from(item);
      final set = _mapSet(mapped);
      if (set != null) {
        sets.add(set);
      }
      if (sets.length >= limit) {
        break;
      }
    }
    return sets;
  }

  @override
  Future<CatalogSet?> fetchSetByCode(String setCode) async {
    final normalized = setCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    final payload = await _fetchJsonMap(
      Uri.parse('https://api.scryfall.com/sets/$normalized'),
    );
    if (payload == null) {
      return null;
    }
    return _mapSet(payload);
  }

  @override
  bool supportsFormat(String format) {
    final normalized = format.trim().toLowerCase();
    return normalized.isNotEmpty;
  }

  @override
  Future<bool> isPrintingLegal(
    String providerObjectId, {
    required String format,
  }) async {
    final bundle = await fetchPrintingByProviderId(providerObjectId);
    if (bundle == null) {
      return false;
    }
    final legalities = bundle.card.metadata['legalities'];
    if (legalities is! Map<String, Object?>) {
      return false;
    }
    final key = format.trim().toLowerCase();
    final value = legalities[key]?.toString().trim().toLowerCase();
    return value == 'legal' || value == 'restricted';
  }

  @override
  Future<List<PriceSnapshot>> fetchLatestPrices(String providerObjectId) async {
    final prices = await legacy_prices.ScryfallPriceProvider().fetchPrices(
      providerObjectId,
    );
    if (prices == null) {
      return const [];
    }
    final printingId = _printingId(providerObjectId.trim());
    final capturedAt = DateTime.now().toUtc();
    final snapshots = <PriceSnapshot>[];
    void addPrice(String? raw, String currencyCode, {String? finishKey}) {
      final parsed = double.tryParse((raw ?? '').trim());
      if (parsed == null) {
        return;
      }
      snapshots.add(
        PriceSnapshot(
          printingId: printingId,
          sourceId: PriceSourceId.scryfall,
          currencyCode: currencyCode,
          amount: parsed,
          capturedAt: capturedAt,
          finishKey: finishKey,
        ),
      );
    }

    addPrice(prices.usd, 'usd');
    addPrice(prices.usdFoil, 'usd', finishKey: 'foil');
    addPrice(prices.usdEtched, 'usd', finishKey: 'etched');
    addPrice(prices.eur, 'eur');
    addPrice(prices.eurFoil, 'eur', finishKey: 'foil');
    addPrice(prices.tix, 'tix');
    return snapshots;
  }

  Future<Map<String, dynamic>?> _fetchJsonMap(Uri uri) async {
    final response = await ScryfallApiClient.instance.get(
      uri,
      timeout: const Duration(seconds: 6),
      maxRetries: 2,
    );
    if (response.statusCode != 200) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  ProviderPrintingBundle? _mapPrintingBundle(Map<String, dynamic> payload) {
    final providerObjectId = (payload['id'] as String?)?.trim() ?? '';
    final setCode = (payload['set'] as String?)?.trim().toLowerCase() ?? '';
    final cardName = (payload['name'] as String?)?.trim() ?? '';
    if (providerObjectId.isEmpty || setCode.isEmpty || cardName.isEmpty) {
      return null;
    }
    final oracleId = (payload['oracle_id'] as String?)?.trim();
    final setName = (payload['set_name'] as String?)?.trim() ?? setCode.toUpperCase();
    final collectorNumber =
        (payload['collector_number'] as String?)?.trim() ?? '';
    final lang = ((payload['lang'] as String?)?.trim().toLowerCase() ?? 'en');
    final releasedAtRaw = (payload['released_at'] as String?)?.trim();
    final releasedAt = releasedAtRaw == null || releasedAtRaw.isEmpty
        ? null
        : DateTime.tryParse(releasedAtRaw);
    final cardId = oracleId != null && oracleId.isNotEmpty
        ? 'mtg:card:$oracleId'
        : 'mtg:card:scryfall:$providerObjectId';
    final setId = _setId(setCode);
    final printingId = _printingId(providerObjectId);

    final legalitiesRaw = payload['legalities'];
    final legalities = <String, Object?>{};
    if (legalitiesRaw is Map) {
      for (final entry in legalitiesRaw.entries) {
        final key = entry.key.toString().trim().toLowerCase();
        if (key.isEmpty) {
          continue;
        }
        legalities[key] = entry.value;
      }
    }

    final imageUris = <String, String>{};
    final imageUrisRaw = payload['image_uris'];
    if (imageUrisRaw is Map) {
      for (final entry in imageUrisRaw.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value?.toString().trim() ?? '';
        if (key.isEmpty || value.isEmpty) {
          continue;
        }
        imageUris[key] = value;
      }
    }

    final finishes = <String>{};
    final finishesRaw = payload['finishes'];
    if (finishesRaw is List) {
      for (final item in finishesRaw) {
        final value = item?.toString().trim().toLowerCase() ?? '';
        if (value.isNotEmpty) {
          finishes.add(value);
        }
      }
    }

    final localized = LocalizedCardData(
      cardId: cardId,
      language: lang == 'it' ? TcgCardLanguage.it : TcgCardLanguage.en,
      name: cardName,
      rulesText: (payload['oracle_text'] as String?)?.trim(),
      flavorText: (payload['flavor_text'] as String?)?.trim(),
    );

    final card = CatalogCard(
      cardId: cardId,
      gameId: gameId,
      canonicalName: cardName,
      sortName: (payload['printed_name'] as String?)?.trim(),
      defaultLocalizedData: localized,
      localizedData: [localized],
      metadata: <String, Object?>{
        'mana_cost': payload['mana_cost'],
        'type_line': payload['type_line'],
        'colors': payload['colors'],
        'color_identity': payload['color_identity'],
        'artist': payload['artist'],
        'power': payload['power'],
        'toughness': payload['toughness'],
        'loyalty': payload['loyalty'],
        'legalities': legalities,
      },
    );

    final set = CatalogSet(
      setId: setId,
      gameId: gameId,
      code: setCode,
      canonicalName: setName,
      releaseDate: releasedAt,
      defaultLocalizedData: LocalizedSetData(
        setId: setId,
        language: localized.language,
        name: setName,
      ),
      localizedData: [
        LocalizedSetData(
          setId: setId,
          language: localized.language,
          name: setName,
        ),
      ],
      metadata: <String, Object?>{
        'set_type': payload['set_type'],
        'card_count': payload['printed_size'] ?? payload['card_count'],
      },
    );

    final printing = CardPrintingRef(
      printingId: printingId,
      cardId: cardId,
      setId: setId,
      gameId: gameId,
      collectorNumber: collectorNumber,
      providerMappings: [
        ProviderMapping(
          providerId: providerId,
          objectType: 'printing',
          providerObjectId: providerObjectId,
        ),
      ],
      rarity: (payload['rarity'] as String?)?.trim(),
      releaseDate: releasedAt,
      imageUris: imageUris,
      finishKeys: finishes,
      metadata: <String, Object?>{
        'lang': lang,
        'scryfall_uri': payload['scryfall_uri'],
      },
    );

    return ProviderPrintingBundle(card: card, set: set, printing: printing);
  }

  CatalogSet? _mapSet(Map<String, dynamic> payload) {
    final code = (payload['code'] as String?)?.trim().toLowerCase() ?? '';
    final name = (payload['name'] as String?)?.trim() ?? '';
    if (code.isEmpty || name.isEmpty) {
      return null;
    }
    final setId = _setId(code);
    final releasedAtRaw =
        (payload['released_at'] as String?)?.trim() ??
        (payload['releasedAt'] as String?)?.trim();
    final releasedAt = releasedAtRaw == null || releasedAtRaw.isEmpty
        ? null
        : DateTime.tryParse(releasedAtRaw);
    const language = TcgCardLanguage.en;
    return CatalogSet(
      setId: setId,
      gameId: gameId,
      code: code,
      canonicalName: name,
      releaseDate: releasedAt,
      defaultLocalizedData: LocalizedSetData(
        setId: setId,
        language: language,
        name: name,
      ),
      localizedData: [
        LocalizedSetData(
          setId: setId,
          language: language,
          name: name,
        ),
      ],
      metadata: <String, Object?>{
        'set_type': payload['set_type'],
        'card_count': payload['card_count'],
      },
    );
  }

  String _setId(String setCode) => 'mtg:set:$setCode';

  String _printingId(String providerObjectId) =>
      'mtg:printing:scryfall:$providerObjectId';
}
