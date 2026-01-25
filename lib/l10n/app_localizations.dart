import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TCG Tracker'**
  String get appTitle;

  /// No description provided for @allCards.
  ///
  /// In en, this message translates to:
  /// **'All cards'**
  String get allCards;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// No description provided for @bulkAllPrintingsTitle.
  ///
  /// In en, this message translates to:
  /// **'All printings'**
  String get bulkAllPrintingsTitle;

  /// No description provided for @bulkAllPrintingsDescription.
  ///
  /// In en, this message translates to:
  /// **'All printings and languages. Heaviest.'**
  String get bulkAllPrintingsDescription;

  /// No description provided for @bulkOracleCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Oracle cards'**
  String get bulkOracleCardsTitle;

  /// No description provided for @bulkOracleCardsDescription.
  ///
  /// In en, this message translates to:
  /// **'One entry per card. Fewer variants.'**
  String get bulkOracleCardsDescription;

  /// No description provided for @bulkUniqueArtworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Unique artwork'**
  String get bulkUniqueArtworkTitle;

  /// No description provided for @bulkUniqueArtworkDescription.
  ///
  /// In en, this message translates to:
  /// **'One entry per artwork. Lightest.'**
  String get bulkUniqueArtworkDescription;

  /// No description provided for @gamePokemonDescription.
  ///
  /// In en, this message translates to:
  /// **'Pokemon TCG collections.'**
  String get gamePokemonDescription;

  /// No description provided for @gameMagicDescription.
  ///
  /// In en, this message translates to:
  /// **'Magic: The Gathering collections.'**
  String get gameMagicDescription;

  /// No description provided for @gameYugiohDescription.
  ///
  /// In en, this message translates to:
  /// **'Yu-Gi-Oh! collections.'**
  String get gameYugiohDescription;

  /// No description provided for @cardCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {0 cards} =1 {1 card} other {{count} cards}}'**
  String cardCount(int count);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @searchLanguages.
  ///
  /// In en, this message translates to:
  /// **'Search languages'**
  String get searchLanguages;

  /// No description provided for @searchLanguagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which card languages appear in search.'**
  String get searchLanguagesSubtitle;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @addLanguage.
  ///
  /// In en, this message translates to:
  /// **'Add language'**
  String get addLanguage;

  /// No description provided for @allLanguagesAdded.
  ///
  /// In en, this message translates to:
  /// **'All languages are already added.'**
  String get allLanguagesAdded;

  /// No description provided for @languageAddedDownloadAgain.
  ///
  /// In en, this message translates to:
  /// **'Language added. Download again to import the cards.'**
  String get languageAddedDownloadAgain;

  /// No description provided for @cardDatabase.
  ///
  /// In en, this message translates to:
  /// **'Card database'**
  String get cardDatabase;

  /// No description provided for @cardDatabaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which database to download from Scryfall.'**
  String get cardDatabaseSubtitle;

  /// No description provided for @selectedType.
  ///
  /// In en, this message translates to:
  /// **'Selected type'**
  String get selectedType;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @changeDatabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Change database?'**
  String get changeDatabaseTitle;

  /// No description provided for @changeDatabaseBody.
  ///
  /// In en, this message translates to:
  /// **'The current database will be removed and you will need to download the cards again.'**
  String get changeDatabaseBody;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @updatingDatabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Updating database'**
  String get updatingDatabaseTitle;

  /// No description provided for @preparingDatabaseBody.
  ///
  /// In en, this message translates to:
  /// **'Preparing the new database...'**
  String get preparingDatabaseBody;

  /// No description provided for @databaseChangedGoHome.
  ///
  /// In en, this message translates to:
  /// **'Database changed. Go back to Home to download.'**
  String get databaseChangedGoHome;

  /// No description provided for @games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get games;

  /// No description provided for @gamesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage which TCGs are enabled.'**
  String get gamesSubtitle;

  /// No description provided for @makePrimary.
  ///
  /// In en, this message translates to:
  /// **'Make primary'**
  String get makePrimary;

  /// No description provided for @addGame.
  ///
  /// In en, this message translates to:
  /// **'Add game'**
  String get addGame;

  /// No description provided for @gameLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Game limit reached'**
  String get gameLimitReachedTitle;

  /// No description provided for @gameLimitReachedBody.
  ///
  /// In en, this message translates to:
  /// **'The free version allows one game. Upgrade to Pro to add more.'**
  String get gameLimitReachedBody;

  /// No description provided for @allGamesAdded.
  ///
  /// In en, this message translates to:
  /// **'All games are already added.'**
  String get allGamesAdded;

  /// No description provided for @primaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primaryLabel;

  /// No description provided for @addedLabel.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get addedLabel;

  /// No description provided for @primaryGameSet.
  ///
  /// In en, this message translates to:
  /// **'Primary game set to {game}.'**
  String primaryGameSet(Object game);

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get pro;

  /// No description provided for @proSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock unlimited collections.'**
  String get proSubtitle;

  /// No description provided for @proStatus.
  ///
  /// In en, this message translates to:
  /// **'Pro status'**
  String get proStatus;

  /// No description provided for @proActive.
  ///
  /// In en, this message translates to:
  /// **'Pro active'**
  String get proActive;

  /// No description provided for @basePlan.
  ///
  /// In en, this message translates to:
  /// **'Base plan'**
  String get basePlan;

  /// No description provided for @storeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Store available'**
  String get storeAvailable;

  /// No description provided for @storeNotAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'Store not available yet'**
  String get storeNotAvailableYet;

  /// No description provided for @unlimitedCollectionsUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlimited collections are unlocked.'**
  String get unlimitedCollectionsUnlocked;

  /// No description provided for @unlockProRemoveLimit.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pro to remove the 5-collection limit.'**
  String get unlockProRemoveLimit;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price: {price}'**
  String priceLabel(Object price);

  /// No description provided for @whatYouGet.
  ///
  /// In en, this message translates to:
  /// **'What you get'**
  String get whatYouGet;

  /// No description provided for @unlimitedCollectionsFeature.
  ///
  /// In en, this message translates to:
  /// **'Unlimited collections'**
  String get unlimitedCollectionsFeature;

  /// No description provided for @supportFuturePremiumFeatures.
  ///
  /// In en, this message translates to:
  /// **'Support future premium features'**
  String get supportFuturePremiumFeatures;

  /// No description provided for @switchToBaseTest.
  ///
  /// In en, this message translates to:
  /// **'Switch to Base (test)'**
  String get switchToBaseTest;

  /// No description provided for @switchToProTest.
  ///
  /// In en, this message translates to:
  /// **'Switch to Pro (test)'**
  String get switchToProTest;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @testMode.
  ///
  /// In en, this message translates to:
  /// **'Test mode'**
  String get testMode;

  /// No description provided for @testModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, Upgrade toggles Pro locally.'**
  String get testModeSubtitle;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all collections and the card database.'**
  String get resetSubtitle;

  /// No description provided for @factoryReset.
  ///
  /// In en, this message translates to:
  /// **'Factory reset'**
  String get factoryReset;

  /// No description provided for @factoryResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Factory reset?'**
  String get factoryResetTitle;

  /// No description provided for @factoryResetBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove all collections, the card database, and downloads. The app will return to a first-launch state.'**
  String get factoryResetBody;

  /// No description provided for @cleaningUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Cleaning up'**
  String get cleaningUpTitle;

  /// No description provided for @removingLocalDataBody.
  ///
  /// In en, this message translates to:
  /// **'Removing local data...'**
  String get removingLocalDataBody;

  /// No description provided for @resetComplete.
  ///
  /// In en, this message translates to:
  /// **'Reset complete. Restart the app.'**
  String get resetComplete;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @chooseDatabase.
  ///
  /// In en, this message translates to:
  /// **'Choose database'**
  String get chooseDatabase;

  /// No description provided for @downloadDatabase.
  ///
  /// In en, this message translates to:
  /// **'Download database'**
  String get downloadDatabase;

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get downloadUpdate;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @downloadingWithPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading... {percent}%'**
  String downloadingWithPercent(int percent);

  /// No description provided for @importingWithPercent.
  ///
  /// In en, this message translates to:
  /// **'Importing... {percent}%'**
  String importingWithPercent(int percent);

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking updates...'**
  String get checkingUpdates;

  /// No description provided for @downloadingUpdateWithTotal.
  ///
  /// In en, this message translates to:
  /// **'Downloading update... {percent}% ({received} / {total})'**
  String downloadingUpdateWithTotal(int percent, Object received, Object total);

  /// No description provided for @downloadingUpdateNoTotal.
  ///
  /// In en, this message translates to:
  /// **'Downloading update... {received}'**
  String downloadingUpdateNoTotal(Object received);

  /// No description provided for @importingCardsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Importing cards... {percent}% ({count} cards)'**
  String importingCardsWithCount(int percent, int count);

  /// No description provided for @downloadFailedTapUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Tap update again.'**
  String get downloadFailedTapUpdate;

  /// No description provided for @selectDatabaseToDownload.
  ///
  /// In en, this message translates to:
  /// **'Select a database to download.'**
  String get selectDatabaseToDownload;

  /// No description provided for @databaseMissingDownloadRequired.
  ///
  /// In en, this message translates to:
  /// **'Database {name} missing. Download required.'**
  String databaseMissingDownloadRequired(Object name);

  /// No description provided for @updateReadyWithDate.
  ///
  /// In en, this message translates to:
  /// **'Update ready: {date}'**
  String updateReadyWithDate(Object date);

  /// No description provided for @unknownDate.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknownDate;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date.'**
  String get upToDate;

  /// No description provided for @importNow.
  ///
  /// In en, this message translates to:
  /// **'Import now'**
  String get importNow;

  /// No description provided for @gameLabel.
  ///
  /// In en, this message translates to:
  /// **'Game: {game}'**
  String gameLabel(Object game);

  /// No description provided for @rebuildingSearchIndex.
  ///
  /// In en, this message translates to:
  /// **'Rebuilding search index'**
  String get rebuildingSearchIndex;

  /// No description provided for @requiredAfterLargeUpdates.
  ///
  /// In en, this message translates to:
  /// **'Required after large updates.'**
  String get requiredAfterLargeUpdates;

  /// No description provided for @addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addTitle;

  /// No description provided for @addCards.
  ///
  /// In en, this message translates to:
  /// **'Add card(s)'**
  String get addCards;

  /// No description provided for @addCardsToCatalogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add to the main catalog.'**
  String get addCardsToCatalogSubtitle;

  /// No description provided for @addCardsToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add card(s) to a collection'**
  String get addCardsToCollection;

  /// No description provided for @addCardsToCollectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a custom collection.'**
  String get addCardsToCollectionSubtitle;

  /// No description provided for @addCollection.
  ///
  /// In en, this message translates to:
  /// **'Add a collection'**
  String get addCollection;

  /// No description provided for @addCollectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create set-based or custom.'**
  String get addCollectionSubtitle;

  /// No description provided for @chooseCollection.
  ///
  /// In en, this message translates to:
  /// **'Choose collection'**
  String get chooseCollection;

  /// No description provided for @chooseCardDatabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose card database'**
  String get chooseCardDatabaseTitle;

  /// No description provided for @chooseYourGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your game'**
  String get chooseYourGameTitle;

  /// No description provided for @collectionLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection limit reached'**
  String get collectionLimitReachedTitle;

  /// No description provided for @collectionLimitReachedBody.
  ///
  /// In en, this message translates to:
  /// **'The free version allows up to {limit} collections. Upgrade to Pro to unlock unlimited collections.'**
  String collectionLimitReachedBody(int limit);

  /// No description provided for @proActiveUnlimitedCollections.
  ///
  /// In en, this message translates to:
  /// **'Pro active. Unlimited collections.'**
  String get proActiveUnlimitedCollections;

  /// No description provided for @basePlanCollectionLimit.
  ///
  /// In en, this message translates to:
  /// **'Base plan: up to {limit} collections.'**
  String basePlanCollectionLimit(int limit);

  /// No description provided for @proEnabled.
  ///
  /// In en, this message translates to:
  /// **'Pro enabled'**
  String get proEnabled;

  /// No description provided for @upgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get upgradeToPro;

  /// No description provided for @myCollections.
  ///
  /// In en, this message translates to:
  /// **'My collections'**
  String get myCollections;

  /// No description provided for @buildYourCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Build your own collections'**
  String get buildYourCollectionsTitle;

  /// No description provided for @buildYourCollectionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to create your first collection.'**
  String get buildYourCollectionsSubtitle;

  /// No description provided for @addCardsNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Add cards now?'**
  String get addCardsNowTitle;

  /// No description provided for @addCardsNowBody.
  ///
  /// In en, this message translates to:
  /// **'Use search and filters to add multiple cards.'**
  String get addCardsNowBody;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @noSetsAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'No sets available yet.'**
  String get noSetsAvailableYet;

  /// No description provided for @newSetCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'New set collection'**
  String get newSetCollectionTitle;

  /// No description provided for @collectionAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Collection already exists.'**
  String get collectionAlreadyExists;

  /// No description provided for @failedToAddCollection.
  ///
  /// In en, this message translates to:
  /// **'Failed to add collection: {error}'**
  String failedToAddCollection(Object error);

  /// No description provided for @newCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get newCollectionTitle;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @collectionNameHint.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get collectionNameHint;

  /// No description provided for @createCustomCollectionFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a custom collection first.'**
  String get createCustomCollectionFirst;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @renameCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get renameCollectionTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @deleteCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete collection?'**
  String get deleteCollectionTitle;

  /// No description provided for @deleteCollectionBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from this device.'**
  String deleteCollectionBody(Object name);

  /// No description provided for @collectionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Collection deleted.'**
  String get collectionDeleted;

  /// No description provided for @downloadLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Download link unavailable.'**
  String get downloadLinkUnavailable;

  /// No description provided for @scryfallBulkUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Scryfall bulk update available.'**
  String get scryfallBulkUpdateAvailable;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @advancedFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced filters'**
  String get advancedFiltersTitle;

  /// No description provided for @rarity.
  ///
  /// In en, this message translates to:
  /// **'Rarity'**
  String get rarity;

  /// No description provided for @setLabel.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setLabel;

  /// No description provided for @colorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorLabel;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorColorless.
  ///
  /// In en, this message translates to:
  /// **'Colorless'**
  String get colorColorless;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageItalian;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageChineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified)'**
  String get languageChineseSimplified;

  /// No description provided for @languageChineseTraditional.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Traditional)'**
  String get languageChineseTraditional;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageHebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get languageHebrew;

  /// No description provided for @languageLatin.
  ///
  /// In en, this message translates to:
  /// **'Latin'**
  String get languageLatin;

  /// No description provided for @languageGreek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get languageGreek;

  /// No description provided for @languageSanskrit.
  ///
  /// In en, this message translates to:
  /// **'Sanskrit'**
  String get languageSanskrit;

  /// No description provided for @languagePhyrexian.
  ///
  /// In en, this message translates to:
  /// **'Phyrexian'**
  String get languagePhyrexian;

  /// No description provided for @languageQuenya.
  ///
  /// In en, this message translates to:
  /// **'Quenya'**
  String get languageQuenya;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @manaValue.
  ///
  /// In en, this message translates to:
  /// **'Mana value'**
  String get manaValue;

  /// No description provided for @minLabel.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minLabel;

  /// No description provided for @maxLabel.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maxLabel;

  /// No description provided for @noFiltersAvailableForList.
  ///
  /// In en, this message translates to:
  /// **'No filters available for this list.'**
  String get noFiltersAvailableForList;

  /// No description provided for @noFiltersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No filters available.'**
  String get noFiltersAvailable;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete: {path}'**
  String downloadComplete(Object path);

  /// No description provided for @downloadFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailedWithError(Object error);

  /// No description provided for @downloadFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Download failed.'**
  String get downloadFailedGeneric;

  /// No description provided for @networkErrorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get networkErrorTryAgain;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @noCardsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No cards match these filters'**
  String get noCardsMatchFilters;

  /// No description provided for @noOwnedCardsYet.
  ///
  /// In en, this message translates to:
  /// **'No owned cards yet'**
  String get noOwnedCardsYet;

  /// No description provided for @noCardsYet.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get noCardsYet;

  /// No description provided for @tryEnablingOwnedOrMissing.
  ///
  /// In en, this message translates to:
  /// **'Try enabling owned or missing cards.'**
  String get tryEnablingOwnedOrMissing;

  /// No description provided for @addCardsHereOrAny.
  ///
  /// In en, this message translates to:
  /// **'Add cards here or inside any collection.'**
  String get addCardsHereOrAny;

  /// No description provided for @addFirstCardToStartCollection.
  ///
  /// In en, this message translates to:
  /// **'Add your first card to start this collection.'**
  String get addFirstCardToStartCollection;

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get addCard;

  /// No description provided for @searchCardsHint.
  ///
  /// In en, this message translates to:
  /// **'Search cards'**
  String get searchCardsHint;

  /// No description provided for @ownedCount.
  ///
  /// In en, this message translates to:
  /// **'Owned ({count})'**
  String ownedCount(int count);

  /// No description provided for @missingCount.
  ///
  /// In en, this message translates to:
  /// **'Missing ({count})'**
  String missingCount(int count);

  /// No description provided for @useListToSetOwnedQuantities.
  ///
  /// In en, this message translates to:
  /// **'Use the list to set owned quantities.'**
  String get useListToSetOwnedQuantities;

  /// No description provided for @addedCards.
  ///
  /// In en, this message translates to:
  /// **'Added {count} cards.'**
  String addedCards(int count);

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @quantityMultiplier.
  ///
  /// In en, this message translates to:
  /// **'x{count}'**
  String quantityMultiplier(int count);

  /// No description provided for @foilLabel.
  ///
  /// In en, this message translates to:
  /// **'Foil'**
  String get foilLabel;

  /// No description provided for @altArtLabel.
  ///
  /// In en, this message translates to:
  /// **'Alt art'**
  String get altArtLabel;

  /// No description provided for @markMissing.
  ///
  /// In en, this message translates to:
  /// **'Mark missing'**
  String get markMissing;

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Import complete.'**
  String get importComplete;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(Object error);

  /// No description provided for @selectFiltersFirst.
  ///
  /// In en, this message translates to:
  /// **'Select filters first.'**
  String get selectFiltersFirst;

  /// No description provided for @selectSetRarityTypeToNarrow.
  ///
  /// In en, this message translates to:
  /// **'Select Set, Rarity, or Type to narrow results.'**
  String get selectSetRarityTypeToNarrow;

  /// No description provided for @addAllResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add all results?'**
  String get addAllResultsTitle;

  /// No description provided for @addAllResultsBody.
  ///
  /// In en, this message translates to:
  /// **'This will add {count} cards to the collection.'**
  String addAllResultsBody(int count);

  /// No description provided for @addAll.
  ///
  /// In en, this message translates to:
  /// **'Add all'**
  String get addAll;

  /// No description provided for @addFilteredCards.
  ///
  /// In en, this message translates to:
  /// **'Add filtered cards'**
  String get addFilteredCards;

  /// No description provided for @addAllResults.
  ///
  /// In en, this message translates to:
  /// **'Add all results'**
  String get addAllResults;

  /// No description provided for @searchCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Search card'**
  String get searchCardTitle;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @addOne.
  ///
  /// In en, this message translates to:
  /// **'Add one'**
  String get addOne;

  /// No description provided for @missingLabel.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missingLabel;

  /// No description provided for @typeCardNameHint.
  ///
  /// In en, this message translates to:
  /// **'Type a card name'**
  String get typeCardNameHint;

  /// No description provided for @resultsWithFilters.
  ///
  /// In en, this message translates to:
  /// **'Results: {visible} / {total} · Languages: {languages}'**
  String resultsWithFilters(int visible, int total, Object languages);

  /// No description provided for @resultsWithoutFilters.
  ///
  /// In en, this message translates to:
  /// **'Results: {total} · Languages: {languages}'**
  String resultsWithoutFilters(int total, Object languages);

  /// No description provided for @startTypingToSearch.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search.'**
  String get startTypingToSearch;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @tryRemovingChangingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try removing or changing filters.'**
  String get tryRemovingChangingFilters;

  /// No description provided for @tryDifferentNameOrSpelling.
  ///
  /// In en, this message translates to:
  /// **'Try a different name or spelling.'**
  String get tryDifferentNameOrSpelling;

  /// No description provided for @allCardsCollectionNotFound.
  ///
  /// In en, this message translates to:
  /// **'All cards collection not found.'**
  String get allCardsCollectionNotFound;

  /// No description provided for @searchSetHint.
  ///
  /// In en, this message translates to:
  /// **'Search set'**
  String get searchSetHint;

  /// No description provided for @setCollectionCount.
  ///
  /// In en, this message translates to:
  /// **'Set • {count} cards'**
  String setCollectionCount(int count);

  /// No description provided for @customCollectionCount.
  ///
  /// In en, this message translates to:
  /// **'Custom • {count} cards'**
  String customCollectionCount(int count);

  /// No description provided for @createCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Create collection'**
  String get createCollectionTitle;

  /// No description provided for @setCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Set collection'**
  String get setCollectionTitle;

  /// No description provided for @setCollectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tracks missing cards by set.'**
  String get setCollectionSubtitle;

  /// No description provided for @customCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom collection'**
  String get customCollectionTitle;

  /// No description provided for @customCollectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add cards manually.'**
  String get customCollectionSubtitle;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @loyaltyLabel.
  ///
  /// In en, this message translates to:
  /// **'Loyalty {value}'**
  String loyaltyLabel(Object value);

  /// No description provided for @detailSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get detailSet;

  /// No description provided for @detailCollector.
  ///
  /// In en, this message translates to:
  /// **'Collector'**
  String get detailCollector;

  /// No description provided for @detailRarity.
  ///
  /// In en, this message translates to:
  /// **'Rarity'**
  String get detailRarity;

  /// No description provided for @detailSetName.
  ///
  /// In en, this message translates to:
  /// **'Set name'**
  String get detailSetName;

  /// No description provided for @detailLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get detailLanguage;

  /// No description provided for @detailRelease.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get detailRelease;

  /// No description provided for @detailArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get detailArtist;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
