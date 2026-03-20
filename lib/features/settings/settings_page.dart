part of 'package:tcg_tracker/main.dart';

class SettingsPostAction {
  const SettingsPostAction._({required this.game, this.mtgBulkType});

  final TcgGame game;
  final String? mtgBulkType;

  factory SettingsPostAction.startMtgDownload({required String bulkType}) =>
      SettingsPostAction._(game: TcgGame.mtg, mtgBulkType: bulkType);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

enum _BackupTarget { local, cloud }

class _SettingsPageState extends State<SettingsPage> {
  static const String _pokemonOwnershipKey =
      PurchaseManager.pokemonOwnershipKey;
  static const Duration _storeOperationTimeout = Duration(seconds: 20);
  bool _loading = true;
  String? _bulkType;
  String _priceSource = 'scryfall';
  String _priceCurrency = 'eur';
  bool _showPrices = true;
  bool _mtgItalianCardsEnabled = false;
  bool _pokemonItalianCardsEnabled = false;
  String _appLocaleCode = 'en';
  String _appThemeCode = 'magic';
  String _appVersion = '0.5.0';
  bool _backupBusy = false;
  String? _latestPokemonAutoBackupName;
  DateTime? _latestPokemonAutoBackupAt;
  bool _gamesBusy = false;
  bool _coherenceCheckBusy = false;
  TcgGame _primaryGame = TcgGame.mtg;
  Set<String> _ownedTcgs = const <String>{};
  late final PurchaseManager _purchaseManager;
  late final VoidCallback _purchaseListener;

  Future<_BackupTarget?> _pickBackupTarget({required bool forImport}) async {
    if (!mounted) {
      return null;
    }
    final italian = _isItalianUi;
    final title = italian
        ? (forImport ? 'Import backup' : 'Export backup')
        : (forImport ? 'Import backup' : 'Export backup');
    final localSubtitle = italian
        ? (forImport
              ? 'Seleziona un file locale sul dispositivo.'
              : 'Salva un file locale sul dispositivo.')
        : (forImport
              ? 'Select a local file on this device.'
              : 'Save a local file on this device.');
    final cloudSubtitle = italian
        ? 'Backup cloud (in arrivo).'
        : 'Cloud backup (coming soon).';
    return showDialog<_BackupTarget>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_android_rounded),
              title: Text(italian ? 'Locale' : 'Local'),
              subtitle: Text(localSubtitle),
              onTap: () => Navigator.of(context).pop(_BackupTarget.local),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text('Cloud'),
              subtitle: Text(cloudSubtitle),
              onTap: () => Navigator.of(context).pop(_BackupTarget.cloud),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _showCloudBackupComingSoon({required bool forImport}) async {
    if (!mounted) {
      return;
    }
    final italian = _isItalianUi;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          italian ? 'Backup cloud in arrivo' : 'Cloud backup coming soon',
        ),
        content: Text(
          italian
              ? 'Il backup cloud non e ancora attivo in questa release. Usa il backup locale per ora.'
              : 'Cloud backup is not enabled in this release yet. Use local backup for now.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              forImport
                  ? AppLocalizations.of(context)!.backupImport
                  : AppLocalizations.of(context)!.backupExport,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    final target = await _pickBackupTarget(forImport: false);
    if (target == null || !mounted) {
      return;
    }
    if (target == _BackupTarget.local) {
      await _exportLocalBackup();
      return;
    }
    await _showCloudBackupComingSoon(forImport: false);
  }

  Future<void> _importBackup() async {
    final target = await _pickBackupTarget(forImport: true);
    if (target == null || !mounted) {
      return;
    }
    if (target == _BackupTarget.local) {
      await _importLocalBackup();
      return;
    }
    await _showCloudBackupComingSoon(forImport: true);
  }

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
    final mtgCardLanguages = await AppSettings.loadCardLanguagesForGame(
      AppTcgGame.mtg,
    );
    final pokemonCardLanguagesRaw = await AppSettings.loadCardLanguagesForGame(
      AppTcgGame.pokemon,
    );
    final pokemonCardLanguages = pokemonCardLanguagesRaw
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final latestPokemonAutoBackup = await LocalBackupService.instance
        .latestBackupFile(
          prefix: LocalBackupService.pokemonAutomaticBackupPrefix,
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
      _latestPokemonAutoBackupName = latestPokemonAutoBackup == null
          ? null
          : path.basename(latestPokemonAutoBackup.path);
      _latestPokemonAutoBackupAt =
          latestPokemonAutoBackup?.statSync().modified;
      _primaryGame = (primaryGame ?? selectedGame) == AppTcgGame.pokemon
          ? TcgGame.pokemon
          : TcgGame.mtg;
      final pokemonAccessible =
          pokemonUnlocked || ownedTcgs.contains(_pokemonOwnershipKey);
      final baseOwned =
          pokemonAccessible && !ownedTcgs.contains(_pokemonOwnershipKey)
          ? {...ownedTcgs, _pokemonOwnershipKey}
          : ownedTcgs;
      _ownedTcgs = _resolveOwnedTcgsForUi(baseOwned);
      _gamesBusy =
          _purchaseManager.purchasePending ||
          _purchaseManager.restoringPurchases;
      _loading = false;
    });
  }

  String _formatBackupTimestamp(DateTime value) {
    final local = value.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  Future<void> _changePrimaryGame(TcgGame selected) async {
    if (selected == _primaryGame) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(context, l10n.primaryGameFixedMessage);
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
          isPrimary ? l10n.primaryFreeForever : l10n.purchasedLabel,
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
    } catch (error) {
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
          title: Text(
            AppLocalizations.of(context)!.buyGameTitle(secondaryName),
          ),
          content: Text(
            AppLocalizations.of(
              context,
            )!.buyGameBody(secondaryName, priceLabel),
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
    } catch (error) {
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
                            label: Text(l10n.restorePurchases),
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
                            onPressed: () =>
                                _reimportDatabaseForGame(TcgGame.mtg),
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
                      AppLocalizations.of(context)!.pokemonDbProfileFullTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.pokemonDbProfileFullDescription,
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
                        final normalizedBulk = (_bulkType ?? '')
                            .trim()
                            .toLowerCase();
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
                        _isItalianUi
                            ? 'Inglese sempre incluso'
                            : 'English always included',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBFAE95),
                        ),
                      ),
                      onChanged: (value) =>
                          _setItalianCardsEnabled(TcgGame.mtg, value),
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
                        _isItalianUi
                            ? 'Inglese sempre incluso. Italiano opzionale (download piu lungo).'
                            : 'English always included. Italian optional (longer download).',
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
                            onPressed: _backupBusy ? null : _exportBackup,
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
                            onPressed: _backupBusy ? null : _importBackup,
                            icon: const Icon(Icons.download_rounded),
                            label: Text(l10n.backupImport),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                            _isItalianUi
                                ? 'Recovery automatico Pokemon'
                                : 'Pokemon automatic recovery',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _latestPokemonAutoBackupName == null
                                ? (_isItalianUi
                                      ? 'Nessun backup automatico Pokemon disponibile.'
                                      : 'No automatic Pokemon backup available.')
                                : (_isItalianUi
                                      ? 'Ultimo backup: ${_formatBackupTimestamp(_latestPokemonAutoBackupAt!)}'
                                      : 'Latest backup: ${_formatBackupTimestamp(_latestPokemonAutoBackupAt!)}'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFFBFAE95)),
                          ),
                          if (_latestPokemonAutoBackupName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _latestPokemonAutoBackupName!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFD8C7AE)),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _backupBusy ||
                                      _latestPokemonAutoBackupName == null
                                  ? null
                                  : _restoreLatestPokemonAutomaticBackup,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF5D4731)),
                              ),
                              icon: const Icon(Icons.restore_rounded),
                              label: Text(
                                _isItalianUi
                                    ? 'Ripristina ultimo backup Pokemon'
                                    : 'Restore latest Pokemon backup',
                              ),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: const Color(0xFFBFAE95),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _appVersion,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
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
                        final buttonWidth =
                            (constraints.maxWidth - spacing) / 2;
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
