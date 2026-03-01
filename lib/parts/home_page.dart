part of 'package:tcg_tracker/main.dart';

class CollectionHomePage extends StatefulWidget {
  const CollectionHomePage({super.key});

  @override
  State<CollectionHomePage> createState() => _CollectionHomePageState();
}

class _CollectionHomePageState extends State<CollectionHomePage>
    with TickerProviderStateMixin {
  final List<CollectionInfo> _collections = [];
  String? _selectedBulkType;
  static const int _freeCollectionLimit = 7;
  static const int _freeSetCollectionLimit = 2;
  static const int _freeCustomCollectionLimit = 2;
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
  String? _bulkDownloadError;
  bool _bulkImporting = false;
  double _bulkImportProgress = 0;
  int _bulkImportedCount = 0;
  String? _pokemonSyncStatus;
  String? _bulkUpdatedAtRaw;
  bool _cardsMissing = false;
  bool _initialCollectionsLoading = true;
  bool _collectionsLoadInProgress = false;
  int _totalCardCount = 0;
  Map<int, int> _deckSideboardCounts = {};
  late final AnimationController _snakeController;
  Map<String, String> _setNameLookup = {};
  static const int _deckImportBatchSize = 120;
  TcgGame _selectedHomeGame = TcgGame.mtg;
  _HomeCollectionsMenu _activeCollectionsMenu = _HomeCollectionsMenu.home;
  bool _forceFreePreview = false;
  bool get _hasRealProAccess => _purchaseManager.isPro || _isProUnlocked;
  bool get _hasProAccess => _hasRealProAccess && !_forceFreePreview;

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
      setState(() {
        _isProUnlocked = _purchaseManager.isPro;
        if (!_hasRealProAccess) {
          _forceFreePreview = false;
        }
      });
    };
    _purchaseManager.addListener(_purchaseListener);
    _isProUnlocked = _purchaseManager.isPro;
    if (!_hasRealProAccess) {
      _forceFreePreview = false;
    }
    _snakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    unawaited(_checkForAppUpdateOnStartup());
    unawaited(_initializeEnvironmentAndData());
    _collectionsRefreshNotifier.addListener(_onCollectionsRefreshRequested);
  }

  Future<void> _initializeEnvironmentAndData() async {
    await _purchaseManager.init();
    await _ensurePrimaryGameSelectionOnFirstLaunch();
    await TcgEnvironmentController.instance.init();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedHomeGame = TcgEnvironmentController.instance.currentGame;
    });
    if (!_isGameUnlocked(_selectedHomeGame)) {
      final fallbackGame = _firstAccessibleGame();
      await TcgEnvironmentController.instance.setGame(fallbackGame);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedHomeGame = fallbackGame;
      });
    }
    await ScryfallDatabase.instance.open();
    await _runCollectionCoherenceCheckIfNeeded();
    await _loadCollections();
    await _maybeShowLatestReleaseNotesBeforeDbDownloads();
    if (!mounted || !context.mounted) {
      return;
    }
    unawaited(_initializeForCurrentGame());
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
    final lastCheckedVersion = await AppSettings
        .loadCollectionCoherenceCheckVersionForGame(game);
    if (lastCheckedVersion == currentVersion) {
      return;
    }
    await ScryfallDatabase.instance.repairAllCardsCoherenceFromCustomCollections();
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
    await _showLatestReleaseNotesPanel(context);
  }

  Future<void> _ensurePrimaryGameSelectionOnFirstLaunch() async {
    final alreadySelected = await AppSettings.hasPrimaryGameSelection();
    if (alreadySelected || !mounted) {
      return;
    }
    final selected = await _showPrimaryGamePickerDialog();
    if (selected == null) {
      await AppSettings.ensurePrimaryTcgGame(AppTcgGame.mtg);
      await AppSettings.saveSelectedTcgGame(AppTcgGame.mtg);
      await _purchaseManager.syncPrimaryGameFromSettings();
      return;
    }
    final selectedGame = selected == TcgGame.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    await AppSettings.savePrimaryTcgGame(selectedGame);
    await AppSettings.saveSelectedTcgGame(selectedGame);
    await _purchaseManager.syncPrimaryGameFromSettings();
  }

  Future<TcgGame?> _showPrimaryGamePickerDialog() async {
    if (!mounted) {
      return null;
    }
    final isItalian = _isItalianUi();
    var current = TcgGame.mtg;
    return showDialog<TcgGame>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: Text(
              isItalian ? 'Scegli gioco primario' : 'Choose primary game',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isItalian
                      ? 'Alla prima apertura scegli il TCG primario (gratis per sempre). L\'altro richiede acquisto.'
                      : 'At first launch choose your primary TCG (free forever). The other requires purchase.',
                ),
                const SizedBox(height: 12),
                RadioGroup<TcgGame>(
                  groupValue: current,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setModalState(() {
                      current = value;
                    });
                  },
                  child: Column(
                    children: [
                      RadioListTile<TcgGame>(
                        value: TcgGame.mtg,
                        title: const Text('Magic'),
                        subtitle: Text(
                          isItalian ? 'Primario gratuito' : 'Primary free',
                        ),
                      ),
                      RadioListTile<TcgGame>(
                        value: TcgGame.pokemon,
                        title: const Text('Pokemon'),
                        subtitle: Text(
                          isItalian ? 'Primario gratuito' : 'Primary free',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(current),
                child: Text(isItalian ? 'Continua' : 'Continue'),
              ),
            ],
          ),
        );
      },
    );
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
    if (_isGameUnlocked(TcgGame.mtg)) {
      return TcgGame.mtg;
    }
    return TcgGame.pokemon;
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
        final selectedProfile = await _showPokemonProfilePickerForMissingDb();
        if (selectedProfile == null || !mounted) {
          return;
        }
        await AppSettings.savePokemonDatasetProfile(selectedProfile);
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
    } catch (error, stackTrace) {
      debugPrint('Pokemon dataset install failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
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
    final normalizedLightning = await ScryfallDatabase.instance
        .normalizePokemonLightningColors();
    final repairedArtists = await ScryfallDatabase.instance
        .backfillArtistsFromCardJson();
    final updated = repairedMissing + normalizedLightning + repairedArtists;
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
      _bulkImportedCount = 0;
      _pokemonSyncStatus = null;
      _bulkDownloadError = null;
    });

    const downloadPhaseLimit = 0.84;
    var lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);
    var lastAcceptedProgress = -1.0;
    await PokemonBulkService.instance.installDataset(
      onStatus: (status) {
        if (!mounted) {
          return;
        }
        setState(() {
          _pokemonSyncStatus = status.trim().isEmpty ? null : status.trim();
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
        setState(() {
          if (!_isMtgActiveGame) {
            _bulkDownloading = true;
            _bulkImporting = false;
            _bulkDownloadProgress = clamped;
            _bulkDownloadReceived = (_bulkDownloadProgress * 10000).round();
            _bulkDownloadTotal = 10000;
            _bulkImportProgress = 0;
            _bulkImportedCount = 0;
          } else if (clamped < downloadPhaseLimit) {
            _bulkDownloading = true;
            _bulkImporting = false;
            _bulkDownloadProgress = (clamped / downloadPhaseLimit).clamp(
              0.0,
              1.0,
            );
            _bulkDownloadReceived = (_bulkDownloadProgress * 10000).round();
            _bulkDownloadTotal = 10000;
          } else {
            _bulkDownloading = false;
            _bulkImporting = true;
            _bulkImportProgress =
                ((clamped - downloadPhaseLimit) / (1.0 - downloadPhaseLimit))
                    .clamp(0.0, 1.0);
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
      _pokemonSyncStatus = null;
    });
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
      final selectedProfile = await _showPokemonProfilePickerForMissingDb();
      if (selectedProfile == null || !mounted) {
        return;
      }
      await AppSettings.savePokemonDatasetProfile(selectedProfile);
    }
    await _initializePokemonStartup();
    if (!mounted) {
      return;
    }
    await _loadCollections();
  }

  String _pokemonProfileLabelForHome(String profile) {
    switch (profile.trim().toLowerCase()) {
      case 'full':
        return _isItalianUi() ? 'Full (tutte le carte)' : 'Full (all cards)';
      case 'expanded':
        return _isItalianUi() ? 'Expanded (10 set)' : 'Expanded (10 sets)';
      case 'standard':
        return _isItalianUi() ? 'Standard (6 set)' : 'Standard (6 sets)';
      case 'starter':
      default:
        return _isItalianUi() ? 'Starter (3 set)' : 'Starter (3 sets)';
    }
  }

  Future<String?> _showPokemonProfilePickerForMissingDb() async {
    if (!mounted) {
      return null;
    }
    final current = await AppSettings.loadPokemonDatasetProfile();
    const options = <String>['starter', 'standard', 'expanded', 'full'];
    if (!mounted) {
      return null;
    }
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        var selected = options.contains(current) ? current : options.first;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              _isItalianUi()
                  ? 'Scegli database Pokemon'
                  : 'Choose Pokemon database',
            ),
            content: RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setDialogState(() {
                  selected = value;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map(
                      (profile) => RadioListTile<String>(
                        value: profile,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_pokemonProfileLabelForHome(profile)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(selected),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  _isItalianUi() ? 'Scarica database' : 'Download database',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLockedGameDialog(TcgGame game) async {
    if (!mounted) {
      return;
    }
    final isItalian = _isItalianUi();
    final gameLabel = game == TcgGame.pokemon ? 'Pokemon' : 'Magic';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isItalian ? '$gameLabel in versione Pro' : '$gameLabel in Pro',
        ),
        content: Text(
          isItalian
              ? '$gameLabel e disponibile come acquisto una tantum. Attivalo dalle Impostazioni.'
              : '$gameLabel is available as a one-time unlock. Activate it from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isItalian ? 'Chiudi' : 'Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
            child: Text(isItalian ? 'Apri impostazioni' : 'Open settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForAppUpdateOnStartup() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
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
    _collectionsRefreshNotifier.removeListener(_onCollectionsRefreshRequested);
    _snakeController.dispose();
    _purchaseManager.removeListener(_purchaseListener);
    super.dispose();
  }

  bool _isSetCollection(CollectionInfo collection) {
    if (collection.type == CollectionType.set) {
      return true;
    }
    return collection.name.startsWith(_setPrefix);
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

  bool _isCollectionNameTaken(
    String name, {
    int? excludeCollectionId,
  }) {
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

  int _userCollectionCount() {
    return _collections
        .where(
          (item) =>
              item.name != _allCardsCollectionName &&
              !_isBasicLandsCollection(item),
        )
        .length;
  }

  bool _canCreateCollection() {
    return _hasProAccess || _userCollectionCount() < _freeCollectionLimit;
  }

  int _setCollectionCount() {
    return _collections.where(_isSetCollection).length;
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
              item.type == CollectionType.custom ||
              item.type == CollectionType.smart,
        )
        .length;
  }

  bool _canCreateCustomCollection() {
    return _hasProAccess ||
        _customCollectionCount() < _freeCustomCollectionLimit;
  }

  int _deckCollectionCount() {
    return _collections
        .where((item) => item.type == CollectionType.deck)
        .length;
  }

  bool _canCreateDeckCollection() {
    return _hasProAccess || _deckCollectionCount() < _freeDeckCollectionLimit;
  }

  Future<void> _showCollectionLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.collectionLimitReachedTitle),
          content: Text(l10n.collectionLimitReachedBody(_freeCollectionLimit)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ProPage()));
              },
              child: Text(l10n.upgrade),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showWishlistLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.wishlistLimitReachedTitle),
          content: Text(l10n.wishlistLimitReachedBody(_freeWishlistLimit)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ProPage()));
              },
              child: Text(l10n.upgrade),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSetCollectionLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.collectionLimitReachedTitle),
          content: Text(
            l10n.collectionLimitReachedBody(_freeSetCollectionLimit),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ProPage()));
              },
              child: Text(l10n.upgrade),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCustomCollectionLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.collectionLimitReachedTitle),
          content: Text(
            l10n.collectionLimitReachedBody(_freeCustomCollectionLimit),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ProPage()));
              },
              child: Text(l10n.upgrade),
            ),
          ],
        );
      },
    );
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
      final setNames = await ScryfallDatabase.instance.fetchSetNamesForCodes(
        setCodes,
      );
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
      });
    } on TimeoutException {
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.downloadFailedGeneric,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.downloadFailedGeneric,
        );
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

  List<Widget> _buildCollectionSections(BuildContext context) {
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
    final disabledCollectionIds = _disabledCollectionIdsForFree(userCollections);
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

    if (allCards != null) {
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
      return widgets;
    }

    widgets.add(const SizedBox(height: 6));
    widgets.add(
      _SectionDivider(label: AppLocalizations.of(context)!.myCollections),
    );
    widgets.add(const SizedBox(height: 12));

    final canCreateSet = _canCreateCollection() && _canCreateSetCollection();
    final canCreateCustom =
        _canCreateCollection() && _canCreateCustomCollection();
    final canCreateDeck = _canCreateCollection() && _canCreateDeckCollection();
    final canCreateWishlist = _canCreateCollection() && _canCreateWishlist();
    final setCollections = nonDeckCollections
        .where(_isSetCollection)
        .toList(growable: false);
    final customCollections = nonDeckCollections
        .where((item) => item.type == CollectionType.custom)
        .toList(growable: false);
    final smartCollections = nonDeckCollections
        .where((item) => item.type == CollectionType.smart)
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
            createTitle: AppLocalizations.of(context)!.createYourSetCollectionTitle,
            description: _sectionHelpText(_HomeCollectionsMenu.set),
            canCreate: canCreateSet,
            onCreate: () => _addSetCollection(context),
          );
        case _HomeCollectionsMenu.custom:
          return buildSingleCategory(
            label: AppLocalizations.of(context)!.createYourCustomCollectionTitle,
            items: customCollections,
            createIcon: Icons.tune,
            createTitle: AppLocalizations.of(context)!.createYourCustomCollectionTitle,
            description: _sectionHelpText(_HomeCollectionsMenu.custom),
            canCreate: canCreateCustom,
            onCreate: () => _addCustomCollection(context),
          );
        case _HomeCollectionsMenu.smart:
          return buildSingleCategory(
            label: _isItalianUi() ? 'Smart collection' : 'Smart collection',
            items: smartCollections,
            createIcon: Icons.auto_fix_high_rounded,
            createTitle: _isItalianUi()
                ? 'Crea una smart collection'
                : 'Create your smart collection',
            description: _sectionHelpText(_HomeCollectionsMenu.smart),
            canCreate: canCreateCustom,
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

  Widget _buildCollectionsMenu() {
    final isItalian = _isItalianUi();
    final items = <(_HomeCollectionsMenu, IconData, String)>[
      (
        _HomeCollectionsMenu.set,
        Icons.auto_awesome_mosaic,
        isItalian ? 'Set' : 'Set',
      ),
      (
        _HomeCollectionsMenu.custom,
        Icons.collections_bookmark_outlined,
        isItalian ? 'Custom' : 'Custom',
      ),
      (
        _HomeCollectionsMenu.smart,
        Icons.auto_fix_high_rounded,
        isItalian ? 'Smart' : 'Smart',
      ),
      (
        _HomeCollectionsMenu.wish,
        Icons.favorite_border_rounded,
        isItalian ? 'Wishlist' : 'Wishlist',
      ),
      (
        _HomeCollectionsMenu.deck,
        Icons.view_carousel_rounded,
        isItalian ? 'Deck' : 'Deck',
      ),
    ];
    return Column(
      children: [
        const Divider(height: 1, color: Color(0x7A5D4731)),
        const SizedBox(height: 10),
        Row(
          children: items
              .map(
                (entry) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _MenuPillButton(
                      icon: entry.$2,
                      tooltip: entry.$3,
                      selected: _activeCollectionsMenu == entry.$1,
                      onTap: () {
                        if (_activeCollectionsMenu == entry.$1) {
                          return;
                        }
                        setState(() {
                          _activeCollectionsMenu = entry.$1;
                        });
                      },
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0x7A5D4731)),
      ],
    );
  }

  String _sectionHelpText(_HomeCollectionsMenu section) {
    final isItalian = _isItalianUi();
    switch (section) {
      case _HomeCollectionsMenu.set:
        return isItalian
            ? 'Scegli un set specifico e segui la checklist in modo chiaro: vedi subito le carte presenti e quelle che ti mancano.'
            : 'Choose a specific set and follow its checklist clearly: instantly see collected cards and missing ones.';
      case _HomeCollectionsMenu.custom:
        return isItalian
            ? 'Crea raccolte manuali aggiungendo solo carte possedute dalla tua inventory.'
            : 'Create manual collections and include only cards you already own in inventory.';
      case _HomeCollectionsMenu.smart:
        return isItalian
            ? 'Salva un filtro dinamico: la smart collection mostra automaticamente solo le carte possedute che rispettano i criteri.'
            : 'Save a dynamic filter: smart collections automatically show only owned cards matching your criteria.';
      case _HomeCollectionsMenu.wish:
        return isItalian
            ? 'Crea una wishlist con filtri avanzati per tenere sotto controllo le carte mancanti che vuoi trovare.'
            : 'Create a wishlist with advanced filters to track the missing cards you are looking for.';
      case _HomeCollectionsMenu.deck:
        return isItalian
            ? 'Tieni traccia dei tuoi mazzi e aggiorna mainboard/sideboard: le carte del deck restano nel mazzo e non vengono aggiunte alle collezioni.'
            : 'Track your decks and update mainboard/sideboard: deck cards stay in the deck and are not added to collections.';
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

    final setItems = userCollections.where(_isSetCollection).toList();
    final customItems = userCollections
        .where(
          (item) =>
              item.type == CollectionType.custom ||
              item.type == CollectionType.smart,
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
    markDisabled(deckItems, _freeDeckCollectionLimit);
    markDisabled(wishItems, _freeWishlistLimit);

    return disabled;
  }

  void _toggleProPreviewMode() {
    if (!_hasRealProAccess) {
      return;
    }
    setState(() {
      _forceFreePreview = !_forceFreePreview;
    });
    final isItalian = _isItalianUi();
    showAppSnackBar(
      context,
      _forceFreePreview
          ? (isItalian
                ? 'Modalita test: comportamento Free attivo.'
                : 'Test mode: Free behavior enabled.')
          : (isItalian
                ? 'Modalita test disattivata: comportamento Pro attivo.'
                : 'Test mode disabled: Pro behavior restored.'),
    );
  }

  Future<void> _showDeckCollectionLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.collectionLimitReachedTitle),
          content: Text(
            l10n.collectionLimitReachedBody(_freeDeckCollectionLimit),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ProPage()));
              },
              child: Text(l10n.upgrade),
            ),
          ],
        );
      },
    );
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
    final storedBulkType = await AppSettings.loadBulkTypeForGame(
      _activeSettingsGame,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBulkType = storedBulkType;
      _bulkUpdateAvailable = false;
      _bulkDownloadUri = null;
      _bulkUpdatedAt = null;
      _bulkUpdatedAtRaw = null;
      _bulkDownloadError = null;
    });

    await _checkCardsInstalled();
    if (!mounted) {
      return;
    }

    var forceBootstrapDownload = false;
    if (_cardsMissing) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      final selected = await _showBulkTypePicker(
        context,
        allowCancel: false,
        selectedType: _selectedBulkType,
        requireConfirmation: true,
        confirmLabel: AppLocalizations.of(context)!.downloadUpdate,
      );
      if (!mounted) {
        return;
      }
      if (selected != null) {
        await AppSettings.saveBulkTypeForGame(_activeSettingsGame, selected);
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedBulkType = selected;
        });
        forceBootstrapDownload = true;
      }
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
    final result = await ScryfallBulkChecker().checkAllCardsUpdate(bulkType);
    if (!mounted) {
      return;
    }
    setState(() {
      _bulkDownloadUri = result.downloadUri ?? _bulkDownloadUri;
      _bulkUpdatedAt = result.updatedAt ?? _bulkUpdatedAt;
      _bulkUpdatedAtRaw = result.updatedAtRaw ?? _bulkUpdatedAtRaw;
      _bulkUpdateAvailable = true;
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
        await _checkScryfallBulk();
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
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
      return;
    }
    if (!_canCreateWishlist()) {
      await _showWishlistLimitDialog();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: l10n.wishlistDefaultName);
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
                Navigator.of(
                  context,
                ).pop(value.isEmpty ? l10n.wishlistDefaultName : value);
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
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
      return;
    }
    if (!_canCreateCustomCollection()) {
      await _showCustomCollectionLimitDialog();
      return;
    }
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
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
                Navigator.of(context).pop(value.isEmpty ? null : value);
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
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
      return;
    }
    if (!_canCreateCustomCollection()) {
      await _showCustomCollectionLimitDialog();
      return;
    }
    final isItalian = _isItalianUi();
    final defaultName = isItalian ? 'Collezione smart' : 'Smart collection';
    final controller = TextEditingController(text: defaultName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(
            isItalian ? 'Nuova collezione smart' : 'New smart collection',
          ),
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
          submitLabel: isItalian ? 'Crea' : 'Create',
        ),
      ),
    );
    if (!context.mounted || filter == null) {
      return;
    }
    if (!_hasAtLeastOneSmartFilter(filter)) {
      showAppSnackBar(
        context,
        isItalian
            ? 'Imposta almeno un filtro per creare una smart collection.'
            : 'Choose at least one filter to create a smart collection.',
      );
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

  Future<void> _addSetCollection(BuildContext context) async {
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
      return;
    }
    if (!_canCreateSetCollection()) {
      await _showSetCollectionLimitDialog();
      return;
    }
    final sets = await ScryfallDatabase.instance.fetchAvailableSets();
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

    final resolvedName = _setCollectionName(selected.code);
    if (_isCollectionNameTaken(resolvedName)) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.collectionAlreadyExists,
      );
      return;
    }

    int id;
    final filter = CollectionFilter(sets: {selected.code.toLowerCase()});
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
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
      return;
    }
    if (!_canCreateDeckCollection()) {
      await _showDeckCollectionLimitDialog();
      return;
    }
    final controller = TextEditingController();
    final allowDeckImport = _isMtgActiveGame;
    String? selectedFormat;
    _DeckImportSource? importSource;
    final request = await showDialog<_DeckCreateRequest>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
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
                    if (value.isEmpty) {
                      Navigator.of(context).pop();
                      return;
                    }
                    Navigator.of(context).pop(
                      _DeckCreateRequest(
                        name: value,
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
    return _isItalianUi() ? 'Carica file Arena/MTGO' : 'Load Arena/MTGO file';
  }

  String _pokemonDeckHintLabel() {
    if (_isItalianUi()) {
      return 'Mazzo Pokemon: 60 carte esatte, max 4 copie per nome (tranne Energie Base), almeno 1 Pokemon Base.';
    }
    return 'Pokemon deck: exactly 60 cards, max 4 copies per name (except Basic Energy), at least 1 Basic Pokemon.';
  }

  String _deckImportMenuLabel() {
    return _isItalianUi() ? 'Importa lista mazzo' : 'Import deck list';
  }

  String _deckExportArenaLabel() {
    return _isItalianUi() ? 'Esporta per Arena' : 'Export for Arena';
  }

  String _deckExportMtgoLabel() {
    return _isItalianUi() ? 'Esporta per MTGO' : 'Export for MTGO';
  }

  String _deckImportedSummaryLabel(int imported, int skipped) {
    if (_isItalianUi()) {
      return 'Mazzo importato: $imported carte, $skipped non trovate';
    }
    return 'Deck imported: $imported cards, $skipped not found';
  }

  String _deckImportingLabel() {
    return _isItalianUi()
        ? 'Importazione mazzo in corso...'
        : 'Importing deck...';
  }

  String _deckImportResultTitle() {
    return _isItalianUi() ? 'Risultato import' : 'Import result';
  }

  String _deckImportNotFoundTitle() {
    return _isItalianUi() ? 'Carte non trovate' : 'Cards not found';
  }

  String _deckExportedSummaryLabel(String fileName) {
    if (_isItalianUi()) {
      return 'Mazzo esportato: $fileName';
    }
    return 'Deck exported: $fileName';
  }

  String _deckImportFailedLabel(Object error) {
    if (_isItalianUi()) {
      return 'Import mazzo non riuscito: $error';
    }
    return 'Deck import failed: $error';
  }

  String _deckExportFailedLabel(Object error) {
    if (_isItalianUi()) {
      return 'Export mazzo non riuscito: $error';
    }
    return 'Deck export failed: $error';
  }

  Future<_DeckImportSource?> _pickDeckImportSource() async {
    final result = await FilePicker.platform.pickFiles(
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

  Future<T> _runWithBlockingDialog<T>({
    required String message,
    required Future<T> Function() action,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
      },
    );
    try {
      return await action();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _showDeckImportResultDialog(_DeckImportResult result) async {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final missingPreview = result.notFoundCards
        .take(12)
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_deckImportResultTitle()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_deckImportedSummaryLabel(result.imported, result.skipped)),
              if (missingPreview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _deckImportNotFoundTitle(),
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...missingPreview.map((name) => Text('- $name')),
                if (result.notFoundCards.length > missingPreview.length)
                  Text(
                    _isItalianUi()
                        ? '...e altre ${result.notFoundCards.length - missingPreview.length}'
                        : '...and ${result.notFoundCards.length - missingPreview.length} more',
                    style: Theme.of(dialogContext).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFFBFAE95)),
                  ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
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

  Future<void> _showCreateCollectionOptions(BuildContext context) async {
    final canCreateSet = _canCreateCollection() && _canCreateSetCollection();
    final canCreateCustom =
        _canCreateCollection() && _canCreateCustomCollection();
    final canCreateSmart =
        _canCreateCollection() && _canCreateCustomCollection();
    final canCreateDeck = _canCreateCollection() && _canCreateDeckCollection();
    final selection = await showModalBottomSheet<_CollectionCreateAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CreateCollectionSheet(
          canCreateSet: canCreateSet,
          canCreateCustom: canCreateCustom,
          canCreateSmart: canCreateSmart,
          canCreateDeck: canCreateDeck,
        );
      },
    );
    if (!context.mounted) {
      return;
    }
    if (selection == _CollectionCreateAction.custom) {
      await _addCustomCollection(context);
    } else if (selection == _CollectionCreateAction.smart) {
      await _addSmartCollection(context);
    } else if (selection == _CollectionCreateAction.setBased) {
      await _addSetCollection(context);
    } else if (selection == _CollectionCreateAction.deck) {
      await _addDeckCollection(context);
    }
  }

  Future<void> _showHomeAddOptions(BuildContext context) async {
    final canCreateWishlist = _canCreateCollection() && _canCreateWishlist();
    final selection = await showModalBottomSheet<_HomeAddAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _HomeAddSheet(canCreateWishlist: canCreateWishlist),
    );
    if (!context.mounted) {
      return;
    }
    if (selection == _HomeAddAction.addByScan) {
      await _onScanCardPressed();
    } else if (selection == _HomeAddAction.addCards) {
      await _openAddCardsForAllCards(context);
    } else if (selection == _HomeAddAction.addCollection) {
      await _showCreateCollectionOptions(context);
    } else if (selection == _HomeAddAction.addWishlist) {
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
        MaterialPageRoute(builder: (_) => const _CardScannerPage()),
      );
      if (!mounted || recognizedText == null) {
        return;
      }
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
      final resolved = await _resolveSeedWithPrintingPicker(refinedSeed);
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
        final added = await _addCardToAllCards(resolved.pickedCard!.id);
        if (!mounted || !added) {
          return;
        }
        keepScanning = await _askScanAnotherCard();
        continue;
      }
      final added = await _openScannedCardSearch(
        query: resolved.seed.query,
        initialSetCode: resolved.seed.setCode,
        initialCollectorNumber: resolved.seed.collectorNumber,
      );
      if (!mounted || !added) {
        return;
      }
      keepScanning = await _askScanAnotherCard();
    }
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

  Future<void> _showFreeScanLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.dailyScanLimitReachedTitle),
          content: Text(l10n.freePlan20ScansUpgradePlusBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ProPage()));
              },
              child: Text(l10n.discoverPlus),
            ),
          ],
        );
      },
    );
  }

  Future<_ResolvedScanSelection> _resolveSeedWithPrintingPicker(
    _OcrSearchSeed seed,
  ) async {
    final cardName = seed.cardName?.trim();
    if (cardName == null || cardName.isEmpty) {
      return _ResolvedScanSelection(seed: seed);
    }
    final localBeforeSync = await ScryfallDatabase.instance
        .fetchCardsForAdvancedFilters(
          CollectionFilter(name: cardName),
          languages: const ['en'],
          limit: 250,
        );
    final normalizedName = _normalizeCardNameForMatch(cardName);
    final localBeforeSyncKeys = localBeforeSync
        .where(
          (card) => _normalizeCardNameForMatch(card.name) == normalizedName,
        )
        .map(_printingKeyForCard)
        .toSet();
    // Keep scan flow snappy: avoid long blocking sync for cards with many printings.
    if (localBeforeSyncKeys.length < 4) {
      await _syncOnlinePrintsByName(
        cardName,
        timeBudget: const Duration(seconds: 2),
      );
    }
    if (!mounted) {
      return _ResolvedScanSelection(seed: seed);
    }
    var picked = await _pickCardPrintingForName(
      context,
      cardName,
      preferredSetCode: seed.setCode,
      preferredCollectorNumber: seed.collectorNumber,
      localPrintingKeys: localBeforeSyncKeys,
    );
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
        picked = await _pickCardPrintingForName(
          context,
          cardName,
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
                          card.imageUri != null &&
                              card.imageUri!.trim().isNotEmpty
                          ? Image.network(
                              card.imageUri!.trim(),
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

  Future<bool> _addCardToAllCards(String cardId) async {
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
    await InventoryService.instance.addToInventory(cardId, deltaQty: 1);
    if (!mounted) {
      return false;
    }
    showAppSnackBar(context, AppLocalizations.of(context)!.addedCards(1));
    await _loadCollections();
    return true;
  }

  Future<Set<String>> _fetchKnownSetCodes() async {
    final sets = await ScryfallDatabase.instance.fetchAvailableSets();
    return sets
        .map((set) => set.code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  _OcrSearchSeed? _buildOcrSearchSeed(
    String rawText, {
    required Set<String> knownSetCodes,
  }) {
    var text = rawText.trim();
    String? forcedName;
    String? forcedSet;
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
    );
  }

  Future<_OcrSearchSeed> _refineOcrSeed(_OcrSearchSeed seed) async {
    final query = seed.query.trim();
    final setCode = seed.setCode?.trim().toLowerCase();
    final fallbackName = seed.cardName?.trim();
    if (query.isEmpty) {
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final onlineByName = await _tryOnlineCardFallbackByName(fallbackName);
        if (onlineByName != null) {
          return onlineByName;
        }
      }
      return seed;
    }
    if (setCode == null || setCode.isEmpty) {
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final onlineByName = await _tryOnlineCardFallbackByName(fallbackName);
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
      );
      if (onlineByNameAndSet != null) {
        return onlineByNameAndSet;
      }
    }
    final strictCount = await ScryfallDatabase.instance
        .countCardsForFilterWithSearch(
          CollectionFilter(sets: {setCode}),
          searchQuery: query,
        );
    if (strictCount > 0) {
      // Guard against false positives when collector OCR is wrong but exists in same set.
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final nameInSetCount = await ScryfallDatabase.instance
            .countCardsForFilterWithSearch(
              CollectionFilter(sets: {setCode}),
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
      final onlineByName = await _tryOnlineCardFallbackByName(fallbackName);
      if (onlineByName != null) {
        return onlineByName;
      }
    }
    if (fallbackName != null && fallbackName.isNotEmpty) {
      final nameInSetCount = await ScryfallDatabase.instance
          .countCardsForFilterWithSearch(
            CollectionFilter(sets: {setCode}),
            searchQuery: fallbackName,
          );
      if (nameInSetCount > 0) {
        return _OcrSearchSeed(
          query: fallbackName,
          cardName: fallbackName,
          setCode: setCode,
          collectorNumber: seed.collectorNumber,
        );
      }
      return _OcrSearchSeed(
        query: fallbackName,
        cardName: fallbackName,
        setCode: null,
        collectorNumber: seed.collectorNumber,
      );
    }
    return _OcrSearchSeed(
      query: query,
      cardName: seed.cardName,
      setCode: null,
      collectorNumber: seed.collectorNumber,
    );
  }

  Future<_OcrSearchSeed?> _tryOnlineCardFallbackByName(String cardName) async {
    final name = cardName.trim();
    if (name.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse(
        'https://api.scryfall.com/cards/named?exact=${Uri.encodeQueryComponent(name)}',
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
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncOnlinePrintsByName(
    String cardName, {
    Duration timeBudget = const Duration(seconds: 2),
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
      Uri searchUri;
      if (oracleId != null && oracleId.isNotEmpty) {
        searchUri = Uri.parse(
          'https://api.scryfall.com/cards/search?q=${Uri.encodeQueryComponent('oracleid:$oracleId lang:en unique:prints')}&order=released&dir=desc',
        );
      } else {
        searchUri = Uri.parse(
          'https://api.scryfall.com/cards/search?q=${Uri.encodeQueryComponent('!"$name" lang:en unique:prints')}&order=released&dir=desc',
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
  }) async {
    final name = cardName.trim();
    final set = setCode.trim().toLowerCase();
    if (name.isEmpty || set.isEmpty) {
      return null;
    }
    try {
      final query = '!"$name" set:$set lang:en unique:prints';
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
            CollectionFilter(name: name, sets: {set}),
            languages: const ['en'],
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
        query: selected?.name ?? name,
        cardName: selected?.name ?? name,
        setCode: set,
        collectorNumber: selected != null
            ? _normalizeCollectorForComparison(selected.collectorNumber)
            : _normalizeCollectorForComparison(preferredCollectorNumber ?? ''),
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

  Future<bool> _openScannedCardSearch({
    required String query,
    String? initialSetCode,
    String? initialCollectorNumber,
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
    final selection = await showModalBottomSheet<_CardSearchSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardSearchSheet(
        initialQuery: query,
        initialSetCode: initialSetCode,
        initialCollectorNumber: initialCollectorNumber,
      ),
    );
    if (!mounted || selection == null) {
      return false;
    }

    if (selection.isBulk) {
      for (final cardId in selection.cardIds) {
        await InventoryService.instance.addToInventory(cardId, deltaQty: 1);
      }
    } else {
      await InventoryService.instance.addToInventory(
        selection.cardIds.first,
        deltaQty: 1,
      );
    }
    if (!mounted) {
      return false;
    }
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.addedCards(selection.count),
    );
    await _loadCollections();
    return true;
  }

  Future<bool> _askScanAnotherCard() async {
    final l10n = AppLocalizations.of(context)!;
    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cardAddedTitle),
        content: Text(l10n.scanAnotherCardQuestion),
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
      ),
    );
    return again ?? false;
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
    final isSmartCollection = collection.type == CollectionType.smart;
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
    if (isSmartCollection) {
      menuItems.add(
        PopupMenuItem(
          value: _CollectionAction.editFilter,
          child: Row(
            children: [
              const Icon(Icons.tune, size: 18),
              const SizedBox(width: 8),
              Text(
                _isItalianUi()
                    ? 'Modifica filtro'
                    : 'Edit filter',
              ),
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
    } else if (selection == _CollectionAction.editFilter) {
      await _editSmartCollectionFilter(collection);
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
    if (_isCollectionNameTaken(resolvedName, excludeCollectionId: collection.id)) {
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

  Future<void> _editSmartCollectionFilter(CollectionInfo collection) async {
    if (collection.type != CollectionType.smart) {
      return;
    }
    final isItalian = _isItalianUi();
    final updatedFilter = await Navigator.of(context).push<CollectionFilter>(
      MaterialPageRoute(
        builder: (_) => _CollectionFilterBuilderPage(
          name: collection.name,
          submitLabel: isItalian ? 'Salva filtro' : 'Save filter',
          initialFilter: collection.filter,
        ),
      ),
    );
    if (!mounted || updatedFilter == null) {
      return;
    }
    if (!_hasAtLeastOneSmartFilter(updatedFilter)) {
      showAppSnackBar(
        context,
        isItalian
            ? 'Imposta almeno un filtro.'
            : 'Choose at least one filter.',
      );
      return;
    }
    await ScryfallDatabase.instance.updateCollectionFilter(
      collection.id,
      filter: updatedFilter,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      final index = _collections.indexWhere((item) => item.id == collection.id);
      if (index != -1) {
        _collections[index] = CollectionInfo(
          id: collection.id,
          name: collection.name,
          cardCount: collection.cardCount,
          type: collection.type,
          filter: updatedFilter,
        );
      }
    });
    await _loadCollections();
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
    showAppSnackBar(context, AppLocalizations.of(context)!.collectionDeleted);
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

        final totalBytes = response.contentLength ?? 0;
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
      final message = (error is HttpException || error is SocketException)
          ? l10n.networkErrorTryAgain
          : l10n.downloadFailedGeneric;
      setState(() {
        _bulkDownloading = false;
        _bulkDownloadError = message;
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
    const allowedLanguages = {'en'};
    setState(() {
      _bulkImporting = true;
      _bulkImportProgress = 0;
      _bulkImportedCount = 0;
    });

    try {
      final importer = ScryfallBulkImporter();
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
          });
        },
      );

      if (!mounted) {
        return;
      }
      await _rebuildSearchIndex();

      if (!mounted) {
        return;
      }
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkImporting = false;
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.importFailed('import_failed'))),
        );
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

  Widget _buildGameSelector() {
    final gameInitial = _selectedHomeGame == TcgGame.mtg ? 'M' : 'P';
    return PopupMenuButton<TcgGame>(
      initialValue: _selectedHomeGame,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      tooltip: 'Game selector (preview)',
      onSelected: (TcgGame selected) async {
        if (selected == _selectedHomeGame) {
          return;
        }
        final hasAccess = await _ensureGameAccessFresh(selected);
        if (!hasAccess) {
          if (!mounted) {
            return;
          }
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
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
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pokemonLocked =
        !_isMtgActiveGame && !_isGameUnlocked(TcgGame.pokemon);
    final isBlockingSync = _bulkDownloading || _bulkImporting;
    final blockingLabel = _bulkDownloading
        ? (_bulkDownloadTotal > 0
              ? l10n.downloadingWithPercent(
                  (_bulkDownloadProgress * 100).clamp(0, 100).round(),
                )
              : l10n.downloading)
        : l10n.importingCardsWithCount(
            (_bulkImportProgress * 100).clamp(0, 100).round(),
            _bulkImportedCount,
          );
    final bulkLabel = _bulkTypeLabel(l10n, _selectedBulkType);
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
                                _activeCollectionsMenu == _HomeCollectionsMenu.home,
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
                          _ProPreviewToggleButton(
                            proModeActive: _hasRealProAccess && !_forceFreePreview,
                            enabled: _hasRealProAccess,
                            onTap: _toggleProPreviewMode,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: l10n.settings,
                            style: IconButton.styleFrom(
                              foregroundColor: const Color(0xFFE9C46A),
                            ),
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsPage(),
                                    ),
                                  )
                                  .then((_) {
                                    if (mounted) {
                                      _initializeEnvironmentAndData();
                                    }
                                  });
                            },
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
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isMtgActiveGame
                                  ? (_bulkDownloadTotal > 0
                                        ? l10n.downloadingUpdateWithTotal(
                                            (_bulkDownloadProgress * 100)
                                                .clamp(0, 100)
                                                .round(),
                                            _formatBytes(_bulkDownloadReceived),
                                            _formatBytes(_bulkDownloadTotal),
                                          )
                                        : l10n.downloadingUpdateNoTotal(
                                            _formatBytes(_bulkDownloadReceived),
                                          ))
                                  : (_isItalianUi()
                                        ? 'Download database Pokemon ${(_bulkDownloadProgress * 100).clamp(0, 100).round()}%'
                                        : 'Downloading Pokemon database ${(_bulkDownloadProgress * 100).clamp(0, 100).round()}%'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFE3B55C)),
                            ),
                            if (!_isMtgActiveGame &&
                                _pokemonSyncStatus != null &&
                                _pokemonSyncStatus!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _pokemonSyncStatus!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFFBFAE95)),
                              ),
                            ],
                          ],
                        )
                      else if (_bulkImporting)
                        Text(
                          _isMtgActiveGame
                              ? l10n.importingCardsWithCount(
                                  (_bulkImportProgress * 100)
                                      .clamp(0, 100)
                                      .round(),
                                  _bulkImportedCount,
                                )
                              : (_isItalianUi()
                                    ? 'Import carte Pokemon ${(_bulkImportProgress * 100).clamp(0, 100).round()}%'
                                    : 'Importing Pokemon cards ${(_bulkImportProgress * 100).clamp(0, 100).round()}%'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFE3B55C)),
                        )
                      else if (_bulkDownloadError != null)
                        Text(
                          _isMtgActiveGame
                              ? l10n.downloadFailedTapUpdate
                              : (_bulkDownloadError!.trim().isEmpty
                                    ? l10n.downloadFailedGeneric
                                    : _bulkDownloadError!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFE38B5C)),
                        )
                      else if (_cardsMissing)
                        Text(
                          _isMtgActiveGame
                              ? (_selectedBulkType == null
                                    ? l10n.selectDatabaseToDownload
                                    : l10n.databaseMissingDownloadRequired(
                                        bulkLabel,
                                      ))
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
                          label: Text(_isItalianUi() ? 'Riprova' : 'Retry'),
                        ),
                      ],
                      if (_bulkDownloading || _bulkImporting)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _SnakeProgressBar(
                            animation: _snakeController,
                            value: _bulkDownloading
                                ? _bulkDownloadProgress
                                : _bulkImportProgress,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _initialCollectionsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                          children: [..._buildCollectionSections(context)],
                        ),
                ),
              ],
            ),
          ),
          if (pokemonLocked)
            Positioned.fill(
              child: Container(
                color: const Color(0xC20E0A08),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1511),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF5D4731)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFFE9C46A),
                            size: 30,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isItalianUi()
                                ? 'Pokemon disponibile nella versione Pro'
                                : 'Pokemon available in Pro',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isItalianUi()
                                ? 'Sblocca Pokemon dalle impostazioni per usare collezioni, ricerca e download del database dedicato.'
                                : 'Unlock Pokemon from Settings to use collections, search, and dedicated database download.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: Text(
                              _isItalianUi()
                                  ? 'Apri impostazioni'
                                  : 'Open settings',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (isBlockingSync) ...[
            const ModalBarrier(dismissible: false, color: Color(0x880E0A08)),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 86),
                  child: Chip(
                    avatar: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: Text(blockingLabel),
                    backgroundColor: const Color(0xFFE9C46A),
                    labelStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(
                          color: const Color(0xFF1C1510),
                          fontWeight: FontWeight.w700,
                        ),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ),
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
  const _HomeIconButton({
    required this.selected,
    required this.onTap,
  });

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

class _ProPreviewToggleButton extends StatelessWidget {
  const _ProPreviewToggleButton({
    required this.proModeActive,
    required this.enabled,
    required this.onTap,
  });

  final bool proModeActive;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: proModeActive
                ? const Color(0xFFE9C46A).withValues(alpha: 0.18)
                : (enabled ? const Color(0x221D1712) : const Color(0x1A1D1712)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: !enabled
                  ? const Color(0xFF3E3327)
                  : proModeActive
                  ? const Color(0xFFE9C46A)
                  : const Color(0xFF5D4731),
            ),
          ),
          child: Text(
            enabled ? (proModeActive ? 'PRO' : 'FREE') : 'PRO',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: !enabled
                  ? const Color(0xFF8E7A62)
                  : proModeActive
                  ? const Color(0xFFEFD28B)
                  : const Color(0xFFBFAE95),
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
                border: enabled ? null : Border.all(color: const Color(0x665D4731)),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFBFAE95),
                              ),
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
                              border: Border.all(color: const Color(0xFFE16464)),
                            ),
                            child: Text(
                              disabledTag!,
                              style:
                                  Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: const Color(0xFFFFD2D2),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11.5,
                                        letterSpacing: 0.8,
                                      ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.lock_outline, color: Color(0xFFBFAE95)),
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
  const _HomeAddSheet({required this.canCreateWishlist});

  final bool canCreateWishlist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.addTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: Text(l10n.addViaScanTitle),
            subtitle: Text(l10n.scanCardWithLiveOcrSubtitle),
            onTap: () => Navigator.of(context).pop(_HomeAddAction.addByScan),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text(l10n.addCards),
            subtitle: Text(l10n.addCardsToCatalogSubtitle),
            onTap: () => Navigator.of(context).pop(_HomeAddAction.addCards),
          ),
          ListTile(
            leading: const Icon(Icons.collections_bookmark),
            title: Text(l10n.addCollection),
            subtitle: Text(l10n.addCollectionSubtitle),
            onTap: () =>
                Navigator.of(context).pop(_HomeAddAction.addCollection),
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
                  ? () => Navigator.of(context).pop(_HomeAddAction.addWishlist)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionFilterBuilderPage extends StatefulWidget {
  const _CollectionFilterBuilderPage({
    required this.name,
    this.submitLabel,
    this.initialFilter,
  });

  final String name;
  final String? submitLabel;
  final CollectionFilter? initialFilter;

  @override
  State<_CollectionFilterBuilderPage> createState() =>
      _CollectionFilterBuilderPageState();
}

class _CollectionFilterBuilderPageState
    extends State<_CollectionFilterBuilderPage> {
  bool get _isPokemonActive =>
      TcgEnvironmentController.instance.currentGame == TcgGame.pokemon;

  List<String> get _knownTypes => _isPokemonActive
      ? const [
          'Pokemon',
          'Trainer',
          'Energy',
          'Item',
          'Supporter',
          'Stadium',
          'Tool',
        ]
      : const [
          'Artifact',
          'Creature',
          'Enchantment',
          'Instant',
          'Land',
          'Planeswalker',
          'Sorcery',
          'Battle',
          'Tribal',
        ];

  List<String> get _rarityOrder => _isPokemonActive
      ? const ['common', 'uncommon', 'rare', 'holo rare', 'ultra rare', 'promo']
      : const ['common', 'uncommon', 'rare', 'mythic'];

  List<String> get _colorOrder => _isPokemonActive
      ? const ['G', 'R', 'L', 'U', 'B', 'F', 'D', 'W', 'C', 'M', 'N']
      : const ['W', 'U', 'B', 'R', 'G', 'C'];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _manaMinController = TextEditingController();
  final TextEditingController _manaMaxController = TextEditingController();

  final Set<String> _selectedSets = {};
  final Set<String> _selectedRarities = {};
  final Set<String> _selectedColors = {};
  final Set<String> _selectedTypes = {};

  List<SetInfo> _availableSets = [];
  bool _loadingSets = true;
  String _setQuery = '';

  bool _previewLoading = false;
  int? _previewTotal;
  List<CardSearchResult> _previewCards = [];

  Timer? _previewDebounce;
  Timer? _artistDebounce;
  List<String> _artistSuggestions = [];
  bool _loadingArtists = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFilter;
    if (initial != null) {
      _nameController.text = initial.name?.trim() ?? '';
      _artistController.text = initial.artist?.trim() ?? '';
      if (initial.manaMin != null) {
        _manaMinController.text = initial.manaMin!.toString();
      }
      if (initial.manaMax != null) {
        _manaMaxController.text = initial.manaMax!.toString();
      }
      _selectedSets.addAll(
        initial.sets.map((value) => value.trim().toLowerCase()),
      );
      _selectedRarities.addAll(
        initial.rarities.map((value) => value.trim().toLowerCase()),
      );
      _selectedColors.addAll(
        initial.colors.map((value) => value.trim().toUpperCase()),
      );
      _selectedTypes.addAll(
        initial.types.map((value) => value.trim()).where((value) => value.isNotEmpty),
      );
    }
    _loadSets();
    _schedulePreviewUpdate();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _artistDebounce?.cancel();
    _nameController.dispose();
    _artistController.dispose();
    _manaMinController.dispose();
    _manaMaxController.dispose();
    super.dispose();
  }

  Future<void> _loadSets() async {
    final sets = await ScryfallDatabase.instance.fetchAvailableSets();
    if (!mounted) {
      return;
    }
    setState(() {
      _availableSets = sets;
      _loadingSets = false;
    });
  }

  void _schedulePreviewUpdate() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _refreshPreview();
    });
  }

  void _onArtistChanged(String value) {
    _artistDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _artistSuggestions = [];
        _loadingArtists = false;
      });
      _schedulePreviewUpdate();
      return;
    }
    _artistDebounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() {
        _loadingArtists = true;
      });
      final results = await ScryfallDatabase.instance.fetchAvailableArtists(
        query: query,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _artistSuggestions = results;
        _loadingArtists = false;
      });
    });
    _schedulePreviewUpdate();
  }

  CollectionFilter _buildFilter() {
    int? minValue = int.tryParse(_manaMinController.text.trim());
    int? maxValue = int.tryParse(_manaMaxController.text.trim());
    if (minValue != null && maxValue != null && minValue > maxValue) {
      final swap = minValue;
      minValue = maxValue;
      maxValue = swap;
    }
    final name = _nameController.text.trim();
    final artist = _artistController.text.trim();
    return CollectionFilter(
      name: name.isEmpty ? null : name,
      artist: artist.isEmpty ? null : artist,
      manaMin: minValue,
      manaMax: maxValue,
      sets: _selectedSets,
      rarities: _selectedRarities,
      colors: _selectedColors,
      types: _selectedTypes,
    );
  }

  bool _hasCriteria(CollectionFilter filter) {
    return (filter.name?.trim().isNotEmpty ?? false) ||
        (filter.artist?.trim().isNotEmpty ?? false) ||
        filter.manaMin != null ||
        filter.manaMax != null ||
        filter.sets.isNotEmpty ||
        filter.rarities.isNotEmpty ||
        filter.colors.isNotEmpty ||
        filter.types.isNotEmpty;
  }

  Future<void> _refreshPreview() async {
    final filter = _buildFilter();
    if (!_hasCriteria(filter)) {
      setState(() {
        _previewLoading = false;
        _previewTotal = null;
        _previewCards = [];
      });
      return;
    }
    setState(() {
      _previewLoading = true;
    });
    final total = await ScryfallDatabase.instance.countCardsForFilter(filter);
    final cards = await ScryfallDatabase.instance.fetchFilteredCardPreviews(
      filter,
      limit: 30,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _previewTotal = total;
      _previewCards = cards;
      _previewLoading = false;
    });
  }

  String _colorLabel(String code) {
    final l10n = AppLocalizations.of(context)!;
    if (_isPokemonActive) {
      switch (code.toUpperCase()) {
        case 'G':
          return _isItalianUi() ? 'Erba' : 'Grass';
        case 'R':
          return _isItalianUi() ? 'Fuoco' : 'Fire';
        case 'U':
          return _isItalianUi() ? 'Acqua' : 'Water';
        case 'L':
          return _isItalianUi() ? 'Lampo' : 'Lightning';
        case 'B':
          return _isItalianUi() ? 'Psico/Oscurita' : 'Psychic/Darkness';
        case 'F':
          return _isItalianUi() ? 'Lotta' : 'Fighting';
        case 'D':
          return _isItalianUi() ? 'Drago' : 'Dragon';
        case 'W':
          return _isItalianUi() ? 'Folletto' : 'Fairy';
        case 'C':
          return _isItalianUi() ? 'Incolore' : 'Colorless';
        case 'M':
          return _isItalianUi() ? 'Metallo' : 'Metal';
        case 'N':
          return _isItalianUi() ? 'Nessuno' : 'None';
        default:
          return code.toUpperCase();
      }
    }
    switch (code.toUpperCase()) {
      case 'W':
        return l10n.colorWhite;
      case 'U':
        return l10n.colorBlue;
      case 'B':
        return l10n.colorBlack;
      case 'R':
        return l10n.colorRed;
      case 'G':
        return l10n.colorGreen;
      case 'C':
        return l10n.colorColorless;
      default:
        return code.toUpperCase();
    }
  }

  String _typeLabel(String value) {
    if (!_isPokemonActive) {
      return value;
    }
    final isIt = _isItalianUi();
    switch (value) {
      case 'Pokemon':
        return 'Pokemon';
      case 'Trainer':
        return isIt ? 'Allenatore' : 'Trainer';
      case 'Energy':
        return isIt ? 'Energia' : 'Energy';
      case 'Item':
        return isIt ? 'Oggetto' : 'Item';
      case 'Supporter':
        return isIt ? 'Aiuto' : 'Supporter';
      case 'Stadium':
        return isIt ? 'Stadio' : 'Stadium';
      case 'Tool':
        return isIt ? 'Strumento Pokemon' : 'Pokemon Tool';
      default:
        return value;
    }
  }

  bool _isItalianUi() {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return code.startsWith('it');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filter = _buildFilter();
    final hasCriteria = _hasCriteria(filter);
    final filteredSets = _setQuery.isEmpty
        ? <SetInfo>[]
        : _availableSets
              .where(
                (set) =>
                    set.name.toLowerCase().contains(_setQuery.toLowerCase()) ||
                    set.code.toLowerCase().contains(_setQuery.toLowerCase()),
              )
              .toList();
    final sortedRarities = _rarityOrder;
    final sortedColors = _colorOrder;

    Widget buildChipRow<T>(
      Iterable<T> items,
      bool Function(T) isSelected,
      void Function(T) toggle,
      String Function(T) label,
    ) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (item) => FilterChip(
                label: Text(label(item)),
                selected: isSelected(item),
                onSelected: (_) => setState(() => toggle(item)),
              ),
            )
            .toList(),
      );
    }

    Widget buildSelectedChips(
      Iterable<String> items,
      void Function(String) remove,
    ) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (item) => InputChip(
                label: Text(item),
                onDeleted: () => setState(() => remove(item)),
              ),
            )
            .toList(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text(
            l10n.searchCardsHint,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: l10n.typeCardNameHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) => _schedulePreviewUpdate(),
          ),
          const SizedBox(height: 16),
          Text(l10n.setLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_selectedSets.isNotEmpty) ...[
            buildSelectedChips(_selectedSets, (value) {
              _selectedSets.remove(value);
              _schedulePreviewUpdate();
            }),
            const SizedBox(height: 8),
          ],
          TextField(
            decoration: InputDecoration(
              hintText: l10n.searchSetHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _setQuery = value.trim();
              });
            },
          ),
          if (_setQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (_loadingSets)
              const Center(child: CircularProgressIndicator())
            else if (filteredSets.isEmpty)
              Text(l10n.noResultsFound)
            else
              SizedBox(
                height: filteredSets.length > 8 ? 200 : null,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredSets.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final set = filteredSets[index];
                    return ListTile(
                      title: Text(set.name),
                      subtitle: Text(set.code.toUpperCase()),
                      onTap: () {
                        setState(() {
                          _selectedSets.add(set.code.toLowerCase());
                          _setQuery = '';
                        });
                        _schedulePreviewUpdate();
                      },
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(l10n.rarity, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          buildChipRow<String>(
            sortedRarities,
            (value) => _selectedRarities.contains(value),
            (value) {
              if (!_selectedRarities.add(value)) {
                _selectedRarities.remove(value);
              }
              _schedulePreviewUpdate();
            },
            (value) => _formatRarity(value),
          ),
          const SizedBox(height: 16),
          Text(
            _isPokemonActive
                ? (_isItalianUi() ? 'Tipo energia' : 'Energy type')
                : l10n.colorLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          buildChipRow<String>(
            sortedColors,
            (value) => _selectedColors.contains(value),
            (value) {
              if (!_selectedColors.add(value)) {
                _selectedColors.remove(value);
              }
              _schedulePreviewUpdate();
            },
            (value) => _colorLabel(value),
          ),
          const SizedBox(height: 16),
          Text(
            _isPokemonActive
                ? (_isItalianUi() ? 'Categoria carta' : 'Card category')
                : l10n.typeLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          buildChipRow<String>(
            _knownTypes,
            (value) => _selectedTypes.contains(value),
            (value) {
              if (!_selectedTypes.add(value)) {
                _selectedTypes.remove(value);
              }
              _schedulePreviewUpdate();
            },
            (value) => _typeLabel(value),
          ),
          const SizedBox(height: 16),
          Text(
            _isPokemonActive
                ? (_isItalianUi()
                      ? 'Costo energia (attacco)'
                      : 'Attack energy cost')
                : l10n.manaValue,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manaMinController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: l10n.minLabel),
                  onChanged: (_) => _schedulePreviewUpdate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _manaMaxController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: l10n.maxLabel),
                  onChanged: (_) => _schedulePreviewUpdate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.detailArtist,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _artistController,
            decoration: InputDecoration(
              hintText: l10n.typeArtistNameHint,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            onChanged: _onArtistChanged,
          ),
          if (_artistController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            if (_loadingArtists)
              const Center(child: CircularProgressIndicator())
            else if (_artistSuggestions.isNotEmpty)
              SizedBox(
                height: _artistSuggestions.length > 6 ? 180 : null,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _artistSuggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final artist = _artistSuggestions[index];
                    return ListTile(
                      title: Text(artist),
                      onTap: () {
                        setState(() {
                          _artistController.text = artist;
                          _artistController.selection = TextSelection.collapsed(
                            offset: artist.length,
                          );
                          _artistSuggestions = [];
                        });
                        _schedulePreviewUpdate();
                      },
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_buildFilter()),
                child: Text(
                  widget.submitLabel ?? l10n.create,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.cardCount(_previewTotal ?? 0),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (!hasCriteria)
            Text(l10n.selectFiltersFirst)
          else if (_previewLoading)
            const Center(child: CircularProgressIndicator())
          else if (_previewCards.isEmpty)
            Text(l10n.noResultsFound)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _previewCards.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final card = _previewCards[index];
                return ListTile(
                  leading: _buildSetIcon(card.setCode, size: 20),
                  title: Text(card.name),
                  subtitle: Text(card.subtitleLabel),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CreateCollectionSheet extends StatelessWidget {
  const _CreateCollectionSheet({
    required this.canCreateSet,
    required this.canCreateCustom,
    required this.canCreateSmart,
    required this.canCreateDeck,
  });

  final bool canCreateSet;
  final bool canCreateCustom;
  final bool canCreateSmart;
  final bool canCreateDeck;

  Widget _buildCreateOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: enabled
            ? Text(subtitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.upgradeToPro,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFE9C46A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(subtitle),
                ],
              ),
        onTap: enabled ? onTap : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.createCollectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildCreateOption(
            context,
            icon: Icons.auto_awesome_mosaic,
            title: l10n.setCollectionTitle,
            subtitle: l10n.setCollectionSubtitle,
            enabled: canCreateSet,
            onTap: () =>
                Navigator.of(context).pop(_CollectionCreateAction.setBased),
          ),
          _buildCreateOption(
            context,
            icon: Icons.tune,
            title: l10n.customCollectionTitle,
            subtitle: l10n.customCollectionSubtitle,
            enabled: canCreateCustom,
            onTap: () =>
                Navigator.of(context).pop(_CollectionCreateAction.custom),
          ),
          _buildCreateOption(
            context,
            icon: Icons.auto_fix_high_rounded,
            title: _isItalianUi(context)
                ? 'Smart collection'
                : 'Smart collection',
            subtitle: _isItalianUi(context)
                ? 'Salva un filtro dinamico e mostra solo le carte possedute.'
                : 'Save a dynamic filter and show only owned cards.',
            enabled: canCreateSmart,
            onTap: () =>
                Navigator.of(context).pop(_CollectionCreateAction.smart),
          ),
          _buildCreateOption(
            context,
            icon: Icons.view_carousel_rounded,
            title: l10n.deckCollectionTitle,
            subtitle: l10n.deckCollectionSubtitle,
            enabled: canCreateDeck,
            onTap: () =>
                Navigator.of(context).pop(_CollectionCreateAction.deck),
          ),
        ],
      ),
    );
  }

  bool _isItalianUi(BuildContext context) {
    return Localizations.localeOf(context)
        .languageCode
        .toLowerCase()
        .startsWith('it');
  }
}

class _OcrSearchSeed {
  const _OcrSearchSeed({
    required this.query,
    this.cardName,
    this.setCode,
    this.collectorNumber,
  });

  final String query;
  final String? cardName;
  final String? setCode;
  final String? collectorNumber;
}

class _ResolvedScanSelection {
  const _ResolvedScanSelection({required this.seed, this.pickedCard});

  final _OcrSearchSeed seed;
  final CardSearchResult? pickedCard;
}

enum _ScanPreviewAction { add, retry }

Future<CardSearchResult?> _pickCardPrintingForName(
  BuildContext context,
  String cardName, {
  String? preferredSetCode,
  String? preferredCollectorNumber,
  Set<String> localPrintingKeys = const {},
}) async {
  final normalizedTarget = _normalizeCardNameForMatch(cardName);
  if (normalizedTarget.isEmpty) {
    return null;
  }
  var results = await ScryfallDatabase.instance.fetchCardsForAdvancedFilters(
    CollectionFilter(name: cardName),
    languages: const ['en'],
    limit: 250,
  );
  if (results.isEmpty) {
    results = await ScryfallDatabase.instance.searchCardsByName(
      cardName,
      limit: 120,
      languages: const ['en'],
    );
  }
  if (results.isEmpty) {
    return null;
  }
  final exact = results
      .where(
        (card) => _normalizeCardNameForMatch(card.name) == normalizedTarget,
      )
      .toList(growable: false);
  final candidates = exact.isNotEmpty ? exact : results;
  final byPrinting = <String, CardSearchResult>{};
  for (final card in candidates) {
    final key =
        '${card.name.toLowerCase()}|${card.setCode.toLowerCase()}|${card.collectorNumber.toLowerCase()}';
    byPrinting.putIfAbsent(key, () => card);
  }
  final unique = byPrinting.values.toList(growable: false);
  if (unique.isEmpty) {
    return null;
  }
  final localKeys = localPrintingKeys;
  final localCandidates = localKeys.isEmpty
      ? unique
      : unique
            .where((card) => localKeys.contains(_printingKeyForCard(card)))
            .toList(growable: false);
  final onlineCandidates = localKeys.isEmpty
      ? <CardSearchResult>[]
      : unique
            .where((card) => !localKeys.contains(_printingKeyForCard(card)))
            .toList(growable: false);
  final preferredSet = preferredSetCode?.trim().toLowerCase();
  var effectivePreferredSet = preferredSet;
  if (effectivePreferredSet != null &&
      effectivePreferredSet.isNotEmpty &&
      !unique.any(
        (card) => card.setCode.trim().toLowerCase() == effectivePreferredSet,
      )) {
    effectivePreferredSet = _approximateSetCodeForCandidates(
      effectivePreferredSet,
      unique.map((card) => card.setCode.trim().toLowerCase()),
    );
  }
  // Do not auto-pick when multiple printings exist:
  // always show chooser so user can select Local vs Online printing.
  if (!context.mounted) {
    return null;
  }
  return showModalBottomSheet<CardSearchResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PickPrintingSheet(
      cardName: unique.first.name,
      candidates: unique,
      localCandidates: localCandidates,
      onlineCandidates: onlineCandidates,
    ),
  );
}

String _normalizeCollectorForComparison(String value) {
  final raw = value.trim().toLowerCase();
  if (raw.isEmpty) {
    return '';
  }
  final match = RegExp(r'^0*(\d+)([a-z]?)$').firstMatch(raw);
  if (match == null) {
    return raw;
  }
  final number = match.group(1) ?? '';
  final suffix = match.group(2) ?? '';
  return '$number$suffix';
}

String? _approximateSetCodeForCandidates(
  String preferredSet,
  Iterable<String> candidateSetCodes,
) {
  final normalizedPreferred = preferredSet
      .trim()
      .toLowerCase()
      .replaceAll('0', 'o')
      .replaceAll('1', 'i')
      .replaceAll('5', 's')
      .replaceAll('8', 'b');
  if (normalizedPreferred.isEmpty) {
    return null;
  }
  String? best;
  var bestDistance = 999;
  for (final rawCandidate in candidateSetCodes) {
    final candidate = rawCandidate.trim().toLowerCase();
    if (candidate.isEmpty) {
      continue;
    }
    final distance = _levenshteinDistance(normalizedPreferred, candidate);
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  if (best == null) {
    return null;
  }
  return bestDistance <= 2 ? best : null;
}

int _levenshteinDistance(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }
  final prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final deletion = prev[j] + 1;
      final insertion = curr[j - 1] + 1;
      final substitution = prev[j - 1] + cost;
      var best = deletion < insertion ? deletion : insertion;
      if (substitution < best) {
        best = substitution;
      }
      curr[j] = best;
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = curr[j];
    }
  }
  return prev[b.length];
}

String _normalizeCardNameForMatch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9'\- ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _printingKeyForCard(CardSearchResult card) {
  return '${_normalizeCardNameForMatch(card.name)}|${card.setCode.trim().toLowerCase()}|${_normalizeCollectorForComparison(card.collectorNumber)}';
}

class _PickPrintingSheet extends StatelessWidget {
  const _PickPrintingSheet({
    required this.cardName,
    required this.candidates,
    this.localCandidates = const [],
    this.onlineCandidates = const [],
  });

  final String cardName;
  final List<CardSearchResult> candidates;
  final List<CardSearchResult> localCandidates;
  final List<CardSearchResult> onlineCandidates;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
              'Choose printing',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              cardName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFBFAE95)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: (candidates.length * 74.0).clamp(220.0, maxHeight),
              child: ListView(
                children: [
                  if (localCandidates.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Local'),
                    for (final card in localCandidates)
                      _buildPrintingTile(context, card),
                  ],
                  if (onlineCandidates.isNotEmpty) ...[
                    if (localCandidates.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                    _buildSectionHeader(context, 'Online'),
                    for (final card in onlineCandidates)
                      _buildPrintingTile(context, card),
                  ],
                  if (localCandidates.isEmpty && onlineCandidates.isEmpty)
                    for (final card in candidates)
                      _buildPrintingTile(context, card),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFFE9C46A),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildPrintingTile(BuildContext context, CardSearchResult card) {
    return ListTile(
      leading: _buildCardPreview(card),
      title: Text(
        card.setName.trim().isEmpty ? card.setCode.toUpperCase() : card.setName,
      ),
      subtitle: Text(card.collectorProgressLabel),
      trailing: _buildSetIcon(card.setCode, size: 32),
      onTap: () => Navigator.of(context).pop(card),
    );
  }

  Widget _buildCardPreview(CardSearchResult card) {
    final uri = card.imageUri?.trim();
    if (uri == null || uri.isEmpty) {
      return _buildSetIcon(card.setCode, size: 22);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 42,
        height: 58,
        child: Image.network(
          uri,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0x221C1713),
            alignment: Alignment.center,
            child: _buildSetIcon(card.setCode, size: 22),
          ),
        ),
      ),
    );
  }
}

class _CardScannerPage extends StatefulWidget {
  const _CardScannerPage();

  @override
  State<_CardScannerPage> createState() => _CardScannerPageState();
}

class _CardScannerPageState extends State<_CardScannerPage>
    with SingleTickerProviderStateMixin {
  static const double _cardAspectRatio = 64 / 96;
  static const bool _showCoverageBadgeInScanner = false;
  static const int _requiredStableHits = 3;
  static const int _requiredNameFieldHits = 2;
  static const int _requiredSetFieldHits = 3;
  static const int _setVoteWindow = 18;
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  late final AnimationController _pulseController;
  CameraController? _cameraController;
  bool _initializing = true;
  bool _handled = false;
  bool _processingFrame = false;
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastCandidateKey = '';
  int _stableHits = 0;
  String _bestStableRawText = '';
  String _lastNameCandidate = '';
  String _lastSetCandidate = '';
  int _nameHits = 0;
  int _setHits = 0;
  String _lockedName = '';
  String _lockedSet = '';
  String _namePreview = '';
  final List<String> _setVoteHistory = <String>[];
  final Map<String, int> _setVoteCounts = <String, int>{};
  Set<String> _knownSetCodes = const {};
  bool _torchEnabled = false;
  bool _torchAvailable = true;
  String _status = '';
  bool _limitedPrintCoverage = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    unawaited(_loadBulkCoverageState());
    unawaited(_loadKnownSetCodesForScanner());
    unawaited(_initializeCamera());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_status.isEmpty) {
      _status = AppLocalizations.of(context)!.alignCardInFrame;
    }
  }

  Future<void> _loadBulkCoverageState() async {
    final selectedGame = await AppSettings.loadSelectedTcgGame();
    final bulkType = await AppSettings.loadBulkTypeForGame(selectedGame);
    if (!mounted) {
      return;
    }
    setState(() {
      _limitedPrintCoverage = _isLimitedPrintCoverage(bulkType);
    });
  }

  Future<void> _loadKnownSetCodesForScanner() async {
    final sets = await ScryfallDatabase.instance.fetchAvailableSets();
    if (!mounted) {
      return;
    }
    setState(() {
      _knownSetCodes = sets
          .map((set) => set.code.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toSet();
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      await controller.initialize();
      await controller.startImageStream(_processCameraFrame);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _initializing = false;
      });
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        if (mounted) {
          setState(() {
            _torchAvailable = false;
          });
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _status = AppLocalizations.of(
          context,
        )!.cameraUnavailableCheckPermissions;
      });
    }
  }

  @override
  void dispose() {
    final controller = _cameraController;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        unawaited(controller.stopImageStream());
      }
      controller.dispose();
    }
    _pulseController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    final controller = _cameraController;
    if (controller == null || !_torchAvailable) {
      return;
    }
    try {
      final next = _torchEnabled ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _torchEnabled = !_torchEnabled;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _torchAvailable = false;
      });
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.flashNotAvailableOnDevice,
      );
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_handled || _processingFrame || !mounted) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastProcessedAt).inMilliseconds < 380) {
      return;
    }
    _lastProcessedAt = now;
    final controller = _cameraController;
    if (controller == null) {
      return;
    }
    final input = _toInputImage(image, controller);
    if (input == null) {
      return;
    }
    _processingFrame = true;
    try {
      final recognized = await _textRecognizer.processImage(input);
      final rawText = recognized.text.trim();
      _updateFieldStates(rawText);
      final stableKey = _buildStabilityKey(rawText);
      if (stableKey.isEmpty) {
        if (mounted) {
          setState(() {
            _status = AppLocalizations.of(context)!.searchingCardTextStatus;
          });
        }
        _stableHits = 0;
        _lastCandidateKey = '';
        _bestStableRawText = '';
        _nameHits = 0;
        _setHits = 0;
        _clearSetVotes();
        return;
      }
      final key = stableKey.toLowerCase();
      if (key == _lastCandidateKey) {
        _stableHits += 1;
        if (rawText.length > _bestStableRawText.length) {
          _bestStableRawText = rawText;
        }
      } else {
        _lastCandidateKey = key;
        _stableHits = 1;
        _bestStableRawText = rawText;
      }
      if (mounted) {
        setState(() {
          if (_lockedName.isEmpty) {
            _status = AppLocalizations.of(context)!.searchingCardNameStatus;
          } else {
            _status = AppLocalizations.of(
              context,
            )!.nameRecognizedOpeningSearchStatus;
          }
        });
      }
      if (_stableHits < _requiredStableHits ||
          rawText.isEmpty ||
          _lockedName.isEmpty) {
        return;
      }
      _handled = true;
      await controller.stopImageStream();
      if (mounted) {
        final payload = jsonEncode({
          'raw': _bestStableRawText.isNotEmpty ? _bestStableRawText : rawText,
          'lockedName': _lockedName,
          'lockedSet': _lockedSet,
        });
        Navigator.of(context).pop('__SCAN_PAYLOAD__$payload');
      }
    } catch (_) {
      _stableHits = 0;
      _bestStableRawText = '';
      _clearSetVotes();
      if (mounted) {
        setState(() {
          _status = AppLocalizations.of(context)!.ocrUnstableRetryingStatus;
        });
      }
    } finally {
      _processingFrame = false;
    }
  }

  String _buildStabilityKey(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return '';
    }
    final name = lines
        .take(6)
        .map((line) => line.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ').trim())
        .firstWhere(
          (line) => line.length >= 3 && RegExp(r'[A-Za-z]').hasMatch(line),
          orElse: () => '',
        );
    final collector =
        (lines.reversed
            .map((line) => line.toLowerCase())
            .map(
              (line) => RegExp(r'(\d{1,5}[a-z]?)').firstMatch(line)?.group(1),
            )
            .firstWhere(
              (value) => value != null && value.isNotEmpty,
              orElse: () => '',
            )) ??
        '';
    final parts = <String>[
      if (name.isNotEmpty) name,
      if (collector.isNotEmpty) collector,
    ];
    final snippet = parts.join(' | ').trim();
    if (snippet.length < 3) {
      return '';
    }
    return snippet.length > 80 ? '${snippet.substring(0, 80)}...' : snippet;
  }

  void _updateFieldStates(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return;
    }
    final nameCandidate = _extractNameForField(lines.take(3).toList());
    final bottomStart = lines.length > 8 ? lines.length - 8 : 0;
    var setCandidate = _extractSetForField(lines.sublist(bottomStart));
    if (setCandidate.isEmpty) {
      setCandidate = _extractSetForField(lines);
    }
    final votedSetCandidate = _registerSetVote(setCandidate);
    _namePreview = nameCandidate;

    if (nameCandidate.isNotEmpty) {
      if (nameCandidate.toLowerCase() == _lastNameCandidate.toLowerCase()) {
        _nameHits += 1;
      } else {
        _lastNameCandidate = nameCandidate;
        _nameHits = 1;
      }
      if (_nameHits >= _requiredNameFieldHits) {
        _lockedName = nameCandidate;
        if (_pulseController.isAnimating) {
          _pulseController.stop();
        }
      }
    }

    if (votedSetCandidate.isNotEmpty) {
      final hasResolvedSet = RegExp(
        r'^[A-Z]{2,5}\s+[0-9]{1,5}[A-Z]?$',
      ).hasMatch(votedSetCandidate.trim().toUpperCase());
      if (!hasResolvedSet) {
        _setHits = 0;
        return;
      }
      if (votedSetCandidate.toLowerCase() == _lastSetCandidate.toLowerCase()) {
        _setHits += 1;
      } else {
        _lastSetCandidate = votedSetCandidate;
        _setHits = 1;
      }
      if (_setHits >= _requiredSetFieldHits) {
        _lockedSet = votedSetCandidate;
      }
    }
  }

  String _registerSetVote(String candidate) {
    final normalized = _normalizeSetCandidateForVote(candidate);
    if (normalized.isEmpty) {
      return '';
    }
    _setVoteHistory.add(normalized);
    _setVoteCounts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
    if (_setVoteHistory.length > _setVoteWindow) {
      final removed = _setVoteHistory.removeAt(0);
      final next = (_setVoteCounts[removed] ?? 0) - 1;
      if (next <= 0) {
        _setVoteCounts.remove(removed);
      } else {
        _setVoteCounts[removed] = next;
      }
    }
    return _bestSetVoteCandidate() ?? normalized;
  }

  String? _bestSetVoteCandidate() {
    String? best;
    var bestCount = 0;
    for (final entry in _setVoteCounts.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        best = entry.key;
      }
    }
    return best;
  }

  String _normalizeSetCandidateForVote(String value) {
    final match = RegExp(
      r'^([A-Z]{2,5})\s+([0-9]{1,5}[A-Z]?)$',
    ).firstMatch(value.trim().toUpperCase());
    if (match == null) {
      return '';
    }
    final setCode = (match.group(1) ?? '').trim();
    final collectorRaw = (match.group(2) ?? '').trim();
    if (setCode.isEmpty || collectorRaw.isEmpty) {
      return '';
    }
    final normalizedCollector = _normalizeCollectorForComparison(collectorRaw);
    return '$setCode ${normalizedCollector.toUpperCase()}';
  }

  void _clearSetVotes() {
    _setVoteHistory.clear();
    _setVoteCounts.clear();
  }

  String _extractNameForField(List<String> lines) {
    for (final rawLine in lines) {
      final cleaned = rawLine
          .replaceAll(RegExp(r"[^A-Za-z0-9'\-\s]"), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length < 3) {
        continue;
      }
      final hasLetters = RegExp(r'[A-Za-z]').hasMatch(cleaned);
      final hasManyDigits =
          RegExp(r'\d').allMatches(cleaned).length > (cleaned.length * 0.25);
      if (!hasLetters || hasManyDigits) {
        continue;
      }
      final words = cleaned.split(' ').where((w) => w.isNotEmpty).length;
      if (words > 7) {
        continue;
      }
      return cleaned;
    }
    return '';
  }

  String _extractSetForField(List<String> lines) {
    final directRegex = RegExp(r'\b([A-Z0-9]{2,5})\s+([0-9]{1,5}[A-Z]?)\b');
    final collectorRegex = RegExp(r'\b([0-9]{1,5}[A-Z]?)\s*/\s*[0-9]{1,5}\b');
    final collectorOnlyRegex = RegExp(r'^\s*([0-9]{1,5}[A-Z]?)\s*$');
    for (var i = lines.length - 1; i >= 0; i--) {
      final upper = lines[i].toUpperCase();
      final match = directRegex.firstMatch(upper);
      if (match == null) {
        final collectorMatch = collectorRegex.firstMatch(upper);
        if (collectorMatch != null) {
          final collector = (collectorMatch.group(1) ?? '').trim();
          final nearSet = _guessSetTokenAroundIndex(lines, i);
          if (collector.isNotEmpty && nearSet.isNotEmpty) {
            return '$nearSet $collector';
          }
          if (collector.isNotEmpty) {
            return '#$collector';
          }
        }
        final clean = upper
            .replaceAll('O', '0')
            .replaceAll('I', '1')
            .replaceAll('L', '1')
            .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
            .trim();
        final singleCollector = collectorOnlyRegex.firstMatch(clean);
        if (singleCollector != null) {
          final collector = (singleCollector.group(1) ?? '').trim();
          if (collector.isNotEmpty) {
            final nearSet = _guessSetTokenAroundIndex(lines, i);
            if (nearSet.isNotEmpty) {
              return '$nearSet $collector';
            }
            return '#$collector';
          }
        }
        continue;
      }
      final setCode = (match.group(1) ?? '').trim();
      final collector = (match.group(2) ?? '').trim();
      if (setCode.isEmpty || collector.isEmpty) {
        continue;
      }
      if (!RegExp(r'[A-Z]').hasMatch(setCode)) {
        continue;
      }
      return '${setCode.toUpperCase()} $collector';
    }
    return '';
  }

  String _guessSetTokenAroundIndex(List<String> lines, int anchorIndex) {
    const rarityTokens = {'C', 'U', 'R', 'M', 'L'};
    for (var delta = 0; delta <= 4; delta++) {
      final indices = <int>{anchorIndex - delta, anchorIndex + delta};
      for (final idx in indices) {
        if (idx < 0 || idx >= lines.length) {
          continue;
        }
        final tokens = lines[idx]
            .toUpperCase()
            .replaceAll('0', 'O')
            .replaceAll('1', 'I')
            .split(RegExp(r'[^A-Z0-9]'))
            .where((t) => t.isNotEmpty)
            .toList(growable: false);
        for (final token in tokens.reversed) {
          if (token.length < 2 || token.length > 5) {
            continue;
          }
          if (rarityTokens.contains(token)) {
            continue;
          }
          if (RegExp(r'^\d+$').hasMatch(token)) {
            continue;
          }
          final resolved = _resolveKnownSetCode(token);
          if (resolved != null) {
            return resolved.toUpperCase();
          }
          if (RegExp(r'^[A-Z]{2,5}$').hasMatch(token)) {
            return token;
          }
        }
      }
    }
    return '';
  }

  String? _resolveKnownSetCode(String token) {
    final raw = token.trim().toLowerCase();
    if (raw.isEmpty) {
      return null;
    }
    if (_knownSetCodes.contains(raw)) {
      return raw;
    }
    final normalized = raw
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('5', 's')
        .replaceAll('8', 'b');
    if (_knownSetCodes.contains(normalized)) {
      return normalized;
    }
    return null;
  }

  InputImage? _toInputImage(CameraImage image, CameraController controller) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }
    final bytes = Uint8List.fromList(
      image.planes.expand((plane) => plane.bytes).toList(growable: false),
    );
    final rotation =
        InputImageRotationValue.fromRawValue(
          controller.description.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Widget _buildLimitedCoverageBadge() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC3A2412),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9C46A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Color(0xFFE9C46A),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.limitedCoverageTapAllArtworks,
            style: TextStyle(
              color: Color(0xFFF5EEDA),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.liveCardScanTitle),
        actions: [
          IconButton(
            tooltip: l10n.torchTooltip,
            onPressed: (_initializing || !_torchAvailable)
                ? null
                : _toggleTorch,
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _torchEnabled ? const Color(0xFFE9C46A) : null,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initializing || controller == null)
            const Center(child: CircularProgressIndicator())
          else
            CameraPreview(controller),
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = (constraints.maxWidth - 48).clamp(
                  110.0,
                  constraints.maxWidth,
                );
                final mediaPadding = MediaQuery.of(context).padding;
                final topReserved = mediaPadding.top + 8;
                final bottomReserved = mediaPadding.bottom + 236;
                final frameAreaHeight =
                    (constraints.maxHeight - topReserved - bottomReserved)
                        .clamp(80.0, constraints.maxHeight);
                final availableHeight = frameAreaHeight;
                var guideWidth = availableWidth;
                var guideHeight = guideWidth / _cardAspectRatio;
                if (guideHeight > availableHeight) {
                  guideHeight = availableHeight;
                  guideWidth = guideHeight * _cardAspectRatio;
                }
                final centerY = topReserved + (frameAreaHeight / 2) + 10;
                final guideRect = Rect.fromCenter(
                  center: Offset(constraints.maxWidth / 2, centerY),
                  width: guideWidth,
                  height: guideHeight,
                );
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => CustomPaint(
                    painter: _CardGuideOverlayPainter(
                      guideRect: guideRect,
                      borderRadius: 20,
                      pulse: _lockedName.isNotEmpty
                          ? 1
                          : (0.45 + (_pulseController.value * 0.55)),
                      locked: _lockedName.isNotEmpty,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_showCoverageBadgeInScanner && _limitedPrintCoverage)
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: Center(child: _buildLimitedCoverageBadge()),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ScanFieldStatusBox(
                    label: AppLocalizations.of(context)!.nameLabel,
                    value: _lockedName.isEmpty
                        ? (_namePreview.isEmpty
                              ? AppLocalizations.of(context)!.waitingStatus
                              : _namePreview)
                        : _lockedName,
                    locked: _lockedName.isNotEmpty,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFEFE7D8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context)!.liveOcrActive,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFE9C46A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardGuideOverlayPainter extends CustomPainter {
  const _CardGuideOverlayPainter({
    required this.guideRect,
    required this.borderRadius,
    required this.pulse,
    required this.locked,
  });

  final Rect guideRect;
  final double borderRadius;
  final double pulse;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final guideRRect = RRect.fromRectAndRadius(
      guideRect,
      Radius.circular(borderRadius),
    );

    final overlayPath = Path()
      ..addRect(fullRect)
      ..addRRect(guideRRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = Colors.black.withValues(
          alpha: locked ? 0.42 : (0.40 + (0.12 * (1 - pulse))),
        ),
    );

    final frameColor = locked
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE9C46A);
    final accentColor = locked
        ? const Color(0xFFC8FACC)
        : const Color(0xFFF5E3A4);
    final glowPaint = Paint()
      ..color = frameColor.withValues(
        alpha: locked ? 0.72 : (0.36 + (0.38 * pulse)),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(guideRRect, glowPaint);

    final outerStroke = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRRect(guideRRect, outerStroke);

    final innerRRect = guideRRect.deflate(6);
    final innerStroke = Paint()
      ..color = accentColor.withValues(
        alpha: locked ? 0.55 : (0.32 + (0.30 * pulse)),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(innerRRect, innerStroke);

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const accentLen = 22.0;
    final left = guideRect.left + 12;
    final right = guideRect.right - 12;
    final top = guideRect.top + 12;
    final bottom = guideRect.bottom - 12;
    canvas.drawLine(
      Offset(left, top),
      Offset(left + accentLen, top),
      accentPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + accentLen),
      accentPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right - accentLen, top),
      accentPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + accentLen),
      accentPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + accentLen, bottom),
      accentPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left, bottom - accentLen),
      accentPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - accentLen, bottom),
      accentPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - accentLen),
      accentPaint,
    );

    final zoneStroke = Paint()
      ..color = const Color(0x99E9C46A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final zoneFill = Paint()
      ..color = const Color(0x22E9C46A)
      ..style = PaintingStyle.fill;

    final nameZone = Rect.fromLTWH(
      guideRect.left + 14,
      guideRect.top + 14,
      guideRect.width - 28,
      guideRect.height * 0.16,
    );
    final nameRRect = RRect.fromRectAndRadius(
      nameZone,
      const Radius.circular(8),
    );
    canvas.drawRRect(nameRRect, zoneFill);
    canvas.drawRRect(nameRRect, zoneStroke);

    final nameTp = TextPainter(
      text: const TextSpan(
        text: 'NAME',
        style: TextStyle(
          color: Color(0xFFE9C46A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nameTp.paint(
      canvas,
      Offset(nameZone.left + 8, nameZone.center.dy - (nameTp.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _CardGuideOverlayPainter oldDelegate) {
    return oldDelegate.guideRect != guideRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.pulse != pulse ||
        oldDelegate.locked != locked;
  }
}

class _ScanFieldStatusBox extends StatelessWidget {
  const _ScanFieldStatusBox({
    required this.label,
    required this.value,
    required this.locked,
  });

  final String label;
  final String value;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final borderColor = locked
        ? const Color(0xFF4CAF50)
        : const Color(0x99E9C46A);
    final fillColor = locked
        ? const Color(0x334CAF50)
        : const Color(0x221C1713);
    final valueColor = locked
        ? const Color(0xFFC8FACC)
        : const Color(0xFFEFE7D8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: borderColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
  editFilter,
  importDeckFile,
  exportDeckArena,
  exportDeckMtgo,
  delete,
}

enum _HomeCollectionsMenu { home, set, custom, smart, wish, deck }

enum _HomeAddAction { addByScan, addCards, addCollection, addWishlist }

enum _CollectionCreateAction { custom, smart, setBased, deck }

class _SnakeProgressBar extends StatelessWidget {
  const _SnakeProgressBar({required this.animation, required this.value});

  final Animation<double> animation;
  final double value;

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
          final clampedValue = value.clamp(0.0, 1.0);
          final fillWidth = maxWidth * clampedValue;
          final snakeWidth = maxWidth * 0.22;

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final availableWidth = fillWidth > 0 ? fillWidth : maxWidth;
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
                  if (fillWidth > 0)
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
