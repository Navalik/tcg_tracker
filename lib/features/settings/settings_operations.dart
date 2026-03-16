// ignore_for_file: invalid_use_of_protected_member, use_build_context_synchronously

part of 'package:tcg_tracker/main.dart';

extension _SettingsOperationsSection on _SettingsPageState {
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
                  decoration: InputDecoration(hintText: l10n.issueDescribeHint),
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
              onPressed: () => Navigator.of(
                context,
              ).pop((controller.text, selectedCategory)),
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
    showAppSnackBar(context, AppLocalizations.of(context)!.diagnosticsCopied);
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

  Future<void> _setItalianCardsEnabled(TcgGame game, bool enabled) async {
    final target = game == TcgGame.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
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
    final requiresAllCards =
        game == TcgGame.mtg && enabled && normalizedBulk != 'all_cards';
    final canReimportNow = !requiresAllCards;
    final shouldReimportNow = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final body = requiresAllCards
            ? (_isItalianUi
                  ? 'Lingue $gameLabel aggiornate. Con il database corrente le carte italiane saranno visibili solo online. Per averle in locale devi usare il database "All Cards".'
                  : '$gameLabel languages updated. With the current database, Italian cards will be visible online only. To have them locally, switch to the "All Cards" database.')
            : (_isItalianUi
                  ? 'Lingue $gameLabel aggiornate. Per applicare la modifica devi reimportare il database locale.'
                  : '$gameLabel languages updated. Reimport the local database to apply this change.');
        return AlertDialog(
          title: Text(_isItalianUi ? 'Lingue aggiornate' : 'Languages updated'),
          content: Text(body),
          actions: canReimportNow
              ? [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.notNow),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(_reimportLabel()),
                  ),
                ]
              : [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.continueLabel),
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
    Navigator.of(
      context,
    ).pop(SettingsPostAction.startMtgDownload(bulkType: selected));
  }

  Future<void> _resetDatabaseForGame(TcgGame game) async {
    final l10n = AppLocalizations.of(context)!;
    final gameLabel = game == TcgGame.mtg ? 'Magic' : 'Pokemon';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.resetGameDatabaseTitle(gameLabel)),
          content: Text(l10n.resetGameDatabaseBody(gameLabel)),
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
            Expanded(child: Text(l10n.cleaningGameDatabase(gameLabel))),
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
    showAppSnackBar(context, l10n.gameDatabaseResetDone(gameLabel));
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

  String _reimportFailedLabel(Object error) {
    if (_isStorageSpaceError(error)) {
      return _storageSpaceErrorMessage(italian: _isItalianUi);
    }
    final text = error.toString();
    if (_isItalianUi) {
      if (text.contains('pokemon_canonical_cache_empty')) {
        return 'Reimport fallito: snapshot locale del catalogo Pokemon non trovato.';
      }
      if (text.contains('pokemon_canonical_cache_invalid')) {
        return 'Reimport fallito: snapshot locale del catalogo Pokemon non valido.';
      }
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
    if (text.contains('pokemon_canonical_cache_empty')) {
      return 'Reimport failed: local Pokemon catalog snapshot not found.';
    }
    if (text.contains('pokemon_canonical_cache_invalid')) {
      return 'Reimport failed: local Pokemon catalog snapshot is invalid.';
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
          if (normalizedBulkType == 'all_cards' && languages.contains('it')) {
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
          await _cleanupMtgBulkFilesKeepingType(bulkType);
        } else {
          await PokemonBulkService.instance
              .reimportOrInstallForCurrentSelection(
                onProgress: (value) =>
                    updateProgress(value, _reimportProgressLabel(gameLabel)),
                onStatus: (value) => updateProgress(progress, value),
              );
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
    showAppSnackBar(context, _reimportDoneLabel(gameLabel));
    _collectionsRefreshNotifier.value = _collectionsRefreshNotifier.value + 1;
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
}
