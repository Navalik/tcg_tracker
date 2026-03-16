import 'dart:io';

import '../domain/domain_models.dart';
import '../services/tcgdex_api_client.dart';
import 'provider_contracts.dart';

class TcgdexPokemonProvider
    implements
        CatalogProvider,
        CatalogSyncService,
        SearchProvider,
        SetProvider,
        PriceProvider {
  TcgdexPokemonProvider({TcgdexApiClient? apiClient})
    : _apiClient = apiClient ?? TcgdexApiClient();

  static const TcgCardLanguage canonicalLanguage = TcgCardLanguage.en;
  static const List<TcgCardLanguage> supportedLanguages = <TcgCardLanguage>[
    TcgCardLanguage.en,
    TcgCardLanguage.it,
  ];
  static const int _setFetchConcurrency = 32;
  static final RegExp _providerObjectIdPattern = RegExp(r'^[a-z0-9-]+$');

  final TcgdexApiClient _apiClient;
  final Map<String, Future<Map<String, dynamic>?>> _setPayloadCache =
      <String, Future<Map<String, dynamic>?>>{};

  @override
  CatalogProviderId get providerId => CatalogProviderId.tcgdex;

  @override
  TcgGameId get gameId => TcgGameId.pokemon;

  @override
  Future<ProviderPrintingBundle?> fetchPrintingByProviderId(
    String providerObjectId,
  ) {
    return fetchPrintingBundle(providerObjectId, languages: supportedLanguages);
  }

  @override
  Future<CatalogSyncStatus> fetchLatestCatalogStatus({
    required String datasetKey,
  }) async {
    final normalizedKey = datasetKey.trim().toLowerCase();
    final probeUri = normalizedKey.isEmpty
        ? _buildUri(
            canonicalLanguage,
            'sets',
            queryParameters: const <String, String>{
              'pagination:itemsPerPage': '1',
            },
          )
        : _buildUri(canonicalLanguage, 'sets/$normalizedKey');
    try {
      final payload = await _apiClient.getJson(probeUri);
      final remoteAvailable =
          payload is Map<String, dynamic> || payload is List<dynamic>;
      return CatalogSyncStatus(
        providerId: providerId,
        gameId: gameId,
        datasetKey: normalizedKey,
        remoteAvailable: remoteAvailable,
        downloadUri: probeUri,
      );
    } catch (_) {
      return CatalogSyncStatus(
        providerId: providerId,
        gameId: gameId,
        datasetKey: normalizedKey,
        remoteAvailable: false,
        downloadUri: probeUri,
      );
    }
  }

  @override
  Future<List<ProviderPrintingBundle>> searchPrintingsByName(
    String query, {
    List<String> languages = const [],
    int limit = 40,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <ProviderPrintingBundle>[];
    }
    final requestedLanguages = _resolveLanguages(languages);
    final searchLanguage = requestedLanguages.first;
    final payload = await _apiClient.getJson(
      _buildUri(
        searchLanguage,
        'cards',
        queryParameters: <String, String>{
          'name': normalizedQuery,
          'pagination:itemsPerPage': '$limit',
        },
      ),
    );
    if (payload is! List) {
      return const <ProviderPrintingBundle>[];
    }
    final bundles = <ProviderPrintingBundle>[];
    for (final item in payload) {
      if (item is! Map) {
        continue;
      }
      final mapped = Map<String, dynamic>.from(item);
      final id = (mapped['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) {
        continue;
      }
      final bundle = await fetchPrintingBundle(
        id,
        languages: requestedLanguages,
      );
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
    final payload = await _apiClient.getJson(
      _buildUri(
        canonicalLanguage,
        'sets',
        queryParameters: <String, String>{'pagination:itemsPerPage': '$limit'},
      ),
    );
    if (payload is! List) {
      return const <CatalogSet>[];
    }
    final sets = <CatalogSet>[];
    for (final item in payload) {
      if (item is! Map) {
        continue;
      }
      final mapped = _mapSet(
        Map<String, dynamic>.from(item),
        canonicalLanguage,
      );
      if (mapped != null) {
        sets.add(mapped);
      }
    }
    return sets;
  }

  @override
  Future<CatalogSet?> fetchSetByCode(String setCode) async {
    return fetchSetByCodeLocalized(setCode, language: canonicalLanguage);
  }

  Future<CatalogSet?> fetchSetByCodeLocalized(
    String setCode, {
    required TcgCardLanguage language,
  }) async {
    final payload = await _fetchSetPayload(setCode, language: language);
    if (payload == null) {
      return null;
    }
    return _mapSet(payload, language);
  }

  Future<List<String>> fetchSetCardIds(
    String setCode, {
    TcgCardLanguage language = canonicalLanguage,
  }) async {
    final payload = await _fetchSetPayload(setCode, language: language);
    if (payload == null) {
      return const <String>[];
    }
    final cards = payload['cards'];
    if (cards is! List) {
      return const <String>[];
    }
    final ids = <String>[];
    for (final item in cards) {
      if (item is! Map) {
        continue;
      }
      final id = (item['id'] as String?)?.trim() ?? '';
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    return ids;
  }

  Future<List<ProviderPrintingBundle>> fetchSetPrintings(
    String setCode, {
    List<TcgCardLanguage> languages = supportedLanguages,
    void Function(int completed, int total)? onProgress,
  }) async {
    final ids = await fetchSetCardIds(setCode);
    if (ids.isEmpty) {
      return const <ProviderPrintingBundle>[];
    }
    final bundlesByIndex = List<ProviderPrintingBundle?>.filled(
      ids.length,
      null,
      growable: false,
    );
    final workerCount = ids.length < _setFetchConcurrency
        ? ids.length
        : _setFetchConcurrency;
    var nextIndex = 0;
    var completed = 0;

    Future<void> worker() async {
      while (true) {
        final currentIndex = nextIndex;
        if (currentIndex >= ids.length) {
          return;
        }
        nextIndex += 1;
        final bundle = await fetchPrintingBundle(
          ids[currentIndex],
          languages: languages,
        );
        bundlesByIndex[currentIndex] = bundle;
        completed += 1;
        onProgress?.call(completed, ids.length);
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    final bundles = <ProviderPrintingBundle>[];
    for (final bundle in bundlesByIndex) {
      if (bundle != null) {
        bundles.add(bundle);
      }
    }
    return bundles;
  }

  Future<ProviderPrintingBundle?> fetchPrintingBundle(
    String providerObjectId, {
    List<TcgCardLanguage> languages = supportedLanguages,
  }) async {
    final normalizedId = _normalizeProviderObjectId(providerObjectId);
    if (normalizedId == null) {
      return null;
    }
    final resolvedLanguages = _resolveLanguages(
      languages.map((language) => language.code).toList(growable: false),
    );
    final localizedPayloads = <TcgCardLanguage, Map<String, dynamic>>{};
    for (final language in resolvedLanguages) {
      try {
        final payload = await _fetchCardPayload(
          normalizedId,
          language: language,
        );
        if (payload != null) {
          localizedPayloads[language] = payload;
        }
      } catch (error) {
        final isCanonical = language == canonicalLanguage;
        if (isCanonical) {
          rethrow;
        }
        if (error.toString().toLowerCase().contains('tcgdex_http_404')) {
          continue;
        }
      }
    }
    final canonicalPayload = localizedPayloads[canonicalLanguage];
    if (canonicalPayload == null) {
      return null;
    }
    return _mapPrintingBundle(canonicalPayload, localizedPayloads);
  }

  @override
  PriceRefreshPolicy get refreshPolicy => const PriceRefreshPolicy(
    ttl: Duration(hours: 24),
    maxConcurrentRequests: 2,
    allowsStaleReads: true,
  );

  @override
  PriceSourceId get sourceId => PriceSourceId.unknown;

  @override
  Future<List<PriceSnapshot>> fetchLatestPrices(
    PriceQuoteRequest request,
  ) async {
    final providerObjectId = _normalizeProviderObjectId(
      request.providerObjectId ?? '',
    );
    if (providerObjectId == null) {
      return const <PriceSnapshot>[];
    }
    final payload = await _fetchCardPayload(
      providerObjectId,
      language: canonicalLanguage,
    );
    if (payload == null) {
      return const <PriceSnapshot>[];
    }
    return _extractPriceSnapshots(payload, request.printingId.trim());
  }

  List<PriceSnapshot> extractPriceSnapshotsFromBundle(
    ProviderPrintingBundle bundle,
  ) {
    final rawPricing = bundle.printing.metadata['raw_pricing'];
    if (rawPricing is! Map) {
      return const <PriceSnapshot>[];
    }
    final payload = <String, dynamic>{
      'pricing': Map<String, dynamic>.from(rawPricing),
    };
    return _extractPriceSnapshots(payload, bundle.printing.printingId);
  }

  CatalogSet? mapSetPayload(
    Map<String, dynamic> payload, {
    required TcgCardLanguage language,
  }) {
    return _mapSet(payload, language);
  }

  ProviderPrintingBundle? mapPrintingBundleFromPayloads(
    Map<String, dynamic> canonicalPayload,
    Map<TcgCardLanguage, Map<String, dynamic>> localizedPayloads,
  ) {
    return _mapPrintingBundle(canonicalPayload, localizedPayloads);
  }

  Future<Map<String, dynamic>?> _fetchCardPayload(
    String providerObjectId, {
    required TcgCardLanguage language,
  }) async {
    try {
      final payload = await _apiClient.getJson(
        _buildUri(language, 'cards/$providerObjectId'),
      );
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      return payload;
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('tcgdex_http_400')) {
        // Ignore malformed/unsupported ids to avoid aborting bulk sync.
        return null;
      }
      if (language != canonicalLanguage) {
        return null;
      }
      if (message.contains('tcgdex_http_404')) {
        // Some printings are not available in all localized catalogs.
        // Treat missing localization as optional and continue with
        // canonical/available languages instead of aborting the sync.
        return null;
      }
      rethrow;
    }
  }

  String? _normalizeProviderObjectId(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (!_providerObjectIdPattern.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  Future<Map<String, dynamic>?> _fetchSetPayload(
    String setCode, {
    required TcgCardLanguage language,
  }) {
    final normalized = setCode.trim();
    if (normalized.isEmpty) {
      return Future<Map<String, dynamic>?>.value(null);
    }
    final resolvedCode = _normalizeTcgdexSetCode(normalized);
    final cacheKey = '${language.code}:$resolvedCode';
    return _setPayloadCache.putIfAbsent(cacheKey, () async {
      for (final candidate in _setEndpointCandidates(resolvedCode)) {
        try {
          final payload = await _apiClient.getJson(
            _buildUri(language, 'sets/$candidate'),
          );
          if (payload is Map<String, dynamic>) {
            return payload;
          }
        } on HttpException catch (error) {
          if (!_isHttp404(error)) {
            rethrow;
          }
        }
      }
      return null;
    });
  }

  Iterable<String> _setEndpointCandidates(String normalized) sync* {
    final emitted = <String>{};
    if (emitted.add(normalized)) {
      yield normalized;
    }
    final zeroPadded = _zeroPadSeriesCode(normalized);
    if (zeroPadded != null && emitted.add(zeroPadded)) {
      yield zeroPadded;
    }
  }

  String _normalizeTcgdexSetCode(String setCode) {
    final normalized = setCode.trim().toLowerCase();
    return _zeroPadSeriesCode(normalized) ?? normalized;
  }

  String? _zeroPadSeriesCode(String setCode) {
    final match = RegExp(r'^(sv)(\d)$').firstMatch(setCode);
    if (match == null) {
      return null;
    }
    return '${match.group(1)}0${match.group(2)}';
  }

  bool _isHttp404(HttpException error) {
    final message = error.message.toLowerCase();
    return message.contains('tcgdex_http_404');
  }

  ProviderPrintingBundle? _mapPrintingBundle(
    Map<String, dynamic> canonicalPayload,
    Map<TcgCardLanguage, Map<String, dynamic>> localizedPayloads,
  ) {
    final providerObjectId = (canonicalPayload['id'] as String?)?.trim() ?? '';
    final localizedSet = canonicalPayload['set'];
    if (providerObjectId.isEmpty || localizedSet is! Map) {
      return null;
    }
    final setMap = Map<String, dynamic>.from(localizedSet);
    final setCode = (setMap['id'] as String?)?.trim().toLowerCase() ?? '';
    final canonicalName = (canonicalPayload['name'] as String?)?.trim() ?? '';
    if (setCode.isEmpty || canonicalName.isEmpty) {
      return null;
    }

    final cardId = _cardId(providerObjectId);
    final setId = _setId(setCode);
    final printingId = _printingId(providerObjectId);
    final localizedCards = <LocalizedCardData>[];
    final localizedSets = <LocalizedSetData>[];
    for (final entry in localizedPayloads.entries) {
      final language = entry.key;
      final payload = entry.value;
      final localizedCard = _mapLocalizedCard(cardId, language, payload);
      if (localizedCard != null) {
        localizedCards.add(localizedCard);
      }
      final localizedSetData = _mapLocalizedSet(
        setId,
        language,
        payload['set'],
      );
      if (localizedSetData != null) {
        localizedSets.add(localizedSetData);
      }
    }
    final defaultLocalizedCard = localizedCards.firstWhere(
      (value) => value.language == canonicalLanguage,
      orElse: () => localizedCards.first,
    );
    final defaultLocalizedSet = localizedSets.firstWhere(
      (value) => value.language == canonicalLanguage,
      orElse: () => localizedSets.first,
    );
    final releaseDateRaw = (canonicalPayload['updated'] as String?)?.trim();
    final updatedAt = releaseDateRaw == null || releaseDateRaw.isEmpty
        ? null
        : DateTime.tryParse(releaseDateRaw)?.toUtc();

    final card = CatalogCard(
      cardId: cardId,
      gameId: gameId,
      canonicalName: canonicalName,
      sortName: _buildPokemonSortName(canonicalPayload),
      defaultLocalizedData: defaultLocalizedCard,
      localizedData: localizedCards,
      metadata: <String, Object?>{
        'provider_object_id': providerObjectId,
        'category': canonicalPayload['category'],
        'dex_id': canonicalPayload['dexId'],
        'description': canonicalPayload['description'],
      },
      pokemon: _mapPokemonMetadata(canonicalPayload),
    );

    final set = CatalogSet(
      setId: setId,
      gameId: gameId,
      code: setCode,
      canonicalName: defaultLocalizedSet.name,
      seriesId: _seriesId(canonicalPayload['set']),
      releaseDate: _parseDate(
        _nestedString(canonicalPayload['set'], 'releaseDate'),
      ),
      defaultLocalizedData: defaultLocalizedSet,
      localizedData: localizedSets,
      metadata: <String, Object?>{
        'serie_id': _nestedString(canonicalPayload['set'], 'serie', 'id'),
        'serie_name': _nestedString(canonicalPayload['set'], 'serie', 'name'),
        'tcg_online': _nestedString(canonicalPayload['set'], 'tcgOnline'),
        'abbreviation_official': _nestedString(
          canonicalPayload['set'],
          'abbreviation',
          'official',
        ),
        'card_count':
            _nestedInt(canonicalPayload['set'], 'cardCount', 'official') ??
            _nestedInt(canonicalPayload['set'], 'cardCount', 'total'),
      },
    );

    final variants = _extractVariantKeys(canonicalPayload);
    final image = (canonicalPayload['image'] as String?)?.trim();
    final imageUris = <String, String>{};
    if (image != null && image.isNotEmpty) {
      imageUris['default'] = image;
      imageUris['high_res'] = '$image/high.webp';
    }
    final printing = CardPrintingRef(
      printingId: printingId,
      cardId: cardId,
      setId: setId,
      gameId: gameId,
      collectorNumber:
          (canonicalPayload['localId'] as String?)?.trim() ?? providerObjectId,
      providerMappings: <ProviderMapping>[
        ProviderMapping(
          providerId: providerId,
          objectType: 'card',
          providerObjectId: providerObjectId,
        ),
        ProviderMapping(
          providerId: providerId,
          objectType: 'printing',
          providerObjectId: providerObjectId,
        ),
        ProviderMapping(
          providerId: CatalogProviderId.pokemonTcgApi,
          objectType: 'legacy_printing',
          providerObjectId: providerObjectId,
        ),
      ],
      rarity: (canonicalPayload['rarity'] as String?)?.trim(),
      releaseDate: _parseDate(
        _nestedString(canonicalPayload['set'], 'releaseDate'),
      ),
      imageUris: imageUris,
      finishKeys: variants,
      metadata: <String, Object?>{
        'local_id': canonicalPayload['localId'],
        'updated_at': updatedAt?.toIso8601String(),
        'legalities': canonicalPayload['legal'],
        if (canonicalPayload['pricing'] is Map)
          'raw_pricing': Map<String, dynamic>.from(
            canonicalPayload['pricing'] as Map,
          ),
      },
    );

    return ProviderPrintingBundle(card: card, set: set, printing: printing);
  }

  CatalogSet? _mapSet(Map<String, dynamic> payload, TcgCardLanguage language) {
    final setCode = (payload['id'] as String?)?.trim().toLowerCase() ?? '';
    final name = (payload['name'] as String?)?.trim() ?? '';
    if (setCode.isEmpty || name.isEmpty) {
      return null;
    }
    final setId = _setId(setCode);
    final localized = LocalizedSetData(
      setId: setId,
      language: language,
      name: name,
      seriesName: _nestedString(payload, 'serie', 'name'),
    );
    return CatalogSet(
      setId: setId,
      gameId: gameId,
      code: setCode,
      canonicalName: localized.name,
      seriesId: _seriesId(payload),
      releaseDate: _parseDate((payload['releaseDate'] as String?)?.trim()),
      defaultLocalizedData: localized,
      localizedData: <LocalizedSetData>[localized],
      metadata: <String, Object?>{
        'serie_id': _nestedString(payload, 'serie', 'id'),
        'serie_name': _nestedString(payload, 'serie', 'name'),
        'card_count':
            _nestedInt(payload, 'cardCount', 'official') ??
            _nestedInt(payload, 'cardCount', 'total'),
      },
    );
  }

  LocalizedCardData? _mapLocalizedCard(
    String cardId,
    TcgCardLanguage language,
    Map<String, dynamic> payload,
  ) {
    final name = (payload['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      return null;
    }
    return LocalizedCardData(
      cardId: cardId,
      language: language,
      name: name,
      subtypeLine: _buildSubtypeLine(payload),
      rulesText: _buildRulesText(payload),
      flavorText: (payload['description'] as String?)?.trim(),
      searchAliases: <String>[
        name,
        if (((payload['localId'] as String?) ?? '').trim().isNotEmpty)
          ((payload['localId'] as String?) ?? '').trim(),
      ],
    );
  }

  LocalizedSetData? _mapLocalizedSet(
    String setId,
    TcgCardLanguage language,
    Object? rawSet,
  ) {
    if (rawSet is! Map) {
      return null;
    }
    final payload = Map<String, dynamic>.from(rawSet);
    final name = (payload['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      return null;
    }
    return LocalizedSetData(
      setId: setId,
      language: language,
      name: name,
      seriesName: _nestedString(payload, 'serie', 'name'),
    );
  }

  PokemonCardMetadata _mapPokemonMetadata(Map<String, dynamic> payload) {
    return PokemonCardMetadata(
      category: (payload['category'] as String?)?.trim(),
      hp: _toInt(payload['hp']),
      types: _stringList(payload['types']),
      subtypes: _subtypes(payload),
      stage: (payload['stage'] as String?)?.trim(),
      evolvesFrom: _firstNonEmpty(
        (payload['evolveFrom'] as String?)?.trim(),
        (payload['evolvesFrom'] as String?)?.trim(),
      ),
      regulationMark: (payload['regulationMark'] as String?)?.trim(),
      retreatCost: _toInt(payload['retreat']),
      weaknesses: _mapWeaknesses(payload['weaknesses']),
      resistances: _mapResistances(payload['resistances']),
      attacks: _mapAttacks(payload['attacks']),
      abilities: _mapAbilities(payload['abilities']),
      illustrator: (payload['illustrator'] as String?)?.trim(),
    );
  }

  List<PriceSnapshot> _extractPriceSnapshots(
    Map<String, dynamic> payload,
    String printingId,
  ) {
    final pricing = payload['pricing'];
    if (pricing is! Map) {
      return const <PriceSnapshot>[];
    }
    final pricingMap = Map<String, dynamic>.from(pricing);
    final snapshots = <PriceSnapshot>[];
    void addSnapshot({
      required PriceSourceId sourceId,
      required String currencyCode,
      required double amount,
      required DateTime capturedAt,
      String? finishKey,
    }) {
      snapshots.add(
        PriceSnapshot(
          printingId: printingId,
          sourceId: sourceId,
          currencyCode: currencyCode,
          amount: amount,
          capturedAt: capturedAt,
          finishKey: finishKey,
        ),
      );
    }

    final cardmarket = pricingMap['cardmarket'];
    if (cardmarket is Map) {
      final cardmarketMap = Map<String, dynamic>.from(cardmarket);
      final capturedAt =
          _parseDateTime(cardmarketMap['updated']) ?? DateTime.now().toUtc();
      final avg = _toDouble(cardmarketMap['avg']);
      if (avg != null) {
        addSnapshot(
          sourceId: PriceSourceId.unknown,
          currencyCode: ((cardmarketMap['unit'] as String?) ?? 'eur')
              .trim()
              .toLowerCase(),
          amount: avg,
          capturedAt: capturedAt,
        );
      }
      final holo = _toDouble(cardmarketMap['avg-holo']);
      if (holo != null) {
        addSnapshot(
          sourceId: PriceSourceId.unknown,
          currencyCode: ((cardmarketMap['unit'] as String?) ?? 'eur')
              .trim()
              .toLowerCase(),
          amount: holo,
          capturedAt: capturedAt,
          finishKey: 'holo',
        );
      }
    }

    final tcgplayer = pricingMap['tcgplayer'];
    if (tcgplayer is Map) {
      final tcgplayerMap = Map<String, dynamic>.from(tcgplayer);
      final capturedAt =
          _parseDateTime(tcgplayerMap['updated']) ?? DateTime.now().toUtc();
      final unit = ((tcgplayerMap['unit'] as String?) ?? 'usd')
          .trim()
          .toLowerCase();
      for (final entry in tcgplayerMap.entries) {
        if (entry.value is! Map) {
          continue;
        }
        final finishKey = entry.key.trim().toLowerCase();
        final values = Map<String, dynamic>.from(entry.value as Map);
        final marketPrice = _toDouble(values['marketPrice']);
        if (marketPrice != null) {
          addSnapshot(
            sourceId: PriceSourceId.unknown,
            currencyCode: unit,
            amount: marketPrice,
            capturedAt: capturedAt,
            finishKey: finishKey,
          );
        }
      }
    }
    return snapshots;
  }

  Uri _buildUri(
    TcgCardLanguage language,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(
      '${TcgdexApiClient.baseUrl}/${language.code}/$normalizedPath',
    ).replace(queryParameters: queryParameters);
  }

  List<TcgCardLanguage> _resolveLanguages(List<String> rawLanguages) {
    final resolved = <TcgCardLanguage>[canonicalLanguage];
    for (final raw in rawLanguages) {
      final normalized = raw.trim().toLowerCase();
      final language = switch (normalized) {
        'it' => TcgCardLanguage.it,
        'en' => TcgCardLanguage.en,
        _ => null,
      };
      if (language != null && !resolved.contains(language)) {
        resolved.add(language);
      }
    }
    return resolved;
  }

  String _cardId(String providerObjectId) =>
      'pokemon:card:tcgdex:$providerObjectId';

  String _setId(String setCode) => 'pokemon:set:$setCode';

  String _printingId(String providerObjectId) =>
      'pokemon:printing:tcgdex:$providerObjectId';

  String? _seriesId(Object? rawSet) {
    if (rawSet is! Map) {
      return null;
    }
    final value = _nestedString(
      Map<String, dynamic>.from(rawSet),
      'serie',
      'id',
    );
    if (value == null || value.isEmpty) {
      return null;
    }
    return 'pokemon:series:$value';
  }

  String _buildPokemonSortName(Map<String, dynamic> payload) {
    final name = (payload['name'] as String?)?.trim() ?? '';
    final localId = (payload['localId'] as String?)?.trim() ?? '';
    if (localId.isEmpty) {
      return name;
    }
    return '$name $localId';
  }

  String? _buildSubtypeLine(Map<String, dynamic> payload) {
    final parts = <String>[
      if (((payload['category'] as String?) ?? '').trim().isNotEmpty)
        ((payload['category'] as String?) ?? '').trim(),
      if (((payload['stage'] as String?) ?? '').trim().isNotEmpty)
        ((payload['stage'] as String?) ?? '').trim(),
    ];
    final subtypes = _subtypes(payload);
    if (subtypes.isNotEmpty) {
      parts.add(subtypes.join(' / '));
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' - ');
  }

  String? _buildRulesText(Map<String, dynamic> payload) {
    final parts = <String>[];
    final abilities = _mapAbilities(payload['abilities']);
    for (final ability in abilities) {
      final text = ability.text?.trim() ?? '';
      if (text.isEmpty) {
        continue;
      }
      parts.add('${ability.name}: $text');
    }
    final attacks = _mapAttacks(payload['attacks']);
    for (final attack in attacks) {
      final buffer = StringBuffer(attack.name);
      final damage = attack.damage?.trim() ?? '';
      if (damage.isNotEmpty) {
        buffer.write(' [$damage]');
      }
      final text = attack.text?.trim() ?? '';
      if (text.isNotEmpty) {
        buffer.write(': $text');
      }
      parts.add(buffer.toString());
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('\n');
  }

  Set<String> _extractVariantKeys(Map<String, dynamic> payload) {
    final raw = payload['variants'];
    if (raw is! Map) {
      return const <String>{};
    }
    final result = <String>{};
    for (final entry in raw.entries) {
      if (entry.value == true) {
        final key = entry.key.toString().trim().toLowerCase();
        if (key.isNotEmpty) {
          result.add(key);
        }
      }
    }
    return result;
  }

  List<String> _subtypes(Map<String, dynamic> payload) {
    final category = (payload['category'] as String?)?.trim() ?? '';
    final stage = (payload['stage'] as String?)?.trim() ?? '';
    final values = <String>[..._stringList(payload['types'])];
    if (category.isNotEmpty &&
        category.toLowerCase() != 'pokemon' &&
        !values.contains(category)) {
      values.add(category);
    }
    if (stage.isNotEmpty && !values.contains(stage)) {
      values.add(stage);
    }
    return values;
  }

  List<PokemonAttack> _mapAttacks(Object? raw) {
    if (raw is! List) {
      return const <PokemonAttack>[];
    }
    final result = <PokemonAttack>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final name = (map['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) {
        continue;
      }
      result.add(
        PokemonAttack(
          name: name,
          text: (map['effect'] as String?)?.trim(),
          damage: map['damage']?.toString().trim(),
          energyCost: _stringList(map['cost']),
          convertedEnergyCost: _energyCost(map),
        ),
      );
    }
    return result;
  }

  List<PokemonAbility> _mapAbilities(Object? raw) {
    if (raw is! List) {
      return const <PokemonAbility>[];
    }
    final result = <PokemonAbility>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final name = (map['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) {
        continue;
      }
      result.add(
        PokemonAbility(
          name: name,
          type: ((map['type'] as String?) ?? '').trim(),
          text: (map['effect'] as String?)?.trim(),
        ),
      );
    }
    return result;
  }

  List<PokemonWeakness> _mapWeaknesses(Object? raw) {
    if (raw is! List) {
      return const <PokemonWeakness>[];
    }
    final result = <PokemonWeakness>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final type = (map['type'] as String?)?.trim() ?? '';
      if (type.isEmpty) {
        continue;
      }
      result.add(
        PokemonWeakness(type: type, value: (map['value'] as String?)?.trim()),
      );
    }
    return result;
  }

  List<PokemonResistance> _mapResistances(Object? raw) {
    if (raw is! List) {
      return const <PokemonResistance>[];
    }
    final result = <PokemonResistance>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final type = (map['type'] as String?)?.trim() ?? '';
      if (type.isEmpty) {
        continue;
      }
      result.add(
        PokemonResistance(type: type, value: (map['value'] as String?)?.trim()),
      );
    }
    return result;
  }

  List<String> _stringList(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  int? _energyCost(Map<String, dynamic> attack) {
    final converted = _toInt(attack['convertedEnergyCost']);
    if (converted != null) {
      return converted;
    }
    final cost = attack['cost'];
    if (cost is! List) {
      return null;
    }
    return cost.length;
  }

  String? _nestedString(
    Map<String, dynamic> source,
    String key1, [
    String? key2,
    String? key3,
  ]) {
    Object? current = source[key1];
    if (key2 != null) {
      if (current is! Map) {
        return null;
      }
      current = current[key2];
    }
    if (key3 != null) {
      if (current is! Map) {
        return null;
      }
      current = current[key3];
    }
    final value = current?.toString().trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  int? _nestedInt(
    Map<String, dynamic> source,
    String key1, [
    String? key2,
    String? key3,
  ]) {
    Object? current = source[key1];
    if (key2 != null) {
      if (current is! Map) {
        return null;
      }
      current = current[key2];
    }
    if (key3 != null) {
      if (current is! Map) {
        return null;
      }
      current = current[key3];
    }
    return _toInt(current);
  }

  int? _toInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw.trim());
    }
    return null;
  }

  double? _toDouble(Object? raw) {
    if (raw is double) {
      return raw;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw.trim());
    }
    return null;
  }

  DateTime? _parseDate(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  DateTime? _parseDateTime(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  String? _firstNonEmpty(String? a, String? b) {
    final first = a?.trim() ?? '';
    if (first.isNotEmpty) {
      return first;
    }
    final second = b?.trim() ?? '';
    if (second.isNotEmpty) {
      return second;
    }
    return null;
  }
}
