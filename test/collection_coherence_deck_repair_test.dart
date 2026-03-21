import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcg_tracker/db/app_database.dart';
import 'package:tcg_tracker/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'collection_coherence_deck_repair_test_',
    );
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    debugAppDatabaseDirectoryOverride = tempDir.path;
    await ScryfallDatabase.instance.setDatabaseFileName('mtg.db');
  });

  tearDown(() async {
    await ScryfallDatabase.instance.close();
    debugAppDatabaseDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'coherence repair restores misclassified format-only smart collections with inventory as decks',
    () async {
      final deckId = await ScryfallDatabase.instance.addCollection(
        'Deck 1',
        type: CollectionType.deck,
        filter: const CollectionFilter(format: 'standard'),
      );
      final db = await ScryfallDatabase.instance.open();
      await db.into(db.cards).insert(
        CardsCompanion.insert(
          id: 'card-1',
          name: 'Test Card',
        ),
      );
      await ScryfallDatabase.instance.upsertCollectionCard(
        deckId,
        'card-1',
        quantity: 1,
        foil: false,
        altArt: false,
      );
      await db.customStatement(
        'UPDATE collections SET type = ? WHERE id = ?',
        <Object?>['smart', deckId],
      );

      await ScryfallDatabase.instance.repairAllCardsCoherenceFromCustomCollections();

      final collections = await ScryfallDatabase.instance.fetchCollections();
      final repairedDeck = collections.singleWhere((item) => item.id == deckId);
      expect(repairedDeck.type, CollectionType.deck);
      expect(repairedDeck.cardCount, 1);
    },
  );

  test(
    'coherence repair restores misclassified default-named deck even without remaining direct inventory rows',
    () async {
      final deckId = await ScryfallDatabase.instance.addCollection(
        'Deck 1',
        type: CollectionType.deck,
        filter: const CollectionFilter(format: 'standard'),
      );
      final db = await ScryfallDatabase.instance.open();
      await db.customStatement(
        'UPDATE collections SET type = ? WHERE id = ?',
        <Object?>['smart', deckId],
      );

      await ScryfallDatabase.instance.repairAllCardsCoherenceFromCustomCollections();

      final collections = await ScryfallDatabase.instance.fetchCollections();
      final repairedDeck = collections.singleWhere((item) => item.id == deckId);
      expect(repairedDeck.type, CollectionType.deck);
    },
  );
}
