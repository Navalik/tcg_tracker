import '../domain/domain_models.dart';
import 'provider_contracts.dart';

class OnePiecePilotProvider
    implements
        CatalogProvider,
        CatalogSyncService,
        SearchProvider,
        SetProvider {
  const OnePiecePilotProvider();

  static const String datasetKey = 'one_piece_pilot_v1';

  static final List<ProviderPrintingBundle> catalog = _onePieceCatalogEntries
      .map((entry) => entry.bundle)
      .toList(growable: false);

  @override
  CatalogProviderId get providerId => CatalogProviderId.onePiecePilot;

  @override
  TcgGameId get gameId => TcgGameId.onePiece;

  @override
  Future<ProviderPrintingBundle?> fetchPrintingByProviderId(
    String providerObjectId,
  ) async {
    final normalized = providerObjectId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final entry in _onePieceCatalogEntries) {
      final bundle = entry.bundle;
      final matches = bundle.printing.providerMappings.any(
        (mapping) =>
            mapping.providerObjectId.trim().toLowerCase() == normalized,
      );
      if (matches) {
        return bundle;
      }
    }
    return null;
  }

  @override
  Future<CatalogSyncStatus> fetchLatestCatalogStatus({
    required String datasetKey,
  }) async {
    return CatalogSyncStatus(
      providerId: providerId,
      gameId: gameId,
      datasetKey: OnePiecePilotProvider.datasetKey,
      remoteAvailable: true,
      updatedAt: DateTime.utc(2026, 3, 13),
      sizeBytes: _onePieceCatalogEntries.length * 1024,
    );
  }

  @override
  Future<List<ProviderPrintingBundle>> searchPrintingsByName(
    String query, {
    List<String> languages = const [],
    int limit = 40,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <ProviderPrintingBundle>[];
    }
    final results = <ProviderPrintingBundle>[];
    for (final entry in _onePieceCatalogEntries) {
      final haystacks = <String>{
        entry.bundle.card.canonicalName.toLowerCase(),
        ...entry.bundle.card.localizedData.map(
          (item) => item.name.toLowerCase(),
        ),
        ...entry.bundle.card.localizedData.expand(
          (item) => item.searchAliases.map((alias) => alias.toLowerCase()),
        ),
        entry.bundle.printing.collectorNumber.toLowerCase(),
        entry.bundle.set.code.toLowerCase(),
        entry.bundle.set.canonicalName.toLowerCase(),
      };
      if (haystacks.any((value) => value.contains(normalized))) {
        results.add(entry.bundle);
      }
      if (results.length >= limit) {
        break;
      }
    }
    return results;
  }

  @override
  Future<List<CatalogSet>> fetchSets({int limit = 500}) async {
    final seen = <String>{};
    final results = <CatalogSet>[];
    for (final entry in _onePieceCatalogEntries) {
      if (seen.add(entry.bundle.set.setId)) {
        results.add(entry.bundle.set);
      }
    }
    results.sort((a, b) => a.canonicalName.compareTo(b.canonicalName));
    return results.take(limit).toList(growable: false);
  }

  @override
  Future<CatalogSet?> fetchSetByCode(String setCode) async {
    final normalized = setCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final entry in _onePieceCatalogEntries) {
      if (entry.bundle.set.code.trim().toLowerCase() == normalized) {
        return entry.bundle.set;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> buildLegacyCardMaps() {
    return _onePieceCatalogEntries
        .map((entry) => entry.legacyCardJson)
        .toList(growable: false);
  }
}

class _OnePieceCatalogEntry {
  const _OnePieceCatalogEntry({
    required this.bundle,
    required this.legacyCardJson,
  });

  final ProviderPrintingBundle bundle;
  final Map<String, dynamic> legacyCardJson;
}

Map<String, dynamic> _legacyCardJson({
  required String id,
  required String name,
  required String setCode,
  required String setName,
  required int setTotal,
  required String collectorNumber,
  required String rarity,
  required String typeLine,
  required List<String> colors,
  required String artist,
  required String imageUri,
  required String releasedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'set': setCode,
    'set_name': setName,
    'set_total': setTotal,
    'collector_number': collectorNumber,
    'rarity': rarity,
    'type_line': typeLine,
    'colors': colors,
    'color_identity': colors,
    'artist': artist,
    'lang': 'en',
    'released_at': releasedAt,
    'image_uris': <String, String>{'normal': imageUri},
    'legalities': const <String, String>{},
  };
}

final List<_OnePieceCatalogEntry>
_onePieceCatalogEntries = <_OnePieceCatalogEntry>[
  _OnePieceCatalogEntry(
    bundle: ProviderPrintingBundle(
      card: CatalogCard(
        cardId: 'one_piece:card:pilot:op01-001',
        gameId: TcgGameId.onePiece,
        canonicalName: 'Monkey.D.Luffy',
        defaultLocalizedData: LocalizedCardData(
          cardId: 'one_piece:card:pilot:op01-001',
          languageCode: TcgLanguageCodes.en,
          name: 'Monkey.D.Luffy',
          subtypeLine: 'Leader / Straw Hat Crew',
          searchAliases: <String>['luffy leader'],
        ),
        localizedData: <LocalizedCardData>[
          LocalizedCardData(
            cardId: 'one_piece:card:pilot:op01-001',
            languageCode: TcgLanguageCodes.en,
            name: 'Monkey.D.Luffy',
            subtypeLine: 'Leader / Straw Hat Crew',
            searchAliases: <String>['luffy leader'],
          ),
        ],
        metadata: <String, Object?>{
          'type_line': 'Leader / Straw Hat Crew',
          'colors_json': <String>['R'],
          'color_identity_json': <String>['R'],
        },
      ),
      set: CatalogSet(
        setId: 'one_piece:set:op01',
        gameId: TcgGameId.onePiece,
        code: 'op01',
        canonicalName: 'Romance Dawn',
        releaseDate: DateTime.utc(2022, 7, 22),
        defaultLocalizedData: LocalizedSetData(
          setId: 'one_piece:set:op01',
          languageCode: TcgLanguageCodes.en,
          name: 'Romance Dawn',
        ),
        localizedData: <LocalizedSetData>[
          LocalizedSetData(
            setId: 'one_piece:set:op01',
            languageCode: TcgLanguageCodes.en,
            name: 'Romance Dawn',
          ),
        ],
        metadata: <String, Object?>{'official_total': 121},
      ),
      printing: CardPrintingRef(
        printingId: 'one_piece:printing:pilot:op01-001',
        cardId: 'one_piece:card:pilot:op01-001',
        setId: 'one_piece:set:op01',
        gameId: TcgGameId.onePiece,
        collectorNumber: '001',
        languageCode: TcgLanguageCodes.en,
        rarity: 'L',
        releaseDate: DateTime.utc(2022, 7, 22),
        imageUris: <String, String>{
          'normal': 'https://example.com/one-piece/op01-001-monkey-d-luffy.jpg',
        },
        providerMappings: <ProviderMapping>[
          ProviderMapping(
            providerId: CatalogProviderId.onePiecePilot,
            objectType: 'printing',
            providerObjectId: 'op01-001',
          ),
          ProviderMapping(
            providerId: CatalogProviderId.onePiecePilot,
            objectType: 'legacy_printing',
            providerObjectId: 'one_piece:legacy:op01-001',
          ),
        ],
        metadata: <String, Object?>{
          'type_line': 'Leader / Straw Hat Crew',
          'artist': 'BANDAI',
          'colors_json': <String>['R'],
          'color_identity_json': <String>['R'],
        },
      ),
    ),
    legacyCardJson: {
      'id': 'one_piece:legacy:op01-001',
      'name': 'Monkey.D.Luffy',
      'set': 'op01',
      'set_name': 'Romance Dawn',
      'set_total': 121,
      'collector_number': '001',
      'rarity': 'L',
      'type_line': 'Leader / Straw Hat Crew',
      'colors': <String>['R'],
      'color_identity': <String>['R'],
      'artist': 'BANDAI',
      'lang': 'en',
      'released_at': '2022-07-22',
      'image_uris': <String, String>{
        'normal': 'https://example.com/one-piece/op01-001-monkey-d-luffy.jpg',
      },
      'legalities': <String, String>{},
    },
  ),
  _OnePieceCatalogEntry(
    bundle: ProviderPrintingBundle(
      card: CatalogCard(
        cardId: 'one_piece:card:pilot:op01-025',
        gameId: TcgGameId.onePiece,
        canonicalName: 'Roronoa Zoro',
        defaultLocalizedData: LocalizedCardData(
          cardId: 'one_piece:card:pilot:op01-025',
          languageCode: TcgLanguageCodes.en,
          name: 'Roronoa Zoro',
          subtypeLine: 'Character / Straw Hat Crew',
          searchAliases: <String>['zoro'],
        ),
        localizedData: <LocalizedCardData>[
          LocalizedCardData(
            cardId: 'one_piece:card:pilot:op01-025',
            languageCode: TcgLanguageCodes.en,
            name: 'Roronoa Zoro',
            subtypeLine: 'Character / Straw Hat Crew',
            searchAliases: <String>['zoro'],
          ),
        ],
        metadata: <String, Object?>{
          'type_line': 'Character / Straw Hat Crew',
          'colors_json': <String>['G'],
          'color_identity_json': <String>['G'],
        },
      ),
      set: CatalogSet(
        setId: 'one_piece:set:op01',
        gameId: TcgGameId.onePiece,
        code: 'op01',
        canonicalName: 'Romance Dawn',
        releaseDate: DateTime.utc(2022, 7, 22),
        defaultLocalizedData: LocalizedSetData(
          setId: 'one_piece:set:op01',
          languageCode: TcgLanguageCodes.en,
          name: 'Romance Dawn',
        ),
        localizedData: <LocalizedSetData>[
          LocalizedSetData(
            setId: 'one_piece:set:op01',
            languageCode: TcgLanguageCodes.en,
            name: 'Romance Dawn',
          ),
        ],
        metadata: <String, Object?>{'official_total': 121},
      ),
      printing: CardPrintingRef(
        printingId: 'one_piece:printing:pilot:op01-025',
        cardId: 'one_piece:card:pilot:op01-025',
        setId: 'one_piece:set:op01',
        gameId: TcgGameId.onePiece,
        collectorNumber: '025',
        languageCode: TcgLanguageCodes.en,
        rarity: 'SR',
        releaseDate: DateTime.utc(2022, 7, 22),
        imageUris: <String, String>{
          'normal': 'https://example.com/one-piece/op01-025-zoro.jpg',
        },
        providerMappings: <ProviderMapping>[
          ProviderMapping(
            providerId: CatalogProviderId.onePiecePilot,
            objectType: 'printing',
            providerObjectId: 'op01-025',
          ),
          ProviderMapping(
            providerId: CatalogProviderId.onePiecePilot,
            objectType: 'legacy_printing',
            providerObjectId: 'one_piece:legacy:op01-025',
          ),
        ],
        metadata: <String, Object?>{
          'type_line': 'Character / Straw Hat Crew',
          'artist': 'BANDAI',
          'colors_json': <String>['G'],
          'color_identity_json': <String>['G'],
        },
      ),
    ),
    legacyCardJson: _legacyCardJson(
      id: 'one_piece:legacy:op01-025',
      name: 'Roronoa Zoro',
      setCode: 'op01',
      setName: 'Romance Dawn',
      setTotal: 121,
      collectorNumber: '025',
      rarity: 'SR',
      typeLine: 'Character / Straw Hat Crew',
      colors: <String>['G'],
      artist: 'BANDAI',
      imageUri: 'https://example.com/one-piece/op01-025-zoro.jpg',
      releasedAt: '2022-07-22',
    ),
  ),
  _OnePieceCatalogEntry(
    bundle: ProviderPrintingBundle(
      card: CatalogCard(
        cardId: 'one_piece:card:pilot:op02-013',
        gameId: TcgGameId.onePiece,
        canonicalName: 'Portgas.D.Ace',
        defaultLocalizedData: LocalizedCardData(
          cardId: 'one_piece:card:pilot:op02-013',
          languageCode: TcgLanguageCodes.en,
          name: 'Portgas.D.Ace',
          subtypeLine: 'Character / Whitebeard Pirates',
          searchAliases: <String>['ace'],
        ),
        localizedData: <LocalizedCardData>[
          LocalizedCardData(
            cardId: 'one_piece:card:pilot:op02-013',
            languageCode: TcgLanguageCodes.en,
            name: 'Portgas.D.Ace',
            subtypeLine: 'Character / Whitebeard Pirates',
            searchAliases: <String>['ace'],
          ),
        ],
        metadata: <String, Object?>{
          'type_line': 'Character / Whitebeard Pirates',
          'colors_json': <String>['R'],
          'color_identity_json': <String>['R'],
        },
      ),
      set: CatalogSet(
        setId: 'one_piece:set:op02',
        gameId: TcgGameId.onePiece,
        code: 'op02',
        canonicalName: 'Paramount War',
        releaseDate: DateTime.utc(2022, 11, 4),
        defaultLocalizedData: LocalizedSetData(
          setId: 'one_piece:set:op02',
          languageCode: TcgLanguageCodes.en,
          name: 'Paramount War',
        ),
        localizedData: <LocalizedSetData>[
          LocalizedSetData(
            setId: 'one_piece:set:op02',
            languageCode: TcgLanguageCodes.en,
            name: 'Paramount War',
          ),
        ],
        metadata: <String, Object?>{'official_total': 121},
      ),
      printing: CardPrintingRef(
        printingId: 'one_piece:printing:pilot:op02-013',
        cardId: 'one_piece:card:pilot:op02-013',
        setId: 'one_piece:set:op02',
        gameId: TcgGameId.onePiece,
        collectorNumber: '013',
        languageCode: TcgLanguageCodes.en,
        rarity: 'SR',
        releaseDate: DateTime.utc(2022, 11, 4),
        imageUris: <String, String>{
          'normal': 'https://example.com/one-piece/op02-013-ace.jpg',
        },
        providerMappings: <ProviderMapping>[
          ProviderMapping(
            providerId: CatalogProviderId.onePiecePilot,
            objectType: 'printing',
            providerObjectId: 'op02-013',
          ),
          ProviderMapping(
            providerId: CatalogProviderId.onePiecePilot,
            objectType: 'legacy_printing',
            providerObjectId: 'one_piece:legacy:op02-013',
          ),
        ],
        metadata: <String, Object?>{
          'type_line': 'Character / Whitebeard Pirates',
          'artist': 'BANDAI',
          'colors_json': <String>['R'],
          'color_identity_json': <String>['R'],
        },
      ),
    ),
    legacyCardJson: _legacyCardJson(
      id: 'one_piece:legacy:op02-013',
      name: 'Portgas.D.Ace',
      setCode: 'op02',
      setName: 'Paramount War',
      setTotal: 121,
      collectorNumber: '013',
      rarity: 'SR',
      typeLine: 'Character / Whitebeard Pirates',
      colors: <String>['R'],
      artist: 'BANDAI',
      imageUri: 'https://example.com/one-piece/op02-013-ace.jpg',
      releasedAt: '2022-11-04',
    ),
  ),
  _OnePieceCatalogEntry(
    bundle: ProviderPrintingBundle(
      card: CatalogCard(
        cardId: 'one_piece:card:pilot:op02-059',
        gameId: TcgGameId.onePiece,
        canonicalName: 'Boa Hancock',
        defaultLocalizedData: LocalizedCardData(
          cardId: 'one_piece:card:pilot:op02-059',
          languageCode: TcgLanguageCodes.en,
          name: 'Boa Hancock',
          subtypeLine: 'Character / The Seven Warlords of the Sea',
          searchAliases: <String>['hancock'],
        ),
        localizedData: <LocalizedCardData>[
          LocalizedCardData(
            cardId: 'one_piece:card:pilot:op02-059',
            languageCode: TcgLanguageCodes.en,
            name: 'Boa Hancock',
            subtypeLine: 'Character / The Seven Warlords of the Sea',
            searchAliases: <String>['hancock'],
          ),
        ],
        metadata: <String, Object?>{
          'type_line': 'Character / The Seven Warlords of the Sea',
          'colors_json': <String>['B'],
          'color_identity_json': <String>['B'],
        },
      ),
      set: CatalogSet(
        setId: 'one_piece:set:op02',
        gameId: TcgGameId.onePiece,
        code: 'op02',
        canonicalName: 'Paramount War',
        releaseDate: DateTime.utc(2022, 11, 4),
        defaultLocalizedData: LocalizedSetData(
          setId: 'one_piece:set:op02',
          languageCode: TcgLanguageCodes.en,
          name: 'Paramount War',
        ),
        localizedData: <LocalizedSetData>[
          LocalizedSetData(
            setId: 'one_piece:set:op02',
            languageCode: TcgLanguageCodes.en,
            name: 'Paramount War',
          ),
        ],
        metadata: <String, Object?>{'official_total': 121},
      ),
      printing: CardPrintingRef(
        printingId: 'one_piece:printing:pilot:op02-059',
        cardId: 'one_piece:card:pilot:op02-059',
        setId: 'one_piece:set:op02',
        gameId: TcgGameId.onePiece,
        collectorNumber: '059',
        languageCode: TcgLanguageCodes.en,
        rarity: 'UC',
        releaseDate: DateTime.utc(2022, 11, 4),
        imageUris: <String, String>{
          'normal': 'https://example.com/one-piece/op02-059-hancock.jpg',
        },
        providerMappings: <ProviderMapping>[
          ProviderMapping(
            providerId: CatalogProviderId.onePiecePilot,
            objectType: 'printing',
            providerObjectId: 'op02-059',
          ),
          ProviderMapping(
            providerId: CatalogProviderId.onePiecePilot,
            objectType: 'legacy_printing',
            providerObjectId: 'one_piece:legacy:op02-059',
          ),
        ],
        metadata: <String, Object?>{
          'type_line': 'Character / The Seven Warlords of the Sea',
          'artist': 'BANDAI',
          'colors_json': <String>['B'],
          'color_identity_json': <String>['B'],
        },
      ),
    ),
    legacyCardJson: _legacyCardJson(
      id: 'one_piece:legacy:op02-059',
      name: 'Boa Hancock',
      setCode: 'op02',
      setName: 'Paramount War',
      setTotal: 121,
      collectorNumber: '059',
      rarity: 'UC',
      typeLine: 'Character / The Seven Warlords of the Sea',
      colors: <String>['B'],
      artist: 'BANDAI',
      imageUri: 'https://example.com/one-piece/op02-059-hancock.jpg',
      releasedAt: '2022-11-04',
    ),
  ),
];
