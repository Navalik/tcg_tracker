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
  static const int _freeCollectionLimit = 3;
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
  String? _bulkUpdatedAtRaw;
  bool _cardsMissing = false;
  bool _initialCollectionsLoading = true;
  int _totalCardCount = 0;
  late final AnimationController _snakeController;
  Map<String, String> _setNameLookup = {};

  @override
  void initState() {
    super.initState();
    unawaited(ScryfallDatabase.instance.open());
    _purchaseManager = PurchaseManager.instance;
    _purchaseListener = () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProUnlocked = _purchaseManager.isPro;
      });
    };
    _purchaseManager.addListener(_purchaseListener);
    unawaited(_purchaseManager.init());
    _isProUnlocked = _purchaseManager.isPro;
    _snakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _initializeStartup();
    _loadCollections();
  }

  @override
  void dispose() {
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
    return collection.name;
  }

  int _userCollectionCount() {
    return _collections
        .where((item) => item.name != _allCardsCollectionName)
        .length;
  }

  bool _canCreateCollection() {
    return _isProUnlocked || _userCollectionCount() < _freeCollectionLimit;
  }

  bool _filterHasCriteria(CollectionFilter filter) {
    return (filter.name?.trim().isNotEmpty ?? false) ||
        (filter.artist?.trim().isNotEmpty ?? false) ||
        filter.manaMin != null ||
        filter.manaMax != null ||
        filter.sets.isNotEmpty ||
        filter.rarities.isNotEmpty ||
        filter.colors.isNotEmpty ||
        filter.types.isNotEmpty;
  }

  Future<void> _showCollectionLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.collectionLimitReachedTitle),
          content: Text(
            l10n.collectionLimitReachedBody(_freeCollectionLimit),
          ),
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


  Future<void> _loadCollections() async {
    try {
      final collections = await ScryfallDatabase.instance.fetchCollections();
      final owned = await ScryfallDatabase.instance.countOwnedCards();
      if (!mounted) {
        return;
      }
      final hasAllCards = collections
          .any((collection) => collection.name == _allCardsCollectionName);
      if (!hasAllCards) {
        final id =
            await ScryfallDatabase.instance.addCollection(
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
        });
        return;
      }
      if (collections.isEmpty) {
        final id =
            await ScryfallDatabase.instance.addCollection(
              _allCardsCollectionName,
              type: CollectionType.all,
            );
        if (!mounted) {
          return;
        }
        setState(() {
          _collections
            ..clear()
            ..add(CollectionInfo(
                id: id,
                name: _allCardsCollectionName,
                cardCount: 0,
                type: CollectionType.all,
                filter: null,
              ));
          _totalCardCount = owned;
        });
        return;
      }
      final renamed = <CollectionInfo>[];
      final setCodes = <String>[];
      for (final collection in collections) {
        if (collection.name == _legacyMyCollectionName) {
          await ScryfallDatabase.instance
              .renameCollection(collection.id, _allCardsCollectionName);
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
      final setNames =
          await ScryfallDatabase.instance.fetchSetNamesForCodes(setCodes);
      if (!mounted) {
        return;
      }
      setState(() {
        _collections
          ..clear()
          ..addAll(renamed);
        _totalCardCount = owned;
        _setNameLookup = setNames;
      });
    } finally {
      if (mounted && _initialCollectionsLoading) {
        setState(() {
          _initialCollectionsLoading = false;
        });
      }
    }
  }

  List<Widget> _buildCollectionSections(BuildContext context) {
    final allCards = _collections
        .cast<CollectionInfo?>()
        .firstWhere((item) => item?.name == _allCardsCollectionName,
            orElse: () => null);
    final userCollections = _collections
        .where((collection) => collection.name != _allCardsCollectionName)
        .toList();
    final widgets = <Widget>[];

    if (allCards != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CollectionCard(
            name: _collectionDisplayName(allCards),
            count: _totalCardCount,
            onLongPress: (position) {
              _showCollectionActions(allCards, position);
            },
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailPage(
                    collectionId: allCards.id,
                    name: _collectionDisplayName(allCards),
                    isAllCards: true,
                    filter: allCards.filter,
                  ),
                ),
              ).then((_) => _loadCollections());
            },
          ),
        ),
      );
    }

    widgets.add(const SizedBox(height: 6));
    widgets.add(_SectionDivider(label: AppLocalizations.of(context)!.myCollections));
    widgets.add(const SizedBox(height: 12));

    if (userCollections.isEmpty) {
      widgets.add(_buildCreateCollectionCard(
        context,
        title: AppLocalizations.of(context)!.buildYourCollectionsTitle,
        subtitle: AppLocalizations.of(context)!.buildYourCollectionsSubtitle,
        onTap: () => _showCreateCollectionOptions(context),
      ));
      return widgets;
    }

    for (final collection in userCollections) {
      final setCode = _setCodeForCollection(collection);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CollectionCard(
            name: _collectionDisplayName(collection),
            count: collection.cardCount,
            onLongPress: (position) {
              _showCollectionActions(collection, position);
            },
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CollectionDetailPage(
                    collectionId: collection.id,
                    name: _collectionDisplayName(collection),
                    isSetCollection: setCode != null,
                    setCode: setCode,
                    filter: collection.filter,
                  ),
                ),
              ).then((_) => _loadCollections());
            },
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildCreateCollectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3A2F24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.add_box, color: Color(0xFFE9C46A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFBFAE95),
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFBFAE95)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initializeStartup() async {
    final storedBulkType = await AppSettings.loadBulkType();
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

    if (_cardsMissing && _selectedBulkType == null) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      final selected =
          await _showBulkTypePicker(context, allowCancel: false);
      if (!mounted) {
        return;
      }
      if (selected != null) {
        await AppSettings.saveBulkType(selected);
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedBulkType = selected;
        });
      }
    }

    if (_selectedBulkType != null) {
      await _checkScryfallBulk();
    }
  }

  Future<void> _checkScryfallBulk() async {
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
    await _maybeStartBulkDownload();
  }

  Future<void> _checkCardsInstalled() async {
    final count = await ScryfallDatabase.instance.countCards();
    final owned = await ScryfallDatabase.instance.countOwnedCards();
    if (!mounted) {
      return;
    }
    if (count > 0) {
      final needsReimport =
          await ScryfallDatabase.instance.needsLightReimport();
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
    await _maybeStartBulkDownload();
  }

  Future<void> _maybeStartBulkDownload() async {
    if (_bulkDownloading || _bulkImporting) {
      return;
    }
    if (_bulkDownloadUri == null) {
      return;
    }
    if (!_cardsMissing && !_bulkUpdateAvailable) {
      return;
    }
    await _downloadBulkFile(_bulkDownloadUri!);
  }

  Future<void> _addCollection(BuildContext context) async {
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
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
            decoration: InputDecoration(
              hintText: l10n.collectionNameHint,
            ),
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
    if (!context.mounted) {
      return;
    }

    final filter = await Navigator.of(context).push<CollectionFilter>(
      MaterialPageRoute(
        builder: (_) => _CollectionFilterBuilderPage(name: name),
      ),
    );
    if (filter == null) {
      return;
    }
    if (!_filterHasCriteria(filter)) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.selectFiltersFirst,
      );
      return;
    }
    if (!_filterHasCriteria(filter)) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.selectFiltersFirst,
      );
      return;
    }

    int id;
    try {
      id = await ScryfallDatabase.instance.addCollection(
        name,
        type: CollectionType.custom,
        filter: filter,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.failedToAddCollection(error.toString()),
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
          type: CollectionType.custom,
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
                .where((set) =>
                    set.name.toLowerCase().contains(query.toLowerCase()) ||
                    set.code.toLowerCase().contains(query.toLowerCase()))
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
                      decoration: InputDecoration(
                        hintText: l10n.searchSetHint,
                      ),
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
    if (_collections.any((item) => item.name == resolvedName)) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.collectionAlreadyExists,
      );
      return;
    }

    int id;
    final filter = CollectionFilter(
      sets: {selected.code.toLowerCase()},
    );
    try {
      id = await ScryfallDatabase.instance.addCollection(
        resolvedName,
        type: CollectionType.set,
        filter: filter,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.failedToAddCollection(error.toString()),
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
      _setNameLookup = {
        ..._setNameLookup,
        selected.code: selected.name,
      };
    });
    await _loadCollections();
  }

  Future<void> _showCreateCollectionOptions(BuildContext context) async {
    if (!_canCreateCollection()) {
      await _showCollectionLimitDialog();
      return;
    }
    final selection = await showModalBottomSheet<_CollectionCreateAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CreateCollectionSheet();
      },
    );
    if (!context.mounted) {
      return;
    }
    if (selection == _CollectionCreateAction.custom) {
      await _addCollection(context);
    } else if (selection == _CollectionCreateAction.setBased) {
      await _addSetCollection(context);
    }
  }

  Future<void> _showHomeAddOptions(BuildContext context) async {
    final selection = await showModalBottomSheet<_HomeAddAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HomeAddSheet(),
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
    }
  }

  Future<void> _onSearchCardPressed() async {
    CollectionInfo? allCards;
    for (final collection in _collections) {
      if (collection.name == _allCardsCollectionName) {
        allCards = collection;
        break;
      }
    }
    if (allCards == null) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.allCardsCollectionNotFound,
      );
      return;
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
        MaterialPageRoute(
          builder: (_) => const _CardScannerPage(),
        ),
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
    if (_isProUnlocked) {
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
    if (_isProUnlocked) {
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
        return AlertDialog(
          title: const Text('Daily scan limit reached'),
          content: const Text(
            'Free plan allows 20 scans per day. Upgrade to Plus for unlimited scans.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
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
              child: const Text('Discover Plus'),
            ),
          ],
        );
      },
    );
  }

  Future<_ResolvedScanSelection> _resolveSeedWithPrintingPicker(_OcrSearchSeed seed) async {
    final cardName = seed.cardName?.trim();
    if (cardName == null || cardName.isEmpty) {
      return _ResolvedScanSelection(seed: seed);
    }
    final localBeforeSync =
        await ScryfallDatabase.instance.fetchCardsForAdvancedFilters(
      CollectionFilter(name: cardName),
      languages: const ['en'],
      limit: 250,
    );
    final normalizedName = _normalizeCardNameForMatch(cardName);
    final localBeforeSyncKeys = localBeforeSync
        .where((card) => _normalizeCardNameForMatch(card.name) == normalizedName)
        .map(_printingKeyForCard)
        .toSet();
    // Keep scan flow snappy: avoid long blocking sync for cards with many printings.
    if (localBeforeSyncKeys.length < 4) {
      await _syncOnlinePrintsByName(cardName, timeBudget: const Duration(seconds: 2));
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
        setCode: picked.setCode.trim().isEmpty ? null : picked.setCode.trim().toLowerCase(),
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
                      child: card.imageUri != null && card.imageUri!.trim().isNotEmpty
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
                        label: const Text('Riprova'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(_ScanPreviewAction.add),
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi'),
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
    CollectionInfo? allCards;
    for (final collection in _collections) {
      if (collection.name == _allCardsCollectionName) {
        allCards = collection;
        break;
      }
    }
    if (allCards == null) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.allCardsCollectionNotFound,
      );
      return false;
    }
    await ScryfallDatabase.instance.addCardToCollection(allCards.id, cardId);
    if (!mounted) {
      return false;
    }
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.addedCards(1),
    );
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
    collectorNumber = _pickBetterCollectorNumber(collectorNumber, setAndCollector.$2);

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
          collectorNumber = _pickBetterCollectorNumber(collectorNumber, fromNext);
        }

        if (token.contains('/')) {
          final part = token.split('/').first;
          final normalized = _normalizeCollectorNumber(part);
          collectorNumber = _pickBetterCollectorNumber(collectorNumber, normalized);
        }

        collectorNumber = _pickBetterCollectorNumber(
          collectorNumber,
          _normalizeCollectorNumber(token),
        );
      }

    }

    if (bestName.isEmpty &&
        setCode == null &&
        collectorNumber == null) {
      return null;
    }

    final fallbackQuery = bestName.isEmpty ? lines.first : bestName;
    final useCollectorQuery = collectorNumber != null &&
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
    final strictCount = await ScryfallDatabase.instance.countCardsForFilterWithSearch(
      CollectionFilter(sets: {setCode}),
      searchQuery: query,
    );
    if (strictCount > 0) {
      // Guard against false positives when collector OCR is wrong but exists in same set.
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final nameInSetCount =
            await ScryfallDatabase.instance.countCardsForFilterWithSearch(
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
      final nameInSetCount =
          await ScryfallDatabase.instance.countCardsForFilterWithSearch(
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
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
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
      final fetchedCollector =
          (payload['collector_number'] as String?)?.trim().toLowerCase();
      return _OcrSearchSeed(
        query: (fetchedName != null && fetchedName.isNotEmpty) ? fetchedName : name,
        cardName: fetchedName ?? name,
        setCode: fetchedSet?.isNotEmpty == true ? fetchedSet : null,
        collectorNumber:
            fetchedCollector?.isNotEmpty == true ? fetchedCollector : null,
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
      final namedResponse =
          await http.get(namedUri).timeout(const Duration(seconds: 2));
      String? oracleId;
      if (namedResponse.statusCode == 200) {
        final namedPayload = jsonDecode(namedResponse.body);
        if (namedPayload is Map<String, dynamic>) {
          await ScryfallDatabase.instance.upsertCardFromScryfall(namedPayload);
          oracleId = (namedPayload['oracle_id'] as String?)?.trim().toLowerCase();
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
      final response = await http.get(nextUri).timeout(const Duration(seconds: 2));
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
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
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
      final preferredCollector =
          _normalizeCollectorForComparison(preferredCollectorNumber ?? '');
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        await ScryfallDatabase.instance.upsertCardFromScryfall(item);
      }
      final localCandidates =
          await ScryfallDatabase.instance.fetchCardsForAdvancedFilters(
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
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
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
      final fetchedCollector =
          (payload['collector_number'] as String?)?.trim().toLowerCase();
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
      final normalized =
          _trimToNameSegment(_normalizePotentialCardName(lines[i]));
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
      final oracleHits =
          wordsList.where((w) => oracleLikeWords.contains(w)).length;
      final digits = RegExp(r'\d').allMatches(normalized).length;
      if (digits > normalized.length * 0.25) {
        continue;
      }
      final digitPenalty = digits * 2;
      final oraclePenalty = oracleHits * 5;
      final longSentencePenalty = wordsList.length >= 6 ? 4 : 0;
      final topBonus = (8 - i);
      final score = (normalized.length.clamp(0, 30)) +
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
    final setCollectorRegex = RegExp(r'\b([A-Z0-9]{2,5})\s+([0-9]{1,5}[A-Z]?)\b');
    final collectorSlashRegex = RegExp(r'\b([0-9]{1,5}[A-Z]?)\s*/\s*[0-9]{1,5}\b');
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
    final direct = RegExp(r'^([A-Z0-9]{2,5})\s+([0-9]{1,5}[A-Z]?)$')
        .firstMatch(upper);
    if (direct != null) {
      final rawSet = (direct.group(1) ?? '').trim().toLowerCase();
      final setCode = _detectSetCodeFromToken(
            rawSet,
            knownSetCodes: knownSetCodes,
          ) ??
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
      final set = _detectSetCodeFromToken(
        token,
        knownSetCodes: knownSetCodes,
      );
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
    final candidates = <String>{
      raw,
      _normalizeSetCodeCandidate(raw),
    };
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
    CollectionInfo? allCards;
    for (final collection in _collections) {
      if (collection.name == _allCardsCollectionName) {
        allCards = collection;
        break;
      }
    }
    if (allCards == null) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.allCardsCollectionNotFound,
      );
      return false;
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
      await ScryfallDatabase.instance.addCardsToCollection(
        allCards.id,
        selection.cardIds,
      );
    } else {
      await ScryfallDatabase.instance.addCardToCollection(
        allCards.id,
        selection.cardIds.first,
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
    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Carta aggiunta'),
        content: const Text('Vuoi scansionare un\'altra carta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Si'),
          ),
        ],
      ),
    );
    return again ?? false;
  }

  Future<void> _openAddCardsForAllCards(BuildContext context) async {
    CollectionInfo? allCards;
    for (final collection in _collections) {
      if (collection.name == _allCardsCollectionName) {
        allCards = collection;
        break;
      }
    }
    if (allCards == null) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.allCardsCollectionNotFound,
      );
      return;
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
    if (collection.name == _allCardsCollectionName) {
      return;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return;
    }
    final isSetCollection = _isSetCollection(collection);
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
      menuItems.add(
        PopupMenuItem(
          value: _CollectionAction.editFilters,
          child: Row(
            children: [
              Icon(Icons.tune, size: 18),
              SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.filters),
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
    } else if (selection == _CollectionAction.editFilters) {
      await _editCollectionFilters(collection);
    } else if (selection == _CollectionAction.delete) {
      await _deleteCollection(collection);
    }
  }

  Future<void> _editCollectionFilters(CollectionInfo collection) async {
    if (_isSetCollection(collection)) {
      return;
    }
    final filter = await Navigator.of(context).push<CollectionFilter>(
      MaterialPageRoute(
        builder: (_) => _CollectionFilterBuilderPage(
          name: _collectionDisplayName(collection),
          initialFilter: collection.filter,
        ),
      ),
    );
    if (filter == null) {
      return;
    }
    await ScryfallDatabase.instance.updateCollectionFilter(
      collection.id,
      filter: filter,
    );
    if (!mounted) {
      return;
    }
    await _loadCollections();
  }

  Future<void> _renameCollection(CollectionInfo collection) async {
    if (_isSetCollection(collection)) {
      return;
    }
    final controller =
        TextEditingController(text: _collectionDisplayName(collection));
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.renameCollectionTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.collectionNameHint,
            ),
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
    if (resolvedName == collection.name) {
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
      final index =
          _collections.indexWhere((item) => item.id == collection.id);
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
    if (!mounted) {
      return;
    }
    setState(() {
      _collections.removeWhere((item) => item.id == collection.id);
    });
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.collectionDeleted,
    );
  }

  Future<void> _downloadBulkFile(String downloadUri) async {
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
        final targetPath =
            '${directory.path}/${_bulkTypeFileName(bulkType)}';
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
          final shouldReport = progressThrottle.elapsed >= minProgressInterval ||
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
        await _importBulkFile(targetPath);
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

  Future<void> _importBulkFile(String filePath) async {
    if (_bulkImporting) {
      return;
    }
    if (!mounted) {
      return;
    }
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
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.importComplete,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bulkImporting = false;
      });
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.importFailed(error.toString()),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                          const SizedBox(width: 40),
                          Expanded(
                            child: Column(
                              children: [
                                _TitleLockup(),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.settings,
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ),
                              ).then((_) {
                                if (mounted) {
                                  _initializeStartup();
                                }
                              });
                            },
                          ),
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
                        Text(
                          _bulkDownloadTotal > 0
                              ? l10n.downloadingUpdateWithTotal(
                                  (_bulkDownloadProgress * 100)
                                      .clamp(0, 100)
                                      .round(),
                                  _formatBytes(_bulkDownloadReceived),
                                  _formatBytes(_bulkDownloadTotal),
                                )
                              : l10n.downloadingUpdateNoTotal(
                                  _formatBytes(_bulkDownloadReceived),
                                ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE3B55C),
                              ),
                        )
                      else if (_bulkImporting)
                        Text(
                          l10n.importingCardsWithCount(
                            (_bulkImportProgress * 100).clamp(0, 100).round(),
                            _bulkImportedCount,
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE3B55C),
                              ),
                        )
                      else if (_bulkDownloadError != null)
                        Text(
                          l10n.downloadFailedTapUpdate,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE38B5C),
                              ),
                        )
                      else if (_cardsMissing)
                        Text(
                          _selectedBulkType == null
                              ? l10n.selectDatabaseToDownload
                              : l10n.databaseMissingDownloadRequired(bulkLabel),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE38B5C),
                              ),
                        )
                      else if (_bulkUpdateAvailable)
                        Text(
                          l10n.updateReadyWithDate(
                            _bulkUpdatedAt
                                    ?.toLocal()
                                    .toIso8601String()
                                    .split('T')
                                    .first ??
                                l10n.unknownDate,
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFE3B55C),
                              ),
                        )
                      else
                        Text(
                          l10n.upToDate,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF908676),
                              ),
                        ),
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
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                          children: [
                            ..._buildCollectionSections(context),
                          ],
                        ),
                ),
              ],
            ),
          ),
          if (isBlockingSync) ...[
            const ModalBarrier(
              dismissible: false,
              color: Color(0x880E0A08),
            ),
            Center(
              child: Chip(
                avatar: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: Text('$blockingLabel. Please wait.'),
                backgroundColor: const Color(0xFFE9C46A),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                onPressed: isBlockingSync ? null : () => _showHomeAddOptions(context),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.name,
    required this.count,
    required this.onTap,
    this.onLongPress,
  });

  final String name;
  final int count;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onLongPress;

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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
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
                const Icon(Icons.collections_bookmark, color: Color(0xFFE9C46A)),
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
                        l10n.cardCount(count),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFBFAE95),
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFBFAE95)),
              ],
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
        const Expanded(
          child: _DividerGlow(),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFC9BDA4),
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _DividerGlow(),
        ),
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
  const _HomeAddSheet();

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
            l10n.addTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Aggiungi tramite scan'),
            subtitle: const Text('Scansiona una carta con OCR live'),
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
            onTap: () => Navigator.of(context).pop(_HomeAddAction.addCollection),
          ),
        ],
      ),
    );
  }
}

class _CollectionFilterBuilderPage extends StatefulWidget {
  const _CollectionFilterBuilderPage({
    required this.name,
    this.initialFilter,
  });

  final String name;
  final CollectionFilter? initialFilter;

  @override
  State<_CollectionFilterBuilderPage> createState() =>
      _CollectionFilterBuilderPageState();
}

class _CollectionFilterBuilderPageState
    extends State<_CollectionFilterBuilderPage> {
  static const List<String> _knownTypes = [
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
  static const List<String> _rarityOrder = [
    'common',
    'uncommon',
    'rare',
    'mythic',
  ];
  static const List<String> _colorOrder = ['W', 'U', 'B', 'R', 'G', 'C'];

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
  String _typeQuery = '';

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
      _nameController.text = initial.name ?? '';
      _artistController.text = initial.artist ?? '';
      if (initial.manaMin != null) {
        _manaMinController.text = initial.manaMin.toString();
      }
      if (initial.manaMax != null) {
        _manaMaxController.text = initial.manaMax.toString();
      }
      _selectedSets.addAll(initial.sets);
      _selectedRarities.addAll(initial.rarities);
      _selectedColors.addAll(initial.colors);
      _selectedTypes.addAll(initial.types);
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
      final results =
          await ScryfallDatabase.instance.fetchAvailableArtists(query: query);
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
    final total =
        await ScryfallDatabase.instance.countCardsForFilter(filter);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.initialFilter != null;
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
    final filteredTypes = _typeQuery.isEmpty
        ? <String>[]
        : _knownTypes
            .where((type) =>
                type.toLowerCase().contains(_typeQuery.toLowerCase()))
            .toList()
          ..sort();
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
      appBar: AppBar(
        title: Text(widget.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text(
            l10n.advancedFiltersTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
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
          Text(
            l10n.setLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (_selectedSets.isNotEmpty) ...[
            buildSelectedChips(
              _selectedSets,
              (value) {
                _selectedSets.remove(value);
                _schedulePreviewUpdate();
              },
            ),
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
          Text(
            l10n.rarity,
            style: Theme.of(context).textTheme.titleSmall,
          ),
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
            l10n.colorLabel,
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
            l10n.typeLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (_selectedTypes.isNotEmpty) ...[
            buildSelectedChips(
              _selectedTypes,
              (value) {
                _selectedTypes.remove(value);
                _schedulePreviewUpdate();
              },
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _typeQuery = value.trim();
              });
            },
          ),
          if (_typeQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (filteredTypes.isEmpty)
              Text(l10n.noResultsFound)
            else
              SizedBox(
                height: filteredTypes.length > 8 ? 200 : null,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredTypes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final type = filteredTypes[index];
                    return ListTile(
                      title: Text(type),
                      onTap: () {
                        setState(() {
                          _selectedTypes.add(type);
                          _typeQuery = '';
                        });
                        _schedulePreviewUpdate();
                      },
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.manaValue,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manaMinController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: l10n.minLabel,
                  ),
                  onChanged: (_) => _schedulePreviewUpdate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _manaMaxController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: l10n.maxLabel,
                  ),
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
                          _artistController.selection =
                              TextSelection.collapsed(offset: artist.length);
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
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_buildFilter()),
                child: Text(isEditing ? l10n.save : l10n.create),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateCollectionSheet extends StatelessWidget {
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
          ListTile(
            leading: const Icon(Icons.auto_awesome_mosaic),
            title: Text(l10n.setCollectionTitle),
            subtitle: Text(l10n.setCollectionSubtitle),
            onTap: () => Navigator.of(context)
                .pop(_CollectionCreateAction.setBased),
          ),
          ListTile(
            leading: const Icon(Icons.collections_bookmark),
            title: Text(l10n.customCollectionTitle),
            subtitle: Text(l10n.customCollectionSubtitle),
            onTap: () =>
                Navigator.of(context).pop(_CollectionCreateAction.custom),
          ),
        ],
      ),
    );
  }
}

class _TitleLockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context)!.appTitle;
    final textStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          title,
          style: textStyle?.copyWith(
            color: const Color(0xFF39251A),
            shadows: [
              const Shadow(
                blurRadius: 18,
                color: Color(0x55E2C26A),
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Color(0xFFF5E3A4),
                Color(0xFFE2C26A),
                Color(0xFFB85C38),
              ],
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
          },
          child: Text(
            title,
            style: textStyle?.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
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
  const _ResolvedScanSelection({
    required this.seed,
    this.pickedCard,
  });

  final _OcrSearchSeed seed;
  final CardSearchResult? pickedCard;
}

enum _ScanPreviewAction { add, retry }

Future<CardSearchResult?> _pickCardPrintingForName(
  BuildContext context,
  String cardName,
  {String? preferredSetCode,
  String? preferredCollectorNumber,
  Set<String> localPrintingKeys = const {}}
) async {
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
      .where((card) => _normalizeCardNameForMatch(card.name) == normalizedTarget)
      .toList(growable: false);
  final candidates = exact.isNotEmpty ? exact : results;
  final byPrinting = <String, CardSearchResult>{};
  for (final card in candidates) {
    final key = '${card.name.toLowerCase()}|${card.setCode.toLowerCase()}|${card.collectorNumber.toLowerCase()}';
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFBFAE95),
                  ),
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
                    for (final card in candidates) _buildPrintingTile(context, card),
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
  String _status = 'Allinea la carta nel riquadro.';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    unawaited(_loadKnownSetCodesForScanner());
    unawaited(_initializeCamera());
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
        _status = 'Camera non disponibile. Controlla i permessi.';
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
      showAppSnackBar(context, 'Flash non disponibile su questo device.');
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
            _status = 'Cerco testo carta...';
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
            _status = 'Cerco nome carta...';
          } else {
            _status = 'Nome riconosciuto. Apro la ricerca...';
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
        Navigator.of(context).pop(
          '__SCAN_PAYLOAD__$payload',
        );
      }
    } catch (_) {
      _stableHits = 0;
      _bestStableRawText = '';
      _clearSetVotes();
      if (mounted) {
        setState(() {
          _status = 'OCR instabile, riprovo...';
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
    final collector = (lines.reversed
        .map((line) => line.toLowerCase())
        .map((line) => RegExp(r'(\d{1,5}[a-z]?)').firstMatch(line)?.group(1))
        .firstWhere((value) => value != null && value.isNotEmpty, orElse: () => '')) ??
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
      final hasResolvedSet = RegExp(r'^[A-Z]{2,5}\s+[0-9]{1,5}[A-Z]?$')
          .hasMatch(votedSetCandidate.trim().toUpperCase());
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
    final match = RegExp(r'^([A-Z]{2,5})\s+([0-9]{1,5}[A-Z]?)$')
        .firstMatch(value.trim().toUpperCase());
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
      final hasManyDigits = RegExp(r'\d').allMatches(cleaned).length >
          (cleaned.length * 0.25);
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

  InputImage? _toInputImage(
    CameraImage image,
    CameraController controller,
  ) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }
    final bytes = Uint8List.fromList(
      image.planes.expand((plane) => plane.bytes).toList(growable: false),
    );
    final rotation = InputImageRotationValue.fromRawValue(
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

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live card scan'),
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: (_initializing || !_torchAvailable) ? null : _toggleTorch,
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
                final availableWidth = (constraints.maxWidth - 48)
                    .clamp(110.0, constraints.maxWidth);
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
                  center: Offset(
                    constraints.maxWidth / 2,
                    centerY,
                  ),
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
                    label: 'Nome',
                    value: _lockedName.isEmpty
                        ? (_namePreview.isEmpty ? 'In attesa' : _namePreview)
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
                    'Live OCR attivo',
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

    final frameColor = locked ? const Color(0xFF4CAF50) : const Color(0xFFE9C46A);
    final accentColor = locked ? const Color(0xFFC8FACC) : const Color(0xFFF5E3A4);
    final glowPaint = Paint()
      ..color = frameColor.withValues(alpha: locked ? 0.72 : (0.36 + (0.38 * pulse)))
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
      ..color = accentColor.withValues(alpha: locked ? 0.55 : (0.32 + (0.30 * pulse)))
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
    canvas.drawLine(Offset(left, top), Offset(left + accentLen, top), accentPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + accentLen), accentPaint);
    canvas.drawLine(Offset(right, top), Offset(right - accentLen, top), accentPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + accentLen), accentPaint);
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
    final nameRRect = RRect.fromRectAndRadius(nameZone, const Radius.circular(8));
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
      Offset(
        nameZone.left + 8,
        nameZone.center.dy - (nameTp.height / 2),
      ),
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
    final borderColor =
        locked ? const Color(0xFF4CAF50) : const Color(0x99E9C46A);
    final fillColor =
        locked ? const Color(0x334CAF50) : const Color(0x221C1713);
    final valueColor =
        locked ? const Color(0xFFC8FACC) : const Color(0xFFEFE7D8);
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

enum _CollectionAction { rename, editFilters, delete }

enum _HomeAddAction { addByScan, addCards, addCollection }

enum _CollectionCreateAction { custom, setBased }



class _SnakeProgressBar extends StatelessWidget {
  const _SnakeProgressBar({
    required this.animation,
    required this.value,
  });

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

