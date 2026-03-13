import '../db/app_database.dart';
import '../db/canonical_catalog_store.dart';
import '../domain/domain_models.dart';
import '../providers/one_piece_pilot_provider.dart';
import 'game_registry.dart';

class OnePiecePilotImportReport {
  const OnePiecePilotImportReport({
    required this.cardsImported,
    required this.setsImported,
    required this.printingsImported,
  });

  final int cardsImported;
  final int setsImported;
  final int printingsImported;
}

class OnePiecePilotImportService {
  OnePiecePilotImportService({
    OnePiecePilotProvider? provider,
    CanonicalCatalogStore? store,
    ScryfallDatabase? database,
  }) : _provider = provider ?? const OnePiecePilotProvider(),
       _store = store,
       _database = database ?? ScryfallDatabase.instance;

  final OnePiecePilotProvider _provider;
  final CanonicalCatalogStore? _store;
  final ScryfallDatabase _database;

  Future<OnePiecePilotImportReport> installPilotCatalog() async {
    final bundles = OnePiecePilotProvider.catalog;
    final batch = CanonicalCatalogImportBatch(
      cards: bundles.map((item) => item.card).toList(growable: false),
      sets: {
        for (final item in bundles) item.set.setId: item.set,
      }.values.toList(growable: false),
      printings: bundles.map((item) => item.printing).toList(growable: false),
      cardLocalizations: bundles
          .expand((item) => item.card.localizedData)
          .toList(growable: false),
      setLocalizations: {
        for (final item in bundles.expand((entry) => entry.set.localizedData))
          '${item.setId}:${item.language.code}': item,
      }.values.toList(growable: false),
      providerMappings: bundles
          .expand(
            (item) => item.printing.providerMappings.map(
              (mapping) => ProviderMappingRecord(
                mapping: mapping,
                cardId: item.card.cardId,
                printingId: item.printing.printingId,
                setId: item.set.setId,
              ),
            ),
          )
          .toList(growable: false),
      priceSnapshots: const <PriceSnapshot>[],
    );

    final store = _store ?? await CanonicalCatalogStore.openDefault();
    final ownsStore = _store == null;
    try {
      store.replaceCatalogForGame(TcgGameId.onePiece, batch);
    } finally {
      if (ownsStore) {
        store.dispose();
      }
    }

    final definition = GameRegistry.instance.definitionForId(
      TcgGameId.onePiece,
    );
    final fileName = definition?.dbFileName ?? 'one_piece.db';
    await _database.runWithDatabaseFileName(fileName, () async {
      final db = await _database.open();
      await db.customStatement("DELETE FROM cards WHERE id LIKE 'one_piece:%'");
      await _database.insertCardsBatch(db, _provider.buildLegacyCardMaps());
      await _database.rebuildPrintedNameSearchIndex();
      await db.rebuildFts();
    });

    return OnePiecePilotImportReport(
      cardsImported: batch.cards.length,
      setsImported: batch.sets.length,
      printingsImported: batch.printings.length,
    );
  }
}
