import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcg_tracker/db/app_database.dart';
import 'package:tcg_tracker/db/canonical_catalog_store.dart';
import 'package:tcg_tracker/domain/domain_models.dart';
import 'package:tcg_tracker/models.dart';
import 'package:tcg_tracker/services/app_settings.dart';
import 'package:tcg_tracker/services/inventory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'owned_cards_canonical_repair_test_',
    );
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    debugAppDatabaseDirectoryOverride = tempDir.path;
    CanonicalCatalogStore.debugDefaultPathOverride =
        '${tempDir.path}${Platform.pathSeparator}${CanonicalCatalogStore.defaultFileName}';
    await AppSettings.saveSelectedTcgGame(AppTcgGame.pokemon);
    await ScryfallDatabase.instance.setDatabaseFileName('pokemon.db');
  });

  tearDown(() async {
    await ScryfallDatabase.instance.close();
    debugAppDatabaseDirectoryOverride = null;
    CanonicalCatalogStore.debugDefaultPathOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'fetchOwnedCards repairs stale pokemon printing ids via legacy card mapping',
    () async {
      final store = await CanonicalCatalogStore.openDefault();
      try {
        store.replacePokemonCatalog(
          CanonicalCatalogImportBatch(
            cards: const <CatalogCard>[
              CatalogCard(
                cardId: 'pokemon:card:tcgdex:base1-1',
                gameId: TcgGameId.pokemon,
                canonicalName: 'Alakazam',
                defaultLocalizedData: LocalizedCardData(
                  cardId: 'pokemon:card:tcgdex:base1-1',
                  languageCode: 'it',
                  name: 'Alakazam',
                  subtypeLine: 'Pokemon',
                ),
                localizedData: <LocalizedCardData>[
                  LocalizedCardData(
                    cardId: 'pokemon:card:tcgdex:base1-1',
                    languageCode: 'it',
                    name: 'Alakazam',
                    subtypeLine: 'Pokemon',
                  ),
                ],
                pokemon: PokemonCardMetadata(
                  category: 'Pokemon',
                  illustrator: 'Ken Sugimori',
                  types: <String>['Psychic'],
                ),
              ),
            ],
            sets: const <CatalogSet>[
              CatalogSet(
                setId: 'pokemon:set:base1',
                gameId: TcgGameId.pokemon,
                code: 'base1',
                canonicalName: 'Set Base',
                defaultLocalizedData: LocalizedSetData(
                  setId: 'pokemon:set:base1',
                  languageCode: 'it',
                  name: 'Set Base',
                ),
                localizedData: <LocalizedSetData>[
                  LocalizedSetData(
                    setId: 'pokemon:set:base1',
                    languageCode: 'it',
                    name: 'Set Base',
                  ),
                ],
                metadata: <String, Object?>{'card_count': 102},
              ),
            ],
            printings: const <CardPrintingRef>[
              CardPrintingRef(
                printingId: 'pokemon:printing:tcgdex:base1-1:it',
                cardId: 'pokemon:card:tcgdex:base1-1',
                setId: 'pokemon:set:base1',
                gameId: TcgGameId.pokemon,
                collectorNumber: '1',
                languageCode: 'it',
                rarity: 'Rare Holo',
                imageUris: <String, String>{'high_res': 'https://img/alakazam.webp'},
              ),
            ],
            cardLocalizations: const <LocalizedCardData>[
              LocalizedCardData(
                cardId: 'pokemon:card:tcgdex:base1-1',
                languageCode: 'it',
                name: 'Alakazam',
                subtypeLine: 'Pokemon',
              ),
            ],
            setLocalizations: const <LocalizedSetData>[
              LocalizedSetData(
                setId: 'pokemon:set:base1',
                languageCode: 'it',
                name: 'Set Base',
              ),
            ],
            providerMappings: const <ProviderMappingRecord>[
              ProviderMappingRecord(
                mapping: ProviderMapping(
                  providerId: CatalogProviderId.pokemonTcgApi,
                  objectType: 'legacy_printing',
                  providerObjectId: 'base1-1',
                ),
                cardId: 'pokemon:card:tcgdex:base1-1',
                printingId: 'pokemon:printing:tcgdex:base1-1:it',
                setId: 'pokemon:set:base1',
              ),
            ],
            priceSnapshots: const <PriceSnapshot>[],
          ),
        );
      } finally {
        store.dispose();
      }

      final db = await ScryfallDatabase.instance.open();
      final allCardsId = await ScryfallDatabase.instance.ensureAllCardsCollectionId();
      await db.customStatement(
        '''
        INSERT INTO collection_cards(
          collection_id,
          card_id,
          quantity,
          foil,
          alt_art,
          printing_id
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        <Object?>[
          allCardsId,
          'base1-1',
          4,
          0,
          0,
          'pokemon:printing:tcgdex:base1-1',
        ],
      );

      final owned = await ScryfallDatabase.instance.fetchOwnedCards();
      expect(owned, hasLength(1));
      expect(owned.first.cardId, equals('base1-1'));
      expect(owned.first.printingId, equals('pokemon:printing:tcgdex:base1-1:it'));
      expect(owned.first.name, equals('Alakazam'));
      expect(owned.first.setCode, equals('base1'));
      expect(owned.first.quantity, equals(4));
      expect(owned.first.imageUri, equals('https://img/alakazam.webp'));
    },
  );

  test(
    'pokemon italian set filter tracks owned state on the localized printing',
    () async {
      final store = await CanonicalCatalogStore.openDefault();
      try {
        store.replacePokemonCatalog(
          CanonicalCatalogImportBatch(
            cards: const <CatalogCard>[
              CatalogCard(
                cardId: 'pokemon:card:tcgdex:base1-1',
                gameId: TcgGameId.pokemon,
                canonicalName: 'Alakazam',
                defaultLocalizedData: LocalizedCardData(
                  cardId: 'pokemon:card:tcgdex:base1-1',
                  languageCode: 'en',
                  name: 'Alakazam',
                  subtypeLine: 'Pokemon',
                ),
                localizedData: <LocalizedCardData>[
                  LocalizedCardData(
                    cardId: 'pokemon:card:tcgdex:base1-1',
                    languageCode: 'en',
                    name: 'Alakazam',
                    subtypeLine: 'Pokemon',
                  ),
                  LocalizedCardData(
                    cardId: 'pokemon:card:tcgdex:base1-1',
                    languageCode: 'it',
                    name: 'Alakazam IT',
                    subtypeLine: 'Pokemon',
                  ),
                ],
                pokemon: PokemonCardMetadata(
                  category: 'Pokemon',
                  illustrator: 'Ken Sugimori',
                  types: <String>['Psychic'],
                ),
              ),
            ],
            sets: const <CatalogSet>[
              CatalogSet(
                setId: 'pokemon:set:base1',
                gameId: TcgGameId.pokemon,
                code: 'base1',
                canonicalName: 'Base Set',
                defaultLocalizedData: LocalizedSetData(
                  setId: 'pokemon:set:base1',
                  languageCode: 'en',
                  name: 'Base Set',
                ),
                localizedData: <LocalizedSetData>[
                  LocalizedSetData(
                    setId: 'pokemon:set:base1',
                    languageCode: 'en',
                    name: 'Base Set',
                  ),
                  LocalizedSetData(
                    setId: 'pokemon:set:base1',
                    languageCode: 'it',
                    name: 'Set Base',
                  ),
                ],
                metadata: <String, Object?>{'card_count': 102},
              ),
            ],
            printings: const <CardPrintingRef>[
              CardPrintingRef(
                printingId: 'pokemon:printing:tcgdex:base1-1:en',
                cardId: 'pokemon:card:tcgdex:base1-1',
                setId: 'pokemon:set:base1',
                gameId: TcgGameId.pokemon,
                collectorNumber: '1',
                languageCode: 'en',
                rarity: 'Rare Holo',
                imageUris: <String, String>{'high_res': 'https://img/alakazam-en.webp'},
              ),
              CardPrintingRef(
                printingId: 'pokemon:printing:tcgdex:base1-1:it',
                cardId: 'pokemon:card:tcgdex:base1-1',
                setId: 'pokemon:set:base1',
                gameId: TcgGameId.pokemon,
                collectorNumber: '1',
                languageCode: 'it',
                rarity: 'Rare Holo',
                imageUris: <String, String>{'high_res': 'https://img/alakazam-it.webp'},
              ),
            ],
            cardLocalizations: const <LocalizedCardData>[
              LocalizedCardData(
                cardId: 'pokemon:card:tcgdex:base1-1',
                languageCode: 'en',
                name: 'Alakazam',
                subtypeLine: 'Pokemon',
              ),
              LocalizedCardData(
                cardId: 'pokemon:card:tcgdex:base1-1',
                languageCode: 'it',
                name: 'Alakazam IT',
                subtypeLine: 'Pokemon',
              ),
            ],
            setLocalizations: const <LocalizedSetData>[
              LocalizedSetData(
                setId: 'pokemon:set:base1',
                languageCode: 'en',
                name: 'Base Set',
              ),
              LocalizedSetData(
                setId: 'pokemon:set:base1',
                languageCode: 'it',
                name: 'Set Base',
              ),
            ],
            providerMappings: const <ProviderMappingRecord>[
              ProviderMappingRecord(
                mapping: ProviderMapping(
                  providerId: CatalogProviderId.pokemonTcgApi,
                  objectType: 'legacy_printing',
                  providerObjectId: 'base1-1',
                ),
                cardId: 'pokemon:card:tcgdex:base1-1',
                printingId: 'pokemon:printing:tcgdex:base1-1:en',
                setId: 'pokemon:set:base1',
              ),
              ProviderMappingRecord(
                mapping: ProviderMapping(
                  providerId: CatalogProviderId.pokemonTcgApi,
                  objectType: 'legacy_printing',
                  providerObjectId: 'base1-1:it',
                ),
                cardId: 'pokemon:card:tcgdex:base1-1',
                printingId: 'pokemon:printing:tcgdex:base1-1:it',
                setId: 'pokemon:set:base1',
              ),
            ],
            priceSnapshots: const <PriceSnapshot>[],
          ),
        );
      } finally {
        store.dispose();
      }

      final filter = const CollectionFilter(
        sets: <String>{'base1'},
        languages: <String>{'it'},
      );
      await ScryfallDatabase.instance.ensureAllCardsCollectionId();

      final before = await ScryfallDatabase.instance.fetchFilteredCollectionCards(
        filter,
        missingOnly: true,
      );
      expect(before, hasLength(1));
      expect(before.first.printingId, equals('pokemon:printing:tcgdex:base1-1:it'));
      expect(before.first.quantity, equals(0));

      await InventoryService.instance.addToInventory(
        before.first.cardId,
        printingId: before.first.printingId,
      );
      final db = await ScryfallDatabase.instance.open();
      final ownedRows = await db.customSelect(
        '''
        SELECT card_id AS card_id, printing_id AS printing_id, quantity AS quantity
        FROM collection_cards
        ''',
      ).get();
      expect(ownedRows, hasLength(1));
      expect(
        ownedRows.first.readNullable<String>('printing_id'),
        equals('pokemon:printing:tcgdex:base1-1:it'),
      );

      final ownedCount = await ScryfallDatabase.instance
          .countOwnedCardsForFilterWithSearch(filter);
      expect(ownedCount, equals(1));

      final afterMissing = await ScryfallDatabase.instance
          .fetchFilteredCollectionCards(
            filter,
            missingOnly: true,
          );
      expect(afterMissing, isEmpty);

      final afterOwned = await ScryfallDatabase.instance.fetchFilteredCollectionCards(
        filter,
        ownedOnly: true,
      );
      expect(afterOwned, hasLength(1));
      expect(afterOwned.first.printingId, equals('pokemon:printing:tcgdex:base1-1:it'));
      expect(afterOwned.first.quantity, equals(1));
    },
  );
}
