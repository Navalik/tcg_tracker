part of 'package:tcg_tracker/main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  bool _loadingGames = true;
  String? _bulkType;
  List<String> _enabledGames = [];
  String? _primaryGameId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bulkType = await AppSettings.loadBulkType();
    final enabledGames = await AppSettings.loadEnabledGames();
    final primaryGameId = await AppSettings.loadPrimaryGameId();
    if (!mounted) {
      return;
    }
    setState(() {
      _bulkType = bulkType;
      _enabledGames = enabledGames;
      _primaryGameId = primaryGameId;
      _loading = false;
      _loadingGames = false;
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
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.primaryGameSet(
            _gameLabel(AppLocalizations.of(context)!, id),
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
    if (!manager.isPro && _enabledGames.isNotEmpty) {
      await _showGameLimitDialog();
      return;
    }
    final remaining = _gameOptions
        .where((option) => !_enabledGames.contains(option.id))
        .toList();
    if (remaining.isEmpty) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.allGamesAdded,
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
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.resetComplete,
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
