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
  static const int _freeCollectionLimit = 5;
  String? _selectedGameId;
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
  int _totalCardCount = 0;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;
  late final Animation<double> _pulseScale;
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
    unawaited(_loadGameSelection());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseScale = Tween<double>(begin: 0.96, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _snakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _initializeStartup();
    _loadCollections();
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
        (filter.flavor?.trim().isNotEmpty ?? false) ||
        filter.manaMin != null ||
        filter.manaMax != null ||
        filter.sets.isNotEmpty ||
        filter.rarities.isNotEmpty ||
        filter.colors.isNotEmpty ||
        filter.types.isNotEmpty;
  }

  Future<void> _loadGameSelection() async {
    final primary = await AppSettings.loadPrimaryGameId();
    final enabled = await AppSettings.loadEnabledGames();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedGameId = primary;
    });
    if (primary == null || primary.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _promptInitialGameSelection();
        }
      });
    } else if (!enabled.contains(primary)) {
      await AppSettings.saveEnabledGames([...enabled, primary]);
    }
  }

  Future<void> _promptInitialGameSelection() async {
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.chooseYourGameTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _gameOptions
                .map(
                  (option) => ListTile(
                    title: Text(option.name),
                    subtitle: Text(_gameDescription(l10n, option.id)),
                    onTap: () => Navigator.of(context).pop(option.id),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (selected == null || selected.isEmpty) {
      return;
    }
    await _setPrimaryGame(selected);
  }

  Future<void> _setPrimaryGame(String id) async {
    final enabled = await AppSettings.loadEnabledGames();
    final updated = enabled.contains(id) ? enabled : [...enabled, id];
    await AppSettings.saveEnabledGames(updated);
    await AppSettings.savePrimaryGameId(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedGameId = id;
    });
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

  Widget _buildProBanner(BuildContext context) {
    final isPro = _isProUnlocked;
    final l10n = AppLocalizations.of(context)!;
    final subtitle = isPro
        ? l10n.proActiveUnlimitedCollections
        : l10n.basePlanCollectionLimit(_freeCollectionLimit);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
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
            Icon(
              isPro ? Icons.verified : Icons.workspace_premium,
              color: const Color(0xFFE9C46A),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPro ? l10n.proEnabled : l10n.upgradeToPro,
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
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProPage(),
                  ),
                );
              },
              child: Text(isPro ? l10n.manage : l10n.upgrade),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCollections() async {
    final collections = await ScryfallDatabase.instance.fetchCollections();
    final owned = await ScryfallDatabase.instance.countOwnedCards();
    if (!mounted) {
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

  Future<bool> _ensureBulkTypeSelected() async {
    if (_selectedBulkType != null) {
      return true;
    }
    final selected = await _showBulkTypePicker(
      context,
      allowCancel: true,
    );
    if (!mounted) {
      return false;
    }
    if (selected == null) {
      return false;
    }
    await AppSettings.saveBulkType(selected);
    if (!mounted) {
      return false;
    }
    setState(() {
      _selectedBulkType = selected;
      _bulkUpdateAvailable = false;
      _bulkDownloadUri = null;
      _bulkUpdatedAt = null;
      _bulkUpdatedAtRaw = null;
    });
    await _checkScryfallBulk();
    return true;
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
  }

  Future<void> _checkCardsInstalled() async {
    final count = await ScryfallDatabase.instance.countCards();
    final owned = await ScryfallDatabase.instance.countOwnedCards();
    if (!mounted) {
      return;
    }
    if (count > 0) {
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
    if (selection == _HomeAddAction.addCards) {
      await _openAddCardsForAllCards(context);
    } else if (selection == _HomeAddAction.addCardsToCollection) {
      await _openAddCardsForCollection(context);
    } else if (selection == _HomeAddAction.addCollection) {
      await _showCreateCollectionOptions(context);
    }
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

  Future<void> _openAddCardsForCollection(BuildContext context) async {
    var candidates = _collections
        .where((collection) => collection.name != _allCardsCollectionName)
        .toList();
    if (candidates.isEmpty) {
      await _loadCollections();
      if (!context.mounted) {
        return;
      }
      candidates = _collections
          .where((collection) => collection.name != _allCardsCollectionName)
          .toList();
    }
    if (candidates.isEmpty) {
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.createCustomCollectionFirst,
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    final selected = await showModalBottomSheet<CollectionInfo>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickCollectionSheet(
        collections: candidates,
        displayName: _collectionDisplayName,
        isSetCollection: _isSetCollection,
      ),
    );
    if (selected == null || !context.mounted) {
      return;
    }
    final isSet = _isSetCollection(selected);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CollectionDetailPage(
              collectionId: selected.id,
              name: _collectionDisplayName(selected),
              isSetCollection: isSet,
              setCode: isSet ? _setCodeForCollection(selected) : null,
              autoOpenAddCard: !isSet,
              filter: selected.filter,
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

  Future<void> _onBulkUpdatePressed() async {
    if (_bulkDownloading) {
      return;
    }
    if (_bulkImporting) {
      return;
    }
    final ready = await _ensureBulkTypeSelected();
    if (!ready) {
      return;
    }
    if (_bulkDownloadUri == null) {
      await _checkScryfallBulk();
    }
    if (!mounted) {
      return;
    }
    if (_bulkDownloadUri == null) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.downloadLinkUnavailable,
      );
      return;
    }
    await _downloadBulkFile(_bulkDownloadUri!);
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
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.downloadComplete(targetPath),
        );
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

  Widget _buildUpdateCta(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progressPercent = (_bulkDownloadProgress * 100).clamp(0, 100).round();
    final importPercent = (_bulkImportProgress * 100).clamp(0, 100).round();
    final isBusy = _bulkDownloading || _bulkImporting;
    final actionLabel = _selectedBulkType == null
        ? l10n.chooseDatabase
        : _cardsMissing
            ? l10n.downloadDatabase
            : l10n.downloadUpdate;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: FadeTransition(
        opacity: _pulseOpacity,
        child: ScaleTransition(
          scale: _pulseScale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE9C46A),
                  Color(0xFFB85C38),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE9C46A).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isBusy ? null : _onBulkUpdatePressed,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isBusy ? Icons.downloading : Icons.cloud_download,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _bulkDownloading
                            ? (_bulkDownloadTotal > 0
                                ? l10n.downloadingWithPercent(progressPercent)
                                : l10n.downloading)
                            : _bulkImporting
                                ? l10n.importingWithPercent(importPercent)
                                : actionLabel,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.black,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bulkLabel = _bulkTypeLabel(l10n, _selectedBulkType);
    final showImportCta = _cardsMissing ||
        _bulkUpdateAvailable ||
        _bulkDownloadError != null ||
        _bulkDownloading ||
        _bulkImporting ||
        _selectedBulkType == null;
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
                      const SizedBox(height: 10),
                      if (showImportCta)
                        OutlinedButton.icon(
                          onPressed: (_bulkDownloading || _bulkImporting)
                              ? null
                              : _onBulkUpdatePressed,
                          icon: const Icon(Icons.cloud_download, size: 18),
                          label: Text(l10n.importNow),
                        ),
                      if (_selectedGameId != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          l10n.gameLabel(_gameLabel(l10n, _selectedGameId)),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFBFAE95),
                                  ),
                        ),
                      ],
                      if (_bulkDownloading || _bulkImporting)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    children: [
                      _buildProBanner(context),
                      ..._buildCollectionSections(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHomeAddOptions(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: (_bulkUpdateAvailable ||
              _bulkDownloading ||
              _bulkImporting ||
              _cardsMissing)
          ? _buildUpdateCta(context)
          : null,
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
            leading: const Icon(Icons.add_circle_outline),
            title: Text(l10n.addCards),
            subtitle: Text(l10n.addCardsToCatalogSubtitle),
            onTap: () => Navigator.of(context).pop(_HomeAddAction.addCards),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(l10n.addCardsToCollection),
            subtitle: Text(l10n.addCardsToCollectionSubtitle),
            onTap: () =>
                Navigator.of(context).pop(_HomeAddAction.addCardsToCollection),
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

class _PickCollectionSheet extends StatelessWidget {
  const _PickCollectionSheet({
    required this.collections,
    required this.displayName,
    required this.isSetCollection,
  });

  final List<CollectionInfo> collections;
  final String Function(CollectionInfo) displayName;
  final bool Function(CollectionInfo) isSetCollection;

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
            l10n.chooseCollection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: collections.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final collection = collections[index];
                final isSet = isSetCollection(collection);
                return ListTile(
                  leading: const Icon(Icons.collections_bookmark),
                  title: Text(displayName(collection)),
                  subtitle: Text(
                    isSet
                        ? l10n.setCollectionCount(collection.cardCount)
                        : l10n.customCollectionCount(collection.cardCount),
                  ),
                  onTap: () => Navigator.of(context).pop(collection),
                );
              },
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
  final TextEditingController _flavorController = TextEditingController();
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
      _flavorController.text = initial.flavor ?? '';
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
    _flavorController.dispose();
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
    final flavor = _flavorController.text.trim();
    return CollectionFilter(
      name: name.isEmpty ? null : name,
      artist: artist.isEmpty ? null : artist,
      flavor: flavor.isEmpty ? null : flavor,
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
        (filter.flavor?.trim().isNotEmpty ?? false) ||
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
            l10n.flavorText,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _flavorController,
            decoration: InputDecoration(
              hintText: l10n.typeFlavorTextHint,
              prefixIcon: const Icon(Icons.format_quote),
            ),
            onChanged: (_) => _schedulePreviewUpdate(),
          ),
          const SizedBox(height: 20),
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

enum _CollectionAction { rename, editFilters, delete }

enum _HomeAddAction { addCards, addCardsToCollection, addCollection }

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

