part of 'package:tcg_tracker/main.dart';

enum _ScannedCardSearchOutcome { added, retryScan, cancelled }

class CollectionHomePage extends StatefulWidget {
  const CollectionHomePage({super.key});

  @override
  State<CollectionHomePage> createState() => _CollectionHomePageState();
}

class _CollectionHomePageState extends State<CollectionHomePage>
    with TickerProviderStateMixin {
  final List<CollectionInfo> _collections = [];
  String? _selectedBulkType;
  static const int _freeSetCollectionLimit = 2;
  static const int _freeCustomCollectionLimit = 2;
  static const int _freeSmartCollectionLimit = 1;
  static const int _freeDeckCollectionLimit = 2;
  static const int _freeWishlistLimit = 1;
  static const int _freeDailyScanLimit = 20;
  bool _isProUnlocked = false;
  late final PurchaseManager _purchaseManager;
  late final VoidCallback _purchaseListener;
  bool _checkingBulk = false;
  bool _bulkUpdateAvailable = false;
  String? _bulkDownloadUri;
  DateTime? _bulkUpdatedAt;
  bool _bulkDownloading = false;
  double _bulkDownloadProgress = 0;
  int _bulkDownloadReceived = 0;
  int _bulkDownloadTotal = 0;
  int? _bulkExpectedSizeBytes;
  String? _bulkDownloadError;
  bool _bulkImporting = false;
  double _bulkImportProgress = 0;
  double _pokemonSyncOverallProgress = 0;
  int _bulkImportedCount = 0;
  String? _mtgSyncStatus;
  String? _pokemonSyncStatus;
  DateTime? _pokemonSyncStartedAt;
  DateTime? _pokemonSyncLastStatusAt;
  Timer? _pokemonSyncUiTimer;
  int _pokemonSyncElapsedSeconds = 0;
  String? _bulkUpdatedAtRaw;
  MtgHostedBundleCheckResult? _mtgHostedBundleResult;
  MtgCanonicalBundleCheckResult? _mtgCanonicalBundleResult;
  bool _cardsMissing = false;
  String _priceCurrency = 'eur';
  bool _showPrices = true;
  bool _initialCollectionsLoading = true;
  bool _collectionsLoadInProgress = false;
  bool _releaseNotesDialogQueued = false;
  int _totalCardCount = 0;
  int _appFirstOpenFlag = 1;
  List<CardSearchResult> _recentAllCards = const [];
  Map<int, int> _deckSideboardCounts = {};
  late final AnimationController _snakeController;
  Map<String, String> _setNameLookup = {};
  static const int _deckImportBatchSize = 120;
  TcgGame _selectedHomeGame = TcgGame.mtg;
  _HomeCollectionsMenu _activeCollectionsMenu = _HomeCollectionsMenu.home;
  bool get _hasProAccess => _purchaseManager.isPro || _isProUnlocked;
  bool get _preferMtgCanonicalCatalog => true;

  void _onCollectionsRefreshRequested() {
    unawaited(_loadCollections());
  }

  @override
  void initState() {
    super.initState();
    _purchaseManager = PurchaseManager.instance;
    _purchaseListener = () {
      if (!mounted) {
        return;
      }
      final nextIsPro = _purchaseManager.isPro;
      final changed = nextIsPro != _isProUnlocked;
      setState(() {
        _isProUnlocked = nextIsPro;
      });
      if (changed) {
        unawaited(_loadCollections());
      }
    };
    _purchaseManager.addListener(_purchaseListener);
    _isProUnlocked = _purchaseManager.isPro;
    _snakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_initializeEnvironmentAndData());
      unawaited(_checkForAppUpdateOnStartup());
    });
    _collectionsRefreshNotifier.addListener(_onCollectionsRefreshRequested);
  }

  Future<void> _initializeEnvironmentAndData() async {
    Future<T?> runStep<T>(
      String label,
      Future<T> Function() action, {
      Duration timeout = const Duration(seconds: 20),
      bool nonBlocking = false,
    }) async {
      try {
        final result = await action().timeout(timeout);
        return result;
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrintStack(stackTrace: stackTrace);
        }
        if (nonBlocking) {
          return null;
        }
        rethrow;
      }
    }

    try {
      await runStep('purchase_init', () => _purchaseManager.init());
      final priceCurrency =
          await runStep<String>(
            'load_price_currency',
            () => AppSettings.loadPriceCurrency(),
          ) ??
          'eur';
      final showPrices =
          await runStep<bool>(
            'load_show_prices',
            () => AppSettings.loadShowPrices(),
          ) ??
          true;
      final firstOpenFlag =
          await runStep<int>(
            'load_first_open_flag',
            () => AppSettings.loadAppFirstOpenFlag(),
          ) ??
          0;
      final cardLanguageOnboardingDone =
          await runStep<bool>(
            'load_card_language_onboarding_done',
            () => AppSettings.loadCardLanguageOnboardingDone(),
          ) ??
          false;
      var shouldRunCardLanguageOnboarding = !cardLanguageOnboardingDone;
      if (mounted) {
        setState(() {
          _priceCurrency = priceCurrency;
          _showPrices = showPrices;
          _appFirstOpenFlag = firstOpenFlag;
        });
      }
      final isFirstOpen = firstOpenFlag == 1;
      await runStep(
        'release_notes_pre',
        () => _maybeShowLatestReleaseNotesBeforeDbDownloads(),
        nonBlocking: true,
      );
      await runStep(
        'ensure_primary_game',
        () => _ensurePrimaryGameSelectionOnFirstLaunch(
          cardLanguageOnboardingDone: cardLanguageOnboardingDone,
        ),
        nonBlocking: true,
      );
      final selectedGameAfterPrimaryChoice =
          await AppSettings.loadSelectedTcgGame();
      if (selectedGameAfterPrimaryChoice == AppTcgGame.pokemon) {
        final updatedCardLanguageOnboardingDone =
            await runStep<bool>(
              'reload_card_language_onboarding_done',
              () => AppSettings.loadCardLanguageOnboardingDone(),
            ) ??
            false;
        shouldRunCardLanguageOnboarding = !updatedCardLanguageOnboardingDone;
      }
      if (shouldRunCardLanguageOnboarding) {
        await runStep(
          'card_language_onboarding',
          () => _runFirstOpenLanguageSteps(),
        );
        await runStep(
          'save_card_language_onboarding_done',
          () => AppSettings.saveCardLanguageOnboardingDone(true),
        );
      }
      if (isFirstOpen) {
        await runStep(
          'save_first_open_flag',
          () => AppSettings.saveAppFirstOpenFlag(0),
        );
      }
      await runStep('env_init', () => TcgEnvironmentController.instance.init());
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedHomeGame = TcgEnvironmentController.instance.currentGame;
      });
      await runStep(
        'ensure_game_unlocked_pre',
        () => _ensureSelectedHomeGameUnlocked(),
        nonBlocking: true,
      );
      await runStep(
        'db_open',
        () => ScryfallDatabase.instance.open(),
        timeout: const Duration(seconds: 35),
      );
      await runStep(
        'coherence_check',
        () => _runCollectionCoherenceCheckIfNeeded(),
        nonBlocking: true,
      );
      await runStep(
        'load_collections',
        () => _loadCollections(),
        timeout: const Duration(seconds: 35),
      );
      await runStep(
        'primary_game_prompt',
        () => _maybePromptPrimaryGameSelectionForCurrentRelease(
          skipForFirstOpen: isFirstOpen || shouldRunCardLanguageOnboarding,
        ),
        nonBlocking: true,
      );
      await runStep(
        'ensure_game_unlocked_post',
        () => _ensureSelectedHomeGameUnlocked(),
        nonBlocking: true,
      );
      if (!mounted || !context.mounted) {
        return;
      }
      await runStep(
        'initialize_current_game',
        () => _initializeForCurrentGame(),
        nonBlocking: true,
      );
    } catch (_) {
      if (mounted && _initialCollectionsLoading) {
        setState(() {
          _initialCollectionsLoading = false;
        });
      }
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.downloadFailedGeneric,
        );
      }
    }
  }

  Future<void> _runCollectionCoherenceCheckIfNeeded() async {
    String currentVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      return;
    }
    final game = _activeSettingsGame;
    final lastCheckedVersion =
        await AppSettings.loadCollectionCoherenceCheckVersionForGame(game);
    if (lastCheckedVersion == currentVersion) {
      return;
    }
    await ScryfallDatabase.instance
        .repairAllCardsCoherenceFromCustomCollections();
    await AppSettings.saveCollectionCoherenceCheckVersionForGame(
      game,
      currentVersion,
    );
  }

  Future<void> _maybeShowLatestReleaseNotesBeforeDbDownloads() async {
    final lastSeen = await AppSettings.loadLastSeenReleaseNotesId();
    if (lastSeen == _latestReleaseNotesId || !mounted) {
      return;
    }
    if (_releaseNotesDialogQueued) {
      return;
    }
    _releaseNotesDialogQueued = true;
    try {
      await _showLatestReleaseNotesPanel(context);
    } finally {
      _releaseNotesDialogQueued = false;
    }
  }

  Future<void> _ensurePrimaryGameSelectionOnFirstLaunch({
    required bool cardLanguageOnboardingDone,
  }) async {
    final alreadySelected = await AppSettings.hasPrimaryGameSelection();
    if (alreadySelected || !mounted) {
      return;
    }
    final selected = await _showPrimaryGamePickerDialog();
    final resolved = selected ?? TcgGame.mtg;
    await _applyPrimaryGameSelection(resolved);
    if (resolved == TcgGame.pokemon && !cardLanguageOnboardingDone) {
      await _showCardLanguagesOnboardingStep(
        selectedGameOverride: AppTcgGame.pokemon,
        titleOverride: _isItalianUi()
            ? 'Configura il catalogo Pokemon'
            : 'Set up the Pokemon catalog',
        bodyOverride: _isItalianUi()
            ? 'Inglese e sempre incluso. Puoi attivare anche italiano per avere nomi carta e ricerca localizzati offline gia dalla prima installazione.'
            : 'English is always included. You can also enable Italian to get localized card names and offline search from the first install.',
        confirmLabelOverride: _isItalianUi()
            ? 'Inizia installazione'
            : 'Start install',
      );
      await AppSettings.saveCardLanguageOnboardingDone(true);
    }
  }

  Future<void> _applyPrimaryGameSelection(TcgGame selected) async {
    final selectedGame = selected == TcgGame.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    await AppSettings.savePrimaryTcgGame(selectedGame);
    await AppSettings.saveSelectedTcgGame(selectedGame);
    await _purchaseManager.syncPrimaryGameFromSettings();
    await TcgEnvironmentController.instance.setGame(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedHomeGame = selected;
    });
  }

  Future<void> _runFirstOpenLanguageSteps() async {
    if (!mounted) {
      return;
    }
    await _showCardLanguagesOnboardingStep();
  }

  Future<void> _showCardLanguagesOnboardingStep({
    AppTcgGame? selectedGameOverride,
    String? titleOverride,
    String? bodyOverride,
    String? confirmLabelOverride,
  }) async {
    if (!mounted) {
      return;
    }
    final selectedGame =
        selectedGameOverride ?? await AppSettings.loadSelectedTcgGame();
    final current = (await AppSettings.loadCardLanguagesForGame(
      selectedGame,
    )).toSet();
    current.add('en');
    if (!mounted) {
      return;
    }
    final mutable = <String>{...current};
    final choices = AppSettings.languageCodes
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toList();
    final picked = await showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final italian = Localizations.localeOf(
          context,
        ).languageCode.toLowerCase().startsWith('it');
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                titleOverride ?? (italian ? 'Lingue carte' : 'Card languages'),
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bodyOverride ??
                            (italian
                                ? 'Inglese sempre incluso. Seleziona eventuali lingue aggiuntive.'
                                : 'English is always included. Select any additional languages.'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: const Color(0x33A06A1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE9C46A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: Color(0xFFE9C46A),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedGame == AppTcgGame.pokemon
                                    ? (italian
                                          ? 'Se attivi anche italiano, il download iniziale sara piu lungo e il database locale occupera piu spazio. Potrai comunque cambiare questa scelta in seguito.'
                                          : 'If you also enable Italian, the initial download will take longer and the local database will use more storage. You can change this later.')
                                    : (italian
                                          ? 'Se attivi anche italiano, il download iniziale includera anche il bundle IT da Firebase.'
                                          : 'If you also enable Italian, the initial download also includes the IT bundle from Firebase.'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...choices.map(
                        (code) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: mutable.contains(code),
                          title: Text(_languageLabelForCode(l10n, code)),
                          onChanged: code == 'en'
                              ? null
                              : (value) {
                                  setModalState(() {
                                    if (value == true) {
                                      mutable.add(code);
                                    } else {
                                      mutable.remove(code);
                                    }
                                    mutable.add('en');
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(<String>{...mutable}),
                  child: Text(
                    confirmLabelOverride ?? (italian ? 'Avanti' : 'Next'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted || picked == null) {
      return;
    }
    await AppSettings.saveCardLanguagesForGame(selectedGame, picked);
  }

  Future<void> _maybePromptPrimaryGameSelectionForCurrentRelease({
    bool skipForFirstOpen = false,
  }) async {
    if (skipForFirstOpen) {
      return;
    }
    final alreadySelected = await AppSettings.hasPrimaryGameSelection();
    if (alreadySelected) {
      await AppSettings.savePrimaryGamePromptVersion(_latestReleaseNotesId);
      return;
    }
    final promptedVersion = await AppSettings.loadPrimaryGamePromptVersion();
    if (promptedVersion == _latestReleaseNotesId || !mounted) {
      return;
    }
    final selected = await _showPrimaryGamePickerDialog();
    await _applyPrimaryGameSelection(selected ?? TcgGame.mtg);
    await AppSettings.savePrimaryGamePromptVersion(_latestReleaseNotesId);
    await TcgEnvironmentController.instance.init();
    if (!mounted) {
      return;
    }
    final nextGame = TcgEnvironmentController.instance.currentGame;
    setState(() {
      _selectedHomeGame = nextGame;
      _initialCollectionsLoading = true;
      _collections.clear();
    });
    await _loadCollections();
  }

  bool get _isMtgActiveGame => _selectedHomeGame == TcgGame.mtg;
  AppTcgGame get _activeSettingsGame =>
      _isMtgActiveGame ? AppTcgGame.mtg : AppTcgGame.pokemon;
  bool _isGameUnlocked(TcgGame game) {
    return _purchaseManager.canAccessGame(
      game == TcgGame.pokemon ? AppTcgGame.pokemon : AppTcgGame.mtg,
    );
  }

  Future<bool> _ensureGameAccessFresh(TcgGame game) async {
    if (_isGameUnlocked(game)) {
      return true;
    }
    try {
      await _purchaseManager.init();
      await _purchaseManager.refreshEntitlementFromStore();
    } catch (_) {
      // Best effort only.
    }
    return _isGameUnlocked(game);
  }

  TcgGame _firstAccessibleGame() {
    if (_isGameUnlocked(TcgGame.pokemon) && !_isGameUnlocked(TcgGame.mtg)) {
      return TcgGame.pokemon;
    }
    if (_isGameUnlocked(TcgGame.mtg)) {
      return TcgGame.mtg;
    }
    return TcgGame.pokemon;
  }

  Future<void> _ensureSelectedHomeGameUnlocked() async {
    if (!_isGameUnlocked(_selectedHomeGame)) {
      final fallbackGame = _firstAccessibleGame();
      await TcgEnvironmentController.instance.setGame(fallbackGame);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedHomeGame = fallbackGame;
      });
      return;
    }
    final envGame = TcgEnvironmentController.instance.currentGame;
    if (envGame != _selectedHomeGame && _isGameUnlocked(envGame)) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedHomeGame = envGame;
      });
    }
  }

  Future<void> _initializeForCurrentGame() async {
    if (!_isGameUnlocked(_selectedHomeGame)) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingBulk = false;
        _bulkUpdateAvailable = false;
        _bulkDownloadError = null;
        _cardsMissing = false;
      });
      return;
    }
    if (_isMtgActiveGame) {
      await _initializeStartup();
      return;
    }
    await _initializePokemonStartup();
  }

  Future<void> _initializePokemonStartup() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _checkingBulk = false;
      _bulkUpdateAvailable = false;
      _bulkDownloadUri = null;
      _bulkUpdatedAt = null;
      _bulkUpdatedAtRaw = null;
      _bulkDownloadError = null;
      _cardsMissing = false;
    });
    try {
      await ScryfallDatabase.instance.repairMissingSetCodesFromCardIds();
      unawaited(_backfillPokemonSetNamesInBackground());
      unawaited(_repairPokemonColorsInBackground());
      final installed = await PokemonBulkService.instance.isInstalled();
      if (!installed) {
        final shouldInstall = await _showPokemonProfilePickerForMissingDb();
        if (shouldInstall != true || !mounted) {
          return;
        }
        await _installPokemonDatasetWithFeedback();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingBulk = false;
        _cardsMissing = false;
        _bulkUpdateAvailable = false;
        _bulkUpdatedAt = null;
        _bulkUpdatedAtRaw = null;
      });
      unawaited(_refreshPokemonUpdateStatusInBackground());
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingBulk = false;
        _cardsMissing = true;
        _bulkUpdateAvailable = false;
        _bulkDownloadError = error.toString();
      });
    }
  }

  Future<void> _refreshPokemonUpdateStatusInBackground() async {
    try {
      final updateStatus = await PokemonBulkService.instance
          .checkForUpdate()
          .timeout(const Duration(seconds: 8));
      if (!mounted) {
        return;
      }
      setState(() {
        _cardsMissing = !updateStatus.installed;
        // Keep "update available" sticky in background checks to avoid
        // flickering from transient remote-check inconsistencies.
        if (updateStatus.updateAvailable) {
          _bulkUpdateAvailable = true;
        } else if (_cardsMissing) {
          _bulkUpdateAvailable = false;
        }
      });
    } on TimeoutException {
      // Keep UI responsive: silently skip slow update checks.
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _backfillPokemonSetNamesInBackground() async {
    final updated = await PokemonBulkService.instance.backfillSetNames();
    if (!mounted || updated <= 0) {
      return;
    }
    await _loadCollections();
  }

  Future<void> _repairPokemonColorsInBackground() async {
    final repairedMissing = await ScryfallDatabase.instance
        .repairMissingColorsFromTypeLine();
    final repairedFromCardJson = await ScryfallDatabase.instance
        .repairMissingPokemonColorsFromCardJson();
    final normalizedLightning = await ScryfallDatabase.instance
        .normalizePokemonLightningColors();
    final repairedArtists = await ScryfallDatabase.instance
        .backfillArtistsFromCardJson();
    final updated =
        repairedMissing +
        repairedFromCardJson +
        normalizedLightning +
        repairedArtists;
    if (!mounted || updated <= 0) {
      return;
    }
    await _loadCollections();
  }

  Future<void> _installPokemonDatasetWithFeedback() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _checkingBulk = false;
      _bulkDownloading = true;
      _bulkDownloadProgress = 0;
      _bulkDownloadReceived = 0;
      _bulkDownloadTotal = 0;
      _bulkImporting = false;
      _bulkImportProgress = 0;
      _pokemonSyncOverallProgress = 0;
      _bulkImportedCount = 0;
      _pokemonSyncStatus = null;
      _pokemonSyncStartedAt = DateTime.now();
      _pokemonSyncLastStatusAt = DateTime.now();
      _pokemonSyncElapsedSeconds = 0;
      _bulkDownloadError = null;
    });
    _startPokemonSyncUiTimer();

    var lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);
    var lastAcceptedProgress = -1.0;
    try {
      await PokemonBulkService.instance.installDataset(
        onStatus: (status) {
          if (!mounted) {
            return;
          }
          setState(() {
            _pokemonSyncStatus = status.trim().isEmpty ? null : status.trim();
            _pokemonSyncLastStatusAt = DateTime.now();
          });
        },
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          final clamped = progress.clamp(0.0, 1.0);
          final now = DateTime.now();
          final progressedEnough = clamped - lastAcceptedProgress >= 0.004;
          final isTerminal = clamped >= 1.0;
          if (!isTerminal &&
              !progressedEnough &&
              now.difference(lastUiTick) < const Duration(milliseconds: 100)) {
            return;
          }
          lastUiTick = now;
          if (clamped > lastAcceptedProgress) {
            lastAcceptedProgress = clamped;
          }
          final pokemonPhase = !_isMtgActiveGame
              ? _pokemonSyncPhaseInfoForProgress(clamped)
              : null;
          final pokemonPhaseProgress = pokemonPhase == null
              ? 0.0
              : _pokemonSyncPhaseProgress(pokemonPhase, clamped);
          setState(() {
            if (!_isMtgActiveGame) {
              _pokemonSyncOverallProgress = clamped;
              final isDownloadPhase = pokemonPhase?.index == 1;
              _bulkDownloading = isDownloadPhase;
              _bulkImporting = !isDownloadPhase;
              _bulkDownloadProgress = isDownloadPhase
                  ? pokemonPhaseProgress
                  : 1;
              _bulkDownloadReceived = (_bulkDownloadProgress * 10000).round();
              _bulkDownloadTotal = 10000;
              _bulkImportProgress = isDownloadPhase ? 0 : pokemonPhaseProgress;
              _bulkImportedCount = 0;
            } else if (clamped < 0.55) {
              _bulkDownloading = true;
              _bulkImporting = false;
              _bulkDownloadProgress = (clamped / 0.55).clamp(0.0, 1.0);
              _bulkDownloadReceived = (_bulkDownloadProgress * 10000).round();
              _bulkDownloadTotal = 10000;
            } else {
              _bulkDownloading = false;
              _bulkImporting = true;
              _bulkImportProgress = ((clamped - 0.55) / (1.0 - 0.55)).clamp(
                0.0,
                1.0,
              );
              _bulkImportedCount = (_bulkImportProgress * 100).round();
            }
          });
        },
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _bulkDownloading = false;
        _bulkDownloadProgress = 1;
        _bulkImporting = false;
        _bulkImportProgress = _isMtgActiveGame ? 1 : 0;
        _pokemonSyncOverallProgress = 1;
        _pokemonSyncStatus = null;
        _pokemonSyncStartedAt = null;
        _pokemonSyncLastStatusAt = null;
        _pokemonSyncElapsedSeconds = 0;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _bulkDownloading = false;
          _bulkImporting = false;
          _pokemonSyncOverallProgress = 0;
          _pokemonSyncStatus = null;
          _pokemonSyncStartedAt = null;
          _pokemonSyncLastStatusAt = null;
          _pokemonSyncElapsedSeconds = 0;
          _bulkDownloadError = error.toString();
        });
      }
      rethrow;
    } finally {
      _stopPokemonSyncUiTimer();
    }
  }

  Future<void> _retryPokemonDatasetInstall() async {
    if (_isMtgActiveGame ||
        _checkingBulk ||
        _bulkDownloading ||
        _bulkImporting) {
      return;
    }
    if (!_isGameUnlocked(TcgGame.pokemon)) {
      await _showLockedGameDialog(TcgGame.pokemon);
      return;
    }
    if (await PokemonBulkService.instance.isInstalled() == false) {
      final shouldInstall = await _showPokemonProfilePickerForMissingDb();
      if (shouldInstall != true || !mounted) {
        return;
      }
    }
    await _initializePokemonStartup();
    if (!mounted) {
      return;
    }
    await _loadCollections();
  }

  Future<bool?> _showPokemonProfilePickerForMissingDb() async {
    if (!mounted) {
      return null;
    }
    return true;
  }

  Future<void> _checkForAppUpdateOnStartup() async {
    if (kDebugMode || kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) {
        return;
      }
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      final immediateAllowed =
          updateInfo.immediateUpdateAllowed || updateInfo.flexibleUpdateAllowed;
      if (!immediateAllowed) {
        return;
      }
      await InAppUpdate.performImmediateUpdate();
    } catch (_) {
      // Best effort only: if Play update API is unavailable, continue app startup.
    }
  }

  @override
  void dispose() {
    _stopPokemonSyncUiTimer();
    _collectionsRefreshNotifier.removeListener(_onCollectionsRefreshRequested);
    _snakeController.dispose();
    _purchaseManager.removeListener(_purchaseListener);
    super.dispose();
  }

  void _startPokemonSyncUiTimer() {
    _stopPokemonSyncUiTimer();
    _pokemonSyncUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_bulkDownloading && !_bulkImporting) {
        _stopPokemonSyncUiTimer();
        return;
      }
      final startedAt = _pokemonSyncStartedAt;
      if (startedAt == null) {
        return;
      }
      final next = DateTime.now().difference(startedAt).inSeconds;
      if (next == _pokemonSyncElapsedSeconds) {
        return;
      }
      setState(() {
        _pokemonSyncElapsedSeconds = next;
      });
    });
  }

  void _stopPokemonSyncUiTimer() {
    _pokemonSyncUiTimer?.cancel();
    _pokemonSyncUiTimer = null;
  }

  String _formatPokemonSyncElapsed() {
    final total = _pokemonSyncElapsedSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _pokemonSyncDetailLabel() {
    final status = (_pokemonSyncStatus ?? '').trim();
    if (status.isEmpty) {
      return _isItalianUi()
          ? 'Preparazione catalogo in corso...'
          : 'Preparing catalog...';
    }
    final now = DateTime.now();
    final lastUpdate = _pokemonSyncLastStatusAt;
    final staleSeconds = lastUpdate == null
        ? 0
        : now.difference(lastUpdate).inSeconds;
    if (staleSeconds < 60) {
      return status;
    }
    return _isItalianUi()
        ? '$status - In corso (${staleSeconds}s)'
        : '$status - In progress (${staleSeconds}s)';
  }

  _PokemonSyncPhaseInfo _pokemonSyncPhaseInfo() {
    return _pokemonSyncPhaseInfoForProgress(_pokemonSyncOverallProgress);
  }

  _PokemonSyncPhaseInfo _pokemonSyncPhaseInfoForProgress(double progress) {
    final status = (_pokemonSyncStatus ?? '').trim().toLowerCase();
    final italian = _isItalianUi();
    if (status.contains('finalizing') || status.contains('completed')) {
      return _PokemonSyncPhaseInfo(
        index: 4,
        total: 4,
        label: italian ? 'Finalizzazione' : 'Finalization',
        startProgress: 0.93,
        endProgress: 1.0,
      );
    }
    if (status.contains('building legacy') ||
        status.contains('rebuilding local pokemon database') ||
        status.contains('reimporting')) {
      return _PokemonSyncPhaseInfo(
        index: 3,
        total: 4,
        label: italian ? 'Build database locale' : 'Build local database',
        startProgress: 0.72,
        endProgress: 0.93,
      );
    }
    if (status.contains('importing local pokemon catalog') ||
        status.contains('restoring pokemon canonical catalog')) {
      return _PokemonSyncPhaseInfo(
        index: 2,
        total: 4,
        label: italian ? 'Import catalogo locale' : 'Import local catalog',
        startProgress: 0.57,
        endProgress: 0.72,
      );
    }
    if (progress >= 0.93) {
      return _PokemonSyncPhaseInfo(
        index: 4,
        total: 4,
        label: italian ? 'Finalizzazione' : 'Finalization',
        startProgress: 0.93,
        endProgress: 1.0,
      );
    }
    if (progress >= 0.72) {
      return _PokemonSyncPhaseInfo(
        index: 3,
        total: 4,
        label: italian ? 'Build database locale' : 'Build local database',
        startProgress: 0.72,
        endProgress: 0.93,
      );
    }
    if (progress >= 0.57) {
      return _PokemonSyncPhaseInfo(
        index: 2,
        total: 4,
        label: italian ? 'Import catalogo locale' : 'Import local catalog',
        startProgress: 0.57,
        endProgress: 0.72,
      );
    }
    return _PokemonSyncPhaseInfo(
      index: 1,
      total: 4,
      label: italian ? 'Download catalogo' : 'Catalog download',
      startProgress: 0.0,
      endProgress: 0.57,
    );
  }

  double _pokemonSyncPhaseProgress(
    _PokemonSyncPhaseInfo phase,
    double progress,
  ) {
    final clamped = progress.clamp(0.0, 1.0);
    final span = (phase.endProgress - phase.startProgress).clamp(0.0001, 1.0);
    return ((clamped - phase.startProgress) / span).clamp(0.0, 1.0);
  }

  String _pokemonSyncMetaLine() {
    return '${_pokemonSyncDetailLabel()} - ${_formatPokemonSyncElapsed()}';
  }

  Widget _buildPokemonSyncChip({
    required _PokemonSyncPhaseInfo phase,
    required String percentText,
    required String metaLine,
  }) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE9C46A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5DEA0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sync_rounded,
                size: 15,
                color: Color(0xFF1C1510),
              ),
              const SizedBox(width: 6),
              Text(
                '${phase.index}/${phase.total}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF1C1510),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1A1C1510),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$percentText%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF1C1510),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            phase.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF1C1510),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metaLine,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF4A3720),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMtgSyncChip({
    required IconData icon,
    required String percentText,
    required String title,
    required String metaLine,
  }) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE9C46A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5DEA0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: const Color(0xFF1C1510)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1A1C1510),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$percentText%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF1C1510),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF1C1510),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metaLine,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF4A3720),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _pokemonDownloadErrorLabel(String raw) {
    final value = raw.trim().toLowerCase();
    final italian = _isItalianUi();
    if (value.contains('pokemon_hosted_bundle_timeout')) {
      return italian
          ? 'Timeout durante il download del bundle Pokemon da Firebase.'
          : 'Timed out while downloading the Pokemon bundle from Firebase.';
    }
    if (value.contains('pokemon_hosted_bundle_unreachable')) {
      return italian
          ? 'Firebase non raggiungibile durante il download del bundle Pokemon.'
          : 'Firebase was unreachable while downloading the Pokemon bundle.';
    }
    if (value.contains('pokemon_api_http_404') ||
        value.contains('pokemon_hosted_bundle_http_404')) {
      return italian
          ? 'Asset del bundle Pokemon non trovato su Firebase.'
          : 'Pokemon bundle asset was not found on Firebase.';
    }
    if (value.contains('pokemon_hosted_bundle_missing_languages')) {
      return italian
          ? 'Il bundle Firebase non contiene tutte le lingue richieste.'
          : 'The Firebase bundle does not contain all required languages.';
    }
    if (value.contains('pokemon_hosted_bundle_unavailable')) {
      return italian
          ? 'Bundle Pokemon Firebase non disponibile per la selezione corrente.'
          : 'The Firebase Pokemon bundle is unavailable for the current selection.';
    }
    if (value.contains('pokemon_hosted_bundle_incomplete')) {
      return italian
          ? 'Bundle Pokemon Firebase scaricato ma incompleto.'
          : 'The Firebase Pokemon bundle was downloaded but is incomplete.';
    }
    if (value.contains('pokemon_hosted_bundle_invalid_payload')) {
      return italian
          ? 'Bundle Pokemon Firebase non valido o corrotto.'
          : 'The Firebase Pokemon bundle is invalid or corrupted.';
    }
    if (value.contains('pokemon_hosted_bundle_failed')) {
      return italian
          ? 'Errore durante il caricamento del bundle Pokemon da Firebase.'
          : 'Failed while loading the Pokemon bundle from Firebase.';
    }
    return raw;
  }

  String? _pokemonDownloadErrorDetail(String raw) {
    final match = RegExp(r'\|\|stage=([^|]+)\|\|detail=(.+)$').firstMatch(raw);
    if (match == null) {
      return null;
    }
    final stage = match.group(1)?.trim();
    final detail = match.group(2)?.trim();
    if ((stage == null || stage.isEmpty) &&
        (detail == null || detail.isEmpty)) {
      return null;
    }
    final parts = <String>[];
    if (stage != null && stage.isNotEmpty) {
      parts.add('stage=$stage');
    }
    if (detail != null && detail.isNotEmpty) {
      parts.add(detail);
    }
    return parts.join(' | ');
  }

  bool _isSetCollection(CollectionInfo collection) {
    if (collection.type == CollectionType.set) {
      return true;
    }
    return collection.name.startsWith(_setPrefix);
  }

  bool _isValidSetCollection(CollectionInfo collection) {
    if (!_isSetCollection(collection)) {
      return false;
    }
    final setCode = _setCodeForCollection(collection);
    return setCode != null && setCode.trim().isNotEmpty;
  }

  bool _isBasicLandsCollection(CollectionInfo collection) {
    return collection.type == CollectionType.basicLands ||
        collection.name.trim().toLowerCase() ==
            _basicLandsCollectionName.toLowerCase();
  }

  bool _isDeckSideboardCollection(CollectionInfo collection) {
    return collection.name.startsWith('__deck_side__:');
  }

  String _setCollectionName(String setCode) {
    return '$_setPrefix${setCode.trim().toLowerCase()}';
  }

  String? _setCodeForCollection(CollectionInfo collection) {
    if (!_isSetCollection(collection)) {
      return null;
    }
    final filter = collection.filter;
    if (filter != null && filter.sets.isNotEmpty) {
      return filter.sets.first;
    }
    return collection.name.substring(_setPrefix.length).trim();
  }

  String _collectionDisplayName(CollectionInfo collection) {
    final setCode = _setCodeForCollection(collection);
    if (setCode != null) {
      return _setNameLookup[setCode] ?? setCode.toUpperCase();
    }
    if (collection.name == _allCardsCollectionName) {
      return AppLocalizations.of(context)!.allCards;
    }
    if (_isBasicLandsCollection(collection)) {
      return AppLocalizations.of(context)!.basicLandsLabel;
    }
    return collection.name;
  }

  String _normalizedCollectionName(String value) {
    return value.trim().toLowerCase();
  }

  bool _isCollectionNameTaken(String name, {int? excludeCollectionId}) {
    final normalized = _normalizedCollectionName(name);
    if (normalized.isEmpty) {
      return false;
    }
    for (final item in _collections) {
      if (excludeCollectionId != null && item.id == excludeCollectionId) {
        continue;
      }
      if (_normalizedCollectionName(item.name) == normalized) {
        return true;
      }
    }
    return false;
  }

  String _nextProgressiveCollectionName(String baseLabel) {
    final base = baseLabel.trim().isEmpty ? 'Collection' : baseLabel.trim();
    final matcher = RegExp(
      '^${RegExp.escape(base)}\\s*(\\d+)?\$',
      caseSensitive: false,
    );
    var maxIndex = 0;
    for (final item in _collections) {
      final match = matcher.firstMatch(item.name.trim());
      if (match == null) {
        continue;
      }
      final rawNumber = match.group(1);
      final parsed = rawNumber == null ? 1 : int.tryParse(rawNumber) ?? 1;
      if (parsed > maxIndex) {
        maxIndex = parsed;
      }
    }
    return '$base ${maxIndex + 1}';
  }

  IconData _collectionIcon(CollectionInfo collection) {
    if (collection.type == CollectionType.deck) {
      return Icons.view_carousel_rounded;
    }
    if (collection.type == CollectionType.wishlist) {
      return Icons.favorite_border_rounded;
    }
    if (_isSetCollection(collection)) {
      return Icons.auto_awesome_mosaic;
    }
    if (collection.type == CollectionType.custom) {
      return Icons.collections_bookmark_outlined;
    }
    if (collection.type == CollectionType.smart) {
      return Icons.tune;
    }
    if (_isBasicLandsCollection(collection)) {
      return Icons.terrain_outlined;
    }
    return Icons.collections_bookmark;
  }

  CollectionInfo? _findAllCardsCollection() {
    CollectionInfo? fallbackByName;
    for (final collection in _collections) {
      if (collection.type == CollectionType.all) {
        return collection;
      }
      if (collection.name == _allCardsCollectionName) {
        fallbackByName ??= collection;
      }
    }
    return fallbackByName;
  }

  int _setCollectionCount() {
    return _collections.where(_isValidSetCollection).length;
  }

  bool _canCreateSetCollection() {
    return _hasProAccess || _setCollectionCount() < _freeSetCollectionLimit;
  }

  int _wishlistCollectionCount() {
    return _collections
        .where((item) => item.type == CollectionType.wishlist)
        .length;
  }

  bool _canCreateWishlist() {
    return _hasProAccess || _wishlistCollectionCount() < _freeWishlistLimit;
  }

  int _customCollectionCount() {
    return _collections
        .where(
          (item) =>
              item.type == CollectionType.custom &&
              !_isSetCollection(item) &&
              !_isDeckSideboardCollection(item),
        )
        .length;
  }

  bool _canCreateCustomCollection() {
    return _hasProAccess ||
        _customCollectionCount() < _freeCustomCollectionLimit;
  }

  int _smartCollectionCount() {
    return _collections
        .where(
          (item) =>
              item.type == CollectionType.smart && !_isSetCollection(item),
        )
        .length;
  }

  bool _canCreateSmartCollection() {
    return _hasProAccess || _smartCollectionCount() < _freeSmartCollectionLimit;
  }

  int _deckCollectionCount() {
    return _collections
        .where((item) => item.type == CollectionType.deck)
        .length;
  }

  bool _canCreateDeckCollection() {
    return _hasProAccess || _deckCollectionCount() < _freeDeckCollectionLimit;
  }

  Future<void> _loadCollections() async {
    if (_collectionsLoadInProgress) {
      return;
    }
    _collectionsLoadInProgress = true;
    try {
      final collections = await ScryfallDatabase.instance
          .fetchCollections()
          .timeout(const Duration(seconds: 15));
      final owned = await ScryfallDatabase.instance.countOwnedCards().timeout(
        const Duration(seconds: 15),
      );
      if (!mounted) {
        return;
      }
      final hasAllCards = collections.any(
        (collection) => collection.name == _allCardsCollectionName,
      );
      if (!hasAllCards) {
        final id = await ScryfallDatabase.instance.addCollection(
          _allCardsCollectionName,
          type: CollectionType.all,
        );
        if (!mounted) {
          return;
        }
        final updated = [
          CollectionInfo(
            id: id,
            name: _allCardsCollectionName,
            cardCount: owned,
            type: CollectionType.all,
            filter: null,
          ),
          ...collections,
        ];
        setState(() {
          _collections
            ..clear()
            ..addAll(updated);
          _totalCardCount = owned;
          _deckSideboardCounts = {};
          _recentAllCards = const [];
        });
        return;
      }
      if (collections.isEmpty) {
        final id = await ScryfallDatabase.instance.addCollection(
          _allCardsCollectionName,
          type: CollectionType.all,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _collections
            ..clear()
            ..add(
              CollectionInfo(
                id: id,
                name: _allCardsCollectionName,
                cardCount: 0,
                type: CollectionType.all,
                filter: null,
              ),
            );
          _totalCardCount = owned;
          _deckSideboardCounts = {};
          _recentAllCards = const [];
        });
        return;
      }
      final renamed = <CollectionInfo>[];
      final setCodes = <String>[];
      for (final collection in collections) {
        if (collection.name == _legacyMyCollectionName) {
          await ScryfallDatabase.instance.renameCollection(
            collection.id,
            _allCardsCollectionName,
          );
          renamed.add(
            CollectionInfo(
              id: collection.id,
              name: _allCardsCollectionName,
              cardCount: collection.cardCount,
              type: CollectionType.all,
              filter: collection.filter,
            ),
          );
        } else {
          renamed.add(collection);
        }
        final setCode = _setCodeForCollection(collection);
        if (setCode != null) {
          setCodes.add(setCode);
        }
      }
      final setNames = await appRepositories.sets
          .fetchSetNamesForCodes(setCodes)
          .timeout(const Duration(seconds: 8), onTimeout: () => const {});
      final deckSideCounts = <int, int>{};
      for (final collection in renamed) {
        if (collection.type != CollectionType.deck) {
          continue;
        }
        final sideboardCollectionId = await ScryfallDatabase.instance
            .fetchDeckSideboardCollectionId(collection.id);
        if (sideboardCollectionId == null) {
          deckSideCounts[collection.id] = 0;
          continue;
        }
        final sideCount = await ScryfallDatabase.instance
            .countCollectionQuantity(sideboardCollectionId);
        deckSideCounts[collection.id] = sideCount;
      }
      final allCardsCollection = renamed.cast<CollectionInfo?>().firstWhere(
        (item) => item?.name == _allCardsCollectionName,
        orElse: () => null,
      );
      final recentAllCards = allCardsCollection == null
          ? const <CardSearchResult>[]
          : await ScryfallDatabase.instance
                .fetchRecentOwnedCardPreviews(allCardsCollection.id, limit: 10)
                .timeout(
                  const Duration(seconds: 6),
                  onTimeout: () => const <CardSearchResult>[],
                );
      if (!mounted) {
        return;
      }
      setState(() {
        _collections
          ..clear()
          ..addAll(renamed);
        _totalCardCount = owned;
        _setNameLookup = setNames;
        _deckSideboardCounts = deckSideCounts;
        _recentAllCards = recentAllCards;
      });
    } on TimeoutException {
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.downloadFailedGeneric,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, _collectionLoadFailedLabel(error));
      }
    } finally {
      _collectionsLoadInProgress = false;
      if (mounted && _initialCollectionsLoading) {
        setState(() {
          _initialCollectionsLoading = false;
        });
      }
    }
  }

  List<Widget> _buildCollectionSections(
    BuildContext context, {
    bool includeAllCards = true,
  }) {
    final allCards = _collections.cast<CollectionInfo?>().firstWhere(
      (item) => item?.name == _allCardsCollectionName,
      orElse: () => null,
    );
    final userCollections = _collections
        .where(
          (collection) =>
              collection.name != _allCardsCollectionName &&
              !_isBasicLandsCollection(collection) &&
              !_isDeckSideboardCollection(collection),
        )
        .toList();
    final disabledCollectionIds = _disabledCollectionIdsForFree(
      userCollections,
    );
    final deckCollections = userCollections
        .where((item) => item.type == CollectionType.deck)
        .toList();
    final nonDeckCollections = userCollections
        .where((item) => item.type != CollectionType.deck)
        .toList();
    final widgets = <Widget>[];

    void openCollection(CollectionInfo collection) {
      final setCode = _setCodeForCollection(collection);
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => CollectionDetailPage(
                collectionId: collection.id,
                name: _collectionDisplayName(collection),
                isSetCollection: setCode != null,
                isDeckCollection: collection.type == CollectionType.deck,
                isBasicLandsCollection:
                    collection.type == CollectionType.basicLands,
                isWishlistCollection:
                    collection.type == CollectionType.wishlist,
                setCode: setCode,
                filter: collection.filter,
              ),
            ),
          )
          .then((_) => _loadCollections());
    }

    if (includeAllCards && allCards != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CollectionCard(
            name: _collectionDisplayName(allCards),
            count: _totalCardCount,
            icon: _collectionIcon(allCards),
            onLongPress: (position) {
              _showCollectionActions(allCards, position);
            },
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => CollectionDetailPage(
                        collectionId: allCards.id,
                        name: _collectionDisplayName(allCards),
                        isAllCards: true,
                        filter: allCards.filter,
                      ),
                    ),
                  )
                  .then((_) => _loadCollections());
            },
          ),
        ),
      );
    }

    if (_activeCollectionsMenu == _HomeCollectionsMenu.home) {
      widgets.addAll(
        _buildRecentAllCardsSection(context, includeHeader: false),
      );
      return widgets;
    }

    widgets.add(const SizedBox(height: 6));
    widgets.add(
      _SectionDivider(label: AppLocalizations.of(context)!.myCollections),
    );
    widgets.add(const SizedBox(height: 12));

    final canCreateSet = _canCreateSetCollection();
    final canCreateCustom = _canCreateCustomCollection();
    final canCreateSmart = _canCreateSmartCollection();
    final canCreateDeck = _canCreateDeckCollection();
    final canCreateWishlist = _canCreateWishlist();
    final setCollections = nonDeckCollections
        .where(_isValidSetCollection)
        .toList(growable: false);
    final customCollections = nonDeckCollections
        .where(
          (item) =>
              item.type == CollectionType.custom && !_isSetCollection(item),
        )
        .toList(growable: false);
    final smartCollections = nonDeckCollections
        .where(
          (item) =>
              item.type == CollectionType.smart && !_isSetCollection(item),
        )
        .toList(growable: false);
    final wishlistCollections = nonDeckCollections
        .where((item) => item.type == CollectionType.wishlist)
        .toList(growable: false);

    List<Widget> buildSingleCategory({
      required String label,
      required List<CollectionInfo> items,
      required IconData createIcon,
      required String createTitle,
      required String description,
      required bool canCreate,
      required VoidCallback onCreate,
      bool includeCountLabel = false,
    }) {
      if (items.isEmpty && !canCreate) {
        return [
          _buildLockedCollectionsPreview(
            context,
            section: _activeCollectionsMenu,
            introTitle: _isItalianUi() ? 'Funzione premium' : 'Premium feature',
            introBody: AppLocalizations.of(context)!.unlockProRemoveLimit,
          ),
        ];
      }
      final sectionWidgets = <Widget>[
        const SizedBox(height: 6),
        _SectionDivider(label: label),
        const SizedBox(height: 12),
      ];
      for (final collection in items) {
        final sideCount = _deckSideboardCounts[collection.id] ?? 0;
        final isDisabled = disabledCollectionIds.contains(collection.id);
        sectionWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CollectionCard(
              name: _collectionDisplayName(collection),
              count: collection.cardCount,
              icon: _collectionIcon(collection),
              enabled: !isDisabled,
              disabledTag: 'PRO',
              countLabel: includeCountLabel
                  ? '${collection.cardCount}+$sideCount'
                  : null,
              onLongPress: isDisabled
                  ? null
                  : (position) {
                      _showCollectionActions(collection, position);
                    },
              onTap: isDisabled ? null : () => openCollection(collection),
            ),
          ),
        );
      }
      sectionWidgets.add(
        _buildCreateCollectionCard(
          context,
          icon: createIcon,
          title: createTitle,
          enabled: canCreate,
          onTap: onCreate,
        ),
      );
      sectionWidgets.add(const SizedBox(height: 2));
      sectionWidgets.add(const _DividerGlow());
      sectionWidgets.add(const SizedBox(height: 10));
      sectionWidgets.add(_buildSectionHintCard(description));
      return sectionWidgets;
    }

    void addCreateCards() {
      widgets.add(
        _buildCreateCollectionCard(
          context,
          icon: Icons.tune,
          title: AppLocalizations.of(context)!.createYourCustomCollectionTitle,
          enabled: canCreateCustom,
          onTap: () => _addCustomCollection(context),
        ),
      );
      widgets.add(
        _buildCreateCollectionCard(
          context,
          icon: Icons.auto_fix_high_rounded,
          title: _isItalianUi()
              ? 'Crea una smart collection'
              : 'Create your smart collection',
          enabled: canCreateCustom,
          onTap: () => _addSmartCollection(context),
        ),
      );
      widgets.add(
        _buildCreateCollectionCard(
          context,
          icon: Icons.auto_awesome_mosaic,
          title: AppLocalizations.of(context)!.createYourSetCollectionTitle,
          enabled: canCreateSet,
          onTap: () => _addSetCollection(context),
        ),
      );
      widgets.add(
        _buildCreateCollectionCard(
          context,
          icon: Icons.favorite_border_rounded,
          title: AppLocalizations.of(context)!.createYourWishlistTitle,
          enabled: canCreateWishlist,
          onTap: () => _addWishlistCollection(context),
        ),
      );
    }

    if (_activeCollectionsMenu != _HomeCollectionsMenu.home) {
      switch (_activeCollectionsMenu) {
        case _HomeCollectionsMenu.set:
          return buildSingleCategory(
            label: AppLocalizations.of(context)!.createYourSetCollectionTitle,
            items: setCollections,
            createIcon: Icons.auto_awesome_mosaic,
            createTitle: AppLocalizations.of(
              context,
            )!.createYourSetCollectionTitle,
            description: _sectionHelpText(_HomeCollectionsMenu.set),
            canCreate: canCreateSet,
            onCreate: () => _addSetCollection(context),
          );
        case _HomeCollectionsMenu.custom:
          return buildSingleCategory(
            label: AppLocalizations.of(
              context,
            )!.createYourCustomCollectionTitle,
            items: customCollections,
            createIcon: Icons.tune,
            createTitle: AppLocalizations.of(
              context,
            )!.createYourCustomCollectionTitle,
            description: _sectionHelpText(_HomeCollectionsMenu.custom),
            canCreate: canCreateCustom,
            onCreate: () => _addCustomCollection(context),
          );
        case _HomeCollectionsMenu.smart:
          return buildSingleCategory(
            label: AppLocalizations.of(context)!.smartCollectionDefaultName,
            items: smartCollections,
            createIcon: Icons.auto_fix_high_rounded,
            createTitle: AppLocalizations.of(
              context,
            )!.createSmartCollectionTitle,
            description: _sectionHelpText(_HomeCollectionsMenu.smart),
            canCreate: canCreateSmart,
            onCreate: () => _addSmartCollection(context),
          );
        case _HomeCollectionsMenu.wish:
          return buildSingleCategory(
            label: AppLocalizations.of(context)!.createYourWishlistTitle,
            items: wishlistCollections,
            createIcon: Icons.favorite_border_rounded,
            createTitle: AppLocalizations.of(context)!.createYourWishlistTitle,
            description: _sectionHelpText(_HomeCollectionsMenu.wish),
            canCreate: canCreateWishlist,
            onCreate: () => _addWishlistCollection(context),
          );
        case _HomeCollectionsMenu.deck:
          return buildSingleCategory(
            label: AppLocalizations.of(context)!.deckCollectionTitle,
            items: deckCollections,
            createIcon: Icons.view_carousel_rounded,
            createTitle: AppLocalizations.of(context)!.createYourDeckTitle,
            description: _sectionHelpText(_HomeCollectionsMenu.deck),
            canCreate: canCreateDeck,
            onCreate: () => _addDeckCollection(context),
            includeCountLabel: true,
          );
        case _HomeCollectionsMenu.home:
          break;
      }
    }

    for (final collection in nonDeckCollections) {
      final isDisabled = disabledCollectionIds.contains(collection.id);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CollectionCard(
            name: _collectionDisplayName(collection),
            count: collection.cardCount,
            icon: _collectionIcon(collection),
            enabled: !isDisabled,
            disabledTag: 'PRO',
            onLongPress: isDisabled
                ? null
                : (position) {
                    _showCollectionActions(collection, position);
                  },
            onTap: isDisabled ? null : () => openCollection(collection),
          ),
        ),
      );
    }

    addCreateCards();

    widgets.add(const SizedBox(height: 6));
    widgets.add(
      _SectionDivider(label: AppLocalizations.of(context)!.deckCollectionTitle),
    );
    widgets.add(const SizedBox(height: 12));

    for (final collection in deckCollections) {
      final sideCount = _deckSideboardCounts[collection.id] ?? 0;
      final isDisabled = disabledCollectionIds.contains(collection.id);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CollectionCard(
            name: _collectionDisplayName(collection),
            count: collection.cardCount,
            icon: _collectionIcon(collection),
            enabled: !isDisabled,
            disabledTag: 'PRO',
            countLabel: '${collection.cardCount}+$sideCount',
            onLongPress: isDisabled
                ? null
                : (position) {
                    _showCollectionActions(collection, position);
                  },
            onTap: isDisabled ? null : () => openCollection(collection),
          ),
        ),
      );
    }

    widgets.add(
      _buildCreateCollectionCard(
        context,
        icon: Icons.view_carousel_rounded,
        title: AppLocalizations.of(context)!.createYourDeckTitle,
        enabled: canCreateDeck,
        onTap: () => _addDeckCollection(context),
      ),
    );

    return widgets;
  }

  List<Widget> _buildRecentAllCardsSection(
    BuildContext context, {
    bool includeHeader = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final widgets = <Widget>[];
    if (includeHeader) {
      widgets.addAll(const [SizedBox(height: 6)]);
      widgets.add(_SectionDivider(label: l10n.latestAddsLabel));
      widgets.addAll(const [SizedBox(height: 12)]);
    }
    if (_recentAllCards.isEmpty) {
      final emptyText = _appFirstOpenFlag == 1
          ? l10n.homeStartCollectionPrompt
          : l10n.noCardsYet;
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0x221D1712),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x445D4731)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFE9C46A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFDCCBAE),
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return widgets;
    }
    widgets.add(
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentAllCards.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.66,
        ),
        itemBuilder: (context, index) {
          final card = _recentAllCards[index];
          final priceLabel = _recentCardPriceLabel(card);
          return _RecentAddedCardTile(
            card: card,
            priceLabel: priceLabel,
            showPrice: _showPrices,
            onTap: () => _showRecentCardDetails(card),
          );
        },
      ),
    );
    return widgets;
  }

  String _recentCardPriceLabel(CardSearchResult card) {
    final currency = _priceCurrency.trim().toLowerCase() == 'usd'
        ? 'usd'
        : 'eur';
    final symbol = currency == 'usd' ? r'$' : '\u20AC';
    final primary = currency == 'usd' ? card.priceUsd : card.priceEur;
    final fallback = currency == 'usd' ? card.priceUsdFoil : card.priceEurFoil;
    final value =
        _normalizePriceValue(primary) ?? _normalizePriceValue(fallback);
    if (value == null) {
      return 'N/A';
    }
    return '$symbol$value';
  }

  Future<void> _showRecentCardDetails(CardSearchResult card) async {
    FocusScope.of(context).unfocus();
    final allCardsId = await ScryfallDatabase.instance
        .ensureAllCardsCollectionId();
    final entry = await ScryfallDatabase.instance.fetchCardEntryById(
      card.id,
      printingId: card.printingId,
      collectionId: allCardsId,
    );
    if (!mounted) {
      return;
    }
    if (entry == null) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.networkErrorTryAgain,
      );
      return;
    }

    final imageUrl = _normalizeCardImageUrlForDisplay(entry.imageUri);
    List<String> legalFormats = const [];
    try {
      legalFormats = await ScryfallDatabase.instance.fetchCardLegalFormats(
        entry.cardId,
      );
    } catch (_) {
      legalFormats = const [];
    }
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final priceCurrency = await AppSettings.loadPriceCurrency();
    if (!mounted) {
      return;
    }
    final details = _parseRecentCardDetails(
      l10n,
      entry,
      legalFormats,
      priceCurrency,
    );
    final typeLine = entry.typeLine.trim();
    final manaCost = entry.manaCost.trim();
    final oracleText = entry.oracleText.trim();
    final stats = _joinStats(entry.power.trim(), entry.toughness.trim());
    final loyalty = entry.loyalty.trim();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final addButtonKey = GlobalKey();
        var showCheck = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handleAdd() async {
              final added = await _addCardToAllCards(
                card.id,
                printingId: card.printingId,
              );
              if (!added || !mounted) {
                return;
              }
              setModalState(() {
                showCheck = true;
              });
              await Future<void>.delayed(const Duration(milliseconds: 700));
              if (!mounted) {
                return;
              }
              setModalState(() {
                showCheck = false;
              });
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Row(
                        children: [
                          if (manaCost.isNotEmpty)
                            _buildRecentManaCostPips(manaCost),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          FilledButton(
                            key: addButtonKey,
                            onPressed: () async {
                              await handleAdd();
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  ),
                              child: showCheck
                                  ? const Icon(
                                      Icons.check,
                                      key: ValueKey('check'),
                                    )
                                  : const Icon(Icons.add, key: ValueKey('add')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildSetIcon(entry.setCode, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _subtitleLabelForRecentEntry(entry),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFFBFAE95)),
                          ),
                        ],
                      ),
                      if (typeLine.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          typeLine,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFE3D4B8)),
                        ),
                      ],
                      if (oracleText.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF201A14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3A2F24)),
                          ),
                          child: Text(
                            oracleText,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      if (stats.isNotEmpty || loyalty.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (stats.isNotEmpty) _buildBadge(stats),
                            if (loyalty.isNotEmpty)
                              _buildBadge(l10n.loyaltyLabel(loyalty)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(imageUrl, fit: BoxFit.contain),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.details,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _buildRecentDetailGrid(details),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<String> _recentManaTokens(String manaCost) {
    final source = manaCost.trim();
    if (source.isEmpty) {
      return const [];
    }
    final matches = RegExp(r'\{([^}]+)\}').allMatches(source).toList();
    if (matches.isEmpty) {
      return [source];
    }
    return matches
        .map((match) => (match.group(1) ?? '').trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  Color _recentManaPipColor(String token) {
    switch (token) {
      case 'W':
        return const Color(0xFFF3E6B2);
      case 'U':
        return const Color(0xFF7DB7FF);
      case 'B':
        return const Color(0xFF5C5C66);
      case 'R':
        return const Color(0xFFE27A5E);
      case 'G':
        return const Color(0xFF74B77F);
      case 'C':
        return const Color(0xFF9AA2AD);
      default:
        if (RegExp(r'^\d+$').hasMatch(token)) {
          return const Color(0xFF8F949C);
        }
        return const Color(0xFF7A8088);
    }
  }

  Widget _buildRecentManaCostPips(String manaCost) {
    final tokens = _recentManaTokens(manaCost);
    if (tokens.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tokens
          .map((token) {
            final color = _recentManaPipColor(token);
            final isColoredSingle = const {
              'W',
              'U',
              'B',
              'R',
              'G',
            }.contains(token);
            final label = isColoredSingle ? '' : token;
            return Container(
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3A2F24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: label.isEmpty
                  ? null
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF1A1714),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            );
          })
          .toList(growable: false),
    );
  }

  String _subtitleLabelForRecentEntry(CollectionCardEntry entry) {
    final setLabel = entry.setName.trim().isNotEmpty
        ? entry.setName.trim()
        : entry.setCode.toUpperCase();
    final progress = entry.collectorNumber.trim();
    if (setLabel.isEmpty) {
      return progress;
    }
    if (progress.isEmpty) {
      return setLabel;
    }
    return '$setLabel \u2022 $progress';
  }

  List<_CardDetail> _parseRecentCardDetails(
    AppLocalizations l10n,
    CollectionCardEntry entry,
    List<String> legalFormats,
    String priceCurrency,
  ) {
    final setLabel = entry.setName.trim().isNotEmpty
        ? entry.setName.trim()
        : entry.setCode.toUpperCase();
    final details = <_CardDetail>[
      _CardDetail(l10n.detailSet, setLabel),
      _CardDetail(l10n.detailCollector, entry.collectorNumber),
    ];

    void add(String label, String value) {
      final text = value.trim();
      if (text.isEmpty) {
        return;
      }
      details.add(_CardDetail(label, text));
    }

    add(l10n.detailRarity, _formatRarity(context, entry.rarity));
    add(l10n.detailSetName, entry.setName);
    add(l10n.detailLanguage, entry.lang);
    add(l10n.detailRelease, entry.releasedAt);
    add(l10n.detailArtist, entry.artist);
    final legalFormatLabels = _normalizeFormatLabels(legalFormats);
    if (legalFormatLabels.isNotEmpty) {
      add(l10n.detailFormat, legalFormatLabels.join(', '));
    }
    final normalizedCurrency = priceCurrency.trim().toLowerCase();
    if (normalizedCurrency == 'usd') {
      add('Price (USD)', _displayRecentUsdPrice(entry));
    } else {
      add('Price (EUR)', _displayRecentEurPrice(entry));
    }
    return details.where((item) => item.value.isNotEmpty).toList();
  }

  String _displayRecentEurPrice(CollectionCardEntry entry) {
    final base = _normalizePriceValue(entry.priceEur);
    final foil = _normalizePriceValue(entry.priceEurFoil);
    final selected = entry.foil ? (foil ?? base) : base;
    if (selected == null) {
      return '\u2014';
    }
    return 'EUR $selected';
  }

  String _displayRecentUsdPrice(CollectionCardEntry entry) {
    final base = _normalizePriceValue(entry.priceUsd);
    final foil = _normalizePriceValue(entry.priceUsdFoil);
    final selected = entry.foil ? (foil ?? base) : base;
    if (selected == null) {
      return '\u2014';
    }
    return 'USD $selected';
  }

  String? _normalizePriceValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  List<String> _normalizeFormatLabels(List<String> rawFormats) {
    final normalized = <String>{};
    for (final item in rawFormats) {
      final value = item.trim().toLowerCase();
      if (value.isNotEmpty) {
        normalized.add(value);
      }
    }
    final values = normalized.toList();
    values.sort((a, b) {
      final ai = kSupportedDeckFormats.indexOf(a);
      final bi = kSupportedDeckFormats.indexOf(b);
      if (ai == -1 && bi == -1) {
        return a.compareTo(b);
      }
      if (ai == -1) {
        return 1;
      }
      if (bi == -1) {
        return -1;
      }
      return ai.compareTo(bi);
    });
    return values.map(deckFormatLabel).toList();
  }

  String _joinStats(String power, String toughness) {
    final p = power.trim();
    final t = toughness.trim();
    if (p.isEmpty && t.isEmpty) {
      return '';
    }
    if (p.isEmpty) {
      return t;
    }
    if (t.isEmpty) {
      return p;
    }
    return '$p/$t';
  }

  Widget _buildRecentDetailGrid(List<_CardDetail> details) {
    if (details.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: details
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _DetailRow(label: item.label, value: item.value),
                ),
              )
              .toList(),
        );
      },
    );
  }

  String _sectionHelpText(_HomeCollectionsMenu section) {
    final l10n = AppLocalizations.of(context)!;
    switch (section) {
      case _HomeCollectionsMenu.set:
        return l10n.homeSetHelp;
      case _HomeCollectionsMenu.custom:
        return l10n.homeCustomHelp;
      case _HomeCollectionsMenu.smart:
        return l10n.homeSmartHelp;
      case _HomeCollectionsMenu.wish:
        return l10n.homeWishHelp;
      case _HomeCollectionsMenu.deck:
        return l10n.homeDeckHelp;
      case _HomeCollectionsMenu.home:
        return '';
    }
  }

  Widget _buildSectionHintCard(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0x221D1712),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF5D4731)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFFE9C46A),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFD6C7B0),
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _lockedPokemonPreviewNames(_HomeCollectionsMenu section) {
    final italian = _isItalianUi();
    switch (section) {
      case _HomeCollectionsMenu.set:
        return italian
            ? const ['Avventure Insieme', 'Destino di Paldea']
            : const ['Journey Together', 'Paldea Evolved'];
      case _HomeCollectionsMenu.custom:
        return italian
            ? const ['Preferite competitive', 'Promo da cercare']
            : const ['Competitive picks', 'Promos to chase'];
      case _HomeCollectionsMenu.smart:
        return italian
            ? const ['Carte possedute rare', 'Carte mancanti supporto']
            : const ['Owned rare cards', 'Missing support cards'];
      case _HomeCollectionsMenu.wish:
        return italian
            ? const ['Wishlist esposizioni', 'Carte da scambiare']
            : const ['Showcase wishlist', 'Cards to trade for'];
      case _HomeCollectionsMenu.deck:
        return italian
            ? const ['Mazzo torneo', 'Lista test ladder']
            : const ['Tournament deck', 'Ladder test list'];
      case _HomeCollectionsMenu.home:
        return italian
            ? const ['Avventure Insieme', 'Destino di Paldea']
            : const ['Journey Together', 'Paldea Evolved'];
    }
  }

  Widget _buildLockedCollectionsPreview(
    BuildContext context, {
    required _HomeCollectionsMenu section,
    String? introTitle,
    String? introBody,
    VoidCallback? cta,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveSection = section == _HomeCollectionsMenu.home
        ? _HomeCollectionsMenu.set
        : section;
    final previewNames = _lockedPokemonPreviewNames(effectiveSection);
    final createTitle = switch (effectiveSection) {
      _HomeCollectionsMenu.set => l10n.createYourSetCollectionTitle,
      _HomeCollectionsMenu.custom => l10n.createYourCustomCollectionTitle,
      _HomeCollectionsMenu.smart =>
        _isItalianUi()
            ? 'Crea una smart collection'
            : 'Create your smart collection',
      _HomeCollectionsMenu.wish => l10n.createYourWishlistTitle,
      _HomeCollectionsMenu.deck => l10n.createYourDeckTitle,
      _HomeCollectionsMenu.home => l10n.createYourSetCollectionTitle,
    };
    final createIcon = switch (effectiveSection) {
      _HomeCollectionsMenu.set => Icons.auto_awesome_mosaic,
      _HomeCollectionsMenu.custom => Icons.tune,
      _HomeCollectionsMenu.smart => Icons.auto_fix_high_rounded,
      _HomeCollectionsMenu.wish => Icons.favorite_border_rounded,
      _HomeCollectionsMenu.deck => Icons.view_carousel_rounded,
      _HomeCollectionsMenu.home => Icons.auto_awesome_mosaic,
    };
    final sectionTitle = switch (effectiveSection) {
      _HomeCollectionsMenu.set => l10n.createYourSetCollectionTitle,
      _HomeCollectionsMenu.custom => l10n.createYourCustomCollectionTitle,
      _HomeCollectionsMenu.smart => l10n.createSmartCollectionTitle,
      _HomeCollectionsMenu.wish => l10n.createYourWishlistTitle,
      _HomeCollectionsMenu.deck => l10n.deckCollectionTitle,
      _HomeCollectionsMenu.home => l10n.createYourSetCollectionTitle,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        if ((introTitle ?? '').trim().isNotEmpty ||
            (introBody ?? '').trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0x221D1712),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF5D4731)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    color: Color(0xFFE9C46A),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((introTitle ?? '').trim().isNotEmpty)
                        Text(
                          introTitle!,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      if ((introTitle ?? '').trim().isNotEmpty &&
                          (introBody ?? '').trim().isNotEmpty)
                        const SizedBox(height: 4),
                      if ((introBody ?? '').trim().isNotEmpty)
                        Text(
                          introBody!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFFBFAE95),
                                height: 1.35,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        _SectionDivider(label: sectionTitle),
        const SizedBox(height: 12),
        _CollectionCard(
          name: previewNames.first,
          count: 0,
          icon: createIcon,
          enabled: true,
        ),
        const SizedBox(height: 12),
        _CollectionCard(
          name: previewNames.length > 1 ? previewNames[1] : previewNames.first,
          count: 2,
          icon: createIcon,
          enabled: false,
          disabledTag: 'PRO',
        ),
        _buildCreateCollectionCard(
          context,
          icon: createIcon,
          title: createTitle,
          enabled: false,
          onTap: cta ?? () {},
        ),
        const SizedBox(height: 2),
        const _DividerGlow(),
        const SizedBox(height: 10),
        _buildSectionHintCard(_sectionHelpText(effectiveSection)),
      ],
    );
  }

  Set<int> _disabledCollectionIdsForFree(List<CollectionInfo> userCollections) {
    if (_hasProAccess) {
      return const <int>{};
    }
    final disabled = <int>{};

    void markDisabled(List<CollectionInfo> items, int limit) {
      for (var i = limit; i < items.length; i++) {
        disabled.add(items[i].id);
      }
    }

    final setItems = userCollections.where(_isValidSetCollection).toList();
    final customItems = userCollections
        .where(
          (item) =>
              item.type == CollectionType.custom &&
              !_isSetCollection(item) &&
              !_isDeckSideboardCollection(item),
        )
        .toList();
    final smartItems = userCollections
        .where(
          (item) =>
              item.type == CollectionType.smart && !_isSetCollection(item),
        )
        .toList();
    final deckItems = userCollections
        .where((item) => item.type == CollectionType.deck)
        .toList();
    final wishItems = userCollections
        .where((item) => item.type == CollectionType.wishlist)
        .toList();

    markDisabled(setItems, _freeSetCollectionLimit);
    markDisabled(customItems, _freeCustomCollectionLimit);
    markDisabled(smartItems, _freeSmartCollectionLimit);
    markDisabled(deckItems, _freeDeckCollectionLimit);
    markDisabled(wishItems, _freeWishlistLimit);

    return disabled;
  }

  Widget _buildCreateCollectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: CustomPaint(
          painter: _DashedRoundedRectPainter(
            color: const Color(0xFF8A6A3A),
            radius: 16,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: const Color(0xFFE9C46A), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE9C46A)),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 18,
                        color: Color(0xFFE9C46A),
                      ),
                    ),
                    if (!enabled)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          l10n.upgradeToPro,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: const Color(0xFFE9C46A),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initializeStartup() async {
    final storedBulkTypeRaw = await AppSettings.loadBulkTypeForGame(
      _activeSettingsGame,
    );
    final storedBulkType = _isMtgActiveGame ? 'all_cards' : storedBulkTypeRaw;
    if (_isMtgActiveGame && storedBulkTypeRaw != 'all_cards') {
      await AppSettings.saveBulkTypeForGame(_activeSettingsGame, 'all_cards');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBulkType = storedBulkType;
      _bulkUpdateAvailable = false;
      _bulkDownloadUri = null;
      _bulkUpdatedAt = null;
      _bulkUpdatedAtRaw = null;
      _bulkExpectedSizeBytes = null;
      _bulkDownloadError = null;
      _mtgHostedBundleResult = null;
      _mtgCanonicalBundleResult = null;
    });

    await _checkCardsInstalled();
    if (!mounted) {
      return;
    }

    var forceBootstrapDownload = false;
    if (_cardsMissing) {
      await AppSettings.saveBulkTypeForGame(_activeSettingsGame, 'all_cards');
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedBulkType = 'all_cards';
      });
      forceBootstrapDownload = true;
    }

    if (_selectedBulkType != null) {
      await _checkScryfallBulk(
        forceDownload: forceBootstrapDownload || _cardsMissing,
        restartAfterImport: forceBootstrapDownload || _cardsMissing,
      );
    }
  }

  Future<void> _checkScryfallBulk({
    bool forceDownload = false,
    bool restartAfterImport = false,
  }) async {
    if (_isMtgActiveGame) {
      await _checkMtgHostedBulk(
        forceDownload: forceDownload,
        restartAfterImport: restartAfterImport,
      );
      return;
    }
    if (_checkingBulk) {
      return;
    }
    final bulkType = _selectedBulkType;
    if (bulkType == null) {
      return;
    }
    setState(() {
      _checkingBulk = true;
    });

    final result = await ScryfallBulkChecker().checkAllCardsUpdate(bulkType);
    if (!mounted) {
      return;
    }

    setState(() {
      _checkingBulk = false;
      _bulkUpdateAvailable = result.updateAvailable;
      _bulkDownloadUri = result.downloadUri;
      _bulkUpdatedAt = result.updatedAt;
      _bulkUpdatedAtRaw = result.updatedAtRaw;
      _bulkExpectedSizeBytes = result.sizeBytes;
    });

    if (result.updateAvailable) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.scryfallBulkUpdateAvailable,
      );
    }
    if (forceDownload || _cardsMissing) {
      await _maybeStartBulkDownload(
        forceDownload: forceDownload || _cardsMissing,
        restartAfterImport: restartAfterImport,
      );
    }
  }

  Future<void> _checkMtgHostedBulk({
    bool forceDownload = false,
    bool restartAfterImport = false,
  }) async {
    if (_checkingBulk) {
      return;
    }
    setState(() {
      _checkingBulk = true;
      _bulkDownloadError = null;
    });

    try {
      final languages = (await AppSettings.loadCardLanguagesForGame(
        _activeSettingsGame,
      )).toSet();
      if (_preferMtgCanonicalCatalog) {
        final result = await MtgCanonicalBundleService().checkForUpdate(
          languages: languages,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _checkingBulk = false;
          _bulkUpdateAvailable = result.updateAvailable;
          _bulkDownloadUri = result.manifestUri.toString();
          _bulkUpdatedAt = result.updatedAt;
          _bulkUpdatedAtRaw = result.updatedAtRaw;
          _bulkExpectedSizeBytes = result.sizeBytes;
          _mtgHostedBundleResult = null;
          _mtgCanonicalBundleResult = result;
        });

        if (result.updateAvailable) {
          showAppSnackBar(
            context,
            AppLocalizations.of(context)!.scryfallBulkUpdateAvailable,
          );
        }
        if (forceDownload || _cardsMissing) {
          await _maybeStartBulkDownload(
            forceDownload: forceDownload || _cardsMissing,
            restartAfterImport: restartAfterImport,
          );
        }
        return;
      }
      final result = await MtgHostedBundleService().checkForUpdate(
        languages: languages,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingBulk = false;
        _bulkUpdateAvailable = result.updateAvailable;
        _bulkDownloadUri = MtgHostedBundleService.manifestUrl;
        _bulkUpdatedAt = result.updatedAt;
        _bulkUpdatedAtRaw = result.updatedAtRaw;
        _bulkExpectedSizeBytes = result.sizeBytes;
        _mtgHostedBundleResult = result;
        _mtgCanonicalBundleResult = null;
      });

      if (result.updateAvailable) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.scryfallBulkUpdateAvailable,
        );
      }
      if (forceDownload || _cardsMissing) {
        await _maybeStartBulkDownload(
          forceDownload: forceDownload || _cardsMissing,
          restartAfterImport: restartAfterImport,
        );
      }
    } catch (error) {
      if (_preferMtgCanonicalCatalog) {
        debugPrint('[mtg-canonical] update check failed, falling back: $error');
        try {
          final languages = (await AppSettings.loadCardLanguagesForGame(
            _activeSettingsGame,
          )).toSet();
          final result = await MtgHostedBundleService().checkForUpdate(
            languages: languages,
          );
          if (!mounted) {
            return;
          }
          setState(() {
            _checkingBulk = false;
            _bulkUpdateAvailable = result.updateAvailable;
            _bulkDownloadUri = MtgHostedBundleService.manifestUrl;
            _bulkUpdatedAt = result.updatedAt;
            _bulkUpdatedAtRaw = result.updatedAtRaw;
            _bulkExpectedSizeBytes = result.sizeBytes;
            _mtgHostedBundleResult = result;
            _mtgCanonicalBundleResult = null;
          });
          if (result.updateAvailable) {
            showAppSnackBar(
              context,
              AppLocalizations.of(context)!.scryfallBulkUpdateAvailable,
            );
          }
          if (forceDownload || _cardsMissing) {
            await _maybeStartBulkDownload(
              forceDownload: forceDownload || _cardsMissing,
              restartAfterImport: restartAfterImport,
            );
          }
          return;
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingBulk = false;
        _bulkDownloadError = error.toString();
      });
    }
  }

  Future<void> _checkCardsInstalled() async {
    final count = await ScryfallDatabase.instance.countCards();
    final owned = await ScryfallDatabase.instance.countOwnedCards();
    if (!mounted) {
      return;
    }
    if (count > 0) {
      final needsReimport = await ScryfallDatabase.instance
          .needsLightReimport();
      if (!mounted) {
        return;
      }
      if (!needsReimport) {
        setState(() {
          _cardsMissing = false;
          _totalCardCount = owned;
        });
        return;
      }
      setState(() {
        _cardsMissing = true;
        _totalCardCount = owned;
      });
    }
    if (count == 0) {
      setState(() {
        _cardsMissing = true;
        _totalCardCount = owned;
      });
    }
    final bulkType = _selectedBulkType;
    if (bulkType == null) {
      return;
    }
    if (_isMtgActiveGame) {
      try {
        final languages = (await AppSettings.loadCardLanguagesForGame(
          _activeSettingsGame,
        )).toSet();
        final canonicalInstalled = _preferMtgCanonicalCatalog
            ? await MtgCanonicalBundleService.hasInstalledCatalog()
            : false;
        if (_preferMtgCanonicalCatalog) {
          final result = await MtgCanonicalBundleService().checkForUpdate(
            languages: languages,
          );
          if (!mounted) {
            return;
          }
          final cardsMissing = canonicalInstalled ? false : _cardsMissing;
          setState(() {
            _cardsMissing = cardsMissing;
            _bulkDownloadUri = result.manifestUri.toString();
            _bulkUpdatedAt = result.updatedAt;
            _bulkUpdatedAtRaw = result.updatedAtRaw;
            _bulkUpdateAvailable = result.updateAvailable || cardsMissing;
            _bulkExpectedSizeBytes = result.sizeBytes;
            _mtgHostedBundleResult = null;
            _mtgCanonicalBundleResult = result;
          });
          if (!cardsMissing) {
            await _maybeStartBulkDownload();
          }
          return;
        }
        final result = await MtgHostedBundleService().checkForUpdate(
          languages: languages,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _bulkDownloadUri = MtgHostedBundleService.manifestUrl;
          _bulkUpdatedAt = result.updatedAt;
          _bulkUpdatedAtRaw = result.updatedAtRaw;
          _bulkUpdateAvailable = result.updateAvailable || _cardsMissing;
          _bulkExpectedSizeBytes = result.sizeBytes;
          _mtgHostedBundleResult = result;
          _mtgCanonicalBundleResult = null;
        });
        if (!_cardsMissing) {
          await _maybeStartBulkDownload();
        }
      } catch (error) {
        if (_preferMtgCanonicalCatalog) {
          debugPrint('[mtg-canonical] install check failed, falling back: $error');
          try {
            final languages = (await AppSettings.loadCardLanguagesForGame(
              _activeSettingsGame,
            )).toSet();
            final result = await MtgHostedBundleService().checkForUpdate(
              languages: languages,
            );
            if (!mounted) {
              return;
            }
            setState(() {
              _bulkDownloadUri = MtgHostedBundleService.manifestUrl;
              _bulkUpdatedAt = result.updatedAt;
              _bulkUpdatedAtRaw = result.updatedAtRaw;
              _bulkUpdateAvailable = result.updateAvailable || _cardsMissing;
              _bulkExpectedSizeBytes = result.sizeBytes;
              _mtgHostedBundleResult = result;
              _mtgCanonicalBundleResult = null;
            });
            if (!_cardsMissing) {
              await _maybeStartBulkDownload();
            }
            return;
          } catch (_) {}
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _bulkDownloadError = error.toString();
        });
      }
      return;
    }
    final result = await ScryfallBulkChecker().checkAllCardsUpdate(bulkType);
    if (!mounted) {
      return;
    }
    setState(() {
      _bulkDownloadUri = result.downloadUri ?? _bulkDownloadUri;
      _bulkUpdatedAt = result.updatedAt ?? _bulkUpdatedAt;
      _bulkUpdatedAtRaw = result.updatedAtRaw ?? _bulkUpdatedAtRaw;
      _bulkUpdateAvailable = true;
      _bulkExpectedSizeBytes = result.sizeBytes ?? _bulkExpectedSizeBytes;
    });
    if (!_cardsMissing) {
      await _maybeStartBulkDownload();
    }
  }

  Future<void> _maybeStartBulkDownload({
    bool forceDownload = false,
    bool restartAfterImport = false,
  }) async {
    if (_bulkDownloading || _bulkImporting) {
      return;
    }
    if (_bulkDownloadUri == null) {
      return;
    }
    if (_isMtgActiveGame) {
      final canonicalBundle = _mtgCanonicalBundleResult;
      if (canonicalBundle != null) {
        if (!forceDownload && !_cardsMissing && !_bulkUpdateAvailable) {
          return;
        }
        try {
          await _downloadMtgCanonicalBundle(
            canonicalBundle,
            restartAfterImport: restartAfterImport,
            rethrowOnError: true,
          );
          return;
        } catch (error) {
          debugPrint('[mtg-canonical] download failed, falling back: $error');
        }
      }
      final hostedBundle = _mtgHostedBundleResult;
      if (hostedBundle == null) {
        return;
      }
      if (!forceDownload && !_cardsMissing && !_bulkUpdateAvailable) {
        return;
      }
      await _downloadMtgHostedBundle(
        hostedBundle,
        restartAfterImport: restartAfterImport,
      );
      return;
    }
    if (!_isAllowedBulkDownloadUri(_bulkDownloadUri!)) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkDownloadError = AppLocalizations.of(
          context,
        )!.downloadFailedGeneric;
      });
      return;
    }
    if (!forceDownload && !_cardsMissing && !_bulkUpdateAvailable) {
      return;
    }
    await _downloadBulkFile(
      _bulkDownloadUri!,
      restartAfterImport: restartAfterImport,
    );
  }

  Future<void> _downloadAvailableDbUpdate() async {
    if (_isMtgActiveGame) {
      if (_bulkDownloading || _bulkImporting) {
        return;
      }
      if (_bulkDownloadUri == null) {
        await _checkMtgHostedBulk();
      }
      if (!mounted) {
        return;
      }
      await _maybeStartBulkDownload(forceDownload: true);
      return;
    }

    if (!_isGameUnlocked(TcgGame.pokemon)) {
      await _showLockedGameDialog(TcgGame.pokemon);
      return;
    }
    if (_checkingBulk || _bulkDownloading || _bulkImporting) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _checkingBulk = true;
      _bulkDownloadError = null;
    });
    try {
      await _installPokemonDatasetWithFeedback();
      final updateStatus = await PokemonBulkService.instance
          .checkForUpdate()
          .timeout(const Duration(seconds: 8));
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingBulk = false;
        _cardsMissing = !updateStatus.installed;
        _bulkUpdateAvailable = updateStatus.updateAvailable;
      });
      await _loadCollections();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingBulk = false;
        _bulkDownloadError = error is TimeoutException
            ? (_isItalianUi()
                  ? 'Controllo aggiornamenti troppo lento. Riprova.'
                  : 'Update check timed out. Please retry.')
            : error.toString();
      });
    }
  }

  bool _isAllowedBulkDownloadUri(String rawUri) {
    final uri = Uri.tryParse(rawUri.trim());
    if (uri == null) {
      return false;
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return false;
    }
    if (uri.userInfo.isNotEmpty || uri.host.trim().isEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host == 'api.scryfall.com' ||
        host == 'data.scryfall.io' ||
        host.endsWith('.scryfall.com') ||
        host.endsWith('.scryfall.io');
  }

  Future<void> _addWishlistCollection(BuildContext context) async {
    if (!_canCreateWishlist()) {
      await _showWishlistLimitDialog();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final defaultName = _nextProgressiveCollectionName(
      l10n.wishlistCollectionTitle,
    );
    final controller = TextEditingController(text: defaultName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.wishlistCollectionTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.collectionNameHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop(value.isEmpty ? defaultName : value);
              },
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );

    if (name == null) {
      return;
    }
    if (_isCollectionNameTaken(name)) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.collectionAlreadyExists,
      );
      return;
    }
    int id;
    try {
      id = await ScryfallDatabase.instance.addCollection(
        name,
        type: CollectionType.wishlist,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.failedToAddCollection('operation_failed'),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    final createdWishlist = CollectionInfo(
      id: id,
      name: name,
      cardCount: 0,
      type: CollectionType.wishlist,
      filter: null,
    );
    setState(() {
      _collections.add(createdWishlist);
    });

    if (!context.mounted) {
      return;
    }
    final shouldAddCardsNow =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(l10n.addCardsNowTitle),
              content: Text(l10n.addCardsNowBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.no),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.yes),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!mounted || !context.mounted) {
      return;
    }
    await _loadCollections();
    if (!mounted || !context.mounted || !shouldAddCardsNow) {
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CollectionDetailPage(
              collectionId: createdWishlist.id,
              name: _collectionDisplayName(createdWishlist),
              isWishlistCollection: true,
              filter: createdWishlist.filter,
              autoOpenAddCard: true,
            ),
          ),
        )
        .then((_) => _loadCollections());
  }

  Future<void> _addCustomCollection(BuildContext context) async {
    if (!_canCreateCustomCollection()) {
      await _showCustomCollectionLimitDialog();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final defaultName = _nextProgressiveCollectionName(
      l10n.customCollectionTitle,
    );
    final controller = TextEditingController(text: defaultName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.newCollectionTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.collectionNameHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop(value.isEmpty ? defaultName : value);
              },
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );

    if (name == null) {
      return;
    }
    if (_isCollectionNameTaken(name)) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.collectionAlreadyExists,
      );
      return;
    }
    if (!context.mounted) {
      return;
    }

    int id;
    try {
      id = await ScryfallDatabase.instance.addCollection(
        name,
        type: CollectionType.custom,
        filter: null,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.failedToAddCollection('operation_failed'),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    final createdCollection = CollectionInfo(
      id: id,
      name: name,
      cardCount: 0,
      type: CollectionType.custom,
      filter: null,
    );
    setState(() {
      _collections.add(createdCollection);
    });

    if (!context.mounted) {
      return;
    }
    final shouldAddCardsNow =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(l10n.addCardsNowTitle),
              content: Text(l10n.addCardsNowBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.no),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.yes),
                ),
              ],
            );
          },
        ) ??
        false;

    await _loadCollections();
    if (!mounted || !context.mounted || !shouldAddCardsNow) {
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CollectionDetailPage(
              collectionId: createdCollection.id,
              name: _collectionDisplayName(createdCollection),
              filter: createdCollection.filter,
              autoOpenAddCard: true,
            ),
          ),
        )
        .then((_) => _loadCollections());
  }

  Future<void> _addSmartCollection(BuildContext context) async {
    if (!_canCreateSmartCollection()) {
      await _showSmartCollectionLimitDialog();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final defaultName = _nextProgressiveCollectionName(
      l10n.smartCollectionDefaultName,
    );
    final controller = TextEditingController(text: defaultName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.newSmartCollectionTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.collectionNameHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop(value.isEmpty ? defaultName : value);
              },
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );
    if (name == null) {
      return;
    }
    if (_isCollectionNameTaken(name)) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.collectionAlreadyExists,
      );
      return;
    }
    if (!context.mounted) {
      return;
    }

    final filter = await Navigator.of(context).push<CollectionFilter>(
      MaterialPageRoute(
        builder: (_) => _CollectionFilterBuilderPage(
          name: name,
          submitLabel: l10n.create,
          initialFilter: null,
        ),
      ),
    );
    if (!context.mounted || filter == null) {
      return;
    }
    if (!_hasAtLeastOneSmartFilter(filter)) {
      showAppSnackBar(context, l10n.smartCollectionNeedFilterToCreate);
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    List<CardSearchResult> previewCards = const [];
    try {
      previewCards = await _collectCardsForSmartPreview(filter);
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!context.mounted) {
      return;
    }
    final confirmed = await _confirmSmartCollectionPreview(
      context,
      name: name,
      cards: previewCards,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    int id;
    try {
      id = await ScryfallDatabase.instance.addCollection(
        name,
        type: CollectionType.smart,
        filter: filter,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.failedToAddCollection('operation_failed'),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _collections.add(
        CollectionInfo(
          id: id,
          name: name,
          cardCount: 0,
          type: CollectionType.smart,
          filter: filter,
        ),
      );
    });
    await _loadCollections();
  }

  Future<List<CardSearchResult>> _collectCardsForSmartPreview(
    CollectionFilter filter, {
    int pageSize = 400,
  }) async {
    final cardsByPrintingKey = <String, CardSearchResult>{};
    var offset = 0;
    while (true) {
      final entries = await ScryfallDatabase.instance
          .fetchFilteredCollectionCards(
            filter,
            limit: pageSize,
            offset: offset,
          );
      if (entries.isEmpty) {
        break;
      }
      for (final entry in entries) {
        final card = CardSearchResult(
          id: entry.cardId,
          printingId: entry.printingId,
          name: entry.name,
          setCode: entry.setCode,
          setName: entry.setName,
          collectorNumber: entry.collectorNumber,
          setTotal: entry.setTotal,
          rarity: entry.rarity,
          typeLine: entry.typeLine,
          colors: entry.colors,
          colorIdentity: entry.colorIdentity,
          priceUsd: entry.priceUsd,
          priceUsdFoil: entry.priceUsdFoil,
          priceEur: entry.priceEur,
          priceEurFoil: entry.priceEurFoil,
          imageUri: entry.imageUri,
        );
        final key = card.printingId ?? '${card.id}::legacy';
        cardsByPrintingKey[key] = card;
      }
      if (entries.length < pageSize) {
        break;
      }
      offset += entries.length;
    }
    return cardsByPrintingKey.values.toList(growable: false);
  }

  Future<void> _showSmartPreviewImage(
    BuildContext context,
    CardSearchResult card,
  ) async {
    final imageUrl = _normalizeCardImageUrlForDisplay(card.imageUri);
    if (imageUrl.isEmpty) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: theme.colorScheme.surface,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => SizedBox(
                          width: 220,
                          height: 300,
                          child: Icon(
                            Icons.style,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirmSmartCollectionPreview(
    BuildContext context, {
    required String name,
    required List<CardSearchResult> cards,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final theme = Theme.of(dialogContext);
        final isItalian =
            Localizations.localeOf(dialogContext).languageCode == 'it';
        final summary = isItalian
            ? 'Carte nel filtro: ${cards.length}'
            : 'Cards in filter: ${cards.length}';
        final previewMessage = isItalian
            ? 'Anteprima delle carte attualmente incluse dal filtro della smart collection.'
            : 'Preview of the cards currently included by the smart collection filter.';
        final emptyMessage = isItalian
            ? 'Al momento nessuna carta corrisponde al filtro. La smart collection verra comunque creata.'
            : 'No cards currently match this filter. The smart collection will still be created.';
        return AlertDialog(
          title: Text(name),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary),
                const SizedBox(height: 12),
                Text(
                  cards.isEmpty ? emptyMessage : previewMessage,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (cards.isNotEmpty)
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.25,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Scrollbar(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: cards.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: theme.dividerColor.withValues(alpha: 0.35),
                          ),
                          itemBuilder: (itemContext, index) {
                            final card = cards[index];
                            final imageUrl = _normalizeCardImageUrlForDisplay(
                              card.imageUri,
                            );
                            return ListTile(
                              dense: true,
                              leading: GestureDetector(
                                onTap: () async {
                                  await _showSmartPreviewImage(
                                    dialogContext,
                                    card,
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 36,
                                    height: 50,
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.style,
                                        size: 18,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                card.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${card.setName} - ${card.collectorProgressLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _addSetCollection(BuildContext context) async {
    if (!_canCreateSetCollection()) {
      await _showSetCollectionLimitDialog();
      return;
    }
    final sets = await appRepositories.sets.fetchAvailableSets();
    if (!context.mounted) {
      return;
    }
    if (sets.isEmpty) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.noSetsAvailableYet,
      );
      return;
    }

    final selected = await showDialog<SetInfo>(
      context: context,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context)!;
            final filtered = sets
                .where(
                  (set) =>
                      set.name.toLowerCase().contains(query.toLowerCase()) ||
                      set.code.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              title: Text(l10n.newSetCollectionTitle),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(hintText: l10n.searchSetHint),
                      onChanged: (value) {
                        setState(() {
                          query = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final set = filtered[index];
                          return ListTile(
                            title: Text(set.name),
                            subtitle: Text(set.code.toUpperCase()),
                            onTap: () => Navigator.of(context).pop(set),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final selectedLanguages = await _pickSetCollectionLanguages(context);
    if (selectedLanguages == null ||
        selectedLanguages.isEmpty ||
        !context.mounted) {
      return;
    }

    final resolvedName = _setCollectionName(selected.code);
    if (_isCollectionNameTaken(resolvedName)) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.collectionAlreadyExists,
      );
      return;
    }

    int id;
    final filter = CollectionFilter(
      sets: {selected.code.toLowerCase()},
      languages: selectedLanguages,
    );
    try {
      id = await ScryfallDatabase.instance.addCollection(
        resolvedName,
        type: CollectionType.set,
        filter: filter,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.failedToAddCollection('operation_failed'),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _collections.add(
        CollectionInfo(
          id: id,
          name: resolvedName,
          cardCount: 0,
          type: CollectionType.set,
          filter: filter,
        ),
      );
      _setNameLookup = {..._setNameLookup, selected.code: selected.name};
    });
    await _loadCollections();
  }

  Future<void> _addDeckCollection(BuildContext context) async {
    if (!_canCreateDeckCollection()) {
      await _showDeckCollectionLimitDialog();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final defaultName = _nextProgressiveCollectionName(
      l10n.deckCollectionTitle,
    );
    final controller = TextEditingController(text: defaultName);
    final allowDeckImport = _isMtgActiveGame;
    String? selectedFormat;
    _DeckImportSource? importSource;
    final request = await showDialog<_DeckCreateRequest>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.newDeckTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(hintText: l10n.deckNameHint),
                  ),
                  if (!allowDeckImport) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _pokemonDeckHintLabel(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBFAE95),
                        ),
                      ),
                    ),
                  ],
                  if (allowDeckImport) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedFormat,
                      decoration: InputDecoration(
                        labelText: l10n.deckFormatOptionalLabel,
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.noFormatOption),
                        ),
                        ...kSupportedDeckFormats.map(
                          (value) => DropdownMenuItem<String?>(
                            value: value,
                            child: Text(deckFormatLabel(value)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedFormat = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _pickDeckImportSource();
                        if (!context.mounted) {
                          return;
                        }
                        if (picked == null) {
                          return;
                        }
                        setState(() {
                          importSource = picked;
                        });
                      },
                      icon: const Icon(Icons.upload_file),
                      label: Text(_deckImportButtonLabel()),
                    ),
                    if (importSource != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          importSource!.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFBFAE95)),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    Navigator.of(context).pop(
                      _DeckCreateRequest(
                        name: value.isEmpty ? defaultName : value,
                        format: allowDeckImport ? selectedFormat : null,
                        importSource: allowDeckImport ? importSource : null,
                      ),
                    );
                  },
                  child: Text(l10n.create),
                ),
              ],
            );
          },
        );
      },
    );

    if (request == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    if (_isCollectionNameTaken(request.name)) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.collectionAlreadyExists,
      );
      return;
    }

    final normalizedFormat = request.format?.trim().toLowerCase();
    final filter = (normalizedFormat == null || normalizedFormat.isEmpty)
        ? null
        : CollectionFilter(format: normalizedFormat);
    int id;
    try {
      id = await ScryfallDatabase.instance.addCollection(
        request.name,
        type: CollectionType.deck,
        filter: filter,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.failedToAddCollection('operation_failed'),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _collections.add(
        CollectionInfo(
          id: id,
          name: request.name,
          cardCount: 0,
          type: CollectionType.deck,
          filter: filter,
        ),
      );
    });
    if (request.importSource != null) {
      await _runDeckImportWithFeedback(
        collectionId: id,
        text: request.importSource!.content,
      );
    }
    await _loadCollections();
  }

  bool _isItalianUi() {
    return Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('it');
  }

  bool _hasAtLeastOneSmartFilter(CollectionFilter filter) {
    return (filter.name?.trim().isNotEmpty ?? false) ||
        (filter.artist?.trim().isNotEmpty ?? false) ||
        filter.manaMin != null ||
        filter.manaMax != null ||
        (filter.format?.trim().isNotEmpty ?? false) ||
        filter.sets.isNotEmpty ||
        filter.rarities.isNotEmpty ||
        filter.colors.isNotEmpty ||
        filter.types.isNotEmpty;
  }

  String _deckImportButtonLabel() {
    return AppLocalizations.of(context)!.loadArenaMtgoFileLabel;
  }

  String _pokemonDeckHintLabel() {
    return AppLocalizations.of(context)!.pokemonDeckHintLabel;
  }

  String _deckImportMenuLabel() {
    return AppLocalizations.of(context)!.importDeckListLabel;
  }

  String _deckExportArenaLabel() {
    return AppLocalizations.of(context)!.exportForArenaLabel;
  }

  String _deckExportMtgoLabel() {
    return AppLocalizations.of(context)!.exportForMtgoLabel;
  }

  String _deckImportedSummaryLabel(int imported, int skipped) {
    return AppLocalizations.of(context)!.deckImportedSummary(imported, skipped);
  }

  String _deckImportingLabel() {
    return AppLocalizations.of(context)!.deckImportingLabel;
  }

  String _deckImportResultTitle() {
    return AppLocalizations.of(context)!.deckImportResultTitle;
  }

  String _deckImportNotFoundTitle() {
    return AppLocalizations.of(context)!.deckImportCardsNotFoundTitle;
  }

  String _deckExportedSummaryLabel(String fileName) {
    return AppLocalizations.of(context)!.deckExportedSummary(fileName);
  }

  String _deckImportFailedLabel(Object error) {
    return AppLocalizations.of(context)!.deckImportFailed(error.toString());
  }

  String _deckExportFailedLabel(Object error) {
    return AppLocalizations.of(context)!.deckExportFailed(error.toString());
  }

  Future<_DeckImportSource?> _pickDeckImportSource() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'dek'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    final fileName = file.name.trim().isEmpty
        ? 'decklist.txt'
        : file.name.trim();
    String? content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    }
    if (content == null || content.trim().isEmpty) {
      return null;
    }
    return _DeckImportSource(fileName: fileName, content: content);
  }

  _ParsedDeckList _parseDeckListText(String text) {
    final mainboard = <String, int>{};
    final sideboard = <String, int>{};
    var inSideboard = false;
    var pendingBlankSideboardSwitch = false;
    var switchedByBlank = false;
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final cardXmlExp = RegExp(
      r'<Cards[^>]*Name="([^"]+)"[^>]*Quantity="(\d+)"[^>]*>',
      caseSensitive: false,
    );
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (!inSideboard && mainboard.isNotEmpty && !switchedByBlank) {
          pendingBlankSideboardSwitch = true;
        }
        continue;
      }
      final hasCountLine = RegExp(r'^\d+\s+.+$').hasMatch(line);
      final hasXmlCard = RegExp(
        r'^<Cards\b',
        caseSensitive: false,
      ).hasMatch(line);
      if (!inSideboard &&
          pendingBlankSideboardSwitch &&
          !switchedByBlank &&
          (hasCountLine || hasXmlCard)) {
        inSideboard = true;
        switchedByBlank = true;
      }
      pendingBlankSideboardSwitch = false;
      final lower = line.toLowerCase();
      if (lower == 'deck' ||
          lower == 'mainboard' ||
          lower == 'maindeck' ||
          lower == 'main') {
        inSideboard = false;
        pendingBlankSideboardSwitch = false;
        continue;
      }
      if (lower == 'sideboard' ||
          lower == 'side board' ||
          lower.startsWith('sideboard ')) {
        inSideboard = true;
        switchedByBlank = true;
        pendingBlankSideboardSwitch = false;
        continue;
      }
      var lineToParse = line;
      if (lower.startsWith('sb:')) {
        inSideboard = true;
        switchedByBlank = true;
        pendingBlankSideboardSwitch = false;
        lineToParse = line.substring(3).trim();
        if (lineToParse.isEmpty) {
          continue;
        }
      }

      final xmlMatch = cardXmlExp.firstMatch(lineToParse);
      if (xmlMatch != null) {
        final name = (xmlMatch.group(1) ?? '').trim();
        final qty = int.tryParse(xmlMatch.group(2) ?? '') ?? 0;
        if (name.isNotEmpty && qty > 0) {
          final xmlIsSideboard = RegExp(
            r'Sideboard\s*=\s*"true"',
            caseSensitive: false,
          ).hasMatch(line);
          final target = (inSideboard || xmlIsSideboard)
              ? sideboard
              : mainboard;
          target[name] = (target[name] ?? 0) + qty;
        }
        continue;
      }

      final mainMatch = RegExp(
        r'^(\d+)\s*x?\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(lineToParse);
      if (mainMatch == null) {
        continue;
      }
      final qty = int.tryParse(mainMatch.group(1) ?? '') ?? 0;
      if (qty <= 0) {
        continue;
      }
      var name = (mainMatch.group(2) ?? '').trim();
      name = name.replaceAll(
        RegExp(r'\s+\([A-Za-z0-9]+\)\s+[A-Za-z0-9]+$'),
        '',
      );
      name = name.replaceAll(RegExp(r'\s+$'), '');
      if (name.isEmpty) {
        continue;
      }
      final target = inSideboard ? sideboard : mainboard;
      target[name] = (target[name] ?? 0) + qty;
    }
    return _ParsedDeckList(mainboard: mainboard, sideboard: sideboard);
  }

  Future<_DeckImportResult> _importDeckTextIntoCollection({
    required int collectionId,
    required String text,
  }) async {
    final parsed = _parseDeckListText(text);
    if (parsed.mainboard.isEmpty && parsed.sideboard.isEmpty) {
      return const _DeckImportResult(
        imported: 0,
        skipped: 0,
        notFoundCards: [],
      );
    }
    final sideboardCollectionId = await ScryfallDatabase.instance
        .ensureDeckSideboardCollectionId(collectionId);
    var importedCards = 0;
    var skippedCards = 0;
    final notFoundCards = <String>[];
    final mainEntries = parsed.mainboard.entries.toList(growable: false);
    final sideEntries = parsed.sideboard.entries.toList(growable: false);
    var processed = 0;
    Future<void> importEntries(
      List<MapEntry<String, int>> entries, {
      required int targetCollectionId,
    }) async {
      for (final entry in entries) {
        processed += 1;
        if (processed % 20 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        final cardId = await _resolveCardIdForDeckImport(entry.key);
        if (cardId == null) {
          skippedCards += entry.value;
          notFoundCards.add(entry.key);
          continue;
        }
        final existing = await ScryfallDatabase.instance.fetchCardEntryById(
          cardId,
          collectionId: targetCollectionId,
        );
        final currentQty = existing?.quantity ?? 0;
        final nextQty = currentQty + entry.value;
        await ScryfallDatabase.instance.upsertCollectionCard(
          targetCollectionId,
          cardId,
          printingId: existing?.printingId,
          quantity: nextQty,
          foil: false,
          altArt: false,
        );
        importedCards += entry.value;
      }
    }

    await importEntries(mainEntries, targetCollectionId: collectionId);
    await importEntries(sideEntries, targetCollectionId: sideboardCollectionId);
    return _DeckImportResult(
      imported: importedCards,
      skipped: skippedCards,
      notFoundCards: notFoundCards,
    );
  }

  Future<String?> _resolveCardIdForDeckImport(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      return null;
    }

    final localId = await ScryfallDatabase.instance
        .fetchPreferredCardIdByExactName(name);
    if (localId != null) {
      return localId;
    }

    Future<String?> fetchOnline(String url) async {
      try {
        final response = await ScryfallApiClient.instance.get(
          Uri.parse(url),
          timeout: const Duration(seconds: 5),
          maxRetries: 2,
        );
        if (response.statusCode != 200) {
          return null;
        }
        final payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic>) {
          return null;
        }
        await ScryfallDatabase.instance.upsertCardFromScryfall(payload);
        final id = (payload['id'] as String?)?.trim();
        if (id != null && id.isNotEmpty) {
          return id;
        }
      } catch (_) {}
      return null;
    }

    final exactUrl =
        'https://api.scryfall.com/cards/named?exact=${Uri.encodeQueryComponent(name)}';
    final exactId = await fetchOnline(exactUrl);
    if (exactId != null) {
      return exactId;
    }

    final fuzzyUrl =
        'https://api.scryfall.com/cards/named?fuzzy=${Uri.encodeQueryComponent(name)}';
    final fuzzyId = await fetchOnline(fuzzyUrl);
    if (fuzzyId != null) {
      return fuzzyId;
    }

    return null;
  }

  Future<void> _runDeckImportWithFeedback({
    required int collectionId,
    required String text,
  }) async {
    try {
      final result = await _runWithBlockingDialog(
        message: _deckImportingLabel(),
        action: () => _importDeckTextIntoCollection(
          collectionId: collectionId,
          text: text,
        ),
      );
      if (!mounted) {
        return;
      }
      await _showDeckImportResultDialog(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, _deckImportFailedLabel(error));
    }
  }

  Future<List<CollectionCardEntry>> _fetchAllCardsForCollection(
    int collectionId,
  ) async {
    final all = <CollectionCardEntry>[];
    var offset = 0;
    while (true) {
      final page = await ScryfallDatabase.instance.fetchCollectionCards(
        collectionId,
        limit: _deckImportBatchSize,
        offset: offset,
      );
      if (page.isEmpty) {
        break;
      }
      all.addAll(page);
      if (page.length < _deckImportBatchSize) {
        break;
      }
      offset += page.length;
    }
    return all;
  }

  Future<void> _exportDeckCollection(
    CollectionInfo collection, {
    required bool arenaFormat,
  }) async {
    try {
      final cards = await _fetchAllCardsForCollection(collection.id);
      final sideboardCollectionId = await ScryfallDatabase.instance
          .ensureDeckSideboardCollectionId(collection.id);
      final sideboardCards = await _fetchAllCardsForCollection(
        sideboardCollectionId,
      );
      final buffer = StringBuffer();
      for (final entry in cards) {
        if (entry.quantity <= 0) {
          continue;
        }
        if (arenaFormat) {
          buffer.writeln(
            '${entry.quantity} ${entry.name} (${entry.setCode.toUpperCase()}) ${entry.collectorNumber}',
          );
        } else {
          buffer.writeln('${entry.quantity} ${entry.name}');
        }
      }
      if (sideboardCards.any((entry) => entry.quantity > 0)) {
        buffer.writeln();
        if (!arenaFormat) {
          buffer.writeln('Sideboard');
        }
        for (final entry in sideboardCards) {
          if (entry.quantity <= 0) {
            continue;
          }
          if (arenaFormat) {
            buffer.writeln(
              '${entry.quantity} ${entry.name} (${entry.setCode.toUpperCase()}) ${entry.collectorNumber}',
            );
          } else {
            buffer.writeln('${entry.quantity} ${entry.name}');
          }
        }
      }
      final docs = await getApplicationDocumentsDirectory();
      final exportDir = Directory(path.join(docs.path, 'deck_exports'));
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }
      final ext = arenaFormat ? 'arena' : 'mtgo';
      final safeName = collection.name
          .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final stamp = DateTime.now()
          .toLocal()
          .toIso8601String()
          .replaceAll(RegExp(r'[:\-]'), '')
          .replaceAll('.', '');
      final fileName =
          '${safeName.isEmpty ? 'deck' : safeName}_${ext}_$stamp.txt';
      final file = File(path.join(exportDir.path, fileName));
      await file.writeAsString(buffer.toString(), flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: fileName),
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, _deckExportedSummaryLabel(fileName));
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, _deckExportFailedLabel(error));
    }
  }

  Future<void> _importDeckFileIntoCollection(CollectionInfo collection) async {
    final picked = await _pickDeckImportSource();
    if (picked == null) {
      return;
    }
    await _runDeckImportWithFeedback(
      collectionId: collection.id,
      text: picked.content,
    );
    if (!mounted) {
      return;
    }
    await _loadCollections();
  }

  Future<void> _showHomeAddOptions(BuildContext context) async {
    switch (_activeCollectionsMenu) {
      case _HomeCollectionsMenu.set:
        return _addSetCollection(context);
      case _HomeCollectionsMenu.custom:
        return _addCustomCollection(context);
      case _HomeCollectionsMenu.smart:
        return _addSmartCollection(context);
      case _HomeCollectionsMenu.deck:
        return _addDeckCollection(context);
      case _HomeCollectionsMenu.wish:
        return _addWishlistCollection(context);
      case _HomeCollectionsMenu.home:
        break;
    }

    final canCreateSet = _canCreateSetCollection();
    final canCreateCustom = _canCreateCustomCollection();
    final canCreateSmart = _canCreateSmartCollection();
    final canCreateWishlist = _canCreateWishlist();
    final canCreateDeck = _canCreateDeckCollection();
    final addContext = switch (_activeCollectionsMenu) {
      _HomeCollectionsMenu.home => _HomeAddContext.home,
      _HomeCollectionsMenu.set => _HomeAddContext.set,
      _HomeCollectionsMenu.custom => _HomeAddContext.custom,
      _HomeCollectionsMenu.smart => _HomeAddContext.smart,
      _HomeCollectionsMenu.deck => _HomeAddContext.deck,
      _HomeCollectionsMenu.wish => _HomeAddContext.wishlist,
    };
    final selection = await showModalBottomSheet<_HomeAddAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HomeAddSheet(
        addContext: addContext,
        canCreateSet: canCreateSet,
        canCreateCustom: canCreateCustom,
        canCreateSmart: canCreateSmart,
        canCreateDeck: canCreateDeck,
        canCreateWishlist: canCreateWishlist,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (selection == _HomeAddAction.addByScan) {
      await _onScanCardPressed();
    } else if (selection == _HomeAddAction.addCards) {
      await _openAddCardsForAllCards(context);
    } else if (selection == _HomeAddAction.addSetCollection) {
      setState(() {
        _activeCollectionsMenu = _HomeCollectionsMenu.set;
      });
      await _addSetCollection(context);
    } else if (selection == _HomeAddAction.addCustomCollection) {
      setState(() {
        _activeCollectionsMenu = _HomeCollectionsMenu.custom;
      });
      await _addCustomCollection(context);
    } else if (selection == _HomeAddAction.addSmartCollection) {
      setState(() {
        _activeCollectionsMenu = _HomeCollectionsMenu.smart;
      });
      await _addSmartCollection(context);
    } else if (selection == _HomeAddAction.addDeck) {
      setState(() {
        _activeCollectionsMenu = _HomeCollectionsMenu.deck;
      });
      await _addDeckCollection(context);
    } else if (selection == _HomeAddAction.addWishlist) {
      setState(() {
        _activeCollectionsMenu = _HomeCollectionsMenu.wish;
      });
      await _addWishlistCollection(context);
    }
  }

  Future<void> _onSearchCardPressed() async {
    CollectionInfo? allCards = _findAllCardsCollection();
    if (allCards == null) {
      final allCardsId = await ScryfallDatabase.instance
          .ensureAllCardsCollectionId();
      allCards = CollectionInfo(
        id: allCardsId,
        name: _allCardsCollectionName,
        cardCount: _totalCardCount,
        type: CollectionType.all,
        filter: null,
      );
      await _loadCollections();
      if (!mounted) {
        return;
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardSearchSheet(
        selectionEnabled: false,
        ownershipCollectionId: allCards!.id,
        showFilterButton: false,
      ),
    );
  }

  Future<void> _onScanCardPressed() async {
    var keepScanning = true;
    while (mounted && keepScanning) {
      final canStart = await _canStartScanSession();
      if (!canStart) {
        return;
      }
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      final recognizedText = await navigator.push<String>(
        PageRouteBuilder<String>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const _CardScannerPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      if (!mounted || recognizedText == null) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final hideProgress = _showScanProgressOverlay(
        l10n.nameRecognizedOpeningSearchStatus,
      );
      await _yieldToUi();
      try {
        final consumed = await _consumeFreeScanIfNeeded();
        if (!consumed || !mounted) {
          return;
        }
        final setCodes = await _fetchKnownSetCodes();
        if (!mounted) {
          return;
        }
        final ocrSeed = _buildOcrSearchSeed(
          recognizedText,
          knownSetCodes: setCodes,
        );
        if (ocrSeed == null) {
          showAppSnackBar(
            context,
            'No card text recognized. Try better light and focus.',
          );
          return;
        }
        final refinedSeed = await _refineOcrSeed(ocrSeed);
        if (!mounted) {
          return;
        }
        var progressHidden = false;
        Future<void> hideProgressBeforeUi() async {
          if (progressHidden) {
            return;
          }
          progressHidden = true;
          hideProgress();
          await _yieldToUi();
        }

        final resolved = await _resolveSeedWithPrintingPicker(
          refinedSeed,
          onBeforePresentingUi: hideProgressBeforeUi,
        );
        if (!mounted) {
          return;
        }
        if (resolved.pickedCard != null) {
          final action = await _showScannedCardPreview(resolved.pickedCard!);
          if (!mounted) {
            return;
          }
          if (action == _ScanPreviewAction.retry) {
            continue;
          }
          if (action != _ScanPreviewAction.add) {
            return;
          }
          final added = await _addCardToAllCards(
            resolved.pickedCard!.id,
            printingId: resolved.pickedCard!.printingId,
            foil: resolved.seed.isFoil,
          );
          if (!mounted || !added) {
            return;
          }
          keepScanning = true;
          continue;
        }
        final searchOutcome = await _openScannedCardSearch(
          query: resolved.seed.query,
          initialSetCode: resolved.seed.setCode,
          initialCollectorNumber: resolved.seed.collectorNumber,
          foil: resolved.seed.isFoil,
          onSheetPresented: hideProgressBeforeUi,
        );
        if (!mounted) {
          return;
        }
        if (searchOutcome == _ScannedCardSearchOutcome.retryScan) {
          keepScanning = true;
          continue;
        }
        if (searchOutcome != _ScannedCardSearchOutcome.added) {
          return;
        }
        keepScanning = true;
      } finally {
        hideProgress();
      }
    }
  }

  Future<void> _yieldToUi() async {
    await WidgetsBinding.instance.endOfFrame;
  }

  VoidCallback _showScanProgressOverlay(String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    var removed = false;
    entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return IgnorePointer(
          ignoring: true,
          child: Stack(
            children: [
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    overlay.insert(entry);
    return () {
      if (removed) {
        return;
      }
      removed = true;
      entry.remove();
    };
  }

  Future<bool> _canStartScanSession() async {
    if (_hasProAccess) {
      return true;
    }
    final remaining = await AppSettings.remainingFreeDailyScans(
      limit: _freeDailyScanLimit,
    );
    if (remaining > 0) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    await _showFreeScanLimitDialog();
    return false;
  }

  Future<bool> _consumeFreeScanIfNeeded() async {
    if (_hasProAccess) {
      return true;
    }
    final consumed = await AppSettings.consumeFreeDailyScan(
      limit: _freeDailyScanLimit,
    );
    if (consumed) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    await _showFreeScanLimitDialog();
    return false;
  }

  Future<_ResolvedScanSelection> _resolveSeedWithPrintingPicker(
    _OcrSearchSeed seed, {
    Future<void> Function()? onBeforePresentingUi,
  }) async {
    final cardName = seed.cardName?.trim();
    if (cardName == null || cardName.isEmpty) {
      return _ResolvedScanSelection(seed: seed);
    }
    if (TcgEnvironmentController.instance.currentGame == TcgGame.pokemon) {
      final resolution = await PokemonScannerResolver.resolve(
        seed: ScannerOcrSeed(
          query: seed.query,
          cardName: seed.cardName,
          setCode: seed.setCode,
          collectorNumber: seed.collectorNumber,
          scannerLanguageCode: seed.scannerLanguageCode,
          isFoil: seed.isFoil,
        ),
        searchRepository: appRepositories.search,
      );
      if (!mounted || resolution.candidates.isEmpty) {
        return _ResolvedScanSelection(seed: seed);
      }
      if (onBeforePresentingUi != null) {
        await onBeforePresentingUi();
      }
      if (!mounted) {
        return _ResolvedScanSelection(seed: seed);
      }
      final picked = await _pickCardPrintingForName(
        context,
        cardName,
        languages:
            PokemonScannerResolver.normalizeScannerLanguageCode(
                  seed.scannerLanguageCode,
                ) ==
                null
            ? const <String>['en']
            : <String>[
                PokemonScannerResolver.normalizeScannerLanguageCode(
                  seed.scannerLanguageCode,
                )!,
                'en',
              ],
        preferredSetCode: seed.setCode,
        preferredCollectorNumber: seed.collectorNumber,
        candidatesOverride: resolution.candidates,
      );
      if (picked == null) {
        return _ResolvedScanSelection(
          seed: _OcrSearchSeed(
            query: cardName,
            cardName: cardName,
            setCode: seed.setCode,
            collectorNumber: seed.collectorNumber,
            scannerLanguageCode: seed.scannerLanguageCode,
            isFoil: seed.isFoil,
          ),
        );
      }
      return _ResolvedScanSelection(
        seed: _OcrSearchSeed(
          query: picked.name,
          cardName: picked.name,
          setCode: picked.setCode.trim().isEmpty
              ? null
              : picked.setCode.trim().toLowerCase(),
          collectorNumber: picked.collectorNumber.trim().isEmpty
              ? null
              : picked.collectorNumber.trim().toLowerCase(),
          scannerLanguageCode: seed.scannerLanguageCode,
          isFoil: seed.isFoil,
        ),
        pickedCard: picked,
      );
    }
    final activeLanguages = await AppSettings.loadCardLanguagesForGame(
      _activeSettingsGame,
    );
    final effectiveScanLanguages =
        (PokemonScannerResolver.normalizeScannerLanguageCode(
              seed.scannerLanguageCode,
            ) !=
            null)
        ? <String>[
            PokemonScannerResolver.normalizeScannerLanguageCode(
              seed.scannerLanguageCode,
            )!,
          ]
        : activeLanguages;
    final fallbackScanLanguages = _scannerOnlineFallbackLanguages(
      effectiveScanLanguages,
      scannerLanguageCode: seed.scannerLanguageCode,
    );
    final localBeforeSync = await ScryfallDatabase.instance
        .fetchCardsForAdvancedFilters(
          CollectionFilter(name: cardName),
          languages: fallbackScanLanguages,
          limit: 250,
        );
    final normalizedName = _normalizeCardNameForMatch(cardName);
    final localBeforeSyncKeys = localBeforeSync
        .where(
          (card) => _normalizeCardNameForMatch(card.name) == normalizedName,
        )
        .map(_printingKeyForCard)
        .toSet();
    if (localBeforeSyncKeys.isEmpty) {
      unawaited(
        _syncOnlinePrintsByName(
          cardName,
          timeBudget: const Duration(seconds: 2),
          preferredLanguages: fallbackScanLanguages,
        ),
      );
      return _ResolvedScanSelection(
        seed: _OcrSearchSeed(
          query: cardName,
          cardName: cardName,
          setCode: seed.setCode,
          collectorNumber: seed.collectorNumber,
          scannerLanguageCode: seed.scannerLanguageCode,
          isFoil: seed.isFoil,
        ),
      );
    }
    // Keep scan flow snappy: avoid long blocking sync for cards with many printings.
    if (localBeforeSyncKeys.length < 4) {
      await _syncOnlinePrintsByName(
        cardName,
        timeBudget: const Duration(seconds: 2),
        preferredLanguages: fallbackScanLanguages,
      );
    }
    if (!mounted) {
      return _ResolvedScanSelection(seed: seed);
    }
    if (onBeforePresentingUi != null) {
      await onBeforePresentingUi();
    }
    if (!mounted) {
      return _ResolvedScanSelection(seed: seed);
    }
    var picked = await _pickCardPrintingForName(
      context,
      cardName,
      languages: fallbackScanLanguages,
      preferredSetCode: seed.setCode,
      preferredCollectorNumber: seed.collectorNumber,
      localPrintingKeys: localBeforeSyncKeys,
    );
    if (picked == null) {
      await _syncOnlinePrintsByName(
        cardName,
        timeBudget: const Duration(seconds: 3),
        preferredLanguages: fallbackScanLanguages,
      );
      if (mounted) {
        if (onBeforePresentingUi != null) {
          await onBeforePresentingUi();
        }
        if (!mounted) {
          return _ResolvedScanSelection(seed: seed);
        }
        picked = await _pickCardPrintingForName(
          context,
          cardName,
          languages: fallbackScanLanguages,
          preferredSetCode: seed.setCode,
          preferredCollectorNumber: seed.collectorNumber,
          localPrintingKeys: localBeforeSyncKeys,
        );
      }
    }
    final preferredSet = seed.setCode?.trim().toLowerCase();
    final missingPreferredSet =
        picked == null && preferredSet != null && preferredSet.isNotEmpty;
    if (missingPreferredSet) {
      final onlineByNameAndSet = await _tryOnlineCardFallbackByNameAndSet(
        cardName,
        preferredSet,
        preferredCollectorNumber: seed.collectorNumber,
      );
      if (onlineByNameAndSet != null && mounted) {
        if (onBeforePresentingUi != null) {
          await onBeforePresentingUi();
        }
        if (!mounted) {
          return _ResolvedScanSelection(seed: seed);
        }
        picked = await _pickCardPrintingForName(
          context,
          cardName,
          languages: fallbackScanLanguages,
          preferredSetCode: onlineByNameAndSet.setCode,
          preferredCollectorNumber: onlineByNameAndSet.collectorNumber,
          localPrintingKeys: localBeforeSyncKeys,
        );
      }
    }
    if (picked == null) {
      return _ResolvedScanSelection(
        seed: _OcrSearchSeed(
          query: cardName,
          cardName: cardName,
          setCode: seed.setCode,
          collectorNumber: seed.collectorNumber,
          scannerLanguageCode: seed.scannerLanguageCode,
          isFoil: seed.isFoil,
        ),
      );
    }
    return _ResolvedScanSelection(
      seed: _OcrSearchSeed(
        query: picked.name,
        cardName: picked.name,
        setCode: picked.setCode.trim().isEmpty
            ? null
            : picked.setCode.trim().toLowerCase(),
        collectorNumber: picked.collectorNumber.trim().isEmpty
            ? null
            : picked.collectorNumber.trim().toLowerCase(),
        scannerLanguageCode: seed.scannerLanguageCode,
        isFoil: seed.isFoil,
      ),
      pickedCard: picked,
    );
  }

  Future<_ScanPreviewAction?> _showScannedCardPreview(CardSearchResult card) {
    return showModalBottomSheet<_ScanPreviewAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final maxHeight = MediaQuery.of(context).size.height * 0.88;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  card.subtitleLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFBFAE95),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight * 0.62),
                  child: AspectRatio(
                    aspectRatio: 63.5 / 88.9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child:
                          _normalizeCardImageUrlForDisplay(
                            card.imageUri,
                          ).trim().isNotEmpty
                          ? Image.network(
                              _normalizeCardImageUrlForDisplay(card.imageUri),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0x221C1713),
                                alignment: Alignment.center,
                                child: _buildSetIcon(card.setCode, size: 54),
                              ),
                            )
                          : Container(
                              color: const Color(0x221C1713),
                              alignment: Alignment.center,
                              child: _buildSetIcon(card.setCode, size: 54),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(_ScanPreviewAction.retry),
                        icon: const Icon(Icons.replay),
                        label: Text(l10n.retry),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(_ScanPreviewAction.add),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _addCardToAllCards(
    String cardId, {
    String? printingId,
    bool foil = false,
  }) async {
    CollectionInfo? allCards = _findAllCardsCollection();
    if (allCards == null) {
      final allCardsId = await ScryfallDatabase.instance
          .ensureAllCardsCollectionId();
      allCards = CollectionInfo(
        id: allCardsId,
        name: _allCardsCollectionName,
        cardCount: _totalCardCount,
        type: CollectionType.all,
        filter: null,
      );
      await _loadCollections();
      if (!mounted) {
        return false;
      }
    }
    await InventoryService.instance.addToInventory(
      cardId,
      printingId: printingId,
      deltaQty: 1,
    );
    if (foil) {
      await ScryfallDatabase.instance.updateCollectionCard(
        allCards.id,
        cardId,
        printingId: printingId,
        foil: true,
      );
    }
    if (!mounted) {
      return false;
    }
    showAppSnackBar(context, AppLocalizations.of(context)!.addedCards(1));
    await _loadCollections();
    return true;
  }

  Future<Set<String>> _fetchKnownSetCodes() async {
    final sets = await appRepositories.sets.fetchAvailableSets();
    return sets
        .map((set) => set.code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  _OcrSearchSeed? _buildOcrSearchSeed(
    String rawText, {
    required Set<String> knownSetCodes,
  }) {
    if (TcgEnvironmentController.instance.currentGame == TcgGame.pokemon) {
      final parsed = PokemonScannerResolver.parseSeed(
        rawText,
        knownSetCodes: knownSetCodes,
      );
      if (parsed == null) {
        return null;
      }
      return _OcrSearchSeed(
        query: parsed.query,
        cardName: parsed.cardName,
        setCode: parsed.setCode,
        collectorNumber: parsed.collectorNumber,
        scannerLanguageCode: parsed.scannerLanguageCode,
        isFoil: parsed.isFoil,
      );
    }
    var text = rawText.trim();
    String? forcedName;
    String? forcedSet;
    String? selectedSetCode;
    String? selectedLanguageCode;
    var isFoil = false;
    if (text.startsWith('__SCAN_PAYLOAD__')) {
      final payloadText = text.substring('__SCAN_PAYLOAD__'.length).trim();
      try {
        final payload = jsonDecode(payloadText);
        if (payload is Map<String, dynamic>) {
          final raw = (payload['raw'] as String?)?.trim();
          final lockedName = (payload['lockedName'] as String?)?.trim();
          final lockedSet = (payload['lockedSet'] as String?)?.trim();
          if (raw != null && raw.isNotEmpty) {
            text = raw;
          }
          if (lockedName != null && lockedName.isNotEmpty) {
            forcedName = lockedName;
          }
          if (lockedSet != null && lockedSet.isNotEmpty) {
            forcedSet = lockedSet;
          }
          final payloadSet = (payload['selectedSetCode'] as String?)?.trim();
          if (payloadSet != null && payloadSet.isNotEmpty) {
            selectedSetCode = payloadSet;
          }
          final payloadLanguage =
              PokemonScannerResolver.normalizeScannerLanguageCode(
                payload['selectedLanguageCode'],
              );
          if (payloadLanguage != null && payloadLanguage.isNotEmpty) {
            selectedLanguageCode = payloadLanguage;
          }
          final payloadFoil = payload['foil'];
          if (payloadFoil is bool) {
            isFoil = payloadFoil;
          }
        }
      } catch (_) {
        // Fallback to plain raw text if payload parsing fails.
      }
    }
    if (text.isEmpty) {
      return null;
    }

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return null;
    }

    final topLines = lines.take(3).toList();
    final bottomStart = lines.length > 5 ? lines.length - 5 : 0;
    final bottomLines = lines.sublist(bottomStart);
    final bestName = (forcedName != null && forcedName.isNotEmpty)
        ? forcedName
        : _extractLikelyCardName(topLines);

    String? setCode;
    String? collectorNumber;
    if (forcedSet != null && forcedSet.isNotEmpty) {
      final forced = _extractSetAndCollectorFromLockedSet(
        forcedSet,
        knownSetCodes: knownSetCodes,
      );
      setCode = forced.$1;
      collectorNumber = forced.$2;
    }
    final setAndCollector = _extractSetAndCollectorFromText(
      bottomLines,
      knownSetCodes: knownSetCodes,
    );
    setCode = setAndCollector.$1 ?? setCode;
    collectorNumber = _pickBetterCollectorNumber(
      collectorNumber,
      setAndCollector.$2,
    );

    for (final rawLine in bottomLines.reversed) {
      if (setCode != null && collectorNumber != null) {
        break;
      }
      final upperLine = rawLine.toUpperCase();
      final tokens = upperLine
          .split(RegExp(r'[^A-Z0-9/]'))
          .where((token) => token.isNotEmpty)
          .toList();
      if (tokens.isEmpty) {
        continue;
      }

      for (var i = 0; i < tokens.length; i++) {
        final token = tokens[i];
        if (setCode == null) {
          final detectedSet = _detectSetCodeFromToken(
            token,
            knownSetCodes: knownSetCodes,
          );
          if (detectedSet != null) {
            setCode = detectedSet;
          }
        }
        if (setCode != null) {
          final next = (i + 1 < tokens.length) ? tokens[i + 1] : null;
          final fromNext = _normalizeCollectorNumber(next ?? '');
          collectorNumber = _pickBetterCollectorNumber(
            collectorNumber,
            fromNext,
          );
        }

        if (token.contains('/')) {
          final part = token.split('/').first;
          final normalized = _normalizeCollectorNumber(part);
          collectorNumber = _pickBetterCollectorNumber(
            collectorNumber,
            normalized,
          );
        }

        collectorNumber = _pickBetterCollectorNumber(
          collectorNumber,
          _normalizeCollectorNumber(token),
        );
      }
    }

    if (selectedSetCode != null) {
      final normalizedSelected = selectedSetCode.trim().toLowerCase();
      if (normalizedSelected.isNotEmpty) {
        if (knownSetCodes.isEmpty ||
            knownSetCodes.contains(normalizedSelected)) {
          setCode = normalizedSelected;
        }
      }
    }

    if (bestName.isEmpty && setCode == null && collectorNumber == null) {
      return null;
    }

    final fallbackQuery = bestName.isEmpty ? lines.first : bestName;
    final useCollectorQuery =
        collectorNumber != null &&
        collectorNumber.isNotEmpty &&
        setCode != null &&
        setCode.isNotEmpty &&
        !_isWeakCollectorNumber(collectorNumber);
    final query = useCollectorQuery ? collectorNumber : fallbackQuery;
    return _OcrSearchSeed(
      query: query,
      cardName: bestName.isEmpty ? null : bestName,
      setCode: setCode,
      collectorNumber: collectorNumber,
      scannerLanguageCode: selectedLanguageCode,
      isFoil: isFoil,
    );
  }

  Future<_OcrSearchSeed> _refineOcrSeed(_OcrSearchSeed seed) async {
    if (TcgEnvironmentController.instance.currentGame == TcgGame.pokemon) {
      return seed;
    }
    final query = seed.query.trim();
    final setCode = seed.setCode?.trim().toLowerCase();
    final fallbackName = seed.cardName?.trim();
    if (query.isEmpty) {
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final onlineByName = await _tryOnlineCardFallbackByName(
          fallbackName,
          isFoil: seed.isFoil,
        );
        if (onlineByName != null) {
          return onlineByName;
        }
      }
      return seed;
    }
    if (setCode == null || setCode.isEmpty) {
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final onlineByName = await _tryOnlineCardFallbackByName(
          fallbackName,
          isFoil: seed.isFoil,
        );
        if (onlineByName != null) {
          return onlineByName;
        }
      }
      return seed;
    }
    if (fallbackName != null && fallbackName.isNotEmpty) {
      final onlineByNameAndSet = await _tryOnlineCardFallbackByNameAndSet(
        fallbackName,
        setCode,
        preferredCollectorNumber: seed.collectorNumber,
        isFoil: seed.isFoil,
      );
      if (onlineByNameAndSet != null) {
        return onlineByNameAndSet;
      }
    }
    final strictCount = await ScryfallDatabase.instance
        .countCardsForFilterWithSearch(
          CollectionFilter(
            sets: {setCode},
            languages:
                PokemonScannerResolver.normalizeScannerLanguageCode(
                      seed.scannerLanguageCode,
                    ) ==
                    null
                ? const <String>{}
                : <String>{
                    PokemonScannerResolver.normalizeScannerLanguageCode(
                      seed.scannerLanguageCode,
                    )!,
                  },
          ),
          searchQuery: query,
        );
    if (strictCount > 0) {
      // Guard against false positives when collector OCR is wrong but exists in same set.
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final nameInSetCount = await ScryfallDatabase.instance
            .countCardsForFilterWithSearch(
              CollectionFilter(
                sets: {setCode},
                languages:
                    PokemonScannerResolver.normalizeScannerLanguageCode(
                          seed.scannerLanguageCode,
                        ) ==
                        null
                    ? const <String>{}
                    : <String>{
                        PokemonScannerResolver.normalizeScannerLanguageCode(
                          seed.scannerLanguageCode,
                        )!,
                      },
              ),
              searchQuery: fallbackName,
            );
        if (nameInSetCount > 0) {
          return seed;
        }
      } else {
        return seed;
      }
    }
    final onlineSeed = await _tryOnlineCardFallback(seed);
    if (onlineSeed != null) {
      return onlineSeed;
    }
    if (fallbackName != null && fallbackName.isNotEmpty) {
      final onlineByName = await _tryOnlineCardFallbackByName(
        fallbackName,
        isFoil: seed.isFoil,
      );
      if (onlineByName != null) {
        return onlineByName;
      }
    }
    if (fallbackName != null && fallbackName.isNotEmpty) {
      final nameInSetCount = await ScryfallDatabase.instance
          .countCardsForFilterWithSearch(
            CollectionFilter(
              sets: {setCode},
              languages:
                  PokemonScannerResolver.normalizeScannerLanguageCode(
                        seed.scannerLanguageCode,
                      ) ==
                      null
                  ? const <String>{}
                  : <String>{
                      PokemonScannerResolver.normalizeScannerLanguageCode(
                        seed.scannerLanguageCode,
                      )!,
                    },
            ),
            searchQuery: fallbackName,
          );
      if (nameInSetCount > 0) {
        return _OcrSearchSeed(
          query: fallbackName,
          cardName: fallbackName,
          setCode: setCode,
          collectorNumber: seed.collectorNumber,
          scannerLanguageCode: seed.scannerLanguageCode,
          isFoil: seed.isFoil,
        );
      }
      return _OcrSearchSeed(
        query: fallbackName,
        cardName: fallbackName,
        setCode: null,
        collectorNumber: seed.collectorNumber,
        scannerLanguageCode: seed.scannerLanguageCode,
        isFoil: seed.isFoil,
      );
    }
    return _OcrSearchSeed(
      query: query,
      cardName: seed.cardName,
      setCode: null,
      collectorNumber: seed.collectorNumber,
      scannerLanguageCode: seed.scannerLanguageCode,
      isFoil: seed.isFoil,
    );
  }

  Future<_OcrSearchSeed?> _tryOnlineCardFallbackByName(
    String cardName, {
    bool isFoil = false,
  }) async {
    final name = cardName.trim();
    if (name.isEmpty) {
      return null;
    }
    Future<_OcrSearchSeed?> fetchNamed(String mode) async {
      try {
        final uri = Uri.parse(
          'https://api.scryfall.com/cards/named?$mode=${Uri.encodeQueryComponent(name)}',
        );
        final response = await ScryfallApiClient.instance.get(
          uri,
          timeout: const Duration(seconds: 4),
          maxRetries: 2,
        );
        if (response.statusCode != 200) {
          return null;
        }
        final payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic>) {
          return null;
        }
        await ScryfallDatabase.instance.upsertCardFromScryfall(payload);
        final fetchedName = (payload['name'] as String?)?.trim();
        final fetchedSet = (payload['set'] as String?)?.trim().toLowerCase();
        final fetchedCollector = (payload['collector_number'] as String?)
            ?.trim()
            .toLowerCase();
        return _OcrSearchSeed(
          query: (fetchedName != null && fetchedName.isNotEmpty)
              ? fetchedName
              : name,
          cardName: fetchedName ?? name,
          setCode: fetchedSet?.isNotEmpty == true ? fetchedSet : null,
          collectorNumber: fetchedCollector?.isNotEmpty == true
              ? fetchedCollector
              : null,
          isFoil: isFoil,
        );
      } catch (_) {
        return null;
      }
    }

    final exactSeed = await fetchNamed('exact');
    if (exactSeed != null) {
      return exactSeed;
    }
    return fetchNamed('fuzzy');
  }

  List<String> _scannerOnlineFallbackLanguages(
    List<String> baseLanguages, {
    String? scannerLanguageCode,
  }) {
    final normalized = <String>{};
    for (final value in baseLanguages) {
      final language = value.trim().toLowerCase();
      if (language.isNotEmpty) {
        normalized.add(language);
      }
    }
    final scanner = PokemonScannerResolver.normalizeScannerLanguageCode(
      scannerLanguageCode,
    );
    if (scanner != null && scanner.isNotEmpty) {
      normalized.add(scanner);
    }
    normalized.add('en');
    normalized.add('it');
    return normalized.toList(growable: false);
  }

  Future<void> _syncOnlinePrintsByName(
    String cardName, {
    Duration timeBudget = const Duration(seconds: 2),
    List<String>? preferredLanguages,
  }) async {
    final name = cardName.trim();
    if (name.isEmpty) {
      return;
    }
    final deadline = DateTime.now().add(timeBudget);
    try {
      final namedUri = Uri.parse(
        'https://api.scryfall.com/cards/named?fuzzy=${Uri.encodeQueryComponent(name)}',
      );
      final namedResponse = await ScryfallApiClient.instance.get(
        namedUri,
        timeout: const Duration(seconds: 2),
        maxRetries: 2,
      );
      String? oracleId;
      if (namedResponse.statusCode == 200) {
        final namedPayload = jsonDecode(namedResponse.body);
        if (namedPayload is Map<String, dynamic>) {
          await ScryfallDatabase.instance.upsertCardFromScryfall(namedPayload);
          oracleId = (namedPayload['oracle_id'] as String?)
              ?.trim()
              .toLowerCase();
        }
      }
      final languageClause = _scryfallLanguageClauseForQuery(
        preferredLanguages ??
            await AppSettings.loadCardLanguagesForGame(_activeSettingsGame),
      );
      Uri searchUri;
      if (oracleId != null && oracleId.isNotEmpty) {
        searchUri = Uri.parse(
          'https://api.scryfall.com/cards/search?q=${Uri.encodeQueryComponent('oracleid:$oracleId $languageClause unique:prints')}&order=released&dir=desc',
        );
      } else {
        searchUri = Uri.parse(
          'https://api.scryfall.com/cards/search?q=${Uri.encodeQueryComponent('!"$name" $languageClause unique:prints')}&order=released&dir=desc',
        );
      }
      await _importScryfallSearchPages(
        searchUri,
        deadline: deadline,
        maxPages: 2,
        maxImported: 120,
      );
    } catch (_) {
      // Best effort: if network is slow/unavailable, keep local flow.
    }
  }

  Future<void> _importScryfallSearchPages(
    Uri firstPageUri, {
    required DateTime deadline,
    int maxPages = 2,
    int maxImported = 120,
  }) async {
    var nextUri = firstPageUri;
    var page = 0;
    var imported = 0;
    while (page < maxPages && imported < maxImported) {
      if (DateTime.now().isAfter(deadline)) {
        return;
      }
      final response = await ScryfallApiClient.instance.get(
        nextUri,
        timeout: const Duration(seconds: 2),
        maxRetries: 2,
      );
      if (response.statusCode != 200) {
        return;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return;
      }
      final data = payload['data'];
      if (data is List) {
        for (final item in data) {
          if (DateTime.now().isAfter(deadline)) {
            return;
          }
          if (item is! Map<String, dynamic>) {
            continue;
          }
          await ScryfallDatabase.instance.upsertCardFromScryfall(item);
          imported += 1;
          if (imported >= maxImported) {
            break;
          }
        }
      }
      final hasMore = payload['has_more'] == true;
      final nextPage = payload['next_page'];
      if (!hasMore || nextPage is! String || nextPage.isEmpty) {
        return;
      }
      nextUri = Uri.parse(nextPage);
      page += 1;
    }
  }

  Future<_OcrSearchSeed?> _tryOnlineCardFallbackByNameAndSet(
    String cardName,
    String setCode, {
    String? preferredCollectorNumber,
    bool isFoil = false,
  }) async {
    final name = cardName.trim();
    final set = setCode.trim().toLowerCase();
    if (name.isEmpty || set.isEmpty) {
      return null;
    }
    try {
      var canonicalName = name;
      final resolvedByName = await _tryOnlineCardFallbackByName(
        name,
        isFoil: isFoil,
      );
      final resolvedName = resolvedByName?.cardName?.trim();
      if (resolvedName != null && resolvedName.isNotEmpty) {
        canonicalName = resolvedName;
      }
      final languageClause = _scryfallLanguageClauseForQuery(
        await AppSettings.loadCardLanguagesForGame(_activeSettingsGame),
      );
      final query = '!"$canonicalName" set:$set $languageClause unique:prints';
      final uri = Uri.parse(
        'https://api.scryfall.com/cards/search?q=${Uri.encodeQueryComponent(query)}',
      );
      final response = await ScryfallApiClient.instance.get(
        uri,
        timeout: const Duration(seconds: 4),
        maxRetries: 2,
      );
      if (response.statusCode != 200) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final data = payload['data'];
      if (data is! List || data.isEmpty) {
        return null;
      }
      CardSearchResult? bestLocal;
      final preferredCollector = _normalizeCollectorForComparison(
        preferredCollectorNumber ?? '',
      );
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        await ScryfallDatabase.instance.upsertCardFromScryfall(item);
      }
      final localCandidates = await ScryfallDatabase.instance
          .fetchCardsForAdvancedFilters(
            CollectionFilter(name: canonicalName, sets: {set}),
            languages: await AppSettings.loadCardLanguagesForGame(
              _activeSettingsGame,
            ),
            limit: 100,
          );
      if (localCandidates.isNotEmpty) {
        if (preferredCollector.isNotEmpty) {
          for (final card in localCandidates) {
            if (_normalizeCollectorForComparison(card.collectorNumber) ==
                preferredCollector) {
              bestLocal = card;
              break;
            }
          }
        }
        bestLocal ??= localCandidates.first;
      }
      final selected = bestLocal;
      return _OcrSearchSeed(
        query: selected?.name ?? canonicalName,
        cardName: selected?.name ?? canonicalName,
        setCode: set,
        collectorNumber: selected != null
            ? _normalizeCollectorForComparison(selected.collectorNumber)
            : _normalizeCollectorForComparison(preferredCollectorNumber ?? ''),
        isFoil: isFoil,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_OcrSearchSeed?> _tryOnlineCardFallback(_OcrSearchSeed seed) async {
    final setCode = seed.setCode?.trim().toLowerCase();
    final collector = seed.collectorNumber?.trim().toLowerCase();
    if (setCode == null ||
        setCode.isEmpty ||
        collector == null ||
        collector.isEmpty ||
        _isWeakCollectorNumber(collector)) {
      return null;
    }
    try {
      final uri = Uri.parse(
        'https://api.scryfall.com/cards/$setCode/${Uri.encodeComponent(collector)}',
      );
      final response = await ScryfallApiClient.instance.get(
        uri,
        timeout: const Duration(seconds: 4),
        maxRetries: 2,
      );
      if (response.statusCode != 200) {
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      await ScryfallDatabase.instance.upsertCardFromScryfall(payload);
      final fetchedName = (payload['name'] as String?)?.trim();
      final fetchedSet = (payload['set'] as String?)?.trim().toLowerCase();
      final fetchedCollector = (payload['collector_number'] as String?)
          ?.trim()
          .toLowerCase();
      return _OcrSearchSeed(
        query: (fetchedName != null && fetchedName.isNotEmpty)
            ? fetchedName
            : seed.query,
        cardName: fetchedName ?? seed.cardName,
        setCode: fetchedSet?.isNotEmpty == true ? fetchedSet : setCode,
        collectorNumber: fetchedCollector?.isNotEmpty == true
            ? fetchedCollector
            : collector,
        isFoil: seed.isFoil,
      );
    } catch (_) {
      return null;
    }
  }

  String _extractLikelyCardName(List<String> lines) {
    const oracleLikeWords = {
      'deals',
      'damage',
      'demage',
      'target',
      'creature',
      'player',
      'draw',
      'discard',
      'counter',
      'mana',
      'until',
      'end',
      'turn',
      'you',
      'your',
    };
    var best = '';
    var bestScore = -1;
    for (var i = 0; i < lines.length && i < 8; i++) {
      final normalized = _trimToNameSegment(
        _normalizePotentialCardName(lines[i]),
      );
      if (normalized.length < 3) {
        continue;
      }
      final words = normalized.split(' ').where((w) => w.isNotEmpty).length;
      if (words > 7) {
        continue;
      }
      final hasLetters = RegExp(r'[A-Za-z]').hasMatch(normalized);
      if (!hasLetters) {
        continue;
      }
      final lower = normalized.toLowerCase();
      final wordsList = lower.split(' ').where((w) => w.isNotEmpty).toList();
      final oracleHits = wordsList
          .where((w) => oracleLikeWords.contains(w))
          .length;
      final digits = RegExp(r'\d').allMatches(normalized).length;
      if (digits > normalized.length * 0.25) {
        continue;
      }
      final digitPenalty = digits * 2;
      final oraclePenalty = oracleHits * 5;
      final longSentencePenalty = wordsList.length >= 6 ? 4 : 0;
      final topBonus = (8 - i);
      final score =
          (normalized.length.clamp(0, 30)) +
          topBonus -
          digitPenalty -
          oraclePenalty -
          longSentencePenalty;
      if (score > bestScore) {
        bestScore = score;
        best = normalized;
      }
    }
    return best;
  }

  String _trimToNameSegment(String value) {
    if (value.isEmpty) {
      return value;
    }
    const cutWords = {
      'deals',
      'damage',
      'demage',
      'target',
      'targets',
      'creature',
      'player',
      'draw',
      'discard',
      'counter',
      'mana',
      'until',
      'when',
      'whenever',
      'if',
      'then',
    };
    final words = value.split(' ').where((w) => w.isNotEmpty).toList();
    final keep = <String>[];
    for (final word in words) {
      final lower = word.toLowerCase();
      if (cutWords.contains(lower)) {
        break;
      }
      keep.add(word);
      if (keep.length >= 6) {
        break;
      }
    }
    final trimmed = keep.join(' ').trim();
    return trimmed.isEmpty ? value : trimmed;
  }

  (String?, String?) _extractSetAndCollectorFromText(
    List<String> lines, {
    required Set<String> knownSetCodes,
  }) {
    final setCollectorRegex = RegExp(
      r'\b([A-Z0-9]{2,5})\s+([0-9]{1,5}[A-Z]?)\b',
    );
    final collectorSlashRegex = RegExp(
      r'\b([0-9]{1,5}[A-Z]?)\s*/\s*[0-9]{1,5}\b',
    );
    String? setCode;
    String? collectorNumber;
    for (var i = lines.length - 1; i >= 0; i--) {
      final upper = lines[i].toUpperCase();
      final direct = setCollectorRegex.firstMatch(upper);
      if (direct != null) {
        setCode ??= _detectSetCodeFromToken(
          direct.group(1) ?? '',
          knownSetCodes: knownSetCodes,
        );
        collectorNumber ??= _normalizeCollectorNumber(direct.group(2) ?? '');
      }
      final slash = collectorSlashRegex.firstMatch(upper);
      if (slash != null) {
        collectorNumber ??= _normalizeCollectorNumber(slash.group(1) ?? '');
      }
      if (collectorNumber != null && setCode == null) {
        setCode = _findNearestSetCode(
          lines,
          anchorIndex: i,
          knownSetCodes: knownSetCodes,
        );
      }
      if (setCode != null && collectorNumber != null) {
        break;
      }
    }
    return (setCode, collectorNumber);
  }

  (String?, String?) _extractSetAndCollectorFromLockedSet(
    String value, {
    required Set<String> knownSetCodes,
  }) {
    final upper = value.trim().toUpperCase();
    if (upper.isEmpty) {
      return (null, null);
    }
    final direct = RegExp(
      r'^([A-Z0-9]{2,5})\s+([0-9]{1,5}[A-Z]?)$',
    ).firstMatch(upper);
    if (direct != null) {
      final rawSet = (direct.group(1) ?? '').trim().toLowerCase();
      final setCode =
          _detectSetCodeFromToken(rawSet, knownSetCodes: knownSetCodes) ??
          (RegExp(r'^[a-z]{2,5}$').hasMatch(rawSet) ? rawSet : null);
      final collector = _normalizeCollectorNumber(direct.group(2) ?? '');
      return (setCode, collector);
    }
    final collectorOnly = RegExp(r'^#?([0-9]{1,5}[A-Z]?)$').firstMatch(upper);
    if (collectorOnly != null) {
      final collector = _normalizeCollectorNumber(collectorOnly.group(1) ?? '');
      return (null, collector);
    }
    return (null, null);
  }

  String? _findNearestSetCode(
    List<String> lines, {
    required int anchorIndex,
    required Set<String> knownSetCodes,
  }) {
    for (var delta = 0; delta <= 2; delta++) {
      final candidates = <int>{anchorIndex - delta, anchorIndex + delta};
      for (final idx in candidates) {
        if (idx < 0 || idx >= lines.length) {
          continue;
        }
        final detected = _detectSetCodeInLine(
          lines[idx],
          knownSetCodes: knownSetCodes,
        );
        if (detected != null) {
          return detected;
        }
      }
    }
    return null;
  }

  String? _detectSetCodeInLine(
    String line, {
    required Set<String> knownSetCodes,
  }) {
    const rarityTokens = {'c', 'u', 'r', 'm', 'l'};
    final tokens = line
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    for (final token in tokens.reversed) {
      if (rarityTokens.contains(token)) {
        continue;
      }
      if (RegExp(r'^\d+$').hasMatch(token)) {
        continue;
      }
      final set = _detectSetCodeFromToken(token, knownSetCodes: knownSetCodes);
      if (set != null) {
        return set;
      }
    }
    return null;
  }

  String? _detectSetCodeFromToken(
    String token, {
    required Set<String> knownSetCodes,
  }) {
    final raw = token.trim().toLowerCase();
    if (raw.isEmpty) {
      return null;
    }
    final candidates = <String>{raw, _normalizeSetCodeCandidate(raw)};
    for (final candidate in candidates) {
      if (candidate.isNotEmpty && knownSetCodes.contains(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  String _normalizeSetCodeCandidate(String value) {
    return value
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('5', 's')
        .replaceAll('8', 'b');
  }

  String _normalizePotentialCardName(String input) {
    return input
        .replaceAll(RegExp(r"[^A-Za-z0-9'\-\s,]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _normalizeCollectorNumber(String input) {
    final value = input
        .trim()
        .toLowerCase()
        .replaceAll('#', '')
        .replaceAll('o', '0')
        .replaceAll('i', '1')
        .replaceAll('l', '1')
        .replaceAll('s', '5')
        .replaceAll(RegExp(r'[^a-z0-9/]'), '');
    if (value.isEmpty) {
      return null;
    }
    final match = RegExp(r'^(\d{1,5}[a-z]?)$').firstMatch(value);
    if (match == null) {
      return null;
    }
    final normalized = _normalizeCollectorForComparison(match.group(1) ?? '');
    return normalized.isEmpty ? null : normalized;
  }

  String? _pickBetterCollectorNumber(String? current, String? candidate) {
    if (candidate == null || candidate.isEmpty) {
      return current;
    }
    if (current == null || current.isEmpty) {
      return candidate;
    }
    final currentScore = _collectorConfidenceScore(current);
    final candidateScore = _collectorConfidenceScore(candidate);
    if (candidateScore > currentScore) {
      return candidate;
    }
    return current;
  }

  int _collectorConfidenceScore(String value) {
    final normalized = value.toLowerCase();
    final digitCount = RegExp(r'\d').allMatches(normalized).length;
    final hasSuffixLetter = RegExp(r'\d+[a-z]$').hasMatch(normalized);
    final isSingleDigit = RegExp(r'^\d$').hasMatch(normalized);
    var score = digitCount * 3;
    if (hasSuffixLetter) {
      score += 2;
    }
    if (isSingleDigit) {
      score -= 4;
    }
    return score;
  }

  bool _isWeakCollectorNumber(String value) {
    return RegExp(r'^\d$').hasMatch(value.trim());
  }

  Future<_ScannedCardSearchOutcome> _openScannedCardSearch({
    required String query,
    String? initialSetCode,
    String? initialCollectorNumber,
    bool foil = false,
    Future<void> Function()? onSheetPresented,
  }) async {
    final selection = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardSearchSheet(
        initialQuery: query,
        initialSetCode: initialSetCode,
        initialCollectorNumber: initialCollectorNumber,
        showRetryScanOnNoResults: true,
        onFirstFrameRendered: onSheetPresented,
      ),
    );
    if (!mounted) {
      return _ScannedCardSearchOutcome.cancelled;
    }
    if (selection == _CardSearchSheetDismissAction.retryScan) {
      return _ScannedCardSearchOutcome.retryScan;
    }
    if (selection is! _CardSearchSelection) {
      return _ScannedCardSearchOutcome.cancelled;
    }

    int? allCardsId;
    if (foil) {
      allCardsId =
          _findAllCardsCollection()?.id ??
          await ScryfallDatabase.instance.ensureAllCardsCollectionId();
    }

    if (selection.isBulk) {
      for (final card in selection.cards) {
        await InventoryService.instance.addToInventory(
          card.id,
          printingId: card.printingId,
          deltaQty: 1,
        );
        if (foil && allCardsId != null) {
          await ScryfallDatabase.instance.updateCollectionCard(
            allCardsId,
            card.id,
            printingId: card.printingId,
            foil: true,
          );
        }
      }
    } else {
      final selectedCard = selection.cards.first;
      await InventoryService.instance.addToInventory(
        selectedCard.id,
        printingId: selectedCard.printingId,
        deltaQty: 1,
      );
      if (foil && allCardsId != null) {
        await ScryfallDatabase.instance.updateCollectionCard(
          allCardsId,
          selectedCard.id,
          printingId: selectedCard.printingId,
          foil: true,
        );
      }
    }
    if (!mounted) {
      return _ScannedCardSearchOutcome.cancelled;
    }
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.addedCards(selection.count),
    );
    await _loadCollections();
    return _ScannedCardSearchOutcome.added;
  }

  Future<void> _openAddCardsForAllCards(BuildContext context) async {
    CollectionInfo? allCards = _findAllCardsCollection();
    if (allCards == null) {
      final allCardsId = await ScryfallDatabase.instance
          .ensureAllCardsCollectionId();
      allCards = CollectionInfo(
        id: allCardsId,
        name: _allCardsCollectionName,
        cardCount: _totalCardCount,
        type: CollectionType.all,
        filter: null,
      );
      await _loadCollections();
      if (!context.mounted) {
        return;
      }
    }
    final resolved = allCards;
    if (!mounted) {
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CollectionDetailPage(
              collectionId: resolved.id,
              name: _collectionDisplayName(resolved),
              isAllCards: true,
              autoOpenAddCard: true,
              filter: resolved.filter,
            ),
          ),
        )
        .then((_) => _loadCollections());
  }

  Future<void> _showCollectionActions(
    CollectionInfo collection,
    Offset globalPosition,
  ) async {
    if (collection.name == _allCardsCollectionName ||
        _isBasicLandsCollection(collection)) {
      return;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return;
    }
    final isSetCollection = _isSetCollection(collection);
    final isDeckCollection = collection.type == CollectionType.deck;
    final menuItems = <PopupMenuEntry<_CollectionAction>>[];
    if (!isSetCollection) {
      menuItems.add(
        PopupMenuItem(
          value: _CollectionAction.rename,
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.rename),
            ],
          ),
        ),
      );
    }
    if (isDeckCollection && _isMtgActiveGame) {
      menuItems.add(
        PopupMenuItem(
          value: _CollectionAction.importDeckFile,
          child: Row(
            children: [
              const Icon(Icons.upload_file, size: 18),
              const SizedBox(width: 8),
              Text(_deckImportMenuLabel()),
            ],
          ),
        ),
      );
      menuItems.add(
        PopupMenuItem(
          value: _CollectionAction.exportDeckArena,
          child: Row(
            children: [
              const Icon(Icons.download, size: 18),
              const SizedBox(width: 8),
              Text(_deckExportArenaLabel()),
            ],
          ),
        ),
      );
      menuItems.add(
        PopupMenuItem(
          value: _CollectionAction.exportDeckMtgo,
          child: Row(
            children: [
              const Icon(Icons.download_for_offline_outlined, size: 18),
              const SizedBox(width: 8),
              Text(_deckExportMtgoLabel()),
            ],
          ),
        ),
      );
    }
    menuItems.add(
      PopupMenuItem(
        value: _CollectionAction.delete,
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18),
            SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.delete),
          ],
        ),
      ),
    );
    final selection = await showMenu<_CollectionAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      ),
      items: menuItems,
    );

    if (selection == _CollectionAction.rename) {
      await _renameCollection(collection);
    } else if (selection == _CollectionAction.importDeckFile) {
      await _importDeckFileIntoCollection(collection);
    } else if (selection == _CollectionAction.exportDeckArena) {
      await _exportDeckCollection(collection, arenaFormat: true);
    } else if (selection == _CollectionAction.exportDeckMtgo) {
      await _exportDeckCollection(collection, arenaFormat: false);
    } else if (selection == _CollectionAction.delete) {
      await _deleteCollection(collection);
    }
  }

  Future<void> _renameCollection(CollectionInfo collection) async {
    if (_isSetCollection(collection)) {
      return;
    }
    final controller = TextEditingController(
      text: _collectionDisplayName(collection),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.renameCollectionTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.collectionNameHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop(value.isEmpty ? null : value);
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    if (name == null) {
      return;
    }

    final resolvedName = name;
    if (_normalizedCollectionName(resolvedName) ==
        _normalizedCollectionName(collection.name)) {
      return;
    }
    if (_isCollectionNameTaken(
      resolvedName,
      excludeCollectionId: collection.id,
    )) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.collectionAlreadyExists,
      );
      return;
    }
    await ScryfallDatabase.instance.renameCollection(
      collection.id,
      resolvedName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      final index = _collections.indexWhere((item) => item.id == collection.id);
      if (index != -1) {
        _collections[index] = CollectionInfo(
          id: collection.id,
          name: resolvedName,
          cardCount: collection.cardCount,
          type: collection.type,
          filter: collection.filter,
        );
      }
    });
  }

  Future<Set<String>?> _pickSetCollectionLanguages(BuildContext context) async {
    final single = await _pickSetCollectionLanguage(context);
    if (single == null || single.trim().isEmpty) {
      return null;
    }
    return {single.trim().toLowerCase()};
  }

  String _collectionLoadFailedLabel(Object error) {
    final raw = error.toString().toLowerCase();
    if (_isItalianUi()) {
      if (raw.contains('sqliteexception') || raw.contains('database')) {
        return 'Errore nel caricamento dei dati locali della collezione.';
      }
      return 'Errore nel caricamento della collezione.';
    }
    if (raw.contains('sqliteexception') || raw.contains('database')) {
      return 'Failed to load local collection data.';
    }
    return 'Failed to load collection.';
  }

  Future<String?> _pickSetCollectionLanguage(BuildContext context) async {
    final available = (await AppSettings.loadCardLanguagesForGame(
      _activeSettingsGame,
    )).toSet();
    if (available.isEmpty) {
      return 'en';
    }
    if (available.length == 1) {
      return available.first;
    }
    if (!context.mounted) {
      return null;
    }
    final l10n = AppLocalizations.of(context)!;
    final options = available.toList()..sort();
    var selected = options.contains('en') ? 'en' : options.first;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                _isItalianUi()
                    ? 'Lingua collezione set'
                    : 'Set collection language',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      selected = value;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: options
                        .map(
                          (code) => RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: code,
                            title: Text(_languageLabelForCode(l10n, code)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: Text(
                    _isItalianUi() ? 'Crea collezione' : 'Create collection',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _languageLabelForCode(AppLocalizations l10n, String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized == 'en') {
      return l10n.languageEnglish;
    }
    if (normalized == 'it') {
      return l10n.languageItalian;
    }
    return normalized.toUpperCase();
  }

  Future<void> _deleteCollection(CollectionInfo collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.deleteCollectionTitle),
          content: Text(
            l10n.deleteCollectionBody(_collectionDisplayName(collection)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ScryfallDatabase.instance.deleteCollection(collection.id);
    if (collection.type == CollectionType.deck) {
      await ScryfallDatabase.instance.deleteDeckSideboardCollection(
        collection.id,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _collections.removeWhere((item) => item.id == collection.id);
    });
    await _loadCollections();
    if (!mounted) {
      return;
    }
    showAppSnackBar(context, AppLocalizations.of(context)!.collectionDeleted);
  }

  Future<void> _downloadMtgHostedBundle(
    MtgHostedBundleCheckResult bundle, {
    bool restartAfterImport = false,
  }) async {
    const bulkType = 'all_cards';
    if (_selectedBulkType != bulkType) {
      await AppSettings.saveBulkTypeForGame(_activeSettingsGame, bulkType);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedBulkType = bulkType;
      });
    }
    setState(() {
      _bulkDownloading = true;
      _bulkDownloadProgress = 0;
      _bulkDownloadReceived = 0;
      _bulkDownloadTotal = bundle.sizeBytes;
      _bulkExpectedSizeBytes = bundle.sizeBytes;
      _bulkDownloadError = null;
      _mtgSyncStatus = _isItalianUi()
          ? 'Download database da Firebase...'
          : 'Downloading database from Firebase...';
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final targetPath = '${directory.path}/${_bulkTypeFileName(bulkType)}';
      final progressThrottle = Stopwatch()..start();
      const minProgressInterval = Duration(milliseconds: 120);
      await MtgHostedBundleService().downloadCombinedJson(
        bundle: bundle,
        targetPath: targetPath,
        onProgress: (received, total) {
          if (!mounted) {
            return;
          }
          final shouldReport =
              progressThrottle.elapsed >= minProgressInterval ||
              (total > 0 && received >= total);
          if (!shouldReport) {
            return;
          }
          progressThrottle.reset();
          setState(() {
            _bulkDownloadReceived = received;
            _bulkDownloadTotal = total;
            if (total > 0) {
              _bulkDownloadProgress = received / total;
            }
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkDownloadReceived = bundle.sizeBytes;
        _bulkDownloadTotal = bundle.sizeBytes;
        _bulkDownloadProgress = 1;
        _bulkDownloading = false;
        _mtgSyncStatus = _isItalianUi()
            ? 'Preparazione import locale...'
            : 'Preparing local import...';
      });
      await _importBulkFile(targetPath, restartAfterImport: restartAfterImport);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final message = _isStorageSpaceError(error)
          ? _storageSpaceErrorMessage(italian: _isItalianUi())
          : ((error is HttpException || error is SocketException)
                ? l10n.networkErrorTryAgain
                : l10n.downloadFailedGeneric);
      setState(() {
        _bulkDownloading = false;
        _bulkDownloadError = message;
        _mtgSyncStatus = null;
      });
      showAppSnackBar(context, message);
    }
  }

  Future<void> _downloadMtgCanonicalBundle(
    MtgCanonicalBundleCheckResult bundle, {
    bool restartAfterImport = false,
    bool rethrowOnError = false,
  }) async {
    setState(() {
      _bulkDownloading = true;
      _bulkImporting = false;
      _bulkDownloadProgress = 0;
      _bulkDownloadReceived = 0;
      _bulkDownloadTotal = bundle.sizeBytes;
      _bulkExpectedSizeBytes = bundle.sizeBytes;
      _bulkDownloadError = null;
      _bulkImportedCount = 0;
      _mtgSyncStatus = _isItalianUi()
          ? 'Download catalogo canonico da Firebase...'
          : 'Downloading canonical catalog from Firebase...';
    });

    final service = MtgCanonicalBundleService();
    try {
      if (kDebugMode) {
        debugPrint('mtg_canonical phase=start_download');
      }
      final batch = await service.downloadImportBatch(
        bundle: bundle,
        onStatus: (status) {
          if (kDebugMode) {
            debugPrint('mtg_canonical phase=$status');
          }
          if (!mounted) {
            return;
          }
          setState(() {
            _mtgSyncStatus = status;
          });
        },
        onProgress: (received, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _bulkDownloadReceived = received;
            _bulkDownloadTotal = total;
            if (total > 0) {
              _bulkDownloadProgress = received / total;
            }
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkDownloadReceived = bundle.sizeBytes;
        _bulkDownloadTotal = bundle.sizeBytes;
        _bulkDownloadProgress = 1;
        _bulkDownloading = false;
        _bulkImporting = true;
        _bulkImportedCount = 0;
        _mtgSyncStatus = _isItalianUi()
            ? 'Scrittura catalogo canonico locale...'
            : 'Writing local canonical catalog...';
      });
      if (kDebugMode) {
        debugPrint('mtg_canonical phase=install_batch');
      }
      await service.installBatch(batch);
      if (kDebugMode) {
        debugPrint('mtg_canonical phase=mark_installed');
      }
      await service.markInstalled(bundle.version);
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkImporting = false;
        _bulkImportProgress = 1;
        _bulkUpdateAvailable = false;
        _cardsMissing = false;
        _bulkImportedCount = batch.printings.length;
        _mtgSyncStatus = null;
      });
      await _loadCollections();
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        _isItalianUi()
            ? 'Catalogo canonico MTG aggiornato.'
            : 'MTG canonical catalog updated.',
      );
      if (restartAfterImport) {
        await _softRestartAfterDatabaseBootstrap();
      }
    } catch (error) {
      if (!mounted) {
        if (rethrowOnError) {
          rethrow;
        }
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final message = _isStorageSpaceError(error)
          ? _storageSpaceErrorMessage(italian: _isItalianUi())
          : ((error is HttpException || error is SocketException)
                ? l10n.networkErrorTryAgain
                : l10n.downloadFailedGeneric);
      setState(() {
        _bulkDownloading = false;
        _bulkImporting = false;
        _bulkDownloadError = message;
        _mtgSyncStatus = null;
      });
      showAppSnackBar(context, message);
      if (rethrowOnError) {
        rethrow;
      }
    } finally {
      service.dispose();
    }
  }

  Future<void> _downloadBulkFile(
    String downloadUri, {
    bool restartAfterImport = false,
  }) async {
    if (!_isAllowedBulkDownloadUri(downloadUri)) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkDownloadError = AppLocalizations.of(
          context,
        )!.downloadFailedGeneric;
      });
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.downloadFailedGeneric,
      );
      return;
    }
    final bulkType = _selectedBulkType;
    if (bulkType == null) {
      return;
    }
    setState(() {
      _bulkDownloading = true;
      _bulkDownloadProgress = 0;
      _bulkDownloadReceived = 0;
      _bulkDownloadTotal = 0;
      _bulkDownloadError = null;
      _mtgSyncStatus = _isItalianUi()
          ? 'Download database in corso...'
          : 'Downloading database...';
    });

    try {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(downloadUri));
        final response = await client.send(request);
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}');
        }

        final directory = await getApplicationDocumentsDirectory();
        final targetPath = '${directory.path}/${_bulkTypeFileName(bulkType)}';
        final tempPath = '$targetPath.download';
        final file = File(tempPath);
        final sink = file.openWrite();

        final totalBytes =
            _bulkExpectedSizeBytes ?? response.contentLength ?? 0;
        if (mounted) {
          setState(() {
            _bulkDownloadTotal = totalBytes;
          });
        }
        var received = 0;
        final progressThrottle = Stopwatch()..start();
        const minProgressInterval = Duration(milliseconds: 120);
        await for (final chunk in response.stream) {
          received += chunk.length;
          sink.add(chunk);
          final shouldReport =
              progressThrottle.elapsed >= minProgressInterval ||
              (totalBytes > 0 && received >= totalBytes);
          if (shouldReport && mounted) {
            progressThrottle.reset();
            setState(() {
              _bulkDownloadReceived = received;
              if (totalBytes > 0) {
                _bulkDownloadProgress = received / totalBytes;
              }
            });
          }
        }
        await sink.flush();
        await sink.close();
        if (totalBytes > 0 && received != totalBytes) {
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
          throw const HttpException('download_incomplete');
        }
        await file.rename(targetPath);

        if (!mounted) {
          return;
        }

        setState(() {
          _bulkDownloadReceived = received;
          if (totalBytes > 0) {
            _bulkDownloadProgress = received / totalBytes;
          }
          _bulkDownloading = false;
          _bulkDownloadProgress = 1;
          _mtgSyncStatus = _isItalianUi()
              ? 'Preparazione import locale...'
              : 'Preparing local import...';
        });
        await _importBulkFile(
          targetPath,
          restartAfterImport: restartAfterImport,
        );
      } finally {
        client.close();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      final message = _isStorageSpaceError(error)
          ? _storageSpaceErrorMessage(italian: _isItalianUi())
          : ((error is HttpException || error is SocketException)
                ? l10n.networkErrorTryAgain
                : l10n.downloadFailedGeneric);
      setState(() {
        _bulkDownloading = false;
        _bulkDownloadError = message;
        _mtgSyncStatus = null;
      });
      showAppSnackBar(context, message);
    }
  }

  Future<void> _importBulkFile(
    String filePath, {
    bool restartAfterImport = false,
  }) async {
    if (_bulkImporting) {
      return;
    }
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final allowedLanguages = (await AppSettings.loadCardLanguagesForGame(
      _activeSettingsGame,
    )).toSet();
    final normalizedBulkType = (_selectedBulkType ?? '').trim().toLowerCase();
    setState(() {
      _bulkImporting = true;
      _bulkImportProgress = 0;
      _bulkImportedCount = 0;
      _mtgSyncStatus = _isItalianUi()
          ? 'Analisi file locale in corso...'
          : 'Analyzing local file...';
    });

    try {
      final importer = ScryfallBulkImporter();
      final preflight = await importer.inspectLocalBulkLanguageCounts(
        filePath,
        maxCards: _mtgHostedBundleResult == null ? 120000 : 300000,
      );
      if (normalizedBulkType == 'all_cards' &&
          allowedLanguages.contains('it')) {
        final sampleIt = preflight.languageCounts['it'] ?? 0;
        if (preflight.sampledCards >= 5000 && sampleIt < 50) {
          throw const FormatException('bulk_local_missing_it');
        }
      }
      if (mounted) {
        setState(() {
          _mtgSyncStatus = _isItalianUi()
              ? 'Import carte in corso...'
              : 'Importing cards...';
        });
      }
      await importer.importAllCardsJson(
        filePath,
        updatedAtRaw: _bulkUpdatedAtRaw,
        bulkType: _selectedBulkType,
        allowedLanguages: allowedLanguages.toList()..sort(),
        onProgress: (count, progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _bulkImportedCount = count;
            _bulkImportProgress = progress;
            _mtgSyncStatus = _isItalianUi()
                ? 'Import carte: $count'
                : 'Importing cards: $count';
          });
        },
      );
      if (_selectedBulkType != null) {
        await _cleanupMtgBulkFilesKeepingType(_selectedBulkType!);
      }
      final hostedBundleVersion = _mtgHostedBundleResult?.version;
      if (hostedBundleVersion != null) {
        await MtgHostedBundleService().markInstalled(hostedBundleVersion);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _mtgSyncStatus = _isItalianUi()
            ? 'Ottimizzazione indice ricerca...'
            : 'Optimizing search index...';
      });
      await _rebuildSearchIndex();

      if (!mounted) {
        return;
      }
      setState(() {
        _mtgSyncStatus = _isItalianUi()
            ? 'Finalizzazione database...'
            : 'Finalizing database...';
      });
      final total = await ScryfallDatabase.instance.countOwnedCards();
      if (!mounted) {
        return;
      }

      setState(() {
        _bulkImporting = false;
        _bulkImportProgress = 1;
        _bulkUpdateAvailable = false;
        _cardsMissing = false;
        _totalCardCount = total;
        _mtgSyncStatus = null;
      });
      await _loadCollections();
      if (!mounted) {
        return;
      }
      if (restartAfterImport) {
        await _softRestartAfterDatabaseBootstrap();
      }
      await _maybeShowLatestReleaseNotesAfterDbImport();
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.importComplete)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkImporting = false;
        _mtgSyncStatus = null;
      });
      final msg = error.toString().contains('bulk_local_missing_it')
          ? (_isItalianUi()
                ? 'File locale non coerente: poche carte IT. Riscarica il bundle Firebase.'
                : 'Local file mismatch: too few IT cards. Download the Firebase bundle again.')
          : (_isStorageSpaceError(error)
                ? _storageSpaceErrorMessage(italian: _isItalianUi())
                : l10n.importFailed('import_failed'));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _maybeShowLatestReleaseNotesAfterDbImport() async {
    final lastSeen = await AppSettings.loadLastSeenReleaseNotesId();
    if (lastSeen == _latestReleaseNotesId) {
      return;
    }
    if (!mounted) {
      return;
    }
    await _showLatestReleaseNotesPanel(context);
  }

  Future<void> _rebuildSearchIndex() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.rebuildingSearchIndex),
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.requiredAfterLargeUpdates,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
    try {
      await ScryfallDatabase.instance.rebuildCardsFts();
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _softRestartAfterDatabaseBootstrap() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _initialCollectionsLoading = true;
    });
    await _loadCollections();
    if (!mounted) {
      return;
    }
    setState(() {
      _initialCollectionsLoading = false;
    });
  }

  Future<void> _openSettingsAndHandlePostAction() async {
    final postAction = await Navigator.of(context).push<SettingsPostAction>(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (!mounted) {
      return;
    }
    if (postAction == null) {
      await _initializeEnvironmentAndData();
      return;
    }
    await _applySettingsPostAction(postAction);
  }

  Future<void> _applySettingsPostAction(SettingsPostAction action) async {
    if (!_isGameUnlocked(action.game)) {
      await _initializeEnvironmentAndData();
      return;
    }
    await TcgEnvironmentController.instance.setGame(action.game);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedHomeGame = action.game;
      _initialCollectionsLoading = true;
      _collections.clear();
      if (action.game == TcgGame.mtg && action.mtgBulkType != null) {
        _selectedBulkType = action.mtgBulkType;
      }
    });
    await _loadCollections();
    if (!mounted) {
      return;
    }
    setState(() {
      _initialCollectionsLoading = false;
    });

    if (action.game == TcgGame.mtg) {
      final targetBulkType =
          action.mtgBulkType ??
          await AppSettings.loadBulkTypeForGame(AppTcgGame.mtg);
      if (targetBulkType == null || targetBulkType.trim().isEmpty) {
        await _initializeEnvironmentAndData();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedBulkType = targetBulkType;
        _bulkDownloadError = null;
        _cardsMissing = true;
      });
      await _checkScryfallBulk(forceDownload: true, restartAfterImport: true);
      return;
    }

    await _installPokemonDatasetWithFeedback();
    if (!mounted) {
      return;
    }
    await _loadCollections();
    unawaited(_refreshPokemonUpdateStatusInBackground());
  }

  Widget _buildGameSelector() {
    final canSwitchGame =
        _isGameUnlocked(TcgGame.mtg) && _isGameUnlocked(TcgGame.pokemon);
    final l10n = AppLocalizations.of(context)!;
    final gameInitial = _selectedHomeGame == TcgGame.mtg ? 'M' : 'P';
    return PopupMenuButton<TcgGame>(
      enabled: canSwitchGame,
      initialValue: _selectedHomeGame,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      tooltip: canSwitchGame
          ? l10n.chooseYourGameTitle
          : l10n.unlockOtherGameToSwitch,
      onSelected: (TcgGame selected) async {
        if (selected == _selectedHomeGame) {
          return;
        }
        final hasAccess = await _ensureGameAccessFresh(selected);
        if (!hasAccess) {
          if (!mounted) {
            return;
          }
          await _openSettingsAndHandlePostAction();
          return;
        }
        await TcgEnvironmentController.instance.setGame(selected);
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedHomeGame = selected;
          _initialCollectionsLoading = true;
          _collections.clear();
        });
        await _loadCollections();
        unawaited(_initializeForCurrentGame());
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: TcgGame.mtg,
          child: Row(
            children: [
              _GameMenuBadge(label: 'M'),
              SizedBox(width: 10),
              Text('Magic', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        PopupMenuItem(
          value: TcgGame.pokemon,
          child: Row(
            children: [
              _GameMenuBadge(label: 'P'),
              SizedBox(width: 10),
              Text('Pokemon', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF5D4731)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE9C46A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                gameInitial,
                style: const TextStyle(
                  color: Color(0xFF1C1510),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              canSwitchGame ? Icons.expand_more : Icons.lock_outline_rounded,
              size: 18,
              color: canSwitchGame ? null : const Color(0xFFBFAE95),
            ),
          ],
        ),
      ),
    );
  }

  String _scryfallLanguageClauseForQuery(List<String> languages) {
    final allowed = AppSettings.languageCodes
        .map((item) => item.toLowerCase())
        .toSet();
    final normalized =
        languages
            .map((item) => item.trim().toLowerCase())
            .where((item) => allowed.contains(item))
            .toSet()
            .toList()
          ..sort();
    if (normalized.isEmpty) {
      return 'lang:en';
    }
    if (normalized.length == 1) {
      return 'lang:${normalized.first}';
    }
    return '(${normalized.map((lang) => 'lang:$lang').join(' or ')})';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pokemonLocked =
        !_isMtgActiveGame && !_isGameUnlocked(TcgGame.pokemon);
    final isBlockingSync = _bulkDownloading || _bulkImporting;
    final pinnedAllCardsCard =
        _activeCollectionsMenu == _HomeCollectionsMenu.home
        ? _buildPinnedAllCardsCard(context)
        : null;
    final pinnedLatestAddsHeader =
        _activeCollectionsMenu == _HomeCollectionsMenu.home
        ? _buildPinnedLatestAddsHeader(context)
        : null;
    final pinnedHomeWidgets = <Widget>[
      ...?((pinnedAllCardsCard == null) ? null : [pinnedAllCardsCard]),
      ...?((pinnedLatestAddsHeader == null) ? null : [pinnedLatestAddsHeader]),
    ];
    final pokemonPhase = (!_isMtgActiveGame && isBlockingSync)
        ? _pokemonSyncPhaseInfo()
        : null;
    final pokemonPercentValue = (!_isMtgActiveGame && pokemonPhase != null)
        ? (_pokemonSyncPhaseProgress(
                    pokemonPhase,
                    _pokemonSyncOverallProgress,
                  ) *
                  100)
              .clamp(0.0, 100.0)
        : ((_bulkDownloading ? _bulkDownloadProgress : _bulkImportProgress) *
                  100)
              .clamp(0.0, 100.0);
    final pokemonPercentText = pokemonPercentValue >= 99.95
        ? '100'
        : pokemonPercentValue.toStringAsFixed(1);
    final pokemonSyncMeta = (!_isMtgActiveGame && isBlockingSync)
        ? _pokemonSyncMetaLine()
        : null;
    final pokemonSyncChip =
        (!_isMtgActiveGame &&
            isBlockingSync &&
            pokemonPhase != null &&
            pokemonSyncMeta != null)
        ? _buildPokemonSyncChip(
            phase: pokemonPhase,
            percentText: pokemonPercentText,
            metaLine: pokemonSyncMeta,
          )
        : null;
    final mtgPercentValue =
        (_bulkDownloading ? _bulkDownloadProgress : _bulkImportProgress) * 100;
    final mtgPercentText = mtgPercentValue >= 99.95
        ? '100'
        : mtgPercentValue.clamp(0.0, 100.0).toStringAsFixed(1);
    final mtgTitle = _bulkDownloading
        ? (_bulkDownloadTotal > 0
              ? l10n.downloadingUpdateWithTotal(
                  (_bulkDownloadProgress * 100).clamp(0, 100).round(),
                  _formatBytes(_bulkDownloadReceived),
                  _formatBytes(_bulkDownloadTotal),
                )
              : l10n.downloadingUpdateNoTotal(
                  _formatBytes(_bulkDownloadReceived),
                ))
        : l10n.importingCardsWithCount(
            (_bulkImportProgress * 100).clamp(0, 100).round(),
            _bulkImportedCount,
          );
    final mtgMeta = ((_mtgSyncStatus ?? '').trim().isNotEmpty)
        ? _mtgSyncStatus!.trim()
        : (_bulkDownloading
              ? l10n.downloading
              : (_isItalianUi() ? 'Importazione in corso' : 'Importing'));
    final mtgSyncChip = (_isMtgActiveGame && isBlockingSync)
        ? _buildMtgSyncChip(
            icon: _bulkDownloading
                ? Icons.download_rounded
                : Icons.inventory_2_rounded,
            percentText: mtgPercentText,
            title: mtgTitle,
            metaLine: mtgMeta,
          )
        : null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _AppBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _HomeIconButton(
                            selected:
                                _activeCollectionsMenu ==
                                _HomeCollectionsMenu.home,
                            onTap: () {
                              if (_activeCollectionsMenu ==
                                  _HomeCollectionsMenu.home) {
                                return;
                              }
                              setState(() {
                                _activeCollectionsMenu =
                                    _HomeCollectionsMenu.home;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _PlanBadgeButton(
                            isPro: _hasProAccess,
                            onTap: _hasProAccess
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const ProPage(),
                                      ),
                                    );
                                  },
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: l10n.settings,
                            style: IconButton.styleFrom(
                              foregroundColor: const Color(0xFFE9C46A),
                            ),
                            icon: const Icon(Icons.settings),
                            onPressed: _openSettingsAndHandlePostAction,
                          ),
                          const SizedBox(width: 4),
                          _buildGameSelector(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_checkingBulk)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(l10n.checkingUpdates),
                          ],
                        )
                      else if (_bulkDownloading)
                        _isMtgActiveGame
                            ? (mtgSyncChip ?? const SizedBox.shrink())
                            : (pokemonSyncChip ?? const SizedBox.shrink())
                      else if (_bulkImporting)
                        _isMtgActiveGame
                            ? (mtgSyncChip ?? const SizedBox.shrink())
                            : (pokemonSyncChip ?? const SizedBox.shrink())
                      else if (_bulkDownloadError != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isMtgActiveGame
                                  ? l10n.downloadFailedTapUpdate
                                  : (_bulkDownloadError!.trim().isEmpty
                                        ? l10n.downloadFailedGeneric
                                        : _pokemonDownloadErrorLabel(
                                            _bulkDownloadError!,
                                          )),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFE38B5C)),
                            ),
                            if (!_isMtgActiveGame &&
                                _pokemonDownloadErrorDetail(
                                      _bulkDownloadError!,
                                    ) !=
                                    null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _pokemonDownloadErrorDetail(
                                  _bulkDownloadError!,
                                )!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFFBFAE95)),
                              ),
                            ],
                          ],
                        )
                      else if (_cardsMissing)
                        Text(
                          _isMtgActiveGame
                              ? (_isItalianUi()
                                    ? 'Database Magic mancante. Tocca Riprova per scaricare il bundle Firebase.'
                                    : 'Magic database missing. Tap Retry to download the Firebase bundle.')
                              : (_isItalianUi()
                                    ? 'Database Pokemon mancante. Tocca Riprova.'
                                    : 'Pokemon database missing. Tap Retry.'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFE38B5C)),
                        )
                      else if (_bulkUpdateAvailable)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _downloadAvailableDbUpdate,
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 18,
                              ),
                              label: Text(l10n.dbUpdateAvailableTapHere),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE9C46A),
                                foregroundColor: const Color(0xFF1C1510),
                                elevation: 7,
                                shadowColor: const Color(0xAA000000),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: const BorderSide(
                                    color: Color(0xFFF5DEA0),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            if (_bulkUpdatedAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                l10n.updateReadyWithDate(
                                  _bulkUpdatedAt
                                          ?.toLocal()
                                          .toIso8601String()
                                          .split('T')
                                          .first ??
                                      l10n.unknownDate,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFFE3B55C)),
                              ),
                            ],
                          ],
                        )
                      else
                        Text(
                          l10n.upToDate,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF908676)),
                        ),
                      const SizedBox(height: 10),
                      _buildCollectionsMenu(),
                      if (!_isMtgActiveGame &&
                          !pokemonLocked &&
                          !_checkingBulk &&
                          !_bulkDownloading &&
                          !_bulkImporting &&
                          (_bulkDownloadError != null || _cardsMissing)) ...[
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _retryPokemonDatasetInstall,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE9C46A),
                            foregroundColor: const Color(0xFF1C1510),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          label: Text(l10n.retry),
                        ),
                      ],
                      if (_bulkDownloading || _bulkImporting)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _SnakeProgressBar(
                            animation: _snakeController,
                            value: _bulkDownloading && !_isMtgActiveGame
                                ? _pokemonSyncOverallProgress
                                : (_bulkDownloading
                                      ? _bulkDownloadProgress
                                      : (!_isMtgActiveGame
                                            ? _pokemonSyncOverallProgress
                                            : _bulkImportProgress)),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _initialCollectionsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : pokemonLocked
                      ? _buildLockedCollectionsPreview(
                          context,
                          section: _activeCollectionsMenu,
                          introTitle: l10n.pokemonInProTitle,
                          introBody: l10n.pokemonInProBody,
                          cta: _openSettingsAndHandlePostAction,
                        )
                      : (_activeCollectionsMenu == _HomeCollectionsMenu.home
                            ? Column(
                                children: [
                                  ...pinnedHomeWidgets,
                                  Expanded(
                                    child: ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        120,
                                      ),
                                      children: [
                                        ..._buildCollectionSections(
                                          context,
                                          includeAllCards: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  120,
                                ),
                                children: [
                                  ..._buildCollectionSections(context),
                                ],
                              )),
                ),
              ],
            ),
          ),
          if (isBlockingSync) ...[
            const ModalBarrier(dismissible: false, color: Color(0x880E0A08)),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FloatingActionButton(
                heroTag: 'home_search_fab',
                onPressed: isBlockingSync ? null : _onSearchCardPressed,
                child: const Icon(Icons.search),
              ),
              FloatingActionButton(
                heroTag: 'home_add_fab',
                onPressed: isBlockingSync
                    ? null
                    : () => _showHomeAddOptions(context),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameMenuBadge extends StatelessWidget {
  const _GameMenuBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE9C46A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1C1510),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MenuPillButton extends StatelessWidget {
  const _MenuPillButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFE9C46A).withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFFE9C46A)
                    : const Color(0xFF5D4731).withValues(alpha: 0.45),
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: selected
                  ? const Color(0xFFEFD28B)
                  : const Color(0xFFE9C46A).withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeIconButton extends StatelessWidget {
  const _HomeIconButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE9C46A).withValues(alpha: 0.18)
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE9C46A)
                  : const Color(0xFF5D4731),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.home_rounded,
              size: 18,
              color: selected
                  ? const Color(0xFFE9C46A)
                  : const Color(0xFFBFAE95),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanBadgeButton extends StatelessWidget {
  const _PlanBadgeButton({required this.isPro, this.onTap});

  final bool isPro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isPro
                ? const Color(0xFFE9C46A).withValues(alpha: 0.18)
                : const Color(0x221D1712),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPro ? const Color(0xFFE9C46A) : const Color(0xFF5D4731),
            ),
          ),
          child: Text(
            isPro ? 'PRO' : 'FREE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isPro ? const Color(0xFFEFD28B) : const Color(0xFFBFAE95),
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final borderPath = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;

    const dashWidth = 7.0;
    const dashSpace = 5.0;
    for (final metric in borderPath.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.name,
    required this.count,
    required this.icon,
    this.onTap,
    this.countLabel,
    this.onLongPress,
    this.enabled = true,
    this.disabledTag,
  });

  final String name;
  final int count;
  final IconData icon;
  final String? countLabel;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onLongPress;
  final bool enabled;
  final String? disabledTag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onLongPressStart: onLongPress == null
          ? null
          : (details) => onLongPress?.call(details.globalPosition),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.58,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: enabled
                    ? null
                    : Border.all(color: const Color(0x665D4731)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFFE9C46A)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          countLabel ?? l10n.cardCount(count),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFBFAE95)),
                        ),
                      ],
                    ),
                  ),
                  if (enabled)
                    const Icon(Icons.chevron_right, color: Color(0xFFBFAE95))
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (disabledTag?.trim().isNotEmpty ?? false)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5A2020),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFE16464),
                              ),
                            ),
                            child: Text(
                              disabledTag!,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFFFFD2D2),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11.5,
                                    letterSpacing: 0.8,
                                  ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.lock_outline,
                          color: Color(0xFFBFAE95),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentAddedCardTile extends StatelessWidget {
  const _RecentAddedCardTile({
    required this.card,
    required this.priceLabel,
    required this.showPrice,
    required this.onTap,
  });

  final CardSearchResult card;
  final String priceLabel;
  final bool showPrice;
  final VoidCallback onTap;

  Decoration _homeCardTintDecoration(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    final accents = _accentColorsForCard(
      colors: card.colors,
      colorIdentity: card.colorIdentity,
      typeLine: card.typeLine,
    );
    if (accents.isEmpty) {
      return BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    final tintStops = accents
        .map((color) => Color.lerp(base, color, 0.35) ?? base)
        .toList();
    return BoxDecoration(
      gradient: LinearGradient(
        colors: tintStops.length == 1 ? [base, tintStops.first] : tintStops,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Decoration _homePriceBadgeDecoration(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    final accents = _accentColorsForCard(
      colors: card.colors,
      colorIdentity: card.colorIdentity,
      typeLine: card.typeLine,
    );
    if (accents.isEmpty) {
      return BoxDecoration(
        color: Color.lerp(base, Colors.black, 0.08) ?? base,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x4A5D4731)),
      );
    }
    final tintStops = accents
        .map((color) => Color.lerp(base, color, 0.35) ?? base)
        .toList();
    return BoxDecoration(
      gradient: LinearGradient(
        colors: tintStops.length == 1 ? [base, tintStops.first] : tintStops,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x4A5D4731)),
    );
  }

  Widget _buildRaritySquare(String rarity) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _rarityColor(rarity),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF3A2F24)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _normalizeCardImageUrlForDisplay(card.imageUri);
    final setLabel = card.setName.trim().isNotEmpty
        ? card.setName.trim()
        : card.setCode.toUpperCase();
    return SizedBox(
      width: 164,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (showPrice)
              Positioned(
                left: 10,
                right: 10,
                bottom: -6,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 2),
                  decoration: _homePriceBadgeDecoration(context),
                  child: Text(
                    AppLocalizations.of(context)!.priceLabel(priceLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFEFE7D8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            Container(
              margin: EdgeInsets.only(bottom: showPrice ? 18 : 0),
              decoration: _homeCardTintDecoration(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (context, error, stackTrace) =>
                                  _missingCardArtPlaceholder(card.setCode),
                            )
                          : _missingCardArtPlaceholder(card.setCode),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 22,
                            child: Text(
                              card.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFFF3E8D0)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _buildSetIcon(card.setCode, size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  setLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFFBFAE95),
                                      ),
                                ),
                              ),
                              if (card.rarity.trim().isNotEmpty) ...[
                                const SizedBox(width: 6),
                                _buildRaritySquare(card.rarity),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _DividerGlow()),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFFC9BDA4),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: _DividerGlow()),
      ],
    );
  }
}

class _DividerGlow extends StatelessWidget {
  const _DividerGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0x00E2C26A),
            const Color(0x66E2C26A),
            const Color(0x00E2C26A),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _HomeAddSheet extends StatelessWidget {
  const _HomeAddSheet({
    required this.addContext,
    required this.canCreateSet,
    required this.canCreateCustom,
    required this.canCreateSmart,
    required this.canCreateDeck,
    required this.canCreateWishlist,
  });

  final _HomeAddContext addContext;
  final bool canCreateSet;
  final bool canCreateCustom;
  final bool canCreateSmart;
  final bool canCreateDeck;
  final bool canCreateWishlist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final sheetMargin = _bottomSheetMenuMargin(context);
    final maxSheetHeight =
        media.size.height -
        media.padding.top -
        sheetMargin.top -
        sheetMargin.bottom;
    return SafeArea(
      bottom: false,
      child: Container(
        margin: sheetMargin,
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.addTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (addContext == _HomeAddContext.home) ...[
                  ListTile(
                    leading: const Icon(Icons.document_scanner_outlined),
                    title: Text(l10n.addViaScanTitle),
                    subtitle: Text(l10n.scanCardWithLiveOcrSubtitle),
                    onTap: () =>
                        Navigator.of(context).pop(_HomeAddAction.addByScan),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text(l10n.addCards),
                    subtitle: Text(l10n.addCardsToCatalogSubtitle),
                    onTap: () =>
                        Navigator.of(context).pop(_HomeAddAction.addCards),
                  ),
                  Opacity(
                    opacity: canCreateSet ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome_mosaic),
                      title: Text(
                        _isItalianUi(context)
                            ? 'Aggiungi set tracker'
                            : 'Add set tracker',
                      ),
                      subtitle: Text(
                        _isItalianUi(context)
                            ? 'Crea una collezione basata su set.'
                            : 'Create a set-based collection.',
                      ),
                      onTap: canCreateSet
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addSetCollection)
                          : null,
                    ),
                  ),
                  Opacity(
                    opacity: canCreateCustom ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.tune),
                      title: Text(
                        _isItalianUi(context)
                            ? 'Aggiungi custom collection'
                            : 'Add custom collection',
                      ),
                      subtitle: Text(l10n.customCollectionSubtitle),
                      onTap: canCreateCustom
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addCustomCollection)
                          : null,
                    ),
                  ),
                  Opacity(
                    opacity: canCreateSmart ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.auto_fix_high_rounded),
                      title: Text(
                        _isItalianUi(context)
                            ? 'Aggiungi smart collection'
                            : 'Add smart collection',
                      ),
                      subtitle: Text(
                        _isItalianUi(context)
                            ? 'Salva un filtro dinamico e mostra solo le carte possedute.'
                            : 'Save a dynamic filter and show only owned cards.',
                      ),
                      onTap: canCreateSmart
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addSmartCollection)
                          : null,
                    ),
                  ),
                  Opacity(
                    opacity: canCreateDeck ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.view_carousel_rounded),
                      title: Text(l10n.deckCollectionTitle),
                      subtitle: canCreateDeck
                          ? Text(l10n.deckCollectionSubtitle)
                          : Text(l10n.upgradeToPro),
                      onTap: canCreateDeck
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addDeck)
                          : null,
                    ),
                  ),
                  Opacity(
                    opacity: canCreateWishlist ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.favorite_border_rounded),
                      title: Text(l10n.addWishlist),
                      subtitle: canCreateWishlist
                          ? Text(l10n.addWishlistSubtitle)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.upgradeToPro,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: const Color(0xFFE9C46A),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(l10n.addWishlistSubtitle),
                              ],
                            ),
                      onTap: canCreateWishlist
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addWishlist)
                          : null,
                    ),
                  ),
                ] else if (addContext == _HomeAddContext.set) ...[
                  Opacity(
                    opacity: canCreateSet ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome_mosaic),
                      title: Text(l10n.setCollectionTitle),
                      subtitle: Text(l10n.setCollectionSubtitle),
                      onTap: canCreateSet
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addSetCollection)
                          : null,
                    ),
                  ),
                ] else if (addContext == _HomeAddContext.custom) ...[
                  Opacity(
                    opacity: canCreateCustom ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.tune),
                      title: Text(l10n.customCollectionTitle),
                      subtitle: Text(l10n.customCollectionSubtitle),
                      onTap: canCreateCustom
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addCustomCollection)
                          : null,
                    ),
                  ),
                ] else if (addContext == _HomeAddContext.smart) ...[
                  Opacity(
                    opacity: canCreateSmart ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.auto_fix_high_rounded),
                      title: Text(
                        _isItalianUi(context)
                            ? 'Smart collection'
                            : 'Smart collection',
                      ),
                      subtitle: Text(
                        _isItalianUi(context)
                            ? 'Salva un filtro dinamico e mostra solo le carte possedute.'
                            : 'Save a dynamic filter and show only owned cards.',
                      ),
                      onTap: canCreateSmart
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addSmartCollection)
                          : null,
                    ),
                  ),
                ] else if (addContext == _HomeAddContext.deck) ...[
                  Opacity(
                    opacity: canCreateDeck ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.view_carousel_rounded),
                      title: Text(l10n.deckCollectionTitle),
                      subtitle: Text(l10n.deckCollectionSubtitle),
                      onTap: canCreateDeck
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addDeck)
                          : null,
                    ),
                  ),
                ] else if (addContext == _HomeAddContext.wishlist) ...[
                  Opacity(
                    opacity: canCreateWishlist ? 1.0 : 0.55,
                    child: ListTile(
                      leading: const Icon(Icons.favorite_border_rounded),
                      title: Text(l10n.addWishlist),
                      subtitle: canCreateWishlist
                          ? Text(l10n.addWishlistSubtitle)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.upgradeToPro,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: const Color(0xFFE9C46A),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(l10n.addWishlistSubtitle),
                              ],
                            ),
                      onTap: canCreateWishlist
                          ? () => Navigator.of(
                              context,
                            ).pop(_HomeAddAction.addWishlist)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isItalianUi(BuildContext context) {
    return Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('it');
  }
}

class _DeckImportSource {
  const _DeckImportSource({required this.fileName, required this.content});

  final String fileName;
  final String content;
}

class _DeckCreateRequest {
  const _DeckCreateRequest({
    required this.name,
    this.format,
    this.importSource,
  });

  final String name;
  final String? format;
  final _DeckImportSource? importSource;
}

class _DeckImportResult {
  const _DeckImportResult({
    required this.imported,
    required this.skipped,
    required this.notFoundCards,
  });

  final int imported;
  final int skipped;
  final List<String> notFoundCards;
}

class _ParsedDeckList {
  const _ParsedDeckList({required this.mainboard, required this.sideboard});

  final Map<String, int> mainboard;
  final Map<String, int> sideboard;
}

enum _CollectionAction {
  rename,
  importDeckFile,
  exportDeckArena,
  exportDeckMtgo,
  delete,
}

enum _HomeCollectionsMenu { home, set, custom, smart, wish, deck }

class _PokemonSyncPhaseInfo {
  const _PokemonSyncPhaseInfo({
    required this.index,
    required this.total,
    required this.label,
    required this.startProgress,
    required this.endProgress,
  });

  final int index;
  final int total;
  final String label;
  final double startProgress;
  final double endProgress;
}

enum _HomeAddAction {
  addByScan,
  addCards,
  addSetCollection,
  addCustomCollection,
  addSmartCollection,
  addDeck,
  addWishlist,
}

class _SnakeProgressBar extends StatelessWidget {
  const _SnakeProgressBar({required this.animation, required this.value});

  final Animation<double> animation;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final trackColor = const Color(0xFF2A221B);
    final fillColor = const Color(0xFFB85C38);
    final highlightColor = const Color(0xFFF3D28B);

    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final clampedValue = value?.clamp(0.0, 1.0);
          final fillWidth = clampedValue == null
              ? 0.0
              : maxWidth * clampedValue;
          final snakeWidth = maxWidth * 0.22;

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final availableWidth = clampedValue == null
                  ? maxWidth
                  : (fillWidth > 0 ? fillWidth : maxWidth);
              final travel = (availableWidth - snakeWidth).clamp(0.0, maxWidth);
              final left = travel * animation.value;

              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  if (clampedValue != null && fillWidth > 0)
                    FractionallySizedBox(
                      widthFactor: clampedValue,
                      child: Container(
                        decoration: BoxDecoration(
                          color: fillColor.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  Positioned(
                    left: left,
                    child: Container(
                      width: snakeWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            highlightColor.withValues(alpha: 0.1),
                            highlightColor,
                            highlightColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
