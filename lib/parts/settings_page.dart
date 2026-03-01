part of 'package:tcg_tracker/main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _pokemonOwnershipKey =
      PurchaseManager.pokemonOwnershipKey;
  static const Duration _storeOperationTimeout = Duration(seconds: 20);
  bool _loading = true;
  String? _bulkType;
  String _pokemonDatasetProfile = 'starter';
  String _priceSource = 'scryfall';
  String _priceCurrency = 'eur';
  bool _showPrices = true;
  String _appLocaleCode = 'en';
  String _appVersion = '0.4.4';
  bool _backupBusy = false;
  bool _gamesBusy = false;
  TcgGame _primaryGame = TcgGame.mtg;
  Set<String> _ownedTcgs = const <String>{};
  late final PurchaseManager _purchaseManager;
  late final VoidCallback _purchaseListener;

  bool get _supportsFirebaseAuth => Platform.isAndroid || Platform.isIOS;
  bool get _isItalianUi => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('it');
  AppTcgGame get _primarySettingsGame =>
      _primaryGame == TcgGame.pokemon ? AppTcgGame.pokemon : AppTcgGame.mtg;
  TcgGame get _secondaryGame =>
      _primaryGame == TcgGame.mtg ? TcgGame.pokemon : TcgGame.mtg;
  String _ownershipKeyForGame(TcgGame game) => game == TcgGame.pokemon
      ? PurchaseManager.pokemonOwnershipKey
      : PurchaseManager.magicOwnershipKey;
  bool _isGameUnlockedForUi(TcgGame game) {
    if (game == _primaryGame) {
      return true;
    }
    if (_ownedTcgs.contains(_ownershipKeyForGame(game))) {
      return true;
    }
    return _purchaseManager.canAccessGame(
      game == TcgGame.pokemon ? AppTcgGame.pokemon : AppTcgGame.mtg,
    );
  }

  String _googleSignInErrorMessage(Object error) {
    final l10n = AppLocalizations.of(context)!;
    if (error is FirebaseAuthException) {
      if (error.code == 'network-request-failed') {
        return l10n.authNetworkErrorDuringSignIn;
      }
      if (error.code == 'invalid-credential') {
        return l10n.authInvalidGoogleCredential;
      }
      return l10n.authGoogleSignInFailedWithCode(error.code);
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      final details = '${error.details ?? ''}'.toLowerCase();
      final blob = '$code $message $details';
      if (blob.contains('10') || blob.contains('developer_error')) {
        return l10n.authGoogleSignInConfigError;
      }
      if (blob.contains('network_error')) {
        return l10n.authGoogleSignInFailedWithCode(error.code);
      }
      if (blob.contains('sign_in_canceled') || blob.contains('cancel')) {
        return l10n.authGoogleSignInCancelled;
      }
      return l10n.authGoogleSignInFailedWithCode(error.code);
    }
    return l10n.authGoogleSignInFailedTryAgain;
  }

  List<Widget> _maybeWidget(Widget? widget) {
    if (widget == null) {
      return const <Widget>[];
    }
    return <Widget>[widget];
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
        _ownedTcgs = _purchaseManager.ownedTcgs;
        _gamesBusy =
            _purchaseManager.purchasePending ||
            _purchaseManager.restoringPurchases;
      });
    };
    _purchaseManager.addListener(_purchaseListener);
    _loadSettings();
  }

  @override
  void dispose() {
    _purchaseManager.removeListener(_purchaseListener);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _purchaseManager.init();
    await _purchaseManager.syncPrimaryGameFromSettings();
    final selectedGame = await AppSettings.loadSelectedTcgGame();
    final primaryGame = await AppSettings.loadPrimaryTcgGameOrNull();
    final bulkType = await AppSettings.loadBulkTypeForGame(selectedGame);
    final priceCurrency = await AppSettings.loadPriceCurrency();
    final showPrices = await AppSettings.loadShowPrices();
    final appLocaleCode = await AppSettings.loadAppLocale();
    final ownedTcgs = await AppSettings.loadOwnedTcgs();
    final pokemonUnlocked = await AppSettings.loadPokemonUnlocked();
    final pokemonDatasetProfile = await AppSettings.loadPokemonDatasetProfile();
    var appVersion = _appVersion;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (_) {
      appVersion = _appVersion;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _bulkType = bulkType;
      _priceCurrency = priceCurrency;
      _showPrices = showPrices;
      _appLocaleCode = appLocaleCode;
      _appVersion = appVersion;
      _primaryGame = (primaryGame ?? selectedGame) == AppTcgGame.pokemon
          ? TcgGame.pokemon
          : TcgGame.mtg;
      final pokemonAccessible =
          pokemonUnlocked || ownedTcgs.contains(_pokemonOwnershipKey);
      if (pokemonAccessible && !ownedTcgs.contains(_pokemonOwnershipKey)) {
        _ownedTcgs = {...ownedTcgs, _pokemonOwnershipKey};
      } else {
        _ownedTcgs = _purchaseManager.ownedTcgs.isNotEmpty
            ? _purchaseManager.ownedTcgs
            : ownedTcgs;
      }
      _gamesBusy =
          _purchaseManager.purchasePending ||
          _purchaseManager.restoringPurchases;
      _pokemonDatasetProfile = pokemonDatasetProfile;
      _loading = false;
    });
  }

  Future<void> _activateSecondaryGameForTest() async {
    final manager = _purchaseManager;
    final secondary = _secondaryGame == TcgGame.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    await manager.setGameUnlockedForTest(secondary, true);
    if (!mounted) {
      return;
    }
    setState(() {
      _ownedTcgs = manager.ownedTcgs;
    });
    showAppSnackBar(
      context,
      _isItalianUi
          ? '${_secondaryGame == TcgGame.pokemon ? 'Pokemon' : 'Magic'} attivato (test).'
          : '${_secondaryGame == TcgGame.pokemon ? 'Pokemon' : 'Magic'} activated (test).',
    );
  }

  Future<void> _changePrimaryGame(TcgGame selected) async {
    if (selected == _primaryGame) {
      return;
    }
    showAppSnackBar(
      context,
      _isItalianUi
          ? 'Il gioco primario è fisso. Usa Reset test per cambiarlo.'
          : 'Primary game is fixed. Use Reset test to change it.',
    );
  }

  Widget _buildGameSelectorEntry(TcgGame game) {
    final isPrimary = game == _primaryGame;
    final isUnlocked = _isGameUnlockedForUi(game);
    final gameName = game == TcgGame.pokemon ? 'Pokemon' : 'Magic';
    if (isUnlocked) {
      return RadioListTile<TcgGame>(
        contentPadding: EdgeInsets.zero,
        value: game,
        title: Text(gameName),
        subtitle: Text(
          isPrimary
              ? (_isItalianUi
                    ? 'Primario gratuito (per sempre)'
                    : 'Primary free (forever)')
              : (_isItalianUi ? 'Acquistato' : 'Purchased'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0x221D1712),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A2F24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gameName, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              _isItalianUi
                  ? 'Secondario: acquisto richiesto'
                  : 'Secondary: purchase required',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFBFAE95)),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _gamesBusy ? null : _purchaseSecondaryGame,
              icon: const Icon(Icons.shopping_cart_checkout),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE9C46A),
                foregroundColor: const Color(0xFF1C1510),
              ),
              label: Text(
                _isItalianUi
                    ? 'Acquista $gameName ${_purchaseManager.additionalTcgPriceLabel ?? ''}'
                          .trim()
                    : 'Buy $gameName ${_purchaseManager.additionalTcgPriceLabel ?? ''}'
                          .trim(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreGamePurchases() async {
    if (_gamesBusy) {
      return;
    }
    setState(() {
      _gamesBusy = true;
    });
    try {
      final manager = _purchaseManager;
      await manager.init();
      await manager.restorePurchases().timeout(_storeOperationTimeout);
      if (!mounted) {
        return;
      }
      setState(() {
        _ownedTcgs = manager.ownedTcgs;
      });
      showAppSnackBar(
        context,
        _isItalianUi
            ? 'Ripristino acquisti completato.'
            : 'Purchases restored.',
      );
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        _isItalianUi
            ? 'Ripristino acquisti troppo lento. Riprova.'
            : 'Restore purchases is taking too long. Try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _gamesBusy = false;
        });
      }
    }
  }

  Future<void> _purchaseSecondaryGame() async {
    if (_gamesBusy) {
      return;
    }
    setState(() {
      _gamesBusy = true;
    });
    try {
      await _purchaseManager.init();
      await _purchaseManager.syncPrimaryGameFromSettings();
      if (_purchaseManager.additionalTcgProduct == null) {
        await _purchaseManager.refreshCatalog().timeout(_storeOperationTimeout);
      }
      if (_purchaseManager.additionalTcgProduct == null) {
        if (!mounted) {
          return;
        }
        showAppSnackBar(
          context,
          _isItalianUi
              ? 'Prodotto non disponibile su Google Play.'
              : 'Product not available on Google Play.',
        );
        return;
      }
      if (!mounted) {
        return;
      }
      final secondaryName = _secondaryGame == TcgGame.pokemon
          ? 'Pokemon'
          : 'Magic';
      final priceLabel = _purchaseManager.additionalTcgPriceLabel ?? '';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _isItalianUi ? 'Acquista $secondaryName' : 'Buy $secondaryName',
          ),
          content: Text(
            _isItalianUi
                ? 'Sblocchi $secondaryName una sola volta, per sempre su questo account. Il prezzo e $priceLabel. Gli acquisti sono gestiti da Google Play.'
                : 'You unlock $secondaryName with a one-time purchase, forever on this account. Price is $priceLabel. Purchases are handled by Google Play.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_isItalianUi ? 'Annulla' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                _isItalianUi ? 'Continua acquisto' : 'Continue purchase',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
      await _purchaseManager.purchaseAdditionalTcgUnlock();
      if (!mounted) {
        return;
      }
      if (_purchaseManager.lastError == 'already_owned') {
        showAppSnackBar(
          context,
          _isItalianUi
              ? 'Acquisto già presente su Google Play. Entitlement sincronizzato.'
              : 'Purchase already owned on Google Play. Entitlement synced.',
        );
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        _isItalianUi
            ? 'Connessione allo store troppo lenta. Riprova.'
            : 'Store connection is taking too long. Try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _gamesBusy =
              _purchaseManager.purchasePending ||
              _purchaseManager.restoringPurchases;
        });
      }
    }
  }

  Future<void> _changeAppLanguage() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.uiLanguageTitle),
          children: [
            RadioGroup<String>(
              groupValue: _appLocaleCode,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'en',
                    title: Text(l10n.languageEnglish),
                  ),
                  RadioListTile<String>(
                    value: 'it',
                    title: Text(l10n.languageItalian),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (selected == null || selected == _appLocaleCode) {
      return;
    }
    await AppSettings.saveAppLocale(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _appLocaleCode = selected;
    });
    _appLocaleNotifier.value = Locale(selected);
  }

  Future<void> _changePriceSource() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SimpleDialog(
          title: Text(l10n.priceSourceTitle),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('scryfall'),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.scryfallProviderLabel),
                subtitle: Text(l10n.dailySnapshot),
              ),
            ),
          ],
        );
      },
    );
    if (selected == null || selected == _priceSource || !mounted) {
      return;
    }
    setState(() {
      _priceSource = selected;
    });
  }

  Future<void> _changePriceCurrency(String currency) async {
    final normalized = currency.trim().toLowerCase() == 'usd' ? 'usd' : 'eur';
    if (normalized == _priceCurrency) {
      return;
    }
    await AppSettings.savePriceCurrency(normalized);
    if (!mounted) {
      return;
    }
    setState(() {
      _priceCurrency = normalized;
    });
  }

  Future<void> _changeShowPrices(String value) async {
    final nextValue = value.trim().toLowerCase() == 'off' ? false : true;
    if (nextValue == _showPrices) {
      return;
    }
    await AppSettings.saveShowPrices(nextValue);
    if (!mounted) {
      return;
    }
    setState(() {
      _showPrices = nextValue;
    });
  }

  Future<void> _changeBulkType() async {
    final isItalian = _isItalianUi;
    final selected = await _showBulkTypePicker(
      context,
      allowCancel: true,
      selectedType: _bulkType,
      requireConfirmation: true,
      confirmLabel: AppLocalizations.of(context)!.downloadUpdate,
      allowResetAction: true,
      resetLabel: isItalian ? 'Reset database Magic' : 'Reset Magic database',
    );
    if (selected == null) {
      return;
    }
    if (selected == _bulkPickerResetAction) {
      await _resetDatabaseForGame(TcgGame.mtg);
      return;
    }
    if (selected == _bulkType) {
      return;
    }
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.changeDatabaseTitle),
          content: Text(l10n.changeDatabaseBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.updatingDatabaseTitle),
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.preparingDatabaseBody)),
            ],
          ),
        );
      },
    );

    try {
      await AppSettings.saveBulkTypeForGame(_primarySettingsGame, selected);
      await ScryfallBulkChecker().resetState();
      await ScryfallDatabase.instance.hardReset();
      await _deleteBulkFiles();
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _bulkType = selected;
    });
    _collectionsRefreshNotifier.value = _collectionsRefreshNotifier.value + 1;
    Navigator.of(context).pop();
  }

  Future<void> _resetDatabaseForGame(TcgGame game) async {
    final l10n = AppLocalizations.of(context)!;
    final isItalian = _isItalianUi;
    final gameLabel = game == TcgGame.mtg ? 'Magic' : 'Pokemon';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isItalian
                ? 'Reset database $gameLabel'
                : 'Reset $gameLabel database',
          ),
          content: Text(
            isItalian
                ? 'Verranno cancellate solo le carte nel database $gameLabel e riscaricate da zero. Collezioni, deck e quantità restano invariati.'
                : 'Only $gameLabel cards will be deleted and reimported from scratch. Collections, decks, and quantities stay unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(isItalian ? 'Reset' : 'Reset'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isItalian ? 'Reset in corso' : 'Reset in progress'),
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
                isItalian
                    ? 'Pulizia database $gameLabel...'
                    : 'Cleaning $gameLabel database...',
              ),
            ),
          ],
        ),
      ),
    );

    try {
      await TcgEnvironmentController.instance.init();
      final activeGame = TcgEnvironmentController.instance.currentGame;
      final activeConfig = TcgEnvironmentController.instance.configFor(
        activeGame,
      );
      final targetConfig = TcgEnvironmentController.instance.configFor(game);
      await ScryfallDatabase.instance.setDatabaseFileName(
        targetConfig.dbFileName,
      );
      await ScryfallDatabase.instance.hardReset();
      if (game == TcgGame.mtg) {
        await ScryfallBulkChecker().resetState();
        await _deleteBulkFiles();
      } else {
        await PokemonBulkService.instance.clearLocalDatasetArtifacts();
      }
      await ScryfallDatabase.instance.setDatabaseFileName(
        activeConfig.dbFileName,
      );
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      isItalian
          ? 'Database $gameLabel resettato. Verrà riscaricato in modo pulito.'
          : '$gameLabel database reset. It will be downloaded again cleanly.',
    );
    _collectionsRefreshNotifier.value = _collectionsRefreshNotifier.value + 1;
  }

  String _pokemonProfileLabel(String profile) {
    switch (profile.trim().toLowerCase()) {
      case 'full':
        return _isItalianUi ? 'Full (tutte le carte)' : 'Full (all cards)';
      case 'expanded':
        return _isItalianUi ? 'Expanded (10 set)' : 'Expanded (10 sets)';
      case 'standard':
        return _isItalianUi ? 'Standard (6 set)' : 'Standard (6 sets)';
      case 'starter':
      default:
        return _isItalianUi ? 'Starter (3 set)' : 'Starter (3 sets)';
    }
  }

  String _pokemonProfileDescription(String profile) {
    switch (profile.trim().toLowerCase()) {
      case 'full':
        return _isItalianUi
            ? 'Catalogo completo via API. Download grande.'
            : 'Complete catalog via API. Large download.';
      case 'expanded':
        return _isItalianUi
            ? 'Più carte offline, download più grande.'
            : 'More offline cards, larger download.';
      case 'standard':
        return _isItalianUi
            ? 'Compromesso tra dimensione e copertura.'
            : 'Balanced size and card coverage.';
      case 'starter':
      default:
        return _isItalianUi
            ? 'Database leggero, ideale per iniziare.'
            : 'Lightweight database, good to start.';
    }
  }

  Future<void> _changePokemonDatasetProfile() async {
    final options = const ['starter', 'standard', 'expanded', 'full'];
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final isIt = _isItalianUi;
        return SimpleDialog(
          title: Text(isIt ? 'Database Pokemon' : 'Pokemon database'),
          children: [
            RadioGroup<String>(
              groupValue: _pokemonDatasetProfile,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                children: options
                    .map(
                      (profile) => RadioListTile<String>(
                        value: profile,
                        title: Text(_pokemonProfileLabel(profile)),
                        subtitle: Text(_pokemonProfileDescription(profile)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        );
      },
    );
    if (selected == null || selected == _pokemonDatasetProfile) {
      return;
    }
    await AppSettings.savePokemonDatasetProfile(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _pokemonDatasetProfile = selected;
    });
    showAppSnackBar(
      context,
      _isItalianUi
          ? 'Profilo Pokemon aggiornato. Tocca Update disponibile in Home per applicarlo.'
          : 'Pokemon profile updated. Tap Update available in Home to apply.',
    );
  }

  Future<void> _deleteBulkFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final legacyPath = '${directory.path}/scryfall_all_cards.json';
    final legacyTempPath = '$legacyPath.download';
    final legacyFile = File(legacyPath);
    final legacyTempFile = File(legacyTempPath);
    if (await legacyFile.exists()) {
      await legacyFile.delete();
    }
    if (await legacyTempFile.exists()) {
      await legacyTempFile.delete();
    }
    for (final option in _bulkOptions) {
      final targetPath = '${directory.path}/${_bulkTypeFileName(option.type)}';
      final tempPath = '$targetPath.download';
      final mainFile = File(targetPath);
      final tempFile = File(tempPath);
      if (await mainFile.exists()) {
        await mainFile.delete();
      }
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.unableToSignOutTryAgain)));
    }
  }

  Future<void> _signInWithGoogleFromSettings() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_googleSignInErrorMessage(error))));
    }
  }

  Future<void> _promptGuestSignIn() async {
    if (!_supportsFirebaseAuth) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final shouldSignIn = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.authSignInWithGoogle),
          content: Text(l10n.authWelcomeSubtitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.login_rounded),
              label: Text(l10n.authSignInWithGoogle),
            ),
          ],
        );
      },
    );
    if (shouldSignIn != true) {
      return;
    }
    await _signInWithGoogleFromSettings();
  }

  Future<void> _exportLocalBackup() async {
    if (_backupBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _backupBusy = true;
    });
    try {
      final result = await LocalBackupService.instance
          .exportCollectionsBackup();
      await AnalyticsService.instance.logBackupExported(
        collections: result.collections,
        collectionCards: result.collectionCards,
        cards: result.cards,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        l10n.backupExported(
          result.file.path.split(Platform.pathSeparator).last,
        ),
      );
      final shareNow = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(l10n.backupShareNowTitle),
            content: Text(l10n.backupShareNowBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.notNow),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.share),
              ),
            ],
          );
        },
      );
      if (shareNow == true && mounted) {
        await _shareBackupFile(result.file);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, l10n.importFailed(error));
    } finally {
      if (mounted) {
        setState(() {
          _backupBusy = false;
        });
      }
    }
  }

  Future<void> _importLocalBackup() async {
    if (_backupBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final backups = await LocalBackupService.instance.listBackupFiles();
    if (!mounted) {
      return;
    }
    if (backups.isEmpty) {
      showAppSnackBar(context, l10n.backupNoFilesFound);
      return;
    }

    final selectedFile = await showDialog<File>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.backupChooseImportFile),
          children: backups
              .take(20)
              .map(
                (file) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(file),
                  child: Text(file.path.split(Platform.pathSeparator).last),
                ),
              )
              .toList(growable: false),
        );
      },
    );
    if (selectedFile == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.backupImportConfirmTitle),
          content: Text(l10n.backupImportConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.importNow),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _backupBusy = true;
    });
    try {
      final stats = await LocalBackupService.instance
          .importCollectionsBackupFromFile(selectedFile);
      await AnalyticsService.instance.logBackupImported(
        collections: stats['collections'] ?? 0,
        collectionCards: stats['collectionCards'] ?? 0,
        cards: stats['cards'] ?? 0,
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        l10n.backupImported(
          stats['collections'] ?? 0,
          stats['collectionCards'] ?? 0,
        ),
      );
      _collectionsRefreshNotifier.value = _collectionsRefreshNotifier.value + 1;
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, l10n.importFailed(error));
    } finally {
      if (mounted) {
        setState(() {
          _backupBusy = false;
        });
      }
    }
  }

  Future<void> _shareBackupFile(File file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: file.path.split(Platform.pathSeparator).last,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.backupShareFailed(error),
      );
    }
  }

  Future<void> _resetPrimaryGameTestState() async {
    final isItalian = _isItalianUi;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isItalian
              ? 'Reset scenario primo avvio'
              : 'Reset first-launch scenario',
        ),
        content: Text(
          isItalian
              ? 'Verrà ripristinata la scelta TCG primario e saranno azzerati gli acquisti (Plus e sblocchi TCG). Collezioni e carte salvate non verranno eliminate.'
              : 'This will reset primary TCG selection and clear purchases (Plus and TCG unlocks). Saved collections and cards will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isItalian ? 'Annulla' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isItalian ? 'Reset test' : 'Reset test'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await AppSettings.resetPrimaryGameSelectionFlow();
    final manager = PurchaseManager.instance;
    await manager.resetPurchaseStateForTest();
    await manager.syncPrimaryGameFromSettings();
    await TcgEnvironmentController.instance.setGame(TcgGame.mtg);

    if (!mounted) {
      return;
    }
    setState(() {
      _primaryGame = TcgGame.mtg;
      _ownedTcgs = const <String>{};
    });
    _collectionsRefreshNotifier.value = _collectionsRefreshNotifier.value + 1;
    showAppSnackBar(
      context,
      isItalian
          ? 'Scenario test ripristinato: scegli di nuovo il TCG primario. Acquisti azzerati.'
          : 'Test scenario restored: choose your primary TCG again. Purchases cleared.',
    );
  }

  Widget _buildProfileTile(User? user) {
    final displayName = user?.displayName?.trim();
    final email = user?.email?.trim();
    final hasDisplayName = displayName != null && displayName.isNotEmpty;
    final hasEmail = email != null && email.isNotEmpty;
    final isGuest = user == null;
    final l10n = AppLocalizations.of(context)!;
    final title = hasDisplayName
        ? displayName
        : (isGuest ? l10n.guestLabel : l10n.googleUserLabel);
    final subtitle = hasEmail
        ? email
        : (isGuest ? l10n.localProfileLabel : l10n.signedInWithGoogle);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: isGuest ? _promptGuestSignIn : null,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFF2D241B),
        foregroundImage: (user?.photoURL?.isNotEmpty ?? false)
            ? NetworkImage(user!.photoURL!)
            : null,
        child: (user?.photoURL?.isNotEmpty ?? false)
            ? null
            : const Icon(Icons.person, color: Color(0xFFEFE7D8)),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isGuest
          ? null
          : TextButton(onPressed: _signOut, child: Text(l10n.signOut)),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    if (!_supportsFirebaseAuth) {
      return _buildProfileTile(null);
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) => _buildProfileTile(snapshot.data),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A2F24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFE9C46A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ..._maybeWidget(trailing),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFBFAE95)),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFF3A2F24)),
          ),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.settings)),
      body: Stack(
        children: [
          const _AppBackground(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                24 + MediaQuery.of(context).padding.bottom + 16,
              ),
              children: [
                _buildSectionCard(
                  context: context,
                  icon: Icons.account_circle_outlined,
                  title: l10n.profile,
                  children: [_buildProfileSection(context)],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.language_rounded,
                  title: l10n.uiLanguageTitle,
                  subtitle: l10n.uiLanguageSubtitle,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _appLocaleCode == 'it'
                            ? l10n.languageItalian
                            : l10n.languageEnglish,
                      ),
                      trailing: OutlinedButton(
                        onPressed: _changeAppLanguage,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF5D4731)),
                        ),
                        child: Text(l10n.change),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.sports_esports_rounded,
                  title: _isItalianUi ? 'Giochi' : 'Games',
                  subtitle: _isItalianUi
                      ? 'Il primo gioco scelto è gratis per sempre. L’altro richiede acquisto.'
                      : 'The first selected game stays free forever. The other requires purchase.',
                  children: [
                    Text(
                      _isItalianUi ? 'Gioco principale' : 'Primary game',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    RadioGroup<TcgGame>(
                      groupValue: _primaryGame,
                      onChanged: (value) {
                        if (value != null) {
                          _changePrimaryGame(value);
                        }
                      },
                      child: Column(
                        children: [
                          _buildGameSelectorEntry(TcgGame.mtg),
                          _buildGameSelectorEntry(TcgGame.pokemon),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _purchaseManager.restoringPurchases
                                ? null
                                : _restoreGamePurchases,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            icon: _purchaseManager.restoringPurchases
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.restore),
                            label: Text(
                              _isItalianUi
                                  ? 'Ripristina acquisti'
                                  : 'Restore purchases',
                            ),
                          ),
                          if (!_isGameUnlockedForUi(_secondaryGame))
                            OutlinedButton.icon(
                              onPressed: _gamesBusy
                                  ? null
                                  : _activateSecondaryGameForTest,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF5D4731),
                                ),
                              ),
                              icon: const Icon(Icons.science_outlined),
                              label: Text(
                                _isItalianUi ? 'Unlock test' : 'Unlock test',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.workspace_premium_outlined,
                  title: l10n.pro,
                  subtitle: l10n.proCardSubtitle,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: BoxDecoration(
                        color: const Color(0x221D1712),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3A2F24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.needMoreThanFreeTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.needMoreThanFreeBody,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFFBFAE95)),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ProPage(),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE9C46A),
                                foregroundColor: const Color(0xFF1C1510),
                              ),
                              icon: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 18,
                              ),
                              label: Text(l10n.discoverPlus),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.storage_rounded,
                  title: l10n.cardDatabase,
                  subtitle: _isItalianUi
                      ? 'Configura separatamente i database di Magic e Pokemon.'
                      : 'Configure Magic and Pokemon databases separately.',
                  children: [
                    Text(
                      'Magic',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bulkTypeLabel(l10n, _bulkType),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _bulkTypeDescription(l10n, _bulkType ?? ''),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8F816B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _resetDatabaseForGame(TcgGame.mtg),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            child: Text(_isItalianUi ? 'Reset' : 'Reset'),
                          ),
                          OutlinedButton(
                            onPressed: _changeBulkType,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            child: Text(l10n.change),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20, color: Color(0xFF3A2F24)),
                    Text(
                      'Pokemon',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pokemonProfileLabel(_pokemonDatasetProfile),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _pokemonProfileDescription(_pokemonDatasetProfile),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8F816B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _resetDatabaseForGame(TcgGame.pokemon),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            child: Text(_isItalianUi ? 'Reset' : 'Reset'),
                          ),
                          OutlinedButton(
                            onPressed: _changePokemonDatasetProfile,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            child: Text(l10n.change),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.sell_outlined,
                  title: l10n.pricesTitle,
                  subtitle: l10n.pricesSubtitle,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.showPricesLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFBFAE95),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Checkbox(
                        value: _showPrices,
                        activeColor: const Color(0xFFE9C46A),
                        checkColor: const Color(0xFF1C1510),
                        onChanged: (value) {
                          _changeShowPrices((value ?? true) ? 'on' : 'off');
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  children: [
                    Text(
                      l10n.scryfallDailySnapshot,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.availableCurrenciesHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<String>(
                      groupValue: _priceCurrency,
                      onChanged: (value) {
                        if (value != null) {
                          _changePriceCurrency(value);
                        }
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    value: 'eur',
                                    title: Text(l10n.currencyEurCode),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    value: 'usd',
                                    title: Text(l10n.currencyUsdCode),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _changePriceSource,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            child: Text(l10n.change),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.backup_outlined,
                  title: l10n.backupTitle,
                  subtitle: l10n.backupSubtitle,
                  trailing: _backupBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _backupBusy ? null : _exportLocalBackup,
                            icon: const Icon(Icons.upload_file_rounded),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            label: Text(l10n.backupExport),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _backupBusy ? null : _importLocalBackup,
                            icon: const Icon(Icons.download_rounded),
                            label: Text(l10n.backupImport),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: l10n.appInfo,
                  children: [
                    ListTile(
                      title: Text(l10n.versionLabel),
                      subtitle: Text(_appVersion),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _resetPrimaryGameTestState,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            child: Text(
                              _isItalianUi ? 'Reset test' : 'Reset test',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _showLatestReleaseNotesPanel(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            child: Text(_whatsNewLabel(context)),
                          ),
                        ],
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
