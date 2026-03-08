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
  bool _mtgItalianCardsEnabled = false;
  bool _pokemonItalianCardsEnabled = false;
  String _appLocaleCode = 'en';
  String _appThemeCode = 'magic';
  String _appVersion = '0.4.4';
  bool _backupBusy = false;
  bool _gamesBusy = false;
  bool _coherenceCheckBusy = false;
  TcgGame _primaryGame = TcgGame.mtg;
  Set<String> _ownedTcgs = const <String>{};
  late final PurchaseManager _purchaseManager;
  late final VoidCallback _purchaseListener;

  bool get _supportsFirebaseAuth => Platform.isAndroid || Platform.isIOS;
  bool get _isItalianUi => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('it');
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

  Set<String> _resolveOwnedTcgsForUi(Set<String> persisted) {
    final merged = <String>{...persisted, ..._purchaseManager.ownedTcgs};
    if (_purchaseManager.canAccessGame(AppTcgGame.mtg)) {
      merged.add(PurchaseManager.magicOwnershipKey);
    }
    if (_purchaseManager.canAccessGame(AppTcgGame.pokemon)) {
      merged.add(PurchaseManager.pokemonOwnershipKey);
    }
    return merged;
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
        _ownedTcgs = _resolveOwnedTcgsForUi(_ownedTcgs);
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
    final bulkType = await AppSettings.loadBulkTypeForGame(AppTcgGame.mtg);
    final priceCurrency = await AppSettings.loadPriceCurrency();
    final showPrices = await AppSettings.loadShowPrices();
    final appLocaleCode = await AppSettings.loadAppLocale();
    final appThemeCode = await AppSettings.loadVisualTheme();
    final ownedTcgs = await AppSettings.loadOwnedTcgs();
    final pokemonUnlocked = await AppSettings.loadPokemonUnlocked();
    final pokemonDatasetProfile = await AppSettings.loadPokemonDatasetProfile();
    final mtgCardLanguages = await AppSettings.loadCardLanguagesForGame(
      AppTcgGame.mtg,
    );
    final pokemonCardLanguages = await AppSettings.loadCardLanguagesForGame(
      AppTcgGame.pokemon,
    );
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
      _mtgItalianCardsEnabled = mtgCardLanguages.contains('it');
      _pokemonItalianCardsEnabled = pokemonCardLanguages.contains('it');
      _appLocaleCode = appLocaleCode;
      _appThemeCode = appThemeCode;
      _appVersion = appVersion;
      _primaryGame = (primaryGame ?? selectedGame) == AppTcgGame.pokemon
          ? TcgGame.pokemon
          : TcgGame.mtg;
      final pokemonAccessible =
          pokemonUnlocked || ownedTcgs.contains(_pokemonOwnershipKey);
      final baseOwned = pokemonAccessible && !ownedTcgs.contains(_pokemonOwnershipKey)
          ? {...ownedTcgs, _pokemonOwnershipKey}
          : ownedTcgs;
      _ownedTcgs = _resolveOwnedTcgsForUi(baseOwned);
      _gamesBusy =
          _purchaseManager.purchasePending ||
          _purchaseManager.restoringPurchases;
      _pokemonDatasetProfile = pokemonDatasetProfile;
      _loading = false;
    });
  }

  Future<void> _changePrimaryGame(TcgGame selected) async {
    if (selected == _primaryGame) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      l10n.primaryGameFixedMessage,
    );
  }

  Widget _buildGameSelectorEntry(TcgGame game) {
    final l10n = AppLocalizations.of(context)!;
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
              ? l10n.primaryFreeForever
              : l10n.purchasedLabel,
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
              l10n.secondaryPurchaseRequired,
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
                l10n
                    .buyGameLabel(
                      gameName,
                      _purchaseManager.additionalTcgPriceLabel ?? '',
                    )
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
        _ownedTcgs = _resolveOwnedTcgsForUi(_ownedTcgs);
      });
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.purchasesRestoredMessage,
      );
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.restorePurchasesTimeoutMessage,
      );
    } catch (error, stackTrace) {
      debugPrint('Restore purchases failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.restorePurchasesErrorMessage,
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
          AppLocalizations.of(context)!.playStoreProductUnavailable,
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
          title: Text(AppLocalizations.of(context)!.buyGameTitle(secondaryName)),
          content: Text(
            AppLocalizations.of(context)!.buyGameBody(secondaryName, priceLabel),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppLocalizations.of(context)!.continuePurchaseLabel),
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
          AppLocalizations.of(context)!.purchaseAlreadyOwnedSynced,
        );
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.storeConnectionTimeout,
      );
    } catch (error, stackTrace) {
      debugPrint('Secondary game purchase flow failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.purchaseFailedRetry,
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

  String _themeLabel(String code) {
    switch (code.trim().toLowerCase()) {
      case 'vault':
        return 'Vault';
      case 'magic':
      default:
        return 'Magic';
    }
  }

  String _themeDescription(String code) {
    final l10n = AppLocalizations.of(context)!;
    final normalized = code.trim().toLowerCase();
    if (normalized == 'vault') {
      return l10n.themeVaultDescription;
    }
    return l10n.themeMagicDescription;
  }

  Future<void> _changeVisualTheme() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SimpleDialog(
          title: Text(l10n.visualThemeTitle),
          children: [
            RadioGroup<String>(
              groupValue: _appThemeCode,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'magic',
                    title: const Text('Magic'),
                    subtitle: Text(l10n.themeMagicSubtitle),
                  ),
                  RadioListTile<String>(
                    value: 'vault',
                    title: const Text('Vault'),
                    subtitle: Text(l10n.themeVaultSubtitle),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (selected == null || selected == _appThemeCode) {
      return;
    }
    await AppSettings.saveVisualTheme(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _appThemeCode = selected;
    });
    _appThemeNotifier.value = appVisualThemeFromCode(selected);
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

  Future<void> _reportIssueFromSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final categories = <String, String>{
      'crash': l10n.issueCategoryCrash,
      'ui': l10n.issueCategoryUi,
      'purchase': l10n.issueCategoryPurchase,
      'database': l10n.issueCategoryDatabase,
      'other': l10n.issueCategoryOther,
    };
    final controller = TextEditingController();
    final payload = await showDialog<(String, String)>(
      context: context,
      builder: (context) {
        var selectedCategory = 'other';
        return AlertDialog(
          title: Text(l10n.reportIssueLabel),
          content: StatefulBuilder(
            builder: (context, setModalState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: l10n.issueCategoryLabel,
                  ),
                  items: categories.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setModalState(() {
                      selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: l10n.issueDescribeHint,
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
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((controller.text, selectedCategory)),
              child: Text(l10n.sendLabel),
            ),
          ],
        );
      },
    );
    if (payload == null || payload.$1.trim().isEmpty || !mounted) {
      return;
    }
    final diagnostics = await _buildIssueDiagnostics();
    final sent = await _submitManualIssueReport(
      payload.$1,
      source: 'settings',
      category: payload.$2,
      diagnostics: diagnostics,
    );
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      sent ? l10n.reportSentThanks : l10n.reportSendUnavailable,
    );
  }

  Future<String> _buildIssueDiagnostics() async {
    final selectedGame = await AppSettings.loadSelectedTcgGame();
    final gameLabel = selectedGame == AppTcgGame.pokemon ? 'pokemon' : 'mtg';
    final tier = _purchaseManager.userTier == UserTier.plus ? 'plus' : 'free';
    final unlocked = _ownedTcgs.toList()..sort();
    return [
      'app_version=$_appVersion',
      'locale=$_appLocaleCode',
      'platform=${Platform.operatingSystem}',
      'platform_version=${Platform.operatingSystemVersion}',
      'selected_game=$gameLabel',
      'primary_game=${_primaryGame == TcgGame.pokemon ? 'pokemon' : 'mtg'}',
      'user_tier=$tier',
      'owned_tcgs=${unlocked.join(',')}',
      'extra_tcg_slots=${_purchaseManager.extraTcgSlots}',
      'store_available=${_purchaseManager.storeAvailable}',
      'last_error=${_purchaseManager.lastError ?? ''}',
      'can_access_mtg=${_purchaseManager.canAccessGame(AppTcgGame.mtg)}',
      'can_access_pokemon=${_purchaseManager.canAccessGame(AppTcgGame.pokemon)}',
      'purchase_pending=${_purchaseManager.purchasePending}',
      'restoring_purchases=${_purchaseManager.restoringPurchases}',
    ].join(' | ');
  }

  Future<void> _copyDiagnosticsToClipboard() async {
    final diagnostics = await _buildIssueDiagnostics();
    await Clipboard.setData(ClipboardData(text: diagnostics));
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.diagnosticsCopied,
    );
  }

  Future<void> _runManualCollectionCoherenceCheck() async {
    if (_coherenceCheckBusy) {
      return;
    }
    setState(() {
      _coherenceCheckBusy = true;
    });
    try {
      final repaired = await ScryfallDatabase.instance
          .repairAllCardsCoherenceFromCustomCollections();
      if (!mounted) {
        return;
      }
      _collectionsRefreshNotifier.value = _collectionsRefreshNotifier.value + 1;
      showAppSnackBar(
        context,
        repaired > 0
            ? (_isItalianUi
                  ? 'Controllo completato: $repaired correzioni applicate.'
                  : 'Check completed: $repaired fixes applied.')
            : (_isItalianUi
                  ? 'Controllo completato: nessuna incoerenza trovata.'
                  : 'Check completed: no inconsistencies found.'),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        _isItalianUi
            ? 'Errore durante il controllo coerenza. Riprova.'
            : 'Error while running coherence check. Please retry.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _coherenceCheckBusy = false;
        });
      }
    }
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

  Future<void> _setItalianCardsEnabled(TcgGame game, bool enabled) async {
    final target = game == TcgGame.pokemon ? AppTcgGame.pokemon : AppTcgGame.mtg;
    final languages = <String>{'en'};
    if (enabled) {
      languages.add('it');
    }
    await AppSettings.saveCardLanguagesForGame(target, languages);
    final bulkType = await AppSettings.loadBulkTypeForGame(target);
    if (!mounted) {
      return;
    }
    setState(() {
      if (game == TcgGame.mtg) {
        _mtgItalianCardsEnabled = enabled;
      } else {
        _pokemonItalianCardsEnabled = enabled;
      }
    });
    final gameLabel = game == TcgGame.pokemon ? 'Pokemon' : 'Magic';
    final normalizedBulk = (bulkType ?? '').trim().toLowerCase();
    final requiresAllCards = enabled && normalizedBulk != 'all_cards';
    final shouldReimportNow = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final body = requiresAllCards
            ? (_isItalianUi
                  ? 'Lingue $gameLabel aggiornate. Per la ricerca locale in italiano usa il database "All Cards". Poi reimporta.'
                  : '$gameLabel languages updated. For Italian local search, use the "All Cards" database. Then reimport.')
            : (_isItalianUi
                  ? 'Lingue $gameLabel aggiornate. Per applicare la modifica devi reimportare il database locale.'
                  : '$gameLabel languages updated. Reimport the local database to apply this change.');
        return AlertDialog(
          title: Text(_isItalianUi ? 'Lingue aggiornate' : 'Languages updated'),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_reimportLabel()),
            ),
          ],
        );
      },
    );
    if (shouldReimportNow == true && mounted) {
      await _reimportDatabaseForGame(game, skipConfirmation: true);
    }
  }

  Future<void> _changeBulkType() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await _showBulkTypePicker(
      context,
      allowCancel: true,
      selectedType: _bulkType,
      requireConfirmation: true,
      confirmLabel: l10n.downloadUpdate,
      allowResetAction: true,
      resetLabel: l10n.resetMagicDatabaseLabel,
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
      await AppSettings.saveBulkTypeForGame(AppTcgGame.mtg, selected);
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
    final gameLabel = game == TcgGame.mtg ? 'Magic' : 'Pokemon';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            l10n.resetGameDatabaseTitle(gameLabel),
          ),
          content: Text(
            l10n.resetGameDatabaseBody(gameLabel),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.reset),
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
        title: Text(l10n.resetInProgressTitle),
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
                l10n.cleaningGameDatabase(gameLabel),
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
      l10n.gameDatabaseResetDone(gameLabel),
    );
    _collectionsRefreshNotifier.value = _collectionsRefreshNotifier.value + 1;
  }

  String _reimportLabel() => _isItalianUi ? 'Reimporta' : 'Reimport';

  String _reimportConfirmTitle(String gameLabel) => _isItalianUi
      ? 'Reimporta database $gameLabel'
      : 'Reimport $gameLabel database';

  String _reimportConfirmBody(String gameLabel) => _isItalianUi
      ? 'Usa i file gia presenti in locale senza scaricare di nuovo.'
      : 'Use already downloaded local files without downloading again.';

  String _reimportProgressLabel(String gameLabel) => _isItalianUi
      ? 'Reimport database $gameLabel in corso...'
      : 'Reimporting $gameLabel database...';

  String _reimportDoneLabel(String gameLabel) => _isItalianUi
      ? 'Reimport database $gameLabel completato.'
      : '$gameLabel database reimport completed.';

  Future<void> _showImportLanguageSummaryDialog({
    required String title,
    required Map<String, int> languageCounts,
    List<String> details = const <String>[],
  }) async {
    if (!mounted || languageCounts.isEmpty) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: languageCounts.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${entry.key.toUpperCase()}: ${entry.value}'),
                    ),
                  )
                  .toList()
                ..addAll(
                  details.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.closeLabel),
          ),
        ],
      ),
    );
  }

  String _reimportFailedLabel(Object error) {
    if (_isStorageSpaceError(error)) {
      return _storageSpaceErrorMessage(italian: _isItalianUi);
    }
    final text = error.toString();
    if (_isItalianUi) {
      if (text.contains('pokemon_dataset_cache_empty')) {
        return 'Reimport fallito: nessun file locale trovato per Pokemon.';
      }
      if (text.contains('bulk_file_not_found')) {
        return 'Reimport fallito: file bulk locale non trovato.';
      }
      if (text.contains('bulk_local_missing_it')) {
        return 'Reimport fallito: il file locale non contiene abbastanza carte italiane. Scarica di nuovo "All printings".';
      }
      return 'Reimport fallito: $text';
    }
    if (text.contains('pokemon_dataset_cache_empty')) {
      return 'Reimport failed: no local Pokemon cache files found.';
    }
    if (text.contains('bulk_file_not_found')) {
      return 'Reimport failed: local bulk file not found.';
    }
    if (text.contains('bulk_local_missing_it')) {
      return 'Reimport failed: local file has too few Italian cards. Download "All printings" again.';
    }
    return 'Reimport failed: $text';
  }

  Future<void> _reimportDatabaseForGame(
    TcgGame game, {
    bool skipConfirmation = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final gameLabel = game == TcgGame.mtg ? 'Magic' : 'Pokemon';
    if (!skipConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(_reimportConfirmTitle(gameLabel)),
            content: Text(_reimportConfirmBody(gameLabel)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(_reimportLabel()),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
    } else if (!mounted) {
      return;
    }

    var progress = 0.0;
    var status = _reimportProgressLabel(gameLabel);
    StateSetter? dialogSetState;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogSetState = setDialogState;
            return AlertDialog(
              title: Text(_reimportLabel()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                ],
              ),
            );
          },
        );
      },
    );

    void updateProgress(double nextProgress, [String? nextStatus]) {
      progress = nextProgress.clamp(0.0, 1.0);
      if (nextStatus != null && nextStatus.trim().isNotEmpty) {
        status = nextStatus.trim();
      }
      if (dialogSetState != null) {
        dialogSetState!(() {});
      }
    }

    var importedLanguageCounts = <String, int>{};
    var localBulkCacheFiles = -1;
    var cleanedBulkFiles = 0;
    try {
      await TcgEnvironmentController.instance.init();
      final activeGame = TcgEnvironmentController.instance.currentGame;
      final activeConfig = TcgEnvironmentController.instance.configFor(
        activeGame,
      );
      final targetConfig = TcgEnvironmentController.instance.configFor(game);
      await ScryfallDatabase.instance.setDatabaseFileName(targetConfig.dbFileName);
      try {
        if (game == TcgGame.mtg) {
          final bulkType =
              await AppSettings.loadBulkTypeForGame(AppTcgGame.mtg) ??
              'oracle_cards';
          final appDir = await getApplicationDocumentsDirectory();
          final bulkPath = '${appDir.path}/${_bulkTypeFileName(bulkType)}';
          final bulkFile = File(bulkPath);
          if (!await bulkFile.exists()) {
            throw FileSystemException('bulk_file_not_found', bulkPath);
          }
          final languages = (await AppSettings.loadCardLanguagesForGame(
            AppTcgGame.mtg,
          )).toSet();
          if (languages.isEmpty) {
            languages.add('en');
          }
          final normalizedBulkType = bulkType.trim().toLowerCase();
          if (normalizedBulkType == 'all_cards' &&
              languages.contains('it')) {
            final preflight = await ScryfallBulkImporter()
                .inspectLocalBulkLanguageCounts(bulkPath);
            final italianCount = preflight.languageCounts['it'] ?? 0;
            if (italianCount < 1000) {
              throw StateError('bulk_local_missing_it:$italianCount');
            }
          }
          updateProgress(0.02, _reimportProgressLabel(gameLabel));
          await ScryfallBulkImporter().importAllCardsJson(
            bulkPath,
            onProgress: (count, value) {
              final label = _isItalianUi
                  ? 'Reimport Magic: $count carte'
                  : 'Reimport Magic: $count cards';
              updateProgress(value, label);
            },
            bulkType: bulkType,
            allowedLanguages: languages.toList()..sort(),
          );
          cleanedBulkFiles = await _cleanupMtgBulkFilesKeepingType(bulkType);
          localBulkCacheFiles = await _countMtgBulkCacheFiles();
          importedLanguageCounts = await ScryfallDatabase.instance
              .fetchCardCountsByLanguage();
        } else {
          await PokemonBulkService.instance.reimportFromLocalCache(
            onProgress: (value) =>
                updateProgress(value, _reimportProgressLabel(gameLabel)),
            onStatus: (value) => updateProgress(progress, value),
          );
          importedLanguageCounts = await ScryfallDatabase.instance
              .fetchCardCountsByLanguage();
        }
      } finally {
        await ScryfallDatabase.instance.setDatabaseFileName(
          activeConfig.dbFileName,
        );
      }
    } catch (error) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, _reimportFailedLabel(error));
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
    if (!mounted) {
      return;
    }
    await _showImportLanguageSummaryDialog(
      title: _isItalianUi
          ? 'Carte importate per lingua'
          : 'Imported cards by language',
      languageCounts: importedLanguageCounts,
      details: localBulkCacheFiles >= 0
          ? <String>[
              'Local bulk cache files: $localBulkCacheFiles (cleaned: $cleanedBulkFiles)',
            ]
          : const <String>[],
    );
    if (!mounted) {
      return;
    }
    showAppSnackBar(context, _reimportDoneLabel(gameLabel));
    _collectionsRefreshNotifier.value = _collectionsRefreshNotifier.value + 1;
  }

  String _pokemonProfileLabel(String profile) {
    return _pokemonDatasetProfileTitle(context, profile);
  }

  String _pokemonProfileDescription(String profile) {
    return _pokemonDatasetProfileDescription(context, profile);
  }

  Future<void> _changePokemonDatasetProfile() async {
    final selected = await _showPokemonDatasetProfilePicker(
      context,
      allowCancel: true,
      selectedProfile: _pokemonDatasetProfile,
      requireConfirmation: true,
      confirmLabel: AppLocalizations.of(context)!.applyProfileLabel,
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
      AppLocalizations.of(context)!.pokemonProfileUpdatedTapUpdate,
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
      final message = _isStorageSpaceError(error)
          ? _storageSpaceErrorMessage(italian: _isItalianUi)
          : l10n.importFailed(error);
      showAppSnackBar(context, message);
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
      final message = _isStorageSpaceError(error)
          ? _storageSpaceErrorMessage(italian: _isItalianUi)
          : l10n.importFailed(error);
      showAppSnackBar(context, message);
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
                  icon: Icons.palette_outlined,
                  title: l10n.visualThemeTitle,
                  subtitle: _themeDescription(_appThemeCode),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_themeLabel(_appThemeCode)),
                      trailing: OutlinedButton(
                        onPressed: _changeVisualTheme,
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
                  title: l10n.games,
                  subtitle: l10n.gamesSelectionSubtitle,
                  children: [
                    Text(
                      l10n.primaryGameLabel,
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
                              l10n.restorePurchases,
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
                  subtitle: l10n.configureBothDatabasesSubtitle,
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
                            child: Text(l10n.reset),
                          ),
                          OutlinedButton(
                            onPressed: () => _reimportDatabaseForGame(TcgGame.mtg),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            child: Text(_reimportLabel()),
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
                            child: Text(l10n.reset),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _reimportDatabaseForGame(TcgGame.pokemon),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF5D4731)),
                            ),
                            child: Text(_reimportLabel()),
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
                  icon: Icons.translate_rounded,
                  title: _isItalianUi
                      ? 'Lingue carte (database e ricerca)'
                      : 'Card languages (database and search)',
                  subtitle: _isItalianUi
                      ? 'Inglese sempre attivo. Per ricerca locale offline multilingua in Magic serve il database "All Cards".'
                      : 'English is always active. For multilingual offline local search in Magic, use the "All Cards" database.',
                  children: [
                    Builder(
                      builder: (context) {
                        final normalizedBulk =
                            (_bulkType ?? '').trim().toLowerCase();
                        final mtgOfflineReady =
                            !_mtgItalianCardsEnabled ||
                            normalizedBulk == 'all_cards';
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            color: mtgOfflineReady
                                ? const Color(0x1A2A4D30)
                                : const Color(0x33A06A1A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: mtgOfflineReady
                                  ? const Color(0xFF4D8B58)
                                  : const Color(0xFFE9C46A),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                mtgOfflineReady
                                    ? Icons.verified_rounded
                                    : Icons.warning_amber_rounded,
                                size: 18,
                                color: mtgOfflineReady
                                    ? const Color(0xFF8DD39A)
                                    : const Color(0xFFE9C46A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  mtgOfflineReady
                                      ? (_isItalianUi
                                            ? 'Magic offline: configurazione OK per ricerca multilingua locale.'
                                            : 'Magic offline: configuration OK for multilingual local search.')
                                      : (_isItalianUi
                                            ? 'Attenzione: con italiano attivo, la ricerca locale Magic funziona correttamente solo con database "All Cards".'
                                            : 'Warning: with Italian enabled, Magic local search works correctly only with the "All Cards" database.'),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFFDFC9A3),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Text(
                      'Magic',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _mtgItalianCardsEnabled,
                      title: Text(
                        _isItalianUi
                            ? 'Aggiungi carte italiane'
                            : 'Include Italian cards',
                      ),
                      subtitle: Text(
                        _isItalianUi ? 'Inglese sempre incluso' : 'English always included',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBFAE95),
                        ),
                      ),
                      onChanged: (value) => _setItalianCardsEnabled(TcgGame.mtg, value),
                    ),
                    const Divider(height: 20, color: Color(0xFF3A2F24)),
                    Text(
                      'Pokemon',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _pokemonItalianCardsEnabled,
                      title: Text(
                        _isItalianUi
                            ? 'Aggiungi carte italiane'
                            : 'Include Italian cards',
                      ),
                      subtitle: Text(
                        _isItalianUi ? 'Inglese sempre incluso' : 'English always included',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBFAE95),
                        ),
                      ),
                      onChanged: (value) =>
                          _setItalianCardsEnabled(TcgGame.pokemon, value),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.versionLabel,
                                    style: Theme.of(context).textTheme.titleSmall
                                        ?.copyWith(
                                          color: const Color(0xFFBFAE95),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _appVersion,
                                    style: Theme.of(context).textTheme.titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFFEFE7D8),
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 168,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _showLatestReleaseNotesPanel(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFE9C46A),
                                  foregroundColor: const Color(0xFF1C1510),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                ),
                                label: Text(_whatsNewLabel(context)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  context: context,
                  icon: Icons.build_circle_outlined,
                  title: l10n.toolsAndDiagnosticsTitle,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final spacing = 10.0;
                        final buttonWidth = (constraints.maxWidth - spacing) / 2;
                        final uniformHeight = const Size.fromHeight(44);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: buttonWidth,
                                  child: FilledButton(
                                    onPressed: _coherenceCheckBusy
                                        ? null
                                        : _runManualCollectionCoherenceCheck,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFE9C46A),
                                      foregroundColor: const Color(0xFF1C1510),
                                      minimumSize: uniformHeight,
                                      maximumSize: uniformHeight,
                                    ),
                                    child: _coherenceCheckBusy
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF1C1510),
                                            ),
                                          )
                                        : Text(
                                            l10n.checkCoherenceLabel,
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ),
                                ),
                                SizedBox(width: spacing),
                                SizedBox(
                                  width: buttonWidth,
                                  child: OutlinedButton(
                                    onPressed: _copyDiagnosticsToClipboard,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF5D4731),
                                      ),
                                      minimumSize: uniformHeight,
                                      maximumSize: uniformHeight,
                                    ),
                                    child: Text(
                                      l10n.copyDiagnosticsLabel,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(width: buttonWidth),
                                SizedBox(width: spacing),
                                SizedBox(
                                  width: buttonWidth,
                                  child: OutlinedButton(
                                    onPressed: _reportIssueFromSettings,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFFC85454),
                                      ),
                                      foregroundColor: const Color(0xFFEAA0A0),
                                      minimumSize: uniformHeight,
                                      maximumSize: uniformHeight,
                                    ),
                                    child: Text(
                                      l10n.reportIssueLabel,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
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

