import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcg_tracker/db/app_database.dart';
import 'package:tcg_tracker/db/canonical_catalog_store.dart';
import 'package:tcg_tracker/domain/domain_models.dart';
import 'package:tcg_tracker/models.dart';
import 'package:tcg_tracker/repositories/app_repositories.dart';
import 'package:tcg_tracker/services/game_registry.dart';
import 'package:tcg_tracker/services/one_piece_pilot_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('one_piece_pilot_test');
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    debugAppDatabaseDirectoryOverride = tempDir.path;
    CanonicalCatalogStore.debugDefaultPathOverride =
        '${tempDir.path}${Platform.pathSeparator}${CanonicalCatalogStore.defaultFileName}';
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
    'One Piece pilot validates third-game repository and collection flow',
    () async {
      final gameDefinition = GameRegistry.instance.definitionForId(
        TcgGameId.onePiece,
      );
      expect(gameDefinition, isNotNull);
      expect(gameDefinition!.providers?.catalog, isNotNull);
      expect(gameDefinition.capabilities.supportsCatalogInstall, isTrue);
      expect(gameDefinition.capabilities.supportsAdvancedFilters, isTrue);

      final store = await CanonicalCatalogStore.openDefault();
      try {
        store.replaceCatalogForGame(
          TcgGameId.onePiece,
          const CanonicalCatalogImportBatch(
            cards: <CatalogCard>[],
            sets: <CatalogSet>[],
            printings: <CardPrintingRef>[],
            cardLocalizations: <LocalizedCardData>[],
            setLocalizations: <LocalizedSetData>[],
            providerMappings: <ProviderMappingRecord>[],
            priceSnapshots: <PriceSnapshot>[],
          ),
        );
      } finally {
        store.dispose();
      }

      await ScryfallDatabase.instance.runWithDatabaseFileName(
        gameDefinition.dbFileName,
        () async {
          final db = await ScryfallDatabase.instance.open();
          await db.customStatement('DELETE FROM collection_cards');
          await db.customStatement('DELETE FROM collections');
          await db.customStatement(
            "DELETE FROM cards WHERE id LIKE 'one_piece:%'",
          );
        },
      );

      final report = await OnePiecePilotImportService().installPilotCatalog();
      expect(report.cardsImported, equals(4));
      expect(report.setsImported, equals(2));
      expect(report.printingsImported, equals(4));

      final sets = await appRepositories.sets.fetchAvailableSets(
        gameId: TcgGameId.onePiece,
      );
      expect(
        sets.map((item) => item.code),
        containsAll(<String>['op01', 'op02']),
      );

      final zoroResults = await appRepositories.search.searchCardsByName(
        'zoro',
        gameId: TcgGameId.onePiece,
        languages: const <String>['en'],
      );
      expect(zoroResults, isNotEmpty);
      expect(zoroResults.first.id, equals('one_piece:legacy:op01-025'));

      final advanced = await appRepositories.search
          .fetchCardsForAdvancedFilters(
            const CollectionFilter(
              sets: <String>{'op02'},
              rarities: <String>{'sr'},
              types: <String>{'character'},
            ),
            gameId: TcgGameId.onePiece,
            languages: const <String>['en'],
          );
      expect(advanced.length, equals(1));
      expect(advanced.first.name, equals('Portgas.D.Ace'));

      final collectionId = await appRepositories.collections.addCollection(
        'One Piece pilot',
        gameId: TcgGameId.onePiece,
        type: CollectionType.custom,
      );
      await appRepositories.collections.upsertCollectionCard(
        collectionId,
        zoroResults.first.id,
        gameId: TcgGameId.onePiece,
        quantity: 2,
        foil: false,
        altArt: false,
      );
      final entries = await appRepositories.collections.fetchCollectionCards(
        collectionId,
        gameId: TcgGameId.onePiece,
      );
      expect(entries.length, equals(1));
      expect(entries.first.cardId, equals('one_piece:legacy:op01-025'));
      expect(entries.first.name, equals('Roronoa Zoro'));
      expect(entries.first.quantity, equals(2));
    },
  );
}
