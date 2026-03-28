// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'BinderVault';

  @override
  String get allCards => 'Tutte le carte';

  @override
  String get notSelected => 'Non selezionato';

  @override
  String get bulkAllPrintingsTitle => 'Tutte le stampe';

  @override
  String get bulkAllPrintingsDescription =>
      'Tutte le stampe (ideale per copertura completa da scansione).';

  @override
  String get bulkOracleCardsTitle => 'Carte Oracle';

  @override
  String get bulkOracleCardsDescription =>
      'Livello Oracle (non tutte le stampe/varianti).';

  @override
  String get bulkUniqueArtworkTitle => 'Artwork unica';

  @override
  String get bulkUniqueArtworkDescription =>
      'Una per artwork (non copertura completa delle stampe).';

  @override
  String get gamePokemonDescription => 'Collezioni Pokemon TCG.';

  @override
  String get gameMagicDescription => 'Collezioni Magic: The Gathering.';

  @override
  String get gameYugiohDescription => 'Collezioni Yu-Gi-Oh!.';

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count carte',
      one: '1 carta',
      zero: '0 carte',
    );
    return '$_temp0';
  }

  @override
  String get settings => 'Impostazioni';

  @override
  String get searchLanguages => 'Lingue ricerca';

  @override
  String get searchLanguagesSubtitle =>
      'Scegli quali lingue delle carte mostrare nella ricerca.';

  @override
  String get cardName => 'Nome carta';

  @override
  String get searchHint => 'Cerca';

  @override
  String get typeArtistNameHint => 'Digita il nome di un artista';

  @override
  String get flavorText => 'Testo narrativo';

  @override
  String get typeFlavorTextHint => 'Digita il testo narrativo';

  @override
  String get loadMore => 'Carica altri risultati';

  @override
  String get defaultLabel => 'Predefinito';

  @override
  String get remove => 'Rimuovi';

  @override
  String get addLanguage => 'Aggiungi lingua';

  @override
  String get allLanguagesAdded => 'Tutte le lingue sono gia state aggiunte.';

  @override
  String get languageAddedDownloadAgain =>
      'Lingua aggiunta. Scarica di nuovo per importare le carte.';

  @override
  String get cardDatabase => 'Database carte';

  @override
  String get cardDatabaseSubtitle =>
      'Configura i database locali: Magic da Scryfall, Pokemon dal bundle pubblicato.';

  @override
  String get selectedType => 'Tipo selezionato';

  @override
  String get change => 'Cambia';

  @override
  String get changeDatabaseTitle => 'Cambiare database?';

  @override
  String get changeDatabaseBody =>
      'Il database attuale verra rimosso e dovrai scaricare di nuovo le carte.';

  @override
  String get confirm => 'Conferma';

  @override
  String get updatingDatabaseTitle => 'Aggiornamento database';

  @override
  String get preparingDatabaseBody => 'Preparazione del nuovo database...';

  @override
  String get databaseChangedGoHome =>
      'Database cambiato. Torna alla Home per scaricare.';

  @override
  String get games => 'Giochi';

  @override
  String get gamesSubtitle => 'Gestisci quali TCG sono abilitati.';

  @override
  String get makePrimary => 'Imposta principale';

  @override
  String get addGame => 'Aggiungi gioco';

  @override
  String get gameLimitReachedTitle => 'Limite giochi raggiunto';

  @override
  String get gameLimitReachedBody =>
      'La versione gratuita consente un solo gioco. Passa a Pro per aggiungerne altri.';

  @override
  String get allGamesAdded => 'Tutti i giochi sono gia stati aggiunti.';

  @override
  String get primaryLabel => 'Principale';

  @override
  String get addedLabel => 'Aggiunto';

  @override
  String primaryGameSet(Object game) {
    return 'Gioco principale impostato su $game.';
  }

  @override
  String get pro => 'Pro';

  @override
  String get proSubtitle => 'Sblocca collezioni illimitate.';

  @override
  String get proStatus => 'Stato Pro';

  @override
  String get proActive => 'Pro attivo';

  @override
  String get basePlan => 'Piano Base';

  @override
  String get storeAvailable => 'Store disponibile';

  @override
  String get storeNotAvailableYet => 'Store non ancora disponibile';

  @override
  String get unlimitedCollectionsUnlocked => 'Collezioni illimitate sbloccate.';

  @override
  String get unlockProRemoveLimit =>
      'Sblocca Pro per rimuovere il limite di 7 collezioni.';

  @override
  String priceLabel(Object price) {
    return 'Prezzo: $price';
  }

  @override
  String get whatYouGet => 'Cosa ottieni';

  @override
  String get unlimitedCollectionsFeature => 'Collezioni illimitate';

  @override
  String get supportFuturePremiumFeatures =>
      'Supporta le future funzioni premium';

  @override
  String get restorePurchases => 'Ripristina acquisti';

  @override
  String get manage => 'Gestisci';

  @override
  String get reset => 'Ripristina';

  @override
  String get resetSubtitle =>
      'Rimuovi tutte le collezioni e il database carte.';

  @override
  String get factoryReset => 'Ripristino di fabbrica';

  @override
  String get factoryResetTitle => 'Ripristino di fabbrica?';

  @override
  String get factoryResetBody =>
      'Rimuovera tutte le collezioni, il database carte e i download. L\'app tornera allo stato iniziale.';

  @override
  String get cleaningUpTitle => 'Pulizia in corso';

  @override
  String get removingLocalDataBody => 'Rimozione dati locali...';

  @override
  String get resetComplete => 'Ripristino completato. Riavvia l\'app.';

  @override
  String get notNow => 'Non ora';

  @override
  String get upgrade => 'Passa a Pro';

  @override
  String get cancel => 'Annulla';

  @override
  String get chooseDatabase => 'Scegli database';

  @override
  String get downloadDatabase => 'Scarica database';

  @override
  String get downloadUpdate => 'Scarica aggiornamento';

  @override
  String get downloading => 'Download in corso...';

  @override
  String downloadingWithPercent(int percent) {
    return 'Download in corso... $percent%';
  }

  @override
  String importingWithPercent(int percent) {
    return 'Importazione in corso... $percent%';
  }

  @override
  String get checkingUpdates => 'Controllo aggiornamenti...';

  @override
  String downloadingUpdateWithTotal(
    int percent,
    Object received,
    Object total,
  ) {
    return 'Download aggiornamento... $percent% ($received / $total)';
  }

  @override
  String downloadingUpdateNoTotal(Object received) {
    return 'Download aggiornamento... $received';
  }

  @override
  String importingCardsWithCount(int percent, int count) {
    return 'Importazione carte... $percent% ($count carte)';
  }

  @override
  String get downloadFailedTapUpdate =>
      'Download fallito. Tocca aggiorna di nuovo.';

  @override
  String get selectDatabaseToDownload => 'Seleziona un database da scaricare.';

  @override
  String databaseMissingDownloadRequired(Object name) {
    return 'Database $name mancante. Download richiesto.';
  }

  @override
  String updateReadyWithDate(Object date) {
    return 'Aggiornamento pronto: $date';
  }

  @override
  String get dbUpdateAvailableTapHere => 'Update DB disponibile, premi qui';

  @override
  String get unknownDate => 'sconosciuta';

  @override
  String get upToDate => 'Aggiornato.';

  @override
  String get importNow => 'Importa ora';

  @override
  String gameLabel(Object game) {
    return 'Gioco: $game';
  }

  @override
  String get rebuildingSearchIndex => 'Ricostruzione indice di ricerca';

  @override
  String get requiredAfterLargeUpdates =>
      'Richiesto dopo aggiornamenti importanti.';

  @override
  String get addTitle => 'Aggiungi';

  @override
  String get addCards => 'Aggiungi carta/e';

  @override
  String get addCardsToCatalogSubtitle => 'Aggiungi al catalogo principale.';

  @override
  String get addCardsToCollection => 'Aggiungi carta/e a una collezione';

  @override
  String get addCardsToCollectionSubtitle =>
      'Scegli una collezione personalizzata.';

  @override
  String get addCollection => 'Aggiungi collezione/set';

  @override
  String get addCollectionSubtitle => 'Crea per set o personalizzata.';

  @override
  String get addWishlist => 'Aggiungi wishlist';

  @override
  String get addWishlistSubtitle => 'Crea una wishlist per carte mancanti.';

  @override
  String get chooseCollection => 'Scegli collezione';

  @override
  String get chooseCardDatabaseTitle => 'Scegli profilo database';

  @override
  String get chooseYourGameTitle => 'Scegli il tuo gioco';

  @override
  String get collectionLimitReachedTitle => 'Limite collezioni raggiunto';

  @override
  String collectionLimitReachedBody(int limit) {
    return 'La versione gratuita consente fino a $limit collezioni. Passa a Pro per sbloccare collezioni illimitate.';
  }

  @override
  String get proActiveUnlimitedCollections =>
      'Pro attivo. Collezioni illimitate.';

  @override
  String basePlanCollectionLimit(int limit) {
    return 'Piano Base: fino a $limit collezioni.';
  }

  @override
  String get proEnabled => 'Pro abilitato';

  @override
  String get upgradeToPro => 'Passa a Pro';

  @override
  String get myCollections => 'Le mie collezioni';

  @override
  String get specialCollections => 'Speciali';

  @override
  String get buildYourCollectionsTitle => 'Crea le tue collezioni';

  @override
  String get buildYourCollectionsSubtitle =>
      'Tocca per creare la tua prima collezione.';

  @override
  String get createYourCustomCollectionTitle =>
      'Crea la tua collezione personalizzata';

  @override
  String get createYourCustomCollectionSubtitle =>
      'Aggiungi carte manualmente.';

  @override
  String get createYourSetCollectionTitle => 'Crea la tua collezione set';

  @override
  String get createYourSetCollectionSubtitle =>
      'Traccia le carte mancanti per set.';

  @override
  String get createYourDeckTitle => 'Crea il tuo mazzo';

  @override
  String get createYourWishlistTitle => 'Crea la tua wishlist';

  @override
  String get createYourWishlistSubtitle =>
      'Aggiungi le carte mancanti che desideri.';

  @override
  String get addCardsNowTitle => 'Aggiungere carte ora?';

  @override
  String get addCardsNowBody =>
      'Usa ricerca e filtri per aggiungere piu carte.';

  @override
  String get yes => 'Si';

  @override
  String get noSetsAvailableYet => 'Nessun set disponibile al momento.';

  @override
  String get newSetCollectionTitle => 'Nuova collezione set';

  @override
  String get collectionAlreadyExists => 'La collezione esiste gia.';

  @override
  String failedToAddCollection(Object error) {
    return 'Impossibile aggiungere collezione: $error';
  }

  @override
  String get newCollectionTitle => 'Nuova collezione';

  @override
  String get newDeckTitle => 'Nuovo mazzo';

  @override
  String get create => 'Crea';

  @override
  String get collectionNameHint => 'Nome collezione';

  @override
  String get deckNameHint => 'Nome mazzo';

  @override
  String get deckFormatOptionalLabel => 'Formato (opzionale)';

  @override
  String get noFormatOption => 'Nessun formato';

  @override
  String get createCustomCollectionFirst =>
      'Crea prima una collezione personalizzata.';

  @override
  String get rename => 'Rinomina';

  @override
  String get delete => 'Elimina';

  @override
  String get renameCollectionTitle => 'Rinomina collezione';

  @override
  String get save => 'Salva';

  @override
  String get deleteCollectionTitle => 'Eliminare collezione?';

  @override
  String deleteCollectionBody(Object name) {
    return '\"$name\" verra rimossa da questo dispositivo.';
  }

  @override
  String get collectionDeleted => 'Collezione eliminata.';

  @override
  String get downloadLinkUnavailable => 'Link download non disponibile.';

  @override
  String get scryfallBulkUpdateAvailable =>
      'Aggiornamento bulk Scryfall disponibile.';

  @override
  String get update => 'Aggiorna';

  @override
  String get advancedFiltersTitle => 'Filtri avanzati';

  @override
  String get rarity => 'Rarita';

  @override
  String get setLabel => 'Espansione';

  @override
  String get colorLabel => 'Colore';

  @override
  String get colorWhite => 'Bianco';

  @override
  String get colorBlue => 'Blu';

  @override
  String get colorBlack => 'Nero';

  @override
  String get colorRed => 'Rosso';

  @override
  String get colorGreen => 'Verde';

  @override
  String get colorColorless => 'Incolore';

  @override
  String get languageEnglish => 'Inglese';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageFrench => 'Francese';

  @override
  String get languageGerman => 'Tedesco';

  @override
  String get languageSpanish => 'Spagnolo';

  @override
  String get languagePortuguese => 'Portoghese';

  @override
  String get languageJapanese => 'Giapponese';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languageRussian => 'Russo';

  @override
  String get languageChineseSimplified => 'Cinese (Semplificato)';

  @override
  String get languageChineseTraditional => 'Cinese (Tradizionale)';

  @override
  String get languageArabic => 'Arabo';

  @override
  String get languageHebrew => 'Ebraico';

  @override
  String get languageLatin => 'Latino';

  @override
  String get languageGreek => 'Greco';

  @override
  String get languageSanskrit => 'Sanscrito';

  @override
  String get languagePhyrexian => 'Phyrexiano';

  @override
  String get languageQuenya => 'Quenya';

  @override
  String get typeLabel => 'Tipo';

  @override
  String get manaValue => 'Valore mana';

  @override
  String get minLabel => 'Minimo';

  @override
  String get maxLabel => 'Massimo';

  @override
  String get noFiltersAvailableForList =>
      'Nessun filtro disponibile per questa lista.';

  @override
  String get noFiltersAvailable => 'Nessun filtro disponibile.';

  @override
  String get clear => 'Pulisci';

  @override
  String get apply => 'Applica';

  @override
  String downloadComplete(Object path) {
    return 'Download completato: $path';
  }

  @override
  String downloadFailedWithError(Object error) {
    return 'Download fallito: $error';
  }

  @override
  String get downloadFailedGeneric => 'Download fallito.';

  @override
  String get networkErrorTryAgain => 'Errore di rete. Riprova.';

  @override
  String get gallery => 'Galleria';

  @override
  String get list => 'Lista';

  @override
  String get noCardsMatchFilters => 'Nessuna carta corrisponde a questi filtri';

  @override
  String get noOwnedCardsYet => 'Nessuna carta posseduta';

  @override
  String get noCardsYet => 'Nessuna carta';

  @override
  String get tryEnablingOwnedOrMissing =>
      'Prova ad abilitare carte possedute o mancanti.';

  @override
  String get addCardsHereOrAny =>
      'Aggiungi carte qui o in qualsiasi collezione.';

  @override
  String get addFirstCardToStartCollection =>
      'Aggiungi la prima carta per iniziare questa collezione.';

  @override
  String get addCard => 'Aggiungi carta';

  @override
  String get searchCardsHint => 'Cerca carte';

  @override
  String ownedCount(int count) {
    return 'Possedute ($count)';
  }

  @override
  String missingCount(int count) {
    return 'Mancanti ($count)';
  }

  @override
  String get useListToSetOwnedQuantities =>
      'Usa la lista per impostare le quantita possedute.';

  @override
  String addedCards(int count) {
    return 'Aggiunte $count carte.';
  }

  @override
  String get quantityLabel => 'Quantita';

  @override
  String quantityMultiplier(int count) {
    return 'x$count';
  }

  @override
  String get foilLabel => 'Foil';

  @override
  String get altArtLabel => 'Art alternativa';

  @override
  String get markMissing => 'Segna come mancante';

  @override
  String get importComplete => 'Importazione completata.';

  @override
  String importFailed(Object error) {
    return 'Importazione fallita: $error';
  }

  @override
  String get selectFiltersFirst => 'Seleziona prima i filtri.';

  @override
  String get selectSetRarityTypeToNarrow =>
      'Seleziona Set, Rarita o Tipo per restringere i risultati.';

  @override
  String get addAllResultsTitle => 'Aggiungere tutti i risultati?';

  @override
  String addAllResultsBody(int count) {
    return 'Questo aggiungera $count carte alla collezione.';
  }

  @override
  String get addAll => 'Aggiungi tutto';

  @override
  String get addFilteredCards => 'Aggiungi carte filtrate';

  @override
  String get addAllResults => 'Aggiungi tutti i risultati';

  @override
  String get filteredResultsTitle => 'Risultati filtrati';

  @override
  String get filteredCardsCountLabel =>
      'Carte che corrispondono ai tuoi filtri';

  @override
  String get refineSearchToSeeMore =>
      'Affina la ricerca per vedere piu di 100 carte.';

  @override
  String get viewResults => 'Vedi risultati';

  @override
  String get searchCardTitle => 'Cerca carta';

  @override
  String get filters => 'Filtri';

  @override
  String get addOne => 'Aggiungi una';

  @override
  String get missingLabel => 'Mancante';

  @override
  String get legalLabel => 'Legale';

  @override
  String get notLegalLabel => 'Non legale';

  @override
  String get typeCardNameHint => 'Digita il nome di una carta';

  @override
  String get deckSectionCreatures => 'Creature';

  @override
  String get deckSectionInstants => 'Istantanei';

  @override
  String get deckSectionSorceries => 'Stregonerie';

  @override
  String get deckSectionArtifacts => 'Artefatti';

  @override
  String get deckSectionEnchantments => 'Incantesimi';

  @override
  String get deckSectionPlaneswalkers => 'Planeswalker';

  @override
  String get deckSectionBattles => 'Battaglie';

  @override
  String get deckSectionLands => 'Terre';

  @override
  String get deckSectionTribals => 'Tribali';

  @override
  String get deckSectionOther => 'Altro';

  @override
  String get basicLandsLabel => 'Terre base';

  @override
  String resultsWithFilters(int visible, int total, Object languages) {
    return 'Risultati: $visible / $total · Lingue: $languages';
  }

  @override
  String resultsWithoutFilters(int total, Object languages) {
    return 'Risultati: $total · Lingue: $languages';
  }

  @override
  String get startTypingToSearch => 'Inizia a digitare per cercare.';

  @override
  String get noResultsFound => 'Nessun risultato trovato';

  @override
  String get tryRemovingChangingFilters =>
      'Prova a rimuovere o cambiare i filtri.';

  @override
  String get tryDifferentNameOrSpelling =>
      'Prova un nome o una grafia diversa.';

  @override
  String get allCardsCollectionNotFound =>
      'Collezione Tutte le carte non trovata.';

  @override
  String get searchSetHint => 'Cerca set';

  @override
  String setCollectionCount(int count) {
    return 'Set • $count carte';
  }

  @override
  String customCollectionCount(int count) {
    return 'Personalizzata • $count carte';
  }

  @override
  String get createCollectionTitle => 'Crea collezione';

  @override
  String get setCollectionTitle => 'Collezione set';

  @override
  String get setCollectionSubtitle => 'Traccia le carte mancanti del set.';

  @override
  String get wishlistCollectionTitle => 'Wishlist';

  @override
  String get wishlistCollectionSubtitle =>
      'Aggiungi le carte mancanti che desideri.';

  @override
  String get wishlistDefaultName => 'Wishlist';

  @override
  String get wishlistLimitReachedTitle => 'Limite wishlist raggiunto';

  @override
  String wishlistLimitReachedBody(int limit) {
    return 'Il piano Free supporta fino a $limit wishlist.';
  }

  @override
  String get customCollectionTitle => 'Collezione personalizzata';

  @override
  String get customCollectionSubtitle => 'Aggiungi carte manualmente.';

  @override
  String get deckCollectionTitle => 'Mazzo';

  @override
  String get deckCollectionSubtitle =>
      'Contenitore per giocare (formato opzionale).';

  @override
  String get details => 'Dettagli';

  @override
  String loyaltyLabel(Object value) {
    return 'Lealta $value';
  }

  @override
  String get detailSet => 'Espansione';

  @override
  String get detailCollector => 'Collezionista';

  @override
  String get detailRarity => 'Rarita';

  @override
  String get detailSetName => 'Nome set';

  @override
  String get detailLanguage => 'Lingua';

  @override
  String get detailRelease => 'Uscita';

  @override
  String get detailArtist => 'Artista';

  @override
  String get detailFormat => 'Formato';

  @override
  String get sortBy => 'Ordina per';

  @override
  String get selectCards => 'Seleziona carte';

  @override
  String selectedCardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionate',
      one: '1 selezionata',
      zero: '0 selezionate',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Seleziona tutto';

  @override
  String get deselectAll => 'Deseleziona tutto';

  @override
  String get deleteCardsTitle => 'Eliminare le carte selezionate?';

  @override
  String deleteCardsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count carte',
      one: '1 carta',
      zero: '0 carte',
    );
    return 'Questo eliminera $_temp0 da questa collezione.';
  }

  @override
  String filteredResultsSummary(int visible, int total) {
    return 'Risultati: $visible/$total';
  }

  @override
  String get viewMoreResults => 'Vedi piu risultati';

  @override
  String get priceSourceTitle => 'Fonte prezzi';

  @override
  String get dailySnapshot => 'Snapshot giornaliera';

  @override
  String get unableToSignOutTryAgain => 'Impossibile uscire. Riprova.';

  @override
  String get signOut => 'Esci';

  @override
  String get guestLabel => 'Ospite';

  @override
  String get googleUserLabel => 'Utente Google';

  @override
  String get accountSyncedLabel => 'Account sincronizzato';

  @override
  String get localProfileLabel => 'Profilo locale';

  @override
  String get signedInWithGoogle => 'Accesso con Google';

  @override
  String get signedInWithEmail => 'Accesso con email';

  @override
  String get profile => 'Profilo';

  @override
  String get proCardSubtitle =>
      'BinderVault e completamente utilizzabile gratis. Plus ti offre limiti piu alti.';

  @override
  String get needMoreThanFreeTitle => 'Vuoi limiti piu alti?';

  @override
  String get needMoreThanFreeBody =>
      'Usa BinderVault gratis, oppure confronta i piani Plus se ti serve piu spazio per il tuo flusso di collezione.';

  @override
  String get discoverPlus => 'Scopri Plus';

  @override
  String get pricesTitle => 'Prezzi';

  @override
  String get pricesSubtitle => 'Provider prezzi e valute visibili.';

  @override
  String get showPricesLabel => 'Mostra prezzi';

  @override
  String get scryfallDailySnapshot => 'Snapshot giornaliera Scryfall';

  @override
  String get availableCurrenciesHint =>
      'Disponibili nell\'app: EUR e USD (foil usa il valore foil quando disponibile).';

  @override
  String get appInfo => 'Info app';

  @override
  String get versionLabel => 'Versione';

  @override
  String get addByNameTitle => 'Per nome';

  @override
  String get addByNameSubtitle => 'Cerca e aggiungi manualmente';

  @override
  String get addByScanTitle => 'Da scansione';

  @override
  String get addByScanSubtitle => 'Riconoscimento carta OCR live';

  @override
  String get noCardTextRecognizedTryLightFocus =>
      'Nessun testo carta riconosciuto. Prova con piu luce e messa a fuoco.';

  @override
  String get dailyScanLimitReachedTitle =>
      'Limite scansioni giornaliere raggiunto';

  @override
  String get freePlan20ScansUpgradePlusBody =>
      'Il piano Free consente 20 scansioni al giorno. Passa a Plus per scansioni illimitate.';

  @override
  String get allArtworks => 'Interroga online';

  @override
  String get ownedLabel => 'Possedute';

  @override
  String get searchingOnlinePrintings => 'Ricerca stampe online...';

  @override
  String get addToCollection => 'Aggiungi alla collezione';

  @override
  String get closePreview => 'Chiudi anteprima';

  @override
  String get retry => 'Riprova';

  @override
  String get addLabel => 'Aggiungi';

  @override
  String get cardAddedTitle => 'Carta aggiunta';

  @override
  String get scanAnotherCardQuestion => 'Vuoi scansionare un\'altra carta?';

  @override
  String get no => 'No';

  @override
  String get addViaScanTitle => 'Aggiungi tramite scan';

  @override
  String get scanCardWithLiveOcrSubtitle => 'Scansiona una carta con OCR live';

  @override
  String get alignCardInFrame => 'Allinea la carta nel riquadro.';

  @override
  String get cameraUnavailableCheckPermissions =>
      'Camera non disponibile. Controlla i permessi.';

  @override
  String get flashNotAvailableOnDevice =>
      'Flash non disponibile su questo dispositivo.';

  @override
  String get searchingCardTextStatus => 'Cerco testo carta...';

  @override
  String get searchingCardNameStatus => 'Cerco nome carta...';

  @override
  String get nameRecognizedOpeningSearchStatus =>
      'Nome riconosciuto. Apro la ricerca...';

  @override
  String get ocrUnstableRetryingStatus => 'OCR instabile, riprovo...';

  @override
  String get nameLabel => 'Nome';

  @override
  String get waitingStatus => 'In attesa';

  @override
  String get pleaseWait => 'Attendi.';

  @override
  String get liveOcrActive => 'OCR live attivo';

  @override
  String get liveCardScanTitle => 'Scansione carta live';

  @override
  String get torchTooltip => 'Torcia';

  @override
  String get uiLanguageTitle => 'Lingua interfaccia';

  @override
  String get uiLanguageSubtitle =>
      'Scegli la lingua dell\'interfaccia dell\'app.';

  @override
  String get plusPageTitle => 'BinderVault Plus';

  @override
  String get plusActive => 'Plus attivo';

  @override
  String get upgradeToPlus => 'Passa a Plus';

  @override
  String get plusPaywallSubtitle =>
      'Sblocca le funzioni premium per tutti i TCG gia attivati.';

  @override
  String get plusTagAccountWide => 'Valido su account';

  @override
  String get plusTagAllUnlockedTcgs => 'Tutti i TCG sbloccati';

  @override
  String get plusPaywallCoverageNote =>
      'Plus si applica alle funzioni premium di ogni TCG che hai gia sbloccato o acquistato.';

  @override
  String get freePlanLabel => 'Gratis';

  @override
  String get plusPlanLabel => 'Plus';

  @override
  String get smartCollectionsFeature => 'Collezioni smart';

  @override
  String get dailyCardScansFeature => 'Scansioni carte giornaliere';

  @override
  String get collectionsFeature => 'Collezioni';

  @override
  String get setCollectionsFeature => 'Collezioni set';

  @override
  String get customCollectionsFeature => 'Collezioni personalizzate';

  @override
  String get decksFeature => 'Mazzi';

  @override
  String get wishlistFeature => 'Wishlist';

  @override
  String get freeCollectionsBreakdown =>
      '2 set, 2 personalizzate, 2 mazzi, 1 wishlist';

  @override
  String get cardSearchAddFeature => 'Ricerca e aggiunta carte';

  @override
  String get advancedFiltersFeature => 'Filtri avanzati';

  @override
  String scansPerDay(int count) {
    return '$count/giorno';
  }

  @override
  String get unlimitedLabel => 'Illimitato';

  @override
  String get monthlyPlanLabel => 'Mensile';

  @override
  String get yearlyPlanLabel => 'Annuale';

  @override
  String get plusMonthlyLabel => 'Mensile';

  @override
  String get plusYearlyLabel => 'Annuale';

  @override
  String plusMonthlyPlanPrice(Object price) {
    return '$price/mese, fatturato ogni mese';
  }

  @override
  String plusYearlyPlanPrice(Object price) {
    return '$price/anno, fatturato ogni anno';
  }

  @override
  String get plusDisclosureAutoRenew =>
      'Gli abbonamenti si rinnovano automaticamente salvo disdetta.';

  @override
  String get plusDisclosureCancellation =>
      'Puoi annullare in qualsiasi momento nelle sottoscrizioni di Google Play.';

  @override
  String get plusDisclosureFreeUsage =>
      'BinderVault puo essere usata anche senza abbonamento. Plus sblocca solo le funzioni premium.';

  @override
  String get plusDisclosureRegionalPricing =>
      'I prezzi possono variare in base alla regione e includere le imposte applicabili.';

  @override
  String get continueWithFree => 'Continua gratis';

  @override
  String get alreadySubscribedRestore => 'Hai gia un abbonamento? Ripristina';

  @override
  String get previewBillingNotice =>
      'I termini dell\'abbonamento sono mostrati qui prima del checkout Google Play.';

  @override
  String get billingLoadingPlans => 'Caricamento piani di abbonamento...';

  @override
  String get billingPlansUnavailable =>
      'I piani di abbonamento non sono disponibili al momento.';

  @override
  String get billingStoreUnavailable =>
      'Store non disponibile su questo dispositivo/account.';

  @override
  String get billingRestoringPurchases => 'Ripristino acquisti in corso...';

  @override
  String get billingWaitingPurchase => 'In attesa della conferma acquisto...';

  @override
  String get scryfallProviderLabel => 'Scryfall';

  @override
  String get currencyEurCode => 'EUR';

  @override
  String get currencyUsdCode => 'USD';

  @override
  String get limitedCoverageTapAllArtworks =>
      'Copertura locale ridotta\nTocca \"Interroga online\" per vedere più carte';

  @override
  String planSelectedPreview(Object plan) {
    return 'Piano $plan selezionato. La fatturazione verra abilitata nel prossimo step.';
  }

  @override
  String get authNetworkErrorDuringSignIn =>
      'Errore di rete durante l\'accesso. Controlla la connessione e riprova.';

  @override
  String get authInvalidGoogleCredential =>
      'Credenziali Google non valide. Riprova.';

  @override
  String authGoogleSignInFailedWithCode(Object code) {
    return 'Accesso Google fallito ($code).';
  }

  @override
  String get authGoogleSignInConfigError =>
      'Errore configurazione Google Sign-In (SHA/package/Firebase config).';

  @override
  String get authNetworkErrorDuringGoogleSignIn =>
      'Errore di rete durante l\'accesso con Google.';

  @override
  String get authGoogleSignInCancelled => 'Accesso Google annullato.';

  @override
  String get authGoogleSignInFailedTryAgain =>
      'Accesso Google fallito. Riprova.';

  @override
  String get authWelcomeTitle => 'Benvenuto in BinderVault';

  @override
  String get authWelcomeSubtitle =>
      'Accedi con Google o con email per sincronizzare il tuo account.';

  @override
  String get authSignInWithGoogle => 'Accedi con Google';

  @override
  String get authContinueWithEmail => 'Continua con email';

  @override
  String get authSignInWithEmail => 'Accedi con email';

  @override
  String get authCreateAccountWithEmail => 'Crea account con email';

  @override
  String get authSignInAction => 'Accedi';

  @override
  String get authCreateAccountAction => 'Crea account';

  @override
  String get authContinueAsGuest => 'Continua come ospite';

  @override
  String get authEmailAddressLabel => 'Indirizzo email';

  @override
  String get authEmailAddressHint => 'nome@esempio.com';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint =>
      'Min. 8 caratteri, 1 maiuscola, 1 numero, 1 simbolo';

  @override
  String get authConfirmPasswordLabel => 'Conferma password';

  @override
  String get authConfirmPasswordHint => 'Ripeti la stessa password';

  @override
  String get authInvalidEmailAddress => 'Inserisci un indirizzo email valido.';

  @override
  String get authPasswordRequired => 'Inserisci la password.';

  @override
  String get authPasswordTooShort =>
      'La password deve avere almeno 8 caratteri.';

  @override
  String get authPasswordNeedsUppercase =>
      'Aggiungi almeno 1 lettera maiuscola.';

  @override
  String get authPasswordNeedsNumber => 'Aggiungi almeno 1 numero.';

  @override
  String get authPasswordNeedsSymbol => 'Aggiungi almeno 1 simbolo.';

  @override
  String get authUnsupportedPasswordCharactersInline =>
      'Usa solo caratteri standard da tastiera.';

  @override
  String get authConfirmPasswordRequired => 'Conferma la password.';

  @override
  String get authPasswordMismatch => 'Le password non corrispondono.';

  @override
  String get authInvalidPasswordRequirements =>
      'Usa almeno 8 caratteri, 1 lettera maiuscola, 1 numero e 1 simbolo.';

  @override
  String get authShowPassword => 'Mostra password';

  @override
  String get authHidePassword => 'Nascondi password';

  @override
  String get authForgotPassword => 'Password dimenticata?';

  @override
  String get authPasswordResetNeedsValidEmail =>
      'Inserisci prima un indirizzo email valido.';

  @override
  String get authPasswordResetConfirmTitle => 'Reimpostare la password?';

  @override
  String authPasswordResetConfirmBody(Object email) {
    return 'Inviare un\'email per reimpostare la password a $email?';
  }

  @override
  String get authPasswordResetConfirmAction => 'Invia email';

  @override
  String get authPasswordResetStatusTitle => 'Reset password';

  @override
  String get authPasswordResetSending => 'Invio email di reset...';

  @override
  String get authPasswordResetSent =>
      'Se questa email e registrata, e stata inviata un\'email per reimpostare la password.';

  @override
  String get authPasswordResetFailed =>
      'Impossibile inviare l\'email di reset password. Riprova.';

  @override
  String get authPasswordResetTooManyRequests =>
      'Troppi tentativi di reset. Riprova piu tardi.';

  @override
  String get authPasswordHelpTitle => 'Regole password';

  @override
  String get authPasswordHelpBody =>
      'Per creare l\'account usa almeno 8 caratteri, 1 lettera maiuscola, 1 numero e 1 simbolo ASCII come !, @, # o ?.';

  @override
  String get authChangePasswordTitle => 'Cambia password';

  @override
  String get authChangePasswordSubtitle =>
      'Conferma la password attuale, poi scegli quella nuova.';

  @override
  String get authChangePasswordAction => 'Cambia password';

  @override
  String get authChangePasswordTileSubtitle =>
      'Aggiorna la password usata per l\'accesso con email.';

  @override
  String get authChangePasswordUnavailable =>
      'Il cambio password non e disponibile per questo account.';

  @override
  String get authChangePasswordFailedTryAgain =>
      'Impossibile cambiare la password ora. Riprova.';

  @override
  String authChangePasswordFailedWithCode(Object code) {
    return 'Cambio password fallito ($code).';
  }

  @override
  String get authCurrentPasswordLabel => 'Password attuale';

  @override
  String get authCurrentPasswordHint => 'Inserisci la password attuale';

  @override
  String get authCurrentPasswordRequired => 'Inserisci la password attuale.';

  @override
  String get authCurrentPasswordIncorrect =>
      'La password attuale non e corretta.';

  @override
  String get authChangeEmailTitle => 'Cambia email';

  @override
  String get authChangeEmailSubtitle =>
      'Conferma la password, poi scegli il nuovo indirizzo email per questo account.';

  @override
  String get authChangeEmailAction => 'Cambia email';

  @override
  String get authChangeEmailTileSubtitle =>
      'Invia un link di verifica a un nuovo indirizzo email.';

  @override
  String get authChangeEmailUnavailable =>
      'Il cambio email non e disponibile per questo account.';

  @override
  String get authChangeEmailVerificationSent =>
      'Verifica inviata al nuovo indirizzo email. Apri l\'email per completare il cambio.';

  @override
  String get authChangeEmailFailedTryAgain =>
      'Impossibile avviare il cambio email ora. Riprova.';

  @override
  String authChangeEmailFailedWithCode(Object code) {
    return 'Cambio email fallito ($code).';
  }

  @override
  String get authCurrentEmailLabel => 'Email attuale';

  @override
  String get authNewEmailLabel => 'Nuova email';

  @override
  String get authNewEmailHint => 'Inserisci il nuovo indirizzo email';

  @override
  String get authNewEmailMustDiffer =>
      'La nuova email deve essere diversa da quella attuale.';

  @override
  String get authEmailVerifiedStatus => 'Email verificata';

  @override
  String get authEmailNotVerifiedStatus => 'Email non ancora verificata';

  @override
  String get authResendVerificationEmailTitle =>
      'Invia di nuovo email di verifica';

  @override
  String get authResendVerificationEmailSubtitle =>
      'Invia un nuovo link di verifica a questo indirizzo email.';

  @override
  String get authVerificationEmailResent =>
      'Email di verifica inviata di nuovo. Controlla la tua casella.';

  @override
  String get authVerificationEmailResendFailed =>
      'Impossibile inviare l\'email di verifica ora. Riprova.';

  @override
  String get authAccountPageSignedOut =>
      'Questa sessione account non e piu disponibile. Torna alle impostazioni per accedere di nuovo.';

  @override
  String get authSignOutSubtitle =>
      'Esci da questo account e torna in modalita ospite.';

  @override
  String get authDeleteAccountTitle => 'Elimina account';

  @override
  String get authDeleteAccountAction => 'Elimina account';

  @override
  String get authDeleteAccountTileSubtitle =>
      'Rimuovi definitivamente questo account Firebase e torna in modalita ospite.';

  @override
  String get authDeleteAccountBodyPassword =>
      'Questo elimina definitivamente il tuo account Firebase. I dati locali su questo dispositivo resteranno. Nel passaggio successivo dovrai inserire la password attuale per confermare.';

  @override
  String get authDeleteAccountBodyProvider =>
      'Questo elimina definitivamente il tuo account Firebase. I dati locali su questo dispositivo resteranno. Dovrai confermare di nuovo con il provider di accesso.';

  @override
  String get authDeleteAccountPasswordTitle => 'Conferma eliminazione account';

  @override
  String get authDeleteAccountUnavailable =>
      'L\'eliminazione account non e disponibile per questo account.';

  @override
  String get authDeleteAccountSuccess =>
      'Account eliminato. Ora sei tornato in modalita ospite.';

  @override
  String get authDeleteAccountFailedTryAgain =>
      'Impossibile eliminare questo account ora. Riprova.';

  @override
  String authDeleteAccountFailedWithCode(Object code) {
    return 'Eliminazione account fallita ($code).';
  }

  @override
  String get authNewPasswordLabel => 'Nuova password';

  @override
  String get authNewPasswordHint => 'Scegli una nuova password';

  @override
  String get authNewPasswordRequired => 'Inserisci una nuova password.';

  @override
  String get authNewPasswordMustDiffer =>
      'La nuova password deve essere diversa da quella attuale.';

  @override
  String get authConfirmNewPasswordLabel => 'Conferma nuova password';

  @override
  String get authConfirmNewPasswordHint => 'Reinserisci la nuova password';

  @override
  String get authPasswordChangedSuccess => 'Password cambiata con successo.';

  @override
  String get authRequiresRecentLogin =>
      'Effettua di nuovo l\'accesso prima di cambiare la password.';

  @override
  String get authUnsupportedPasswordCharactersTitle =>
      'Caratteri password non supportati';

  @override
  String get authUnsupportedPasswordCharactersBody =>
      'Usa solo caratteri standard da tastiera per la password. Non sono supportati caratteri accentati, emoji e simboli come il segno euro.';

  @override
  String get authEmailPasswordPrompt =>
      'Usa email e password per accedere o creare il tuo account.';

  @override
  String get authEmailSignedInSuccess => 'Accesso con email completato.';

  @override
  String get authAccountCreatedSuccess => 'Account creato con successo.';

  @override
  String get authAccountCreatedVerificationSent =>
      'Account creato. Controlla la tua email per verificare l\'indirizzo.';

  @override
  String get authEmailLinkedToGuestSuccess =>
      'Email collegata al tuo account ospite.';

  @override
  String get authEmailLinkedToGuestVerificationSent =>
      'Email collegata al tuo account ospite. Controlla la tua casella per verificare l\'indirizzo.';

  @override
  String get authWeakPassword =>
      'Password troppo debole. Usa almeno 8 caratteri, 1 maiuscola, 1 numero e 1 simbolo.';

  @override
  String get authEmailAlreadyInUse => 'Questa email e gia in uso.';

  @override
  String get authInvalidEmailPasswordCredentials =>
      'Email o password non valide.';

  @override
  String get authEmailPasswordFailedTryAgain =>
      'Accesso email fallito. Riprova.';

  @override
  String authEmailPasswordFailedWithCode(Object code) {
    return 'Accesso email fallito ($code).';
  }

  @override
  String get authSessionExpiredSignedOut =>
      'Il tuo account non e piu disponibile su Firebase. Sei stato disconnesso.';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupSubtitle =>
      'Esporta o importa il backup completo locale delle collezioni.';

  @override
  String get backupExport => 'Esporta';

  @override
  String get backupImport => 'Importa';

  @override
  String get backupNoFilesFound => 'Nessun file di backup locale trovato.';

  @override
  String get backupChooseImportFile => 'Scegli file backup';

  @override
  String get backupImportConfirmTitle => 'Importare backup?';

  @override
  String get backupImportConfirmBody =>
      'Questo sostituira le collezioni correnti e le copie possedute.';

  @override
  String backupExported(Object fileName) {
    return 'Backup esportato: $fileName';
  }

  @override
  String backupImported(int collections, int entries) {
    return 'Backup importato. Collezioni: $collections, voci: $entries';
  }

  @override
  String get share => 'Condividi';

  @override
  String get backupShareNowTitle => 'Condividere backup ora?';

  @override
  String get backupShareNowBody =>
      'Puoi inviare il file esportato via email, app di messaggistica o cloud drive.';

  @override
  String backupShareFailed(Object error) {
    return 'Impossibile condividere il backup: $error';
  }

  @override
  String get primaryGamePickerTitle => 'Scegli il gioco principale';

  @override
  String get primaryGamePickerBody =>
      'Seleziona il tuo gioco principale. L\'altro gioco sara disponibile con Pro.';

  @override
  String get primaryFreeLabel => 'Incluso nel piano free';

  @override
  String get continueLabel => 'Continua';

  @override
  String get latestAddsLabel => 'Ultimi inserimenti';

  @override
  String get homeStartCollectionPrompt =>
      'Inizia ora la tua collezione: premi + e aggiungi le prime carte.';

  @override
  String get unlockOtherGameToSwitch =>
      'Sblocca l\'altro gioco con Pro per poter cambiare.';

  @override
  String get scannerTutorialTitle => 'Tutorial scanner';

  @override
  String get scannerTutorialIntro =>
      'Usa questi controlli per velocizzare il riconoscimento:';

  @override
  String get scannerTutorialSet =>
      '• Set: limita la ricerca al set selezionato.';

  @override
  String get scannerTutorialFoil =>
      '• Foil: marca la carta come foil quando la aggiungi.';

  @override
  String get scannerTutorialCheck =>
      '• Check: se il riquadro e verde e il nome coincide, premi per confermare e velocizzare la scansione.';

  @override
  String get scannerTutorialFlash =>
      '• Flash: utile in ambienti poco illuminati.';

  @override
  String get doNotShowAgain => 'Non mostrare in seguito';

  @override
  String get scannerSetAnyLabel => 'Set: tutti';

  @override
  String get scannerAnySetOption => 'Tutti i set';

  @override
  String get closeLabel => 'Chiudi';

  @override
  String get openSettingsLabel => 'Apri impostazioni';

  @override
  String gameInProTitle(Object game) {
    return '$game in versione Pro';
  }

  @override
  String gameOneTimeUnlockBody(Object game) {
    return '$game e disponibile come acquisto una tantum. Attivalo dalle Impostazioni.';
  }

  @override
  String get pokemonInProTitle => 'Pokemon disponibile nella versione Pro';

  @override
  String get pokemonInProBody =>
      'Sblocca Pokemon dalle impostazioni per usare collezioni, ricerca e download del database dedicato.';

  @override
  String get customLabel => 'Custom';

  @override
  String get smartLabel => 'Smart';

  @override
  String get homeSetHelp =>
      'Scegli un set specifico e segui la checklist in modo chiaro: vedi subito le carte presenti e quelle che ti mancano.';

  @override
  String get homeCustomHelp =>
      'Crea raccolte manuali aggiungendo solo carte possedute dalla tua inventory.';

  @override
  String get homeSmartHelp =>
      'Salva un filtro dinamico: la smart collection mostra automaticamente tutte le carte che rispettano i criteri, possedute e non.';

  @override
  String get homeWishHelp =>
      'Crea una wishlist con filtri avanzati per tenere sotto controllo le carte mancanti che vuoi trovare.';

  @override
  String get homeDeckHelp =>
      'Tieni traccia dei tuoi mazzi e aggiorna mainboard/sideboard: le carte del deck restano nel mazzo e non vengono aggiunte alle collezioni.';

  @override
  String get smartCollectionDefaultName => 'Collezione smart';

  @override
  String get newSmartCollectionTitle => 'Nuova collezione smart';

  @override
  String get smartCollectionNeedFilterToCreate =>
      'Imposta almeno un filtro per creare una smart collection.';

  @override
  String get smartCollectionNeedAtLeastOneFilter => 'Imposta almeno un filtro.';

  @override
  String get saveFilterLabel => 'Salva filtro';

  @override
  String get loadArenaMtgoFileLabel => 'Carica file Arena/MTGO';

  @override
  String get pokemonDeckHintLabel =>
      'Mazzo Pokemon: 60 carte esatte, max 4 copie per nome (tranne Energie Base), almeno 1 Pokemon Base.';

  @override
  String get importDeckListLabel => 'Importa lista mazzo';

  @override
  String get exportForArenaLabel => 'Esporta per Arena';

  @override
  String get exportForMtgoLabel => 'Esporta per MTGO';

  @override
  String deckImportedSummary(int imported, int skipped) {
    return 'Mazzo importato: $imported carte, $skipped non trovate';
  }

  @override
  String get deckImportingLabel => 'Importazione mazzo in corso...';

  @override
  String get deckImportResultTitle => 'Risultato import';

  @override
  String get deckImportCardsNotFoundTitle => 'Carte non trovate';

  @override
  String deckExportedSummary(Object fileName) {
    return 'Mazzo esportato: $fileName';
  }

  @override
  String deckImportFailed(Object error) {
    return 'Import mazzo non riuscito: $error';
  }

  @override
  String deckExportFailed(Object error) {
    return 'Export mazzo non riuscito: $error';
  }

  @override
  String get pokemonDbProfileFullTitle => 'Catalogo completo (tutti i set)';

  @override
  String get pokemonDbProfileExpandedTitle => 'Copertura media (10 set fissi)';

  @override
  String get pokemonDbProfileStandardTitle => 'Copertura base (6 set fissi)';

  @override
  String get pokemonDbProfileStarterTitle => 'Copertura minima (3 set fissi)';

  @override
  String get pokemonDbProfileFullDescription =>
      'Installa il catalogo Pokemon completo pubblicato per avere la copertura offline migliore, con download piu lungo e database piu grande.';

  @override
  String get pokemonDbProfileExpandedDescription =>
      'Importa 10 set predefiniti: base1, swsh1-5, sv1-4. Non include tutte le espansioni recenti.';

  @override
  String get pokemonDbProfileStandardDescription =>
      'Importa 6 set predefiniti: base1, swsh1, sv1-4. Compromesso tra velocita e copertura.';

  @override
  String get pokemonDbProfileStarterDescription =>
      'Importa 3 set predefiniti: base1, swsh1, sv1. Il piu veloce, ma con copertura limitata.';

  @override
  String get pokemonDbPickerTitle => 'Scegli copertura catalogo Pokemon';

  @override
  String get pokemonDbPickerSubtitle =>
      'Scegli quanta parte del catalogo Pokemon pubblicato tenere offline: piu copertura = piu tempo e spazio.';

  @override
  String get primaryGameFixedMessage => 'Il gioco primario e fisso.';

  @override
  String get primaryFreeForever => 'Primario gratuito (per sempre)';

  @override
  String get purchasedLabel => 'Acquistato';

  @override
  String get secondaryPurchaseRequired => 'Secondario: acquisto richiesto';

  @override
  String buyGameLabel(Object game, Object price) {
    return 'Acquista $game $price';
  }

  @override
  String get purchasesRestoredMessage => 'Ripristino acquisti completato.';

  @override
  String get restorePurchasesTimeoutMessage =>
      'Ripristino acquisti troppo lento. Riprova.';

  @override
  String get restorePurchasesErrorMessage =>
      'Errore durante il ripristino acquisti. Riprova.';

  @override
  String get playStoreProductUnavailable =>
      'Prodotto non disponibile su Google Play.';

  @override
  String buyGameTitle(Object game) {
    return 'Sblocca il supporto a $game';
  }

  @override
  String buyGameBody(Object game, Object price) {
    return 'Questo acquisto una tantum sblocca le funzionalita di $game in BinderVault per questo account.\nPrezzo: $price\n\nNessun abbonamento richiesto.\nGli acquisti sono gestiti da Google Play.';
  }

  @override
  String get continuePurchaseLabel => 'Continua acquisto';

  @override
  String get purchaseAlreadyOwnedSynced =>
      'Acquisto gia presente su Google Play. Entitlement sincronizzato.';

  @override
  String get storeConnectionTimeout =>
      'Connessione allo store troppo lenta. Riprova.';

  @override
  String get purchaseFailedRetry => 'Errore durante l\'acquisto. Riprova.';

  @override
  String get themeVaultDescription => 'Blu acciaio e atmosfera tecnica.';

  @override
  String get themeMagicDescription =>
      'Tema classico oro/marrone di BinderVault.';

  @override
  String get visualThemeTitle => 'Tema grafico';

  @override
  String get themeMagicSubtitle => 'Default: stile originale';

  @override
  String get themeVaultSubtitle => 'Look alternativo blu acciaio';

  @override
  String get issueCategoryCrash => 'Crash';

  @override
  String get issueCategoryUi => 'Interfaccia';

  @override
  String get issueCategoryPurchase => 'Acquisti';

  @override
  String get issueCategoryDatabase => 'Database';

  @override
  String get issueCategoryOther => 'Altro';

  @override
  String get reportIssueLabel => 'Segnala problema';

  @override
  String get issueCategoryLabel => 'Categoria';

  @override
  String get issueDescribeHint => 'Descrivi cosa e successo e come riprodurlo.';

  @override
  String get reportIssueConsentTitle => 'Inviare report diagnostico?';

  @override
  String get reportIssueConsentBody =>
      'Il tuo messaggio e una diagnostica tecnica di base verranno inviati a BinderVault tramite Firebase Crashlytics per analizzare il problema. Non inserire dati personali sensibili.';

  @override
  String get reportIssueConsentSend => 'Invia report';

  @override
  String get sendLabel => 'Invia';

  @override
  String get reportSentThanks => 'Segnalazione inviata. Grazie.';

  @override
  String get reportSendUnavailable => 'Invio non disponibile ora. Riprova.';

  @override
  String get diagnosticsCopied => 'Diagnostica copiata negli appunti.';

  @override
  String get resetMagicDatabaseLabel => 'Reset database Magic';

  @override
  String resetGameDatabaseTitle(Object game) {
    return 'Reset database $game';
  }

  @override
  String resetGameDatabaseBody(Object game) {
    return 'Verranno cancellate solo le carte nel database $game e riscaricate da zero. Collezioni, deck e quantita restano invariati.';
  }

  @override
  String get resetInProgressTitle => 'Reset in corso';

  @override
  String cleaningGameDatabase(Object game) {
    return 'Pulizia database $game...';
  }

  @override
  String gameDatabaseResetDone(Object game) {
    return 'Database $game resettato. Verra riscaricato in modo pulito.';
  }

  @override
  String get applyProfileLabel => 'Applica profilo';

  @override
  String get pokemonProfileUpdatedTapUpdate =>
      'Profilo Pokemon aggiornato. Tocca Update disponibile in Home per applicarlo.';

  @override
  String get gamesSelectionSubtitle =>
      'Il primo gioco scelto e gratis per sempre. L\'altro richiede acquisto.';

  @override
  String get primaryGameLabel => 'Gioco principale';

  @override
  String get configureBothDatabasesSubtitle =>
      'Magic e Pokemon hanno profili separati: scegli copertura, tempo download e spazio locale.';

  @override
  String get toolsAndDiagnosticsTitle => 'Tool e diagnostica';

  @override
  String get checkCoherenceLabel => 'Controlla coerenza';

  @override
  String get copyDiagnosticsLabel => 'Copia diagnostica';

  @override
  String get whatsNewButtonLabel => 'Novita';

  @override
  String get whatsNewDialogTitle => 'Novita versione 0.5.4';

  @override
  String get whatsNewFeaturesTitle => 'Novita principali';

  @override
  String get whatsNewBugFixesTitle => 'Correzioni';

  @override
  String get whatsNewLine1 =>
      'Risolti problemi nella protezione del cloud backup e nei controlli di accesso Plus.';

  @override
  String get whatsNewLine2 =>
      'Migliorato il flusso di avvio e la stabilita generale dell\'app.';

  @override
  String get whatsNewLine3 => 'Aggiunto l\'accesso con email e password.';

  @override
  String get whatsNewLine4 => 'Aggiunto il cloud sync per BinderVault Plus.';

  @override
  String get whatsNewLine5 => 'Nuovo splash screen.';

  @override
  String get whatsNewLine6 =>
      'Migliorato il flusso scanner e l\'usabilita generale.';

  @override
  String get whatsNewLine7 => 'Aggiornate le basi tecniche e le librerie.';

  @override
  String get whatsNewLine8 =>
      'Corretti problemi nella UI del backup e alcuni casi limite del ripristino cloud.';

  @override
  String get whatsNewLine9 =>
      'Incluse anche ulteriori correzioni minori e rifiniture generali.';

  @override
  String get createSmartCollectionTitle => 'Crea una smart collection';

  @override
  String get pokemonEnergyGrass => 'Erba';

  @override
  String get pokemonEnergyFire => 'Fuoco';

  @override
  String get pokemonEnergyWater => 'Acqua';

  @override
  String get pokemonEnergyLightning => 'Lampo';

  @override
  String get pokemonEnergyPsychicDarkness => 'Psico/Oscurita';

  @override
  String get pokemonEnergyFighting => 'Lotta';

  @override
  String get pokemonEnergyDragon => 'Drago';

  @override
  String get pokemonEnergyFairy => 'Folletto';

  @override
  String get pokemonEnergyColorless => 'Incolore';

  @override
  String get pokemonEnergyMetal => 'Metallo';

  @override
  String get pokemonEnergyNone => 'Nessuno';

  @override
  String get pokemonTypeTrainer => 'Allenatore';

  @override
  String get pokemonTypeEnergy => 'Energia';

  @override
  String get pokemonTypeItem => 'Oggetto';

  @override
  String get pokemonTypeSupporter => 'Aiuto';

  @override
  String get pokemonTypeStadium => 'Stadio';

  @override
  String get pokemonTypeTool => 'Strumento Pokemon';

  @override
  String get pokemonEnergyTypeLabel => 'Tipo energia';

  @override
  String get pokemonCardCategoryLabel => 'Categoria carta';

  @override
  String get pokemonAttackEnergyCostLabel => 'Costo energia (attacco)';

  @override
  String get addMultipleCardsByFilterTitle => 'Aggiungi piu carte da filtro';

  @override
  String get addMultipleCardsByFilterSubtitle =>
      'Seleziona filtri e aggiungi tutte le carte trovate';

  @override
  String get allSelectedCardsOwned => 'Tutte gia possedute.';

  @override
  String get skippedLabel => 'Saltate';

  @override
  String get totalLabel => 'Totale';

  @override
  String get pokemonEnergyPluralLabel => 'Energie';

  @override
  String get deckRule60Ok => 'Regola 60 carte: OK';

  @override
  String get deckBasicPokemonPresentOk => 'Pokemon Base presente: OK';

  @override
  String get deckBasicPokemonRequired => 'Manca almeno 1 Pokemon Base.';

  @override
  String get deckCopyLimitOk => 'Limite copie: OK';

  @override
  String deckCopyLimitExceeded(int count) {
    return '$count carte superano 4 copie (escluse Energie Base).';
  }

  @override
  String deckAddCardsToReach60(int count) {
    return 'Mancano $count carte per arrivare a 60.';
  }

  @override
  String deckRemoveCardsToReturn60(int count) {
    return 'Rimuovi $count carte per tornare a 60.';
  }
}
