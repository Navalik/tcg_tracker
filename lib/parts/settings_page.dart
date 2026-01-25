part of 'package:tcg_tracker/main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  bool _loadingLanguages = true;
  bool _loadingGames = true;
  List<String> _languageOptions = [];
  Set<String> _selectedLanguages = {};
  String? _bulkType;
  List<String> _enabledGames = [];
  String? _primaryGameId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final stored = await AppSettings.loadSearchLanguages();
    final cachedLanguages = await AppSettings.loadAvailableLanguages();
    final allOptions = AppSettings.languageCodes.toList()..sort();
    final bulkType = await AppSettings.loadBulkType();
    final enabledGames = await AppSettings.loadEnabledGames();
    final primaryGameId = await AppSettings.loadPrimaryGameId();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedLanguages = stored.isEmpty ? {'en'} : stored;
      _languageOptions = cachedLanguages.isEmpty ? allOptions : cachedLanguages;
      _bulkType = bulkType;
      _enabledGames = enabledGames;
      _primaryGameId = primaryGameId;
      _loading = false;
      _loadingLanguages = cachedLanguages.isEmpty;
      _loadingGames = false;
    });
    if (cachedLanguages.isNotEmpty) {
      return;
    }
    final available = AppSettings.languageCodes.toList()..sort();
    if (!mounted) {
      return;
    }
    final resolved =
        available.isEmpty ? AppSettings.defaultLanguages : available;
    await AppSettings.saveAvailableLanguages(resolved);
    if (!mounted) {
      return;
    }
    setState(() {
      _languageOptions = resolved;
      _loadingLanguages = false;
    });
  }

  Future<void> _saveLanguages() async {
    await AppSettings.saveSearchLanguages(_selectedLanguages);
  }

  String _languageLabel(String code) {
    final l10n = AppLocalizations.of(context)!;
    switch (code) {
      case 'en':
        return l10n.languageEnglish;
      case 'it':
        return l10n.languageItalian;
      case 'fr':
        return l10n.languageFrench;
      case 'de':
        return l10n.languageGerman;
      case 'es':
        return l10n.languageSpanish;
      case 'pt':
        return l10n.languagePortuguese;
      case 'ja':
        return l10n.languageJapanese;
      case 'ko':
        return l10n.languageKorean;
      case 'ru':
        return l10n.languageRussian;
      case 'zhs':
        return l10n.languageChineseSimplified;
      case 'zht':
        return l10n.languageChineseTraditional;
      case 'ar':
        return l10n.languageArabic;
      case 'he':
        return l10n.languageHebrew;
      case 'la':
        return l10n.languageLatin;
      case 'grc':
        return l10n.languageGreek;
      case 'sa':
        return l10n.languageSanskrit;
      case 'ph':
        return l10n.languagePhyrexian;
      case 'qya':
        return l10n.languageQuenya;
      default:
        return code.toUpperCase();
    }
  }

  Future<void> _addLanguage() async {
    final options = _languageOptions
        .where((code) => !_selectedLanguages.contains(code))
        .toList()
      ..sort();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.allLanguagesAdded)),
      );
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.addLanguage),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final code = options[index];
                return ListTile(
                  title: Text(_languageLabel(code)),
                  subtitle: Text(code),
                  onTap: () => Navigator.of(context).pop(code),
                );
              },
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
    if (selected == null) {
      return;
    }
    setState(() {
      _selectedLanguages.add(selected);
    });
    await _saveLanguages();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.languageAddedDownloadAgain,
        ),
      ),
    );
  }

  Future<void> _removeLanguage(String code) async {
    if (code == 'en') {
      return;
    }
    setState(() {
      _selectedLanguages.remove(code);
    });
    await _saveLanguages();
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
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _bulkType = selected;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.databaseChangedGoHome,
        ),
      ),
    );
  }

  Future<void> _setPrimaryGame(String id) async {
    if (id.isEmpty) {
      return;
    }
    if (!_enabledGames.contains(id)) {
      _enabledGames = [..._enabledGames, id];
      await AppSettings.saveEnabledGames(_enabledGames);
    }
    await AppSettings.savePrimaryGameId(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _primaryGameId = id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.primaryGameSet(
                _gameLabel(AppLocalizations.of(context)!, id),
              ),
        ),
      ),
    );
  }

  Future<void> _showGameLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.gameLimitReachedTitle),
          content: Text(l10n.gameLimitReachedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.notNow),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProPage(),
                  ),
                );
              },
              child: Text(l10n.upgrade),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addGame() async {
    final manager = PurchaseManager.instance;
    if (!manager.isPro && _enabledGames.length >= 1) {
      await _showGameLimitDialog();
      return;
    }
    final remaining = _gameOptions
        .where((option) => !_enabledGames.contains(option.id))
        .toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.allGamesAdded)),
      );
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.addGame),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: remaining
                .map(
                  (option) => ListTile(
                    title: Text(option.name),
                    subtitle: Text(_gameDescription(l10n, option.id)),
                    onTap: () => Navigator.of(context).pop(option.id),
                  ),
                )
                .toList(),
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
    if (selected == null || selected.isEmpty) {
      return;
    }
    final updated = [..._enabledGames, selected];
    await AppSettings.saveEnabledGames(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _enabledGames = updated;
      _primaryGameId ??= selected;
    });
    await AppSettings.savePrimaryGameId(_primaryGameId!);
  }

  String _gameStatusLabel(String id) {
    if (_primaryGameId == id) {
      return AppLocalizations.of(context)!.primaryLabel;
    }
    return AppLocalizations.of(context)!.addedLabel;
  }

  Future<void> _performHardReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.factoryResetTitle),
          content: Text(l10n.factoryResetBody),
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
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.cleaningUpTitle),
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.removingLocalDataBody),
              ),
            ],
          ),
        );
      },
    );

    try {
      await AppSettings.reset();
      await ScryfallBulkChecker().resetState();
      await ScryfallDatabase.instance.hardReset();
      await _deleteBulkFiles();
    } finally {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.resetComplete),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedLanguages = _selectedLanguages.toList()..sort();
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
                Text(
                  l10n.searchLanguages,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.searchLanguagesSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                if (_loadingLanguages)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  ...selectedLanguages.map(
                    (code) => ListTile(
                      title: Text(_languageLabel(code)),
                      subtitle: Text(code),
                      contentPadding: EdgeInsets.zero,
                      trailing: code == 'en'
                          ? Text(l10n.defaultLabel)
                          : IconButton(
                              tooltip: l10n.remove,
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removeLanguage(code),
                            ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loadingLanguages ? null : _addLanguage,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addLanguage),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.cardDatabase,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.cardDatabaseSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text(_bulkTypeLabel(l10n, _bulkType)),
                  subtitle: Text(l10n.selectedType),
                  contentPadding: EdgeInsets.zero,
                  trailing: TextButton(
                    onPressed: _changeBulkType,
                    child: Text(l10n.change),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.games,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.gamesSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                if (_loadingGames)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  ..._enabledGames.map(
                    (id) => ListTile(
                      title: Text(_gameLabel(l10n, id)),
                      subtitle: Text(_gameStatusLabel(id)),
                      contentPadding: EdgeInsets.zero,
                      trailing: TextButton(
                        onPressed: () => _setPrimaryGame(id),
                        child: Text(l10n.makePrimary),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addGame,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addGame),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.pro,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.proSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: PurchaseManager.instance,
                  builder: (context, _) {
                    final manager = PurchaseManager.instance;
                    return ListTile(
                      title: Text(l10n.proStatus),
                      subtitle: Text(
                        manager.isPro ? l10n.proActive : l10n.basePlan,
                      ),
                      contentPadding: EdgeInsets.zero,
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProPage(),
                            ),
                          );
                        },
                        child: Text(l10n.manage),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.reset,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.resetSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _performHardReset,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB85C38),
                  ),
                  child: Text(l10n.factoryReset),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
