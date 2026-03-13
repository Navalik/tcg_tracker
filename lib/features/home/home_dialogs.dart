// ignore_for_file: invalid_use_of_protected_member, use_build_context_synchronously

part of 'package:tcg_tracker/main.dart';

extension _HomeDialogsStateX on _CollectionHomePageState {
  Future<TcgGame?> _showPrimaryGamePickerDialog() async {
    if (!mounted) {
      return null;
    }
    final l10n = AppLocalizations.of(context)!;
    var current = TcgGame.mtg;
    return showDialog<TcgGame>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: Text(l10n.primaryGamePickerTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.primaryGamePickerBody),
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
                        subtitle: Text(l10n.primaryFreeLabel),
                      ),
                      RadioListTile<TcgGame>(
                        value: TcgGame.pokemon,
                        title: const Text('Pokemon'),
                        subtitle: Text(l10n.primaryFreeLabel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(current),
                child: Text(l10n.continueLabel),
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
    final l10n = AppLocalizations.of(context)!;
    final gameLabel = game == TcgGame.pokemon ? 'Pokemon' : 'Magic';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.gameInProTitle(gameLabel)),
        content: Text(l10n.gameOneTimeUnlockBody(gameLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.closeLabel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
            child: Text(l10n.openSettingsLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _showWishlistLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.wishlistLimitReachedTitle),
          content: Text(
            l10n.wishlistLimitReachedBody(
              _CollectionHomePageState._freeWishlistLimit,
            ),
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

  Future<void> _showSetCollectionLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.collectionLimitReachedTitle),
          content: Text(
            l10n.collectionLimitReachedBody(
              _CollectionHomePageState._freeSetCollectionLimit,
            ),
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
            l10n.collectionLimitReachedBody(
              _CollectionHomePageState._freeCustomCollectionLimit,
            ),
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

  Future<void> _showSmartCollectionLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.collectionLimitReachedTitle),
          content: Text(
            l10n.collectionLimitReachedBody(
              _CollectionHomePageState._freeSmartCollectionLimit,
            ),
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

  Future<void> _showDeckCollectionLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.collectionLimitReachedTitle),
          content: Text(
            l10n.collectionLimitReachedBody(
              _CollectionHomePageState._freeDeckCollectionLimit,
            ),
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
}
