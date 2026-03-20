// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BinderVault';

  @override
  String get allCards => 'All cards';

  @override
  String get notSelected => 'Not selected';

  @override
  String get bulkAllPrintingsTitle => 'All printings';

  @override
  String get bulkAllPrintingsDescription =>
      'All printings (best for full scan coverage).';

  @override
  String get bulkOracleCardsTitle => 'Oracle cards';

  @override
  String get bulkOracleCardsDescription =>
      'Oracle-level (not all printings/variants).';

  @override
  String get bulkUniqueArtworkTitle => 'Unique artwork';

  @override
  String get bulkUniqueArtworkDescription =>
      'One per artwork (not full print coverage).';

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
  String get cardName => 'Card name';

  @override
  String get searchHint => 'Search';

  @override
  String get typeArtistNameHint => 'Type an artist name';

  @override
  String get flavorText => 'Flavor text';

  @override
  String get typeFlavorTextHint => 'Type flavor text';

  @override
  String get loadMore => 'Load more results';

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
      'Configure local databases: Magic from Scryfall, Pokemon from the hosted bundle.';

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
      'Unlock Pro to remove the 7-collection limit.';

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
  String get restorePurchases => 'Restore purchases';

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
  String get dbUpdateAvailableTapHere => 'DB update available, tap here';

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
  String get addCollection => 'Add collection/set';

  @override
  String get addCollectionSubtitle => 'Create set-based or custom.';

  @override
  String get addWishlist => 'Add wishlist';

  @override
  String get addWishlistSubtitle => 'Create a wishlist for missing cards.';

  @override
  String get chooseCollection => 'Choose collection';

  @override
  String get chooseCardDatabaseTitle => 'Choose database profile';

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
  String get specialCollections => 'Special';

  @override
  String get buildYourCollectionsTitle => 'Build your own collections';

  @override
  String get buildYourCollectionsSubtitle =>
      'Tap to create your first collection.';

  @override
  String get createYourCustomCollectionTitle => 'Create your custom collection';

  @override
  String get createYourCustomCollectionSubtitle => 'Add cards manually.';

  @override
  String get createYourSetCollectionTitle => 'Create your set collection';

  @override
  String get createYourSetCollectionSubtitle => 'Track missing cards by set.';

  @override
  String get createYourDeckTitle => 'Create your deck';

  @override
  String get createYourWishlistTitle => 'Create your wishlist';

  @override
  String get createYourWishlistSubtitle => 'Add missing cards you want.';

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
  String get newDeckTitle => 'New deck';

  @override
  String get create => 'Create';

  @override
  String get collectionNameHint => 'Collection name';

  @override
  String get deckNameHint => 'Deck name';

  @override
  String get deckFormatOptionalLabel => 'Format (optional)';

  @override
  String get noFormatOption => 'No format';

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
  String get filteredResultsTitle => 'Filtered results';

  @override
  String get filteredCardsCountLabel => 'Cards matching your filters';

  @override
  String get refineSearchToSeeMore =>
      'Refine your search to view more than 100 cards.';

  @override
  String get viewResults => 'View results';

  @override
  String get searchCardTitle => 'Search card';

  @override
  String get filters => 'Filters';

  @override
  String get addOne => 'Add one';

  @override
  String get missingLabel => 'Missing';

  @override
  String get legalLabel => 'Legal';

  @override
  String get notLegalLabel => 'Not legal';

  @override
  String get typeCardNameHint => 'Type a card name';

  @override
  String get deckSectionCreatures => 'Creatures';

  @override
  String get deckSectionInstants => 'Instants';

  @override
  String get deckSectionSorceries => 'Sorceries';

  @override
  String get deckSectionArtifacts => 'Artifacts';

  @override
  String get deckSectionEnchantments => 'Enchantments';

  @override
  String get deckSectionPlaneswalkers => 'Planeswalkers';

  @override
  String get deckSectionBattles => 'Battles';

  @override
  String get deckSectionLands => 'Lands';

  @override
  String get deckSectionTribals => 'Tribals';

  @override
  String get deckSectionOther => 'Other';

  @override
  String get basicLandsLabel => 'Basic lands';

  @override
  String resultsWithFilters(int visible, int total, Object languages) {
    return 'Results: $visible / $total Â· Languages: $languages';
  }

  @override
  String resultsWithoutFilters(int total, Object languages) {
    return 'Results: $total Â· Languages: $languages';
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
    return 'Set â€¢ $count cards';
  }

  @override
  String customCollectionCount(int count) {
    return 'Custom â€¢ $count cards';
  }

  @override
  String get createCollectionTitle => 'Create collection';

  @override
  String get setCollectionTitle => 'Set collection';

  @override
  String get setCollectionSubtitle => 'Tracks missing cards by set.';

  @override
  String get wishlistCollectionTitle => 'Wishlist';

  @override
  String get wishlistCollectionSubtitle => 'Add missing cards you want.';

  @override
  String get wishlistDefaultName => 'Wishlist';

  @override
  String get wishlistLimitReachedTitle => 'Wishlist limit reached';

  @override
  String wishlistLimitReachedBody(int limit) {
    return 'Free plan supports up to $limit wishlist.';
  }

  @override
  String get customCollectionTitle => 'Custom collection';

  @override
  String get customCollectionSubtitle => 'Create a custom collection.';

  @override
  String get deckCollectionTitle => 'Deck';

  @override
  String get deckCollectionSubtitle =>
      'Container for playing (optional format).';

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

  @override
  String get detailFormat => 'Format';

  @override
  String get sortBy => 'Sort by';

  @override
  String get selectCards => 'Select cards';

  @override
  String selectedCardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: '0 selected',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get deleteCardsTitle => 'Delete selected cards?';

  @override
  String deleteCardsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
      zero: '0 cards',
    );
    return 'This will delete $_temp0 from this collection.';
  }

  @override
  String filteredResultsSummary(int visible, int total) {
    return 'Results: $visible/$total';
  }

  @override
  String get viewMoreResults => 'View more results';

  @override
  String get priceSourceTitle => 'Price source';

  @override
  String get dailySnapshot => 'Daily snapshot';

  @override
  String get unableToSignOutTryAgain => 'Unable to sign out. Try again.';

  @override
  String get signOut => 'Sign out';

  @override
  String get guestLabel => 'Guest';

  @override
  String get googleUserLabel => 'Google User';

  @override
  String get localProfileLabel => 'Local profile';

  @override
  String get signedInWithGoogle => 'Signed in with Google';

  @override
  String get profile => 'Profile';

  @override
  String get proCardSubtitle =>
      'BinderVault is fully usable for free. Plus gives you higher limits.';

  @override
  String get needMoreThanFreeTitle => 'Want higher limits?';

  @override
  String get needMoreThanFreeBody =>
      'Use BinderVault for free, or compare Plus plans if you need more room for your collection workflow.';

  @override
  String get discoverPlus => 'Discover Plus';

  @override
  String get pricesTitle => 'Prices';

  @override
  String get pricesSubtitle => 'Price data provider and visible currencies.';

  @override
  String get showPricesLabel => 'Show prices';

  @override
  String get scryfallDailySnapshot => 'Scryfall daily snapshot';

  @override
  String get availableCurrenciesHint =>
      'Available in app: EUR and USD (foil uses foil value when available).';

  @override
  String get appInfo => 'App info';

  @override
  String get versionLabel => 'Version';

  @override
  String get addByNameTitle => 'By name';

  @override
  String get addByNameSubtitle => 'Search and add manually';

  @override
  String get addByScanTitle => 'By scan';

  @override
  String get addByScanSubtitle => 'Live OCR card recognition';

  @override
  String get noCardTextRecognizedTryLightFocus =>
      'No card text recognized. Try better light and focus.';

  @override
  String get dailyScanLimitReachedTitle => 'Daily scan limit reached';

  @override
  String get freePlan20ScansUpgradePlusBody =>
      'Free plan allows 20 scans per day. Upgrade to Plus for unlimited scans.';

  @override
  String get allArtworks => 'Search online';

  @override
  String get ownedLabel => 'Owned';

  @override
  String get searchingOnlinePrintings => 'Searching online printings...';

  @override
  String get addToCollection => 'Add to collection';

  @override
  String get closePreview => 'Close preview';

  @override
  String get retry => 'Retry';

  @override
  String get addLabel => 'Add';

  @override
  String get cardAddedTitle => 'Card added';

  @override
  String get scanAnotherCardQuestion => 'Do you want to scan another card?';

  @override
  String get no => 'No';

  @override
  String get addViaScanTitle => 'Add via scan';

  @override
  String get scanCardWithLiveOcrSubtitle => 'Scan a card with live OCR';

  @override
  String get alignCardInFrame => 'Align the card in the frame.';

  @override
  String get cameraUnavailableCheckPermissions =>
      'Camera unavailable. Check permissions.';

  @override
  String get flashNotAvailableOnDevice =>
      'Flash is not available on this device.';

  @override
  String get searchingCardTextStatus => 'Searching card text...';

  @override
  String get searchingCardNameStatus => 'Searching card name...';

  @override
  String get nameRecognizedOpeningSearchStatus =>
      'Name recognized. Opening search...';

  @override
  String get ocrUnstableRetryingStatus => 'OCR unstable, retrying...';

  @override
  String get nameLabel => 'Name';

  @override
  String get waitingStatus => 'Waiting';

  @override
  String get pleaseWait => 'Please wait.';

  @override
  String get liveOcrActive => 'Live OCR active';

  @override
  String get liveCardScanTitle => 'Live card scan';

  @override
  String get torchTooltip => 'Torch';

  @override
  String get uiLanguageTitle => 'UI language';

  @override
  String get uiLanguageSubtitle => 'Choose the app interface language.';

  @override
  String get plusPageTitle => 'BinderVault Plus';

  @override
  String get plusActive => 'Plus active';

  @override
  String get upgradeToPlus => 'Upgrade to Plus';

  @override
  String get plusPaywallSubtitle =>
      'Unlock premium features across your unlocked TCGs.';

  @override
  String get plusTagAccountWide => 'Account-wide';

  @override
  String get plusTagAllUnlockedTcgs => 'All unlocked TCGs';

  @override
  String get plusPaywallCoverageNote =>
      'Plus applies to premium features for every TCG you have already unlocked or purchased.';

  @override
  String get freePlanLabel => 'Free';

  @override
  String get plusPlanLabel => 'Plus';

  @override
  String get smartCollectionsFeature => 'Smart collections';

  @override
  String get dailyCardScansFeature => 'Daily card scans';

  @override
  String get collectionsFeature => 'Collections';

  @override
  String get setCollectionsFeature => 'Set collections';

  @override
  String get customCollectionsFeature => 'Custom collections';

  @override
  String get decksFeature => 'Decks';

  @override
  String get wishlistFeature => 'Wishlist';

  @override
  String get freeCollectionsBreakdown => '2 set, 2 custom, 2 decks, 1 wishlist';

  @override
  String get cardSearchAddFeature => 'Card search and add';

  @override
  String get advancedFiltersFeature => 'Advanced filters';

  @override
  String scansPerDay(int count) {
    return '$count/day';
  }

  @override
  String get unlimitedLabel => 'Unlimited';

  @override
  String get monthlyPlanLabel => 'Monthly';

  @override
  String get yearlyPlanLabel => 'Yearly';

  @override
  String get plusMonthlyLabel => 'Monthly';

  @override
  String get plusYearlyLabel => 'Yearly';

  @override
  String plusMonthlyPlanPrice(Object price) {
    return '$price/month, billed monthly';
  }

  @override
  String plusYearlyPlanPrice(Object price) {
    return '$price/year, billed yearly';
  }

  @override
  String get plusDisclosureAutoRenew =>
      'Subscriptions renew automatically unless cancelled.';

  @override
  String get plusDisclosureCancellation =>
      'Cancel anytime in Google Play Subscriptions.';

  @override
  String get plusDisclosureFreeUsage =>
      'BinderVault can be used without a subscription. Plus unlocks premium features only.';

  @override
  String get plusDisclosureRegionalPricing =>
      'Prices may vary by region and include applicable taxes.';

  @override
  String get continueWithFree => 'Continue with Free';

  @override
  String get alreadySubscribedRestore => 'Already subscribed? Restore';

  @override
  String get previewBillingNotice =>
      'Subscription terms are shown here before Google Play checkout.';

  @override
  String get billingLoadingPlans => 'Loading subscription plans...';

  @override
  String get billingPlansUnavailable =>
      'Subscription plans are not available right now.';

  @override
  String get billingStoreUnavailable =>
      'Store is unavailable on this device/account.';

  @override
  String get billingRestoringPurchases => 'Restoring purchases...';

  @override
  String get billingWaitingPurchase => 'Waiting for purchase confirmation...';

  @override
  String get scryfallProviderLabel => 'Scryfall';

  @override
  String get currencyEurCode => 'EUR';

  @override
  String get currencyUsdCode => 'USD';

  @override
  String get limitedCoverageTapAllArtworks =>
      'Limited local coverage\nTap \"Search online\" to see more cards';

  @override
  String planSelectedPreview(Object plan) {
    return '$plan plan selected. Billing will be enabled in a next step.';
  }

  @override
  String get authNetworkErrorDuringSignIn =>
      'Network error during sign-in. Check connection and retry.';

  @override
  String get authInvalidGoogleCredential =>
      'Invalid Google credential. Try again.';

  @override
  String authGoogleSignInFailedWithCode(Object code) {
    return 'Google sign-in failed ($code).';
  }

  @override
  String get authGoogleSignInConfigError =>
      'Google sign-in config error (SHA/package/Firebase config).';

  @override
  String get authNetworkErrorDuringGoogleSignIn =>
      'Network error during Google sign-in.';

  @override
  String get authGoogleSignInCancelled => 'Google sign-in cancelled.';

  @override
  String get authGoogleSignInFailedTryAgain =>
      'Google sign-in failed. Try again.';

  @override
  String get authWelcomeTitle => 'Welcome to BinderVault';

  @override
  String get authWelcomeSubtitle => 'Sign in with Google to sync your account.';

  @override
  String get authSignInWithGoogle => 'Sign in with Google';

  @override
  String get authContinueAsGuest => 'Continue as guest';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupSubtitle =>
      'Export or import your full local collections backup.';

  @override
  String get backupExport => 'Export';

  @override
  String get backupImport => 'Import';

  @override
  String get backupNoFilesFound => 'No local backup files found.';

  @override
  String get backupChooseImportFile => 'Choose backup file';

  @override
  String get backupImportConfirmTitle => 'Import backup?';

  @override
  String get backupImportConfirmBody =>
      'This will replace current collections and owned entries.';

  @override
  String backupExported(Object fileName) {
    return 'Backup exported: $fileName';
  }

  @override
  String backupImported(int collections, int entries) {
    return 'Backup imported. Collections: $collections, entries: $entries';
  }

  @override
  String get share => 'Share';

  @override
  String get backupShareNowTitle => 'Share backup now?';

  @override
  String get backupShareNowBody =>
      'You can send the exported file via email, messaging apps, or cloud drives.';

  @override
  String backupShareFailed(Object error) {
    return 'Unable to share backup: $error';
  }

  @override
  String get primaryGamePickerTitle => 'Choose your primary game';

  @override
  String get primaryGamePickerBody =>
      'Select your main game. The other game will be available with Pro.';

  @override
  String get primaryFreeLabel => 'Included in free plan';

  @override
  String get continueLabel => 'Continue';

  @override
  String get latestAddsLabel => 'Latest adds';

  @override
  String get homeStartCollectionPrompt =>
      'Start your collection now: tap + and add your first cards.';

  @override
  String get unlockOtherGameToSwitch =>
      'Unlock the other game in Pro to switch.';

  @override
  String get scannerTutorialTitle => 'Scanner tutorial';

  @override
  String get scannerTutorialIntro =>
      'Use these controls to speed up recognition:';

  @override
  String get scannerTutorialSet => '• Set: limits search to the selected set.';

  @override
  String get scannerTutorialFoil =>
      '• Foil: marks the card as foil when you add it.';

  @override
  String get scannerTutorialCheck =>
      '• Check: if frame is green and name matches, tap to confirm and speed up scanning.';

  @override
  String get scannerTutorialFlash => '• Flash: useful in low-light conditions.';

  @override
  String get doNotShowAgain => 'Do not show again';

  @override
  String get scannerSetAnyLabel => 'Set: any';

  @override
  String get scannerAnySetOption => 'Any set';

  @override
  String get closeLabel => 'Close';

  @override
  String get openSettingsLabel => 'Open settings';

  @override
  String gameInProTitle(Object game) {
    return '$game in Pro';
  }

  @override
  String gameOneTimeUnlockBody(Object game) {
    return '$game is available as a one-time unlock. Activate it from Settings.';
  }

  @override
  String get pokemonInProTitle => 'Pokemon available in Pro';

  @override
  String get pokemonInProBody =>
      'Unlock Pokemon from Settings to use collections, search, and dedicated database download.';

  @override
  String get customLabel => 'Custom';

  @override
  String get smartLabel => 'Smart';

  @override
  String get homeSetHelp =>
      'Choose a specific set and follow its checklist clearly: instantly see collected cards and missing ones.';

  @override
  String get homeCustomHelp =>
      'Create manual collections and include only cards you already own in inventory.';

  @override
  String get homeSmartHelp =>
      'Save a dynamic filter: smart collections automatically show only owned cards matching your criteria.';

  @override
  String get homeWishHelp =>
      'Create a wishlist with advanced filters to track the missing cards you are looking for.';

  @override
  String get homeDeckHelp =>
      'Track your decks and update mainboard/sideboard: deck cards stay in the deck and are not added to collections.';

  @override
  String get smartCollectionDefaultName => 'Smart collection';

  @override
  String get newSmartCollectionTitle => 'New smart collection';

  @override
  String get smartCollectionNeedFilterToCreate =>
      'Choose at least one filter to create a smart collection.';

  @override
  String get smartCollectionNeedAtLeastOneFilter =>
      'Choose at least one filter.';

  @override
  String get saveFilterLabel => 'Save filter';

  @override
  String get loadArenaMtgoFileLabel => 'Load Arena/MTGO file';

  @override
  String get pokemonDeckHintLabel =>
      'Pokemon deck: exactly 60 cards, max 4 copies per name (except Basic Energy), at least 1 Basic Pokemon.';

  @override
  String get importDeckListLabel => 'Import deck list';

  @override
  String get exportForArenaLabel => 'Export for Arena';

  @override
  String get exportForMtgoLabel => 'Export for MTGO';

  @override
  String deckImportedSummary(int imported, int skipped) {
    return 'Deck imported: $imported cards, $skipped not found';
  }

  @override
  String get deckImportingLabel => 'Importing deck...';

  @override
  String get deckImportResultTitle => 'Import result';

  @override
  String get deckImportCardsNotFoundTitle => 'Cards not found';

  @override
  String deckExportedSummary(Object fileName) {
    return 'Deck exported: $fileName';
  }

  @override
  String deckImportFailed(Object error) {
    return 'Deck import failed: $error';
  }

  @override
  String deckExportFailed(Object error) {
    return 'Deck export failed: $error';
  }

  @override
  String get pokemonDbProfileFullTitle => 'Complete catalog (all sets)';

  @override
  String get pokemonDbProfileExpandedTitle => 'Medium coverage (fixed 10 sets)';

  @override
  String get pokemonDbProfileStandardTitle => 'Base coverage (fixed 6 sets)';

  @override
  String get pokemonDbProfileStarterTitle => 'Minimal coverage (fixed 3 sets)';

  @override
  String get pokemonDbProfileFullDescription =>
      'Installs the full hosted Pokemon catalog for the most complete offline coverage, with longer download and larger local DB.';

  @override
  String get pokemonDbProfileExpandedDescription =>
      'Imports 10 predefined sets: base1, swsh1-5, sv1-4. Does not include all recent expansions.';

  @override
  String get pokemonDbProfileStandardDescription =>
      'Imports 6 predefined sets: base1, swsh1, sv1-4. Balanced speed and coverage.';

  @override
  String get pokemonDbProfileStarterDescription =>
      'Imports 3 predefined sets: base1, swsh1, sv1. Fastest, with limited coverage.';

  @override
  String get pokemonDbPickerTitle => 'Choose Pokemon catalog coverage';

  @override
  String get pokemonDbPickerSubtitle =>
      'Choose how much of the hosted Pokemon catalog to keep offline: more coverage = more time and storage.';

  @override
  String get primaryGameFixedMessage => 'Primary game is fixed.';

  @override
  String get primaryFreeForever => 'Primary free (forever)';

  @override
  String get purchasedLabel => 'Purchased';

  @override
  String get secondaryPurchaseRequired => 'Secondary: purchase required';

  @override
  String buyGameLabel(Object game, Object price) {
    return 'Buy $game $price';
  }

  @override
  String get purchasesRestoredMessage => 'Purchases restored.';

  @override
  String get restorePurchasesTimeoutMessage =>
      'Restore purchases is taking too long. Try again.';

  @override
  String get restorePurchasesErrorMessage =>
      'Error while restoring purchases. Please retry.';

  @override
  String get playStoreProductUnavailable =>
      'Product not available on Google Play.';

  @override
  String buyGameTitle(Object game) {
    return 'Unlock $game Support';
  }

  @override
  String buyGameBody(Object game, Object price) {
    return 'This one-time purchase unlocks $game features in BinderVault for this account.\nPrice: $price\n\nNo subscription required.\nPurchases are handled by Google Play.';
  }

  @override
  String get continuePurchaseLabel => 'Continue purchase';

  @override
  String get purchaseAlreadyOwnedSynced =>
      'Purchase already owned on Google Play. Entitlement synced.';

  @override
  String get storeConnectionTimeout =>
      'Store connection is taking too long. Try again.';

  @override
  String get purchaseFailedRetry => 'Error during purchase. Please retry.';

  @override
  String get themeVaultDescription =>
      'Steel-blue palette with a technical mood.';

  @override
  String get themeMagicDescription => 'Classic BinderVault gold/brown look.';

  @override
  String get visualThemeTitle => 'Visual theme';

  @override
  String get themeMagicSubtitle => 'Default: original style';

  @override
  String get themeVaultSubtitle => 'Alternative steel-blue look';

  @override
  String get issueCategoryCrash => 'Crash';

  @override
  String get issueCategoryUi => 'UI';

  @override
  String get issueCategoryPurchase => 'Purchases';

  @override
  String get issueCategoryDatabase => 'Database';

  @override
  String get issueCategoryOther => 'Other';

  @override
  String get reportIssueLabel => 'Report issue';

  @override
  String get issueCategoryLabel => 'Category';

  @override
  String get issueDescribeHint =>
      'Describe what happened and how to reproduce it.';

  @override
  String get sendLabel => 'Send';

  @override
  String get reportSentThanks => 'Report sent. Thanks.';

  @override
  String get reportSendUnavailable =>
      'Sending is not available right now. Please retry.';

  @override
  String get diagnosticsCopied => 'Diagnostics copied to clipboard.';

  @override
  String get resetMagicDatabaseLabel => 'Reset Magic database';

  @override
  String resetGameDatabaseTitle(Object game) {
    return 'Reset $game database';
  }

  @override
  String resetGameDatabaseBody(Object game) {
    return 'Only $game cards will be deleted and reimported from scratch. Collections, decks, and quantities stay unchanged.';
  }

  @override
  String get resetInProgressTitle => 'Reset in progress';

  @override
  String cleaningGameDatabase(Object game) {
    return 'Cleaning $game database...';
  }

  @override
  String gameDatabaseResetDone(Object game) {
    return '$game database reset. It will be downloaded again cleanly.';
  }

  @override
  String get applyProfileLabel => 'Apply profile';

  @override
  String get pokemonProfileUpdatedTapUpdate =>
      'Pokemon profile updated. Tap Update available in Home to apply.';

  @override
  String get gamesSelectionSubtitle =>
      'The first selected game stays free forever. The other requires purchase.';

  @override
  String get primaryGameLabel => 'Primary game';

  @override
  String get configureBothDatabasesSubtitle =>
      'Magic and Pokemon have separate profiles: choose coverage, download time, and local storage.';

  @override
  String get toolsAndDiagnosticsTitle => 'Tools & diagnostics';

  @override
  String get checkCoherenceLabel => 'Check coherence';

  @override
  String get copyDiagnosticsLabel => 'Copy diagnostics';

  @override
  String get whatsNewButtonLabel => 'What\'s new';

  @override
  String get whatsNewDialogTitle => 'What\'s new in 0.5.2';

  @override
  String get whatsNewFeaturesTitle => 'Main updates';

  @override
  String get whatsNewBugFixesTitle => 'Fixes';

  @override
  String get whatsNewLine1 =>
      'Improved multilingual support across search, results, and the local catalog.';

  @override
  String get whatsNewLine2 =>
      'Refactored the Pokemon database layer for a more solid and maintainable foundation.';

  @override
  String get whatsNewLine3 =>
      'Updated deck card handling with clearer legal and not legal states.';

  @override
  String get whatsNewLine4 =>
      'Improved consistency between counts, previews, and card adding flows in filters.';

  @override
  String get whatsNewLine5 =>
      'Deck search now shows all matching cards with legal or not legal badges.';

  @override
  String get whatsNewLine6 =>
      'Reduced incorrect missing states inside deck-related flows.';

  @override
  String get whatsNewLine7 => '';

  @override
  String get whatsNewLine8 =>
      'Fixed major issues across decks, smart filters, previews, and add-card flows.';

  @override
  String get whatsNewLine9 =>
      'Also includes various minor UI, alignment, and stability fixes.';

  @override
  String get createSmartCollectionTitle => 'Create your smart collection';

  @override
  String get pokemonEnergyGrass => 'Grass';

  @override
  String get pokemonEnergyFire => 'Fire';

  @override
  String get pokemonEnergyWater => 'Water';

  @override
  String get pokemonEnergyLightning => 'Lightning';

  @override
  String get pokemonEnergyPsychicDarkness => 'Psychic/Darkness';

  @override
  String get pokemonEnergyFighting => 'Fighting';

  @override
  String get pokemonEnergyDragon => 'Dragon';

  @override
  String get pokemonEnergyFairy => 'Fairy';

  @override
  String get pokemonEnergyColorless => 'Colorless';

  @override
  String get pokemonEnergyMetal => 'Metal';

  @override
  String get pokemonEnergyNone => 'None';

  @override
  String get pokemonTypeTrainer => 'Trainer';

  @override
  String get pokemonTypeEnergy => 'Energy';

  @override
  String get pokemonTypeItem => 'Item';

  @override
  String get pokemonTypeSupporter => 'Supporter';

  @override
  String get pokemonTypeStadium => 'Stadium';

  @override
  String get pokemonTypeTool => 'Pokemon Tool';

  @override
  String get pokemonEnergyTypeLabel => 'Energy type';

  @override
  String get pokemonCardCategoryLabel => 'Card category';

  @override
  String get pokemonAttackEnergyCostLabel => 'Attack energy cost';

  @override
  String get addMultipleCardsByFilterTitle => 'Add multiple cards by filter';

  @override
  String get addMultipleCardsByFilterSubtitle =>
      'Apply filters and add all matching cards';

  @override
  String get allSelectedCardsOwned => 'All selected cards are already owned.';

  @override
  String get skippedLabel => 'Skipped';

  @override
  String get totalLabel => 'Total';

  @override
  String get pokemonEnergyPluralLabel => 'Energy';

  @override
  String get deckRule60Ok => '60-card rule: OK';

  @override
  String get deckBasicPokemonPresentOk => 'Basic Pokemon present: OK';

  @override
  String get deckBasicPokemonRequired =>
      'At least 1 Basic Pokemon is required.';

  @override
  String get deckCopyLimitOk => 'Copy limit: OK';

  @override
  String deckCopyLimitExceeded(int count) {
    return '$count card names exceed 4 copies (Basic Energy excluded).';
  }

  @override
  String deckAddCardsToReach60(int count) {
    return 'Add $count cards to reach 60.';
  }

  @override
  String deckRemoveCardsToReturn60(int count) {
    return 'Remove $count cards to get back to 60.';
  }
}
