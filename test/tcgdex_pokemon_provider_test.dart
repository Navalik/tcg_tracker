import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tcg_tracker/db/canonical_catalog_store.dart';
import 'package:tcg_tracker/domain/domain_models.dart';
import 'package:tcg_tracker/models.dart';
import 'package:tcg_tracker/providers/tcgdex_pokemon_provider.dart';
import 'package:tcg_tracker/services/pokemon_canonical_import_service.dart';
import 'package:tcg_tracker/services/tcgdex_api_client.dart';

void main() {
  test(
    'TCGdex provider maps Pokemon printing with italian localization',
    () async {
      final provider = TcgdexPokemonProvider(
        apiClient: TcgdexApiClient(httpClient: _fakeTcgdexClient()),
      );

      final bundle = await provider.fetchPrintingByProviderId('base1-1');

      expect(bundle, isNotNull);
      expect(bundle!.card.cardId, 'pokemon:card:tcgdex:base1-1');
      expect(bundle.printing.printingId, 'pokemon:printing:tcgdex:base1-1');
      expect(bundle.set.setId, 'pokemon:set:base1');
      expect(bundle.card.pokemon?.illustrator, 'Ken Sugimori');
      expect(bundle.card.pokemon?.attacks.first.name, 'Confuse Ray');
      expect(
        bundle.card.localizedData.map((item) => item.language),
        containsAll(<TcgCardLanguage>[TcgCardLanguage.en, TcgCardLanguage.it]),
      );
      expect(
        bundle.printing.providerMappings.map((item) => item.providerId),
        containsAll(<CatalogProviderId>[
          CatalogProviderId.tcgdex,
          CatalogProviderId.pokemonTcgApi,
        ]),
      );
    },
  );

  test(
    'Pokemon canonical import stores cards and compatibility mappings',
    () async {
      final provider = TcgdexPokemonProvider(
        apiClient: TcgdexApiClient(httpClient: _fakeTcgdexClient()),
      );
      final store = CanonicalCatalogStore.openInMemory();
      addTearDown(store.dispose);

      final service = PokemonCanonicalImportService(
        provider: provider,
        store: store,
      );
      final report = await service.importProfile(
        profile: 'starter',
        languages: const <TcgCardLanguage>[
          TcgCardLanguage.en,
          TcgCardLanguage.it,
        ],
      );

      expect(report.cardsImported, greaterThan(0));
      expect(report.setsImported, equals(3));
      expect(store.countTableRows('catalog_cards'), greaterThan(0));
      expect(store.countTableRows('catalog_sets'), equals(3));
      expect(store.countTableRows('provider_mappings'), greaterThan(0));
      expect(store.countTableRows('pokemon_printing_metadata'), greaterThan(0));
    },
  );

  test(
    'Pokemon canonical import supports full profile from live set index',
    () async {
      final provider = TcgdexPokemonProvider(
        apiClient: TcgdexApiClient(httpClient: _fakeTcgdexClient()),
      );
      final store = CanonicalCatalogStore.openInMemory();
      addTearDown(store.dispose);

      final service = PokemonCanonicalImportService(
        provider: provider,
        store: store,
      );
      final report = await service.importProfile(
        profile: 'full',
        languages: const <TcgCardLanguage>[
          TcgCardLanguage.en,
          TcgCardLanguage.it,
        ],
      );

      expect(report.setsImported, greaterThan(0));
      expect(report.cardsImported, greaterThan(0));
      expect(store.countTableRows('catalog_sets'), greaterThan(0));
      expect(store.countTableRows('catalog_cards'), greaterThan(0));
    },
  );

  test('Pokemon canonical batch snapshot round-trips through json', () async {
    final provider = TcgdexPokemonProvider(
      apiClient: TcgdexApiClient(httpClient: _fakeTcgdexClient()),
    );
    final service = PokemonCanonicalImportService(provider: provider);
    CanonicalCatalogImportBatch? capturedBatch;

    await service.importProfile(
      profile: 'starter',
      languages: const <TcgCardLanguage>[
        TcgCardLanguage.en,
        TcgCardLanguage.it,
      ],
      onBatchBuilt: (batch) {
        capturedBatch = batch;
      },
    );

    expect(capturedBatch, isNotNull);
    final encoded = jsonEncode(canonicalCatalogBatchToJson(capturedBatch!));
    final decoded = canonicalCatalogBatchFromJson(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );

    expect(decoded.cards.length, equals(capturedBatch!.cards.length));
    expect(decoded.sets.length, equals(capturedBatch!.sets.length));
    expect(decoded.printings.length, equals(capturedBatch!.printings.length));
    expect(
      decoded.providerMappings.length,
      equals(capturedBatch!.providerMappings.length),
    );
    expect(
      decoded.priceSnapshots.length,
      equals(capturedBatch!.priceSnapshots.length),
    );
    expect(decoded.cards.first.pokemon?.attacks.first.name, 'Confuse Ray');
    expect(
      decoded.cardLocalizations.map((item) => item.language),
      contains(TcgCardLanguage.it),
    );
  });

  test(
    'Pokemon canonical store supports localized search and advanced filters',
    () async {
      final provider = TcgdexPokemonProvider(
        apiClient: TcgdexApiClient(httpClient: _fakeTcgdexClient()),
      );
      final store = CanonicalCatalogStore.openInMemory();
      addTearDown(store.dispose);

      final service = PokemonCanonicalImportService(
        provider: provider,
        store: store,
      );
      await service.importProfile(
        profile: 'starter',
        languages: const <TcgCardLanguage>[
          TcgCardLanguage.en,
          TcgCardLanguage.it,
        ],
      );

      final localizedResults = store.searchPokemonCards(
        filter: const CollectionFilter(),
        searchQuery: 'alakazam it',
        preferredLanguages: const <String>['it'],
        limit: 20,
      );
      expect(localizedResults, isNotEmpty);
      expect(localizedResults.first.name, 'Alakazam IT');
      expect(localizedResults.first.setName, 'Set Base');

      final filteredCount = store.countPokemonCards(
        filter: const CollectionFilter(
          collectorNumber: '1',
          hpMin: 70,
          hpMax: 90,
          pokemonCategories: <String>{'Pokemon'},
          types: <String>{'Psychic'},
          pokemonStages: <String>{'Stage2'},
        ),
        preferredLanguages: const <String>['en', 'it'],
      );
      expect(filteredCount, equals(1));
    },
  );

  test(
    'Pokemon import remains identity-stable across repeated installs',
    () async {
      final provider = TcgdexPokemonProvider(
        apiClient: TcgdexApiClient(httpClient: _fakeTcgdexClient()),
      );
      final store = CanonicalCatalogStore.openInMemory();
      addTearDown(store.dispose);

      final service = PokemonCanonicalImportService(
        provider: provider,
        store: store,
      );

      await service.importProfile(
        profile: 'starter',
        languages: const <TcgCardLanguage>[
          TcgCardLanguage.en,
          TcgCardLanguage.it,
        ],
      );
      final firstCards = store.countTableRows('catalog_cards');
      final firstPrintings = store.countTableRows('card_printings');
      final firstMappings = store.countTableRows('provider_mappings');

      await service.importProfile(
        profile: 'starter',
        languages: const <TcgCardLanguage>[
          TcgCardLanguage.en,
          TcgCardLanguage.it,
        ],
      );

      expect(store.countTableRows('catalog_cards'), equals(firstCards));
      expect(store.countTableRows('card_printings'), equals(firstPrintings));
      expect(store.countTableRows('provider_mappings'), equals(firstMappings));
    },
  );

  test(
    'Pokemon localized search respects requested language priority',
    () async {
      final provider = TcgdexPokemonProvider(
        apiClient: TcgdexApiClient(httpClient: _fakeTcgdexClient()),
      );
      final store = CanonicalCatalogStore.openInMemory();
      addTearDown(store.dispose);

      final service = PokemonCanonicalImportService(
        provider: provider,
        store: store,
      );
      await service.importProfile(
        profile: 'starter',
        languages: const <TcgCardLanguage>[
          TcgCardLanguage.en,
          TcgCardLanguage.it,
        ],
      );

      final italianFirst = store.searchPokemonCards(
        filter: const CollectionFilter(),
        searchQuery: 'alakazam',
        preferredLanguages: const <String>['it', 'en'],
        limit: 20,
      );
      final englishFirst = store.searchPokemonCards(
        filter: const CollectionFilter(),
        searchQuery: 'alakazam',
        preferredLanguages: const <String>['en', 'it'],
        limit: 20,
      );

      expect(italianFirst, isNotEmpty);
      expect(englishFirst, isNotEmpty);
      expect(italianFirst.first.name, equals('Alakazam IT'));
      expect(englishFirst.first.name, equals('Alakazam'));
    },
  );

  test(
    'Pokemon promo and special cards support collector and subtype regressions',
    () {
      final store = CanonicalCatalogStore.openInMemory();
      addTearDown(store.dispose);
      store.replacePokemonCatalog(_promoRegressionBatch());

      final promoByCollector = store.searchPokemonCards(
        filter: const CollectionFilter(collectorNumber: 'sv-p001'),
        preferredLanguages: const <String>['en'],
        limit: 20,
      );
      expect(promoByCollector, hasLength(1));
      expect(promoByCollector.first.name, equals('Pikachu Promo'));

      final filteredCount = store.countPokemonCards(
        filter: const CollectionFilter(
          pokemonSubtypes: <String>{'Promo'},
          artist: 'test artist',
          manaMin: 2,
          manaMax: 2,
        ),
        preferredLanguages: const <String>['en'],
      );
      expect(filteredCount, equals(1));
    },
  );
}

CanonicalCatalogImportBatch _promoRegressionBatch() {
  const cardId = 'pokemon:card:test:svp001';
  const setId = 'pokemon:set:svp';
  const printingId = 'pokemon:printing:test:svp001';
  return CanonicalCatalogImportBatch(
    cards: const <CatalogCard>[
      CatalogCard(
        cardId: cardId,
        gameId: TcgGameId.pokemon,
        canonicalName: 'Pikachu Promo',
        defaultLocalizedData: LocalizedCardData(
          cardId: cardId,
          language: TcgCardLanguage.en,
          name: 'Pikachu Promo',
          subtypeLine: 'Pokemon (Promo)',
        ),
        localizedData: <LocalizedCardData>[
          LocalizedCardData(
            cardId: cardId,
            language: TcgCardLanguage.en,
            name: 'Pikachu Promo',
            subtypeLine: 'Pokemon (Promo)',
          ),
          LocalizedCardData(
            cardId: cardId,
            language: TcgCardLanguage.it,
            name: 'Pikachu Promo IT',
            subtypeLine: 'Pokemon (Promo)',
          ),
        ],
        metadata: <String, Object?>{
          'pokemon': <String, Object?>{
            'attacks': <Map<String, Object?>>[
              <String, Object?>{
                'name': 'Promo Spark',
                'converted_energy_cost': 2,
              },
            ],
          },
        },
        pokemon: PokemonCardMetadata(
          category: 'Pokemon',
          hp: 70,
          types: <String>['Lightning'],
          subtypes: <String>['Promo'],
          stage: 'Basic',
          attacks: <PokemonAttack>[
            PokemonAttack(name: 'Promo Spark', convertedEnergyCost: 2),
          ],
          illustrator: 'Test Artist',
        ),
      ),
    ],
    sets: const <CatalogSet>[
      CatalogSet(
        setId: setId,
        gameId: TcgGameId.pokemon,
        code: 'svp',
        canonicalName: 'Scarlet & Violet Promo',
        defaultLocalizedData: LocalizedSetData(
          setId: setId,
          language: TcgCardLanguage.en,
          name: 'Scarlet & Violet Promo',
        ),
        localizedData: <LocalizedSetData>[
          LocalizedSetData(
            setId: setId,
            language: TcgCardLanguage.en,
            name: 'Scarlet & Violet Promo',
          ),
        ],
        metadata: <String, Object?>{'official_total': 99},
      ),
    ],
    printings: const <CardPrintingRef>[
      CardPrintingRef(
        printingId: printingId,
        cardId: cardId,
        setId: setId,
        gameId: TcgGameId.pokemon,
        collectorNumber: 'SV-P001',
        rarity: 'Promo',
        imageUris: <String, String>{
          'normal': 'https://example.invalid/promo.png',
        },
        providerMappings: <ProviderMapping>[
          ProviderMapping(
            providerId: CatalogProviderId.tcgdex,
            objectType: 'printing',
            providerObjectId: 'svp001',
          ),
          ProviderMapping(
            providerId: CatalogProviderId.pokemonTcgApi,
            objectType: 'legacy_printing',
            providerObjectId: 'svp001',
          ),
        ],
      ),
    ],
    cardLocalizations: const <LocalizedCardData>[
      LocalizedCardData(
        cardId: cardId,
        language: TcgCardLanguage.en,
        name: 'Pikachu Promo',
        subtypeLine: 'Pokemon (Promo)',
      ),
      LocalizedCardData(
        cardId: cardId,
        language: TcgCardLanguage.it,
        name: 'Pikachu Promo IT',
        subtypeLine: 'Pokemon (Promo)',
      ),
    ],
    setLocalizations: const <LocalizedSetData>[
      LocalizedSetData(
        setId: setId,
        language: TcgCardLanguage.en,
        name: 'Scarlet & Violet Promo',
      ),
    ],
    providerMappings: const <ProviderMappingRecord>[
      ProviderMappingRecord(
        mapping: ProviderMapping(
          providerId: CatalogProviderId.tcgdex,
          objectType: 'printing',
          providerObjectId: 'svp001',
        ),
        cardId: cardId,
        printingId: printingId,
        setId: setId,
      ),
      ProviderMappingRecord(
        mapping: ProviderMapping(
          providerId: CatalogProviderId.pokemonTcgApi,
          objectType: 'legacy_printing',
          providerObjectId: 'svp001',
        ),
        cardId: cardId,
        printingId: printingId,
        setId: setId,
      ),
    ],
    priceSnapshots: const <PriceSnapshot>[],
  );
}

http.Client _fakeTcgdexClient() {
  final setResponse = <String, dynamic>{
    'id': 'base1',
    'name': 'Base Set',
    'releaseDate': '1999-01-09',
    'serie': <String, dynamic>{'id': 'base', 'name': 'Base'},
    'cardCount': <String, dynamic>{'official': 102, 'total': 102},
    'cards': <Map<String, Object?>>[
      <String, Object?>{'id': 'base1-1', 'localId': '1', 'name': 'Alakazam'},
    ],
  };
  final setResponseIt = <String, dynamic>{
    'id': 'base1',
    'name': 'Set Base',
    'releaseDate': '1999-01-09',
    'serie': <String, dynamic>{'id': 'base', 'name': 'Originale'},
    'cardCount': <String, dynamic>{'official': 102, 'total': 102},
    'cards': <Map<String, Object?>>[
      <String, Object?>{'id': 'base1-1', 'localId': '1', 'name': 'Alakazam'},
    ],
  };
  final cardEn = <String, dynamic>{
    'category': 'Pokemon',
    'id': 'base1-1',
    'illustrator': 'Ken Sugimori',
    'image': 'https://assets.tcgdex.net/en/base/base1/1',
    'localId': '1',
    'name': 'Alakazam',
    'rarity': 'Rare',
    'set': <String, dynamic>{
      'id': 'base1',
      'name': 'Base Set',
      'releaseDate': '1999-01-09',
      'serie': <String, dynamic>{'id': 'base', 'name': 'Base'},
      'cardCount': <String, dynamic>{'official': 102, 'total': 102},
    },
    'hp': 80,
    'types': <String>['Psychic'],
    'evolveFrom': 'Kadabra',
    'stage': 'Stage2',
    'abilities': <Map<String, Object?>>[
      <String, Object?>{
        'type': 'Pokemon Power',
        'name': 'Damage Swap',
        'effect': 'Move 1 damage counter.',
      },
    ],
    'attacks': <Map<String, Object?>>[
      <String, Object?>{
        'cost': <String>['Psychic', 'Psychic', 'Psychic'],
        'name': 'Confuse Ray',
        'effect': 'Flip a coin.',
        'damage': '30',
      },
    ],
    'weaknesses': <Map<String, Object?>>[
      <String, Object?>{'type': 'Psychic', 'value': 'x2'},
    ],
    'retreat': 3,
    'updated': '2026-01-07T12:21:43.000Z',
    'pricing': <String, Object?>{
      'cardmarket': <String, Object?>{
        'updated': '2026-03-13T01:42:16.000Z',
        'unit': 'EUR',
        'avg': 57.76,
      },
      'tcgplayer': <String, Object?>{
        'updated': '2026-03-12T20:05:38.000Z',
        'unit': 'USD',
        'holofoil': <String, Object?>{'marketPrice': 60.4},
      },
    },
    'legal': <String, Object?>{'standard': false, 'expanded': false},
  };
  final cardIt = <String, dynamic>{
    ...cardEn,
    'category': 'Pokémon',
    'name': 'Alakazam IT',
    'set': <String, dynamic>{
      'id': 'base1',
      'name': 'Set Base',
      'releaseDate': '1999-01-09',
      'serie': <String, dynamic>{'id': 'base', 'name': 'Originale'},
      'cardCount': <String, dynamic>{'official': 102, 'total': 102},
    },
    'types': <String>['Psico'],
    'stage': 'Livello 2',
    'abilities': <Map<String, Object?>>[
      <String, Object?>{
        'type': 'Pokemon Power',
        'name': 'Scambio danni',
        'effect': 'Sposta un segnalino danno.',
      },
    ],
    'attacks': <Map<String, Object?>>[
      <String, Object?>{
        'cost': <String>['Psico', 'Psico', 'Psico'],
        'name': 'Storidiraggio',
        'effect': 'Lancia una moneta.',
        'damage': '30',
      },
    ],
    'description': 'Il suo cervello è più potente di un supercomputer.',
  };

  return MockClient((request) async {
    final uri = request.url.toString();
    if (uri.endsWith('/en/sets/base1')) {
      return http.Response(jsonEncode(setResponse), 200);
    }
    if (uri.endsWith('/it/sets/base1')) {
      return http.Response(jsonEncode(setResponseIt), 200);
    }
    if (uri.endsWith('/en/cards/base1-1')) {
      return http.Response(jsonEncode(cardEn), 200);
    }
    if (uri.endsWith('/it/cards/base1-1')) {
      return http.Response(jsonEncode(cardIt), 200);
    }
    if (uri.contains('/en/cards?name=')) {
      return http.Response(
        jsonEncode(<Map<String, Object?>>[
          <String, Object?>{
            'id': 'base1-1',
            'localId': '1',
            'name': 'Alakazam',
            'image': 'https://assets.tcgdex.net/en/base/base1/1',
          },
        ]),
        200,
      );
    }
    if (uri.contains('/en/sets?pagination%3AitemsPerPage=')) {
      return http.Response(jsonEncode(<Object?>[setResponse]), 200);
    }
    if (uri.contains('/en/sets/swsh1')) {
      return http.Response(
        jsonEncode(<String, Object?>{
          ...setResponse,
          'id': 'swsh1',
          'name': 'Sword & Shield',
          'cards': <Map<String, Object?>>[],
        }),
        200,
      );
    }
    if (uri.contains('/en/sets/sv1') || uri.contains('/en/sets/sv01')) {
      return http.Response(
        jsonEncode(<String, Object?>{
          ...setResponse,
          'id': 'sv01',
          'name': 'Scarlet & Violet',
          'cards': <Map<String, Object?>>[],
        }),
        200,
      );
    }
    if (uri.contains('/it/sets/swsh1')) {
      return http.Response(
        jsonEncode(<String, Object?>{
          ...setResponseIt,
          'id': 'swsh1',
          'name': 'Spada e Scudo',
          'cards': <Map<String, Object?>>[],
        }),
        200,
      );
    }
    if (uri.contains('/it/sets/sv1') || uri.contains('/it/sets/sv01')) {
      return http.Response(
        jsonEncode(<String, Object?>{
          ...setResponseIt,
          'id': 'sv01',
          'name': 'Scarlatto e Violetto',
          'cards': <Map<String, Object?>>[],
        }),
        200,
      );
    }
    throw StateError('Unhandled test request: $uri');
  });
}
