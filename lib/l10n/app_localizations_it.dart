// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'TCG Tracker';

  @override
  String get allCards => 'All cards';

  @override
  String get notSelected => 'Not selected';

  @override
  String get bulkAllPrintingsTitle => 'All printings';

  @override
  String get bulkAllPrintingsDescription =>
      'All printings and languages. Heaviest.';

  @override
  String get bulkOracleCardsTitle => 'Oracle cards';

  @override
  String get bulkOracleCardsDescription =>
      'One entry per card. Fewer variants.';

  @override
  String get bulkUniqueArtworkTitle => 'Unique artwork';

  @override
  String get bulkUniqueArtworkDescription => 'One entry per artwork. Lightest.';

  @override
  String get gamePokemonDescription => 'Pokemon TCG collections.';

  @override
  String get gameMagicDescription => 'Magic: The Gathering collections.';

  @override
  String get gameYugiohDescription => 'Yu-Gi-Oh! collections.';

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
      zero: '0 cards',
    );
    return '$_temp0';
  }

  @override
  String get settings => 'Settings';

  @override
  String get searchLanguages => 'Search languages';

  @override
  String get searchLanguagesSubtitle =>
      'Choose which card languages appear in search.';

  @override
  String get defaultLabel => 'Default';

  @override
  String get remove => 'Remove';

  @override
  String get addLanguage => 'Add language';

  @override
  String get allLanguagesAdded => 'All languages are already added.';

  @override
  String get languageAddedDownloadAgain =>
      'Language added. Download again to import the cards.';

  @override
  String get cardDatabase => 'Card database';

  @override
  String get cardDatabaseSubtitle =>
      'Choose which database to download from Scryfall.';

  @override
  String get selectedType => 'Selected type';

  @override
  String get change => 'Change';

  @override
  String get changeDatabaseTitle => 'Change database?';

  @override
  String get changeDatabaseBody =>
      'The current database will be removed and you will need to download the cards again.';

  @override
  String get confirm => 'Confirm';

  @override
  String get updatingDatabaseTitle => 'Updating database';

  @override
  String get preparingDatabaseBody => 'Preparing the new database...';

  @override
  String get databaseChangedGoHome =>
      'Database changed. Go back to Home to download.';

  @override
  String get games => 'Games';

  @override
  String get gamesSubtitle => 'Manage which TCGs are enabled.';

  @override
  String get makePrimary => 'Make primary';

  @override
  String get addGame => 'Add game';

  @override
  String get gameLimitReachedTitle => 'Game limit reached';

  @override
  String get gameLimitReachedBody =>
      'The free version allows one game. Upgrade to Pro to add more.';

  @override
  String get allGamesAdded => 'All games are already added.';

  @override
  String get primaryLabel => 'Primary';

  @override
  String get addedLabel => 'Added';

  @override
  String primaryGameSet(Object game) {
    return 'Primary game set to $game.';
  }

  @override
  String get pro => 'Pro';

  @override
  String get proSubtitle => 'Unlock unlimited collections.';

  @override
  String get proStatus => 'Pro status';

  @override
  String get proActive => 'Pro active';

  @override
  String get basePlan => 'Base plan';

  @override
  String get storeAvailable => 'Store available';

  @override
  String get storeNotAvailableYet => 'Store not available yet';

  @override
  String get unlimitedCollectionsUnlocked =>
      'Unlimited collections are unlocked.';

  @override
  String get unlockProRemoveLimit =>
      'Unlock Pro to remove the 5-collection limit.';

  @override
  String priceLabel(Object price) {
    return 'Price: $price';
  }

  @override
  String get whatYouGet => 'What you get';

  @override
  String get unlimitedCollectionsFeature => 'Unlimited collections';

  @override
  String get supportFuturePremiumFeatures => 'Support future premium features';

  @override
  String get switchToBaseTest => 'Switch to Base (test)';

  @override
  String get switchToProTest => 'Switch to Pro (test)';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get testMode => 'Test mode';

  @override
  String get testModeSubtitle => 'When enabled, Upgrade toggles Pro locally.';

  @override
  String get manage => 'Manage';

  @override
  String get reset => 'Reset';

  @override
  String get resetSubtitle => 'Remove all collections and the card database.';

  @override
  String get factoryReset => 'Factory reset';

  @override
  String get factoryResetTitle => 'Factory reset?';

  @override
  String get factoryResetBody =>
      'This will remove all collections, the card database, and downloads. The app will return to a first-launch state.';

  @override
  String get cleaningUpTitle => 'Cleaning up';

  @override
  String get removingLocalDataBody => 'Removing local data...';

  @override
  String get resetComplete => 'Reset complete. Restart the app.';

  @override
  String get notNow => 'Not now';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get cancel => 'Cancel';

  @override
  String get chooseDatabase => 'Choose database';

  @override
  String get downloadDatabase => 'Download database';

  @override
  String get downloadUpdate => 'Download update';

  @override
  String get downloading => 'Downloading...';

  @override
  String downloadingWithPercent(int percent) {
    return 'Downloading... $percent%';
  }

  @override
  String importingWithPercent(int percent) {
    return 'Importing... $percent%';
  }

  @override
  String get checkingUpdates => 'Checking updates...';

  @override
  String downloadingUpdateWithTotal(
    int percent,
    Object received,
    Object total,
  ) {
    return 'Downloading update... $percent% ($received / $total)';
  }

  @override
  String downloadingUpdateNoTotal(Object received) {
    return 'Downloading update... $received';
  }

  @override
  String importingCardsWithCount(int percent, int count) {
    return 'Importing cards... $percent% ($count cards)';
  }

  @override
  String get downloadFailedTapUpdate => 'Download failed. Tap update again.';

  @override
  String get selectDatabaseToDownload => 'Select a database to download.';

  @override
  String databaseMissingDownloadRequired(Object name) {
    return 'Database $name missing. Download required.';
  }

  @override
  String updateReadyWithDate(Object date) {
    return 'Update ready: $date';
  }

  @override
  String get unknownDate => 'unknown';

  @override
  String get upToDate => 'Up to date.';

  @override
  String get importNow => 'Import now';

  @override
  String gameLabel(Object game) {
    return 'Game: $game';
  }

  @override
  String get rebuildingSearchIndex => 'Rebuilding search index';

  @override
  String get requiredAfterLargeUpdates => 'Required after large updates.';

  @override
  String get addTitle => 'Add';

  @override
  String get addCards => 'Add card(s)';

  @override
  String get addCardsToCatalogSubtitle => 'Add to the main catalog.';

  @override
  String get addCardsToCollection => 'Add card(s) to a collection';

  @override
  String get addCardsToCollectionSubtitle => 'Choose a custom collection.';

  @override
  String get addCollection => 'Add a collection';

  @override
  String get addCollectionSubtitle => 'Create set-based or custom.';

  @override
  String get chooseCollection => 'Choose collection';

  @override
  String get chooseCardDatabaseTitle => 'Choose card database';

  @override
  String get chooseYourGameTitle => 'Choose your game';

  @override
  String get collectionLimitReachedTitle => 'Collection limit reached';

  @override
  String collectionLimitReachedBody(int limit) {
    return 'The free version allows up to $limit collections. Upgrade to Pro to unlock unlimited collections.';
  }

  @override
  String get proActiveUnlimitedCollections =>
      'Pro active. Unlimited collections.';

  @override
  String basePlanCollectionLimit(int limit) {
    return 'Base plan: up to $limit collections.';
  }

  @override
  String get proEnabled => 'Pro enabled';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String get myCollections => 'My collections';

  @override
  String get buildYourCollectionsTitle => 'Build your own collections';

  @override
  String get buildYourCollectionsSubtitle =>
      'Tap to create your first collection.';

  @override
  String get addCardsNowTitle => 'Add cards now?';

  @override
  String get addCardsNowBody => 'Use search and filters to add multiple cards.';

  @override
  String get yes => 'Yes';

  @override
  String get noSetsAvailableYet => 'No sets available yet.';

  @override
  String get newSetCollectionTitle => 'New set collection';

  @override
  String get collectionAlreadyExists => 'Collection already exists.';

  @override
  String failedToAddCollection(Object error) {
    return 'Failed to add collection: $error';
  }

  @override
  String get newCollectionTitle => 'New collection';

  @override
  String get create => 'Create';

  @override
  String get collectionNameHint => 'Collection name';

  @override
  String get createCustomCollectionFirst => 'Create a custom collection first.';

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String get renameCollectionTitle => 'Rename collection';

  @override
  String get save => 'Save';

  @override
  String get deleteCollectionTitle => 'Delete collection?';

  @override
  String deleteCollectionBody(Object name) {
    return '\"$name\" will be removed from this device.';
  }

  @override
  String get collectionDeleted => 'Collection deleted.';

  @override
  String get downloadLinkUnavailable => 'Download link unavailable.';

  @override
  String get scryfallBulkUpdateAvailable => 'Scryfall bulk update available.';

  @override
  String get update => 'Update';

  @override
  String get advancedFiltersTitle => 'Advanced filters';

  @override
  String get rarity => 'Rarity';

  @override
  String get setLabel => 'Set';

  @override
  String get colorLabel => 'Color';

  @override
  String get colorWhite => 'White';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorRed => 'Red';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorColorless => 'Colorless';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageItalian => 'Italian';

  @override
  String get languageFrench => 'French';

  @override
  String get languageGerman => 'German';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageChineseSimplified => 'Chinese (Simplified)';

  @override
  String get languageChineseTraditional => 'Chinese (Traditional)';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageHebrew => 'Hebrew';

  @override
  String get languageLatin => 'Latin';

  @override
  String get languageGreek => 'Greek';

  @override
  String get languageSanskrit => 'Sanskrit';

  @override
  String get languagePhyrexian => 'Phyrexian';

  @override
  String get languageQuenya => 'Quenya';

  @override
  String get typeLabel => 'Type';

  @override
  String get manaValue => 'Mana value';

  @override
  String get minLabel => 'Min';

  @override
  String get maxLabel => 'Max';

  @override
  String get noFiltersAvailableForList => 'No filters available for this list.';

  @override
  String get noFiltersAvailable => 'No filters available.';

  @override
  String get clear => 'Clear';

  @override
  String get apply => 'Apply';

  @override
  String downloadComplete(Object path) {
    return 'Download complete: $path';
  }

  @override
  String downloadFailedWithError(Object error) {
    return 'Download failed: $error';
  }

  @override
  String get downloadFailedGeneric => 'Download failed.';

  @override
  String get networkErrorTryAgain => 'Network error. Please try again.';

  @override
  String get gallery => 'Gallery';

  @override
  String get list => 'List';

  @override
  String get noCardsMatchFilters => 'No cards match these filters';

  @override
  String get noOwnedCardsYet => 'No owned cards yet';

  @override
  String get noCardsYet => 'No cards yet';

  @override
  String get tryEnablingOwnedOrMissing =>
      'Try enabling owned or missing cards.';

  @override
  String get addCardsHereOrAny => 'Add cards here or inside any collection.';

  @override
  String get addFirstCardToStartCollection =>
      'Add your first card to start this collection.';

  @override
  String get addCard => 'Add card';

  @override
  String get searchCardsHint => 'Search cards';

  @override
  String ownedCount(int count) {
    return 'Owned ($count)';
  }

  @override
  String missingCount(int count) {
    return 'Missing ($count)';
  }

  @override
  String get useListToSetOwnedQuantities =>
      'Use the list to set owned quantities.';

  @override
  String addedCards(int count) {
    return 'Added $count cards.';
  }

  @override
  String get quantityLabel => 'Quantity';

  @override
  String quantityMultiplier(int count) {
    return 'x$count';
  }

  @override
  String get foilLabel => 'Foil';

  @override
  String get altArtLabel => 'Alt art';

  @override
  String get markMissing => 'Mark missing';

  @override
  String get importComplete => 'Import complete.';

  @override
  String importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get selectFiltersFirst => 'Select filters first.';

  @override
  String get selectSetRarityTypeToNarrow =>
      'Select Set, Rarity, or Type to narrow results.';

  @override
  String get addAllResultsTitle => 'Add all results?';

  @override
  String addAllResultsBody(int count) {
    return 'This will add $count cards to the collection.';
  }

  @override
  String get addAll => 'Add all';

  @override
  String get addFilteredCards => 'Add filtered cards';

  @override
  String get addAllResults => 'Add all results';

  @override
  String get searchCardTitle => 'Search card';

  @override
  String get filters => 'Filters';

  @override
  String get addOne => 'Add one';

  @override
  String get missingLabel => 'Missing';

  @override
  String get typeCardNameHint => 'Type a card name';

  @override
  String resultsWithFilters(int visible, int total, Object languages) {
    return 'Results: $visible / $total · Languages: $languages';
  }

  @override
  String resultsWithoutFilters(int total, Object languages) {
    return 'Results: $total · Languages: $languages';
  }

  @override
  String get startTypingToSearch => 'Start typing to search.';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get tryRemovingChangingFilters => 'Try removing or changing filters.';

  @override
  String get tryDifferentNameOrSpelling => 'Try a different name or spelling.';

  @override
  String get allCardsCollectionNotFound => 'All cards collection not found.';

  @override
  String get searchSetHint => 'Search set';

  @override
  String setCollectionCount(int count) {
    return 'Set • $count cards';
  }

  @override
  String customCollectionCount(int count) {
    return 'Custom • $count cards';
  }

  @override
  String get createCollectionTitle => 'Create collection';

  @override
  String get setCollectionTitle => 'Set collection';

  @override
  String get setCollectionSubtitle => 'Tracks missing cards by set.';

  @override
  String get customCollectionTitle => 'Custom collection';

  @override
  String get customCollectionSubtitle => 'Add cards manually.';

  @override
  String get details => 'Details';

  @override
  String loyaltyLabel(Object value) {
    return 'Loyalty $value';
  }

  @override
  String get detailSet => 'Set';

  @override
  String get detailCollector => 'Collector';

  @override
  String get detailRarity => 'Rarity';

  @override
  String get detailSetName => 'Set name';

  @override
  String get detailLanguage => 'Language';

  @override
  String get detailRelease => 'Release';

  @override
  String get detailArtist => 'Artist';
}
