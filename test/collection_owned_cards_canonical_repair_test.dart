import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcg_tracker/db/app_database.dart';
import 'package:tcg_tracker/db/canonical_catalog_store.dart';
import 'package:tcg_tracker/domain/domain_models.dart';
import 'package:tcg_tracker/services/app_settings.dart';

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
}
