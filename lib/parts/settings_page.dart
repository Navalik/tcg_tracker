part of 'package:tcg_tracker/main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  String? _bulkType;
  String _priceSource = 'scryfall';
  String _priceCurrency = 'eur';
  bool _showPrices = true;
  String _appLocaleCode = 'en';
  String _appVersion = '0.4.2';

  bool get _supportsFirebaseAuth => Platform.isAndroid || Platform.isIOS;

  List<Widget> _maybeWidget(Widget? widget) {
    if (widget == null) {
      return const <Widget>[];
    }
    return <Widget>[widget];
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bulkType = await AppSettings.loadBulkType();
    final priceCurrency = await AppSettings.loadPriceCurrency();
    final showPrices = await AppSettings.loadShowPrices();
    final appLocaleCode = await AppSettings.loadAppLocale();
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
      _loading = false;
    });
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
                title: const Text('Scryfall'),
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
    final selected = await _showBulkTypePicker(
      context,
      allowCancel: true,
      selectedType: _bulkType,
    );
    if (selected == null || selected == _bulkType) {
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
              Expanded(
                child: Text(l10n.preparingDatabaseBody),
              ),
            ],
          ),
        );
      },
    );

    try {
      await AppSettings.saveBulkType(selected);
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
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.databaseChangedGoHome,
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
      final targetPath =
          '${directory.path}/${_bulkTypeFileName(option.type)}';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unableToSignOutTryAgain)),
      );
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authGoogleSignInFailedTryAgain)),
      );
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

  Widget _buildProfileTile(User? user) {
    final displayName = user?.displayName?.trim();
    final email = user?.email?.trim();
    final hasDisplayName = displayName != null && displayName.isNotEmpty;
    final hasEmail = email != null && email.isNotEmpty;
    final isGuest = user == null;
    final l10n = AppLocalizations.of(context)!;
    final title =
        hasDisplayName ? displayName : (isGuest ? l10n.guestLabel : l10n.googleUserLabel);
    final subtitle =
        hasEmail ? email : (isGuest ? l10n.localProfileLabel : l10n.signedInWithGoogle);

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
          : TextButton(
              onPressed: _signOut,
              child: Text(l10n.signOut),
            ),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFBFAE95),
                  ),
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
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: Stack(
        children: [
          const _AppBackground(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _buildSectionCard(
                  context: context,
                  icon: Icons.account_circle_outlined,
                  title: l10n.profile,
                  children: [
                    _buildProfileSection(context),
                  ],
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
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFBFAE95),
                                ),
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
                              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
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
                  subtitle: l10n.cardDatabaseSubtitle,
                  children: [
                    Text(
                      _bulkTypeLabel(l10n, _bulkType),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bulkTypeDescription(l10n, _bulkType ?? ''),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFBFAE95),
                          ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: _changeBulkType,
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
                              children: const [
                                Expanded(
                                  child: RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    value: 'eur',
                                    title: Text('EUR'),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    value: 'usd',
                                    title: Text('USD'),
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
                  icon: Icons.info_outline_rounded,
                  title: l10n.appInfo,
                  children: [
                    ListTile(
                      title: Text(l10n.versionLabel),
                      subtitle: Text(_appVersion),
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
