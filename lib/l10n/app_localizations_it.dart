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
      'Scegli quale database scaricare da Scryfall.';

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
      'Sblocca Pro per rimuovere il limite di 5 collezioni.';

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
  String get switchToBaseTest => 'Passa a Base (test)';

  @override
  String get switchToProTest => 'Passa a Pro (test)';

  @override
  String get restorePurchases => 'Ripristina acquisti';

  @override
  String get testMode => 'Modalita test';

  @override
  String get testModeSubtitle =>
      'Quando abilitata, Upgrade attiva Pro localmente.';

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
  String get addCollection => 'Aggiungi una collezione';

  @override
  String get addCollectionSubtitle => 'Crea per set o personalizzata.';

  @override
  String get chooseCollection => 'Scegli collezione';

  @override
  String get chooseCardDatabaseTitle => 'Scegli database carte';

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
  String get buildYourCollectionsTitle => 'Crea le tue collezioni';

  @override
  String get buildYourCollectionsSubtitle =>
      'Tocca per creare la tua prima collezione.';

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
  String get create => 'Crea';

  @override
  String get collectionNameHint => 'Nome collezione';

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
  String get typeCardNameHint => 'Digita il nome di una carta';

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
  String get customCollectionTitle => 'Collezione personalizzata';

  @override
  String get customCollectionSubtitle => 'Aggiungi carte manualmente.';

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
  String get localProfileLabel => 'Profilo locale';

  @override
  String get signedInWithGoogle => 'Accesso con Google';

  @override
  String get profile => 'Profilo';

  @override
  String get proCardSubtitle =>
      'Sblocca limiti piu alti e funzionalita premium in arrivo.';

  @override
  String get needMoreThanFreeTitle => 'Ti serve piu del piano Free?';

  @override
  String get needMoreThanFreeBody =>
      'Confronta i piani, i limiti, e scegli l\'opzione migliore per il tuo flusso di collezione.';

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
  String get allArtworks => 'Tutte le artwork';

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
  String get liveOcrActive => 'OCR live attivo';

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
  String get freePlanLabel => 'Gratis';

  @override
  String get plusPlanLabel => 'Plus';

  @override
  String get dailyCardScansFeature => 'Scansioni carte giornaliere';

  @override
  String get collectionsFeature => 'Collezioni';

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
  String get oneMonthLabel => '1 mese';

  @override
  String get twelveMonthsLabel => '12 mesi';

  @override
  String get alreadySubscribedRestore => 'Hai gia un abbonamento? Ripristina';

  @override
  String get previewBillingNotice =>
      'Schermata preview: il flusso di pagamento reale verra integrato nel prossimo step.';

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
      'Accedi con Google per sincronizzare il tuo account.';

  @override
  String get authSignInWithGoogle => 'Accedi con Google';

  @override
  String get authContinueAsGuest => 'Continua come ospite';
}
