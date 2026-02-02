part of 'package:tcg_tracker/main.dart';

enum _CardSortMode {
  name,
  color,
  type,
}

enum _AddCardEntryMode {
  byName,
  byScan,
}

class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    required this.name,
    this.isAllCards = false,
    this.isSetCollection = false,
    this.setCode,
    this.filter,
    this.autoOpenAddCard = false,
  });

  final int collectionId;
  final String name;
  final bool isAllCards;
  final bool isSetCollection;
  final String? setCode;
  final CollectionFilter? filter;
  final bool autoOpenAddCard;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}



class _CollectionDetailPageState extends State<CollectionDetailPage> {
  static const int _pageSize = 120;
  final List<CollectionCardEntry> _cards = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _loadedOffset = 0;
  int? _ownedCollectionId;
  Timer? _searchDebounce;
  CollectionViewMode _viewMode = CollectionViewMode.list;
  bool _showOwned = true;
  bool _showMissing = true;
  String _searchQuery = '';
  final Set<String> _selectedRarities = {};
  final Set<String> _selectedSetCodes = {};
  final Set<String> _selectedColors = {};
  final Set<String> _selectedTypes = {};
  int? _manaValueMin;
  int? _manaValueMax;
  int? _ownedCount;
  int? _missingCount;
  bool _autoAddShown = false;
  Map<String, int> _setTotalsByCode = {};
  _CardSortMode _sortMode = _CardSortMode.name;
  bool _selectionMode = false;
  final Set<String> _selectedCardIds = {};

  bool get _isFilterCollection =>
      !widget.isAllCards && (widget.filter != null || widget.isSetCollection);

  @override
  void initState() {
    super.initState();
    _initialize();
    _loadViewMode();
    _scrollController.addListener(_onScroll);
    if (widget.autoOpenAddCard && !widget.isSetCollection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoAddShown) {
          return;
        }
        _autoAddShown = true;
        _addCard(context);
      });
    }
  }

  Future<void> _initialize() async {
    if (widget.isAllCards) {
      _ownedCollectionId = widget.collectionId;
    } else {
      _ownedCollectionId =
          await ScryfallDatabase.instance.fetchAllCardsCollectionId();
    }
    if (!mounted) {
      return;
    }
    await _loadCards();
  }

  Future<void> _loadViewMode() async {
    final mode = await AppSettings.loadCollectionViewMode();
    if (!mounted) {
      return;
    }
    setState(() {
      _viewMode = mode;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 400) {
      _loadMoreCards();
    }
  }


  Future<void> _loadCards() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _loadingMore = false;
      _hasMore = true;
      _loadedOffset = 0;
      _cards.clear();
      _setTotalsByCode = {};
      _selectionMode = false;
      _selectedCardIds.clear();
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _refreshCounts();
    await _loadMoreCards(initial: true);
  }

  CollectionFilter? _effectiveFilter() {
    final fallbackFilter = widget.isSetCollection &&
            (widget.setCode?.trim().isNotEmpty ?? false)
        ? CollectionFilter(sets: {widget.setCode!.trim().toLowerCase()})
        : null;
    return widget.filter ?? fallbackFilter;
  }

  Future<void> _refreshCounts() async {
    if (!mounted) {
      return;
    }
    if (!_isFilterCollection) {
      final total = await ScryfallDatabase.instance.countCollectionCards(
        widget.collectionId,
        searchQuery: _searchQuery,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ownedCount = total;
        _missingCount = 0;
      });
      return;
    }
    final filter = _effectiveFilter();
    if (filter == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ownedCount = 0;
        _missingCount = 0;
      });
      return;
    }
    final owned = await ScryfallDatabase.instance
        .countOwnedCardsForFilterWithSearch(
      filter,
      searchQuery: _searchQuery,
    );
    final total =
        await ScryfallDatabase.instance.countCardsForFilterWithSearch(
      filter,
      searchQuery: _searchQuery,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _ownedCount = owned;
      _missingCount = (total - owned).clamp(0, total);
    });
  }

  Future<void> _loadMoreCards({bool initial = false}) async {
    if (_loadingMore || !_hasMore) {
      return;
    }
    if (mounted) {
      setState(() {
        _loadingMore = true;
      });
    }
    if (!_showOwned && !_showMissing) {
      if (mounted) {
        setState(() {
          _cards.clear();
          _loadingMore = false;
          _loading = false;
          _hasMore = false;
        });
      }
      return;
    }
    try {
      final ownedCollectionId = _ownedCollectionId;
      if (!widget.isAllCards && ownedCollectionId == null) {
        if (mounted) {
          setState(() {
            _loadingMore = false;
            _loading = false;
            _hasMore = false;
          });
        }
        return;
      }
      final filter = _effectiveFilter();
      final ownedOnly = _showOwned && !_showMissing;
      final missingOnly = _showMissing && !_showOwned;
      final cards = widget.isAllCards
          ? await ScryfallDatabase.instance.fetchOwnedCards(
              searchQuery: _searchQuery,
              limit: _pageSize,
              offset: _loadedOffset,
            )
          : filter != null
              ? await ScryfallDatabase.instance.fetchFilteredCollectionCards(
                  filter,
                  searchQuery: _searchQuery,
                  ownedOnly: ownedOnly,
                  missingOnly: missingOnly,
                  limit: _pageSize,
                  offset: _loadedOffset,
                )
              : await ScryfallDatabase.instance.fetchCollectionCards(
                  widget.collectionId,
                  limit: _pageSize,
                  offset: _loadedOffset,
                );

      final newSetCodes = cards
          .map((entry) => entry.setCode.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .where((code) => !_setTotalsByCode.containsKey(code))
          .toSet()
          .toList();
      final totals = newSetCodes.isEmpty
          ? <String, int>{}
          : await ScryfallDatabase.instance.fetchSetTotalsForCodes(newSetCodes);

      if (!mounted) {
        return;
      }
      setState(() {
        _cards.addAll(cards);
        _setTotalsByCode.addAll(totals);
        _loadedOffset += cards.length;
        _hasMore = cards.length == _pageSize;
        _loadingMore = false;
        _loading = false;
      });
      _maybePrefetchIfShort();
    } catch (error, stackTrace) {
      debugPrint('CollectionDetailPage _loadMoreCards failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _loading = false;
        _hasMore = false;
      });
    }
  }

  void _maybePrefetchIfShort() {
    if (!_hasMore || _loadingMore) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadingMore || !_hasMore) {
        return;
      }
      if (!_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 200) {
        _loadMoreCards();
      }
    });
  }

  Widget _buildLoadMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  List<CollectionCardEntry> _baseVisibleCards() {
    if (!_isFilterCollection) {
      return _cards;
    }
    if (_showOwned && _showMissing) {
      return _cards;
    }
    return _cards.where((entry) {
      final owned = entry.quantity > 0;
      if (owned && _showOwned) {
        return true;
      }
      if (!owned && _showMissing) {
        return true;
      }
      return false;
    }).toList();
  }

  List<CollectionCardEntry> _filteredCards() {
    final base = _baseVisibleCards();
    if (_selectedRarities.isEmpty &&
        _selectedSetCodes.isEmpty &&
        _selectedColors.isEmpty &&
        _selectedTypes.isEmpty &&
        _manaValueMin == null &&
        _manaValueMax == null) {
      return base;
    }
    return base.where(_matchesAdvancedFilters).toList();
  }

  List<CollectionCardEntry> _sortedCards() {
    final base = _filteredCards();
    if (base.length < 2) {
      return base;
    }
    final sorted = List<CollectionCardEntry>.from(base);
    int compareName(CollectionCardEntry a, CollectionCardEntry b) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    int compareColor(CollectionCardEntry a, CollectionCardEntry b) {
      final keyA = _colorSortKey(a);
      final keyB = _colorSortKey(b);
      final primary = keyA.compareTo(keyB);
      if (primary != 0) {
        return primary;
      }
      return compareName(a, b);
    }

    int compareType(CollectionCardEntry a, CollectionCardEntry b) {
      final keyA = _typeSortKey(a);
      final keyB = _typeSortKey(b);
      final primary = keyA.compareTo(keyB);
      if (primary != 0) {
        return primary;
      }
      return compareName(a, b);
    }

    switch (_sortMode) {
      case _CardSortMode.name:
        sorted.sort(compareName);
        break;
      case _CardSortMode.color:
        sorted.sort(compareColor);
        break;
      case _CardSortMode.type:
        sorted.sort(compareType);
        break;
    }
    return sorted;
  }

  String _colorSortKey(CollectionCardEntry entry) {
    const order = ['W', 'U', 'B', 'R', 'G', 'C'];
    final colors = _cardColors(entry).toList()
      ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return colors.join();
  }

  String _typeSortKey(CollectionCardEntry entry) {
    const order = [
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
    final types = _cardTypes(entry);
    if (types.isEmpty) {
      return '';
    }
    for (final type in order) {
      if (types.contains(type)) {
        return type;
      }
    }
    final sorted = types.toList()..sort();
    return sorted.join('/');
  }

  void _toggleSelection(CollectionCardEntry entry) {
    setState(() {
      _selectionMode = true;
      if (!_selectedCardIds.add(entry.cardId)) {
        _selectedCardIds.remove(entry.cardId);
      }
      if (_selectedCardIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _exitSelection() {
    if (!_selectionMode && _selectedCardIds.isEmpty) {
      return;
    }
    setState(() {
      _selectionMode = false;
      _selectedCardIds.clear();
    });
  }

  bool _isSelected(CollectionCardEntry entry) {
    return _selectedCardIds.contains(entry.cardId);
  }

  bool _areAllVisibleSelected(List<CollectionCardEntry> visibleCards) {
    if (visibleCards.isEmpty) {
      return false;
    }
    for (final entry in visibleCards) {
      if (!_selectedCardIds.contains(entry.cardId)) {
        return false;
      }
    }
    return true;
  }

  void _toggleSelectAll(List<CollectionCardEntry> visibleCards) {
    if (visibleCards.isEmpty) {
      return;
    }
    final ids = visibleCards.map((entry) => entry.cardId).toSet();
    setState(() {
      _selectionMode = true;
      final allSelected = ids.every(_selectedCardIds.contains);
      if (allSelected) {
        _selectedCardIds.removeAll(ids);
        if (_selectedCardIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedCardIds.addAll(ids);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null || _selectedCardIds.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedCardIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteCardsTitle),
          content: Text(l10n.deleteCardsBody(count)),
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
    final ids = _selectedCardIds.toList(growable: false);
    final isFilterCollection = !widget.isAllCards;
    for (final cardId in ids) {
      if (isFilterCollection) {
        await ScryfallDatabase.instance.upsertCollectionCard(
          ownedCollectionId,
          cardId,
          quantity: 0,
          foil: false,
          altArt: false,
        );
      } else {
        await ScryfallDatabase.instance.deleteCollectionCard(
          ownedCollectionId,
          cardId,
        );
      }
    }
    if (!mounted) {
      return;
    }
    _exitSelection();
    await _loadCards();
  }

  String _sortLabel(_CardSortMode mode, AppLocalizations l10n) {
    switch (mode) {
      case _CardSortMode.name:
        return l10n.cardName;
      case _CardSortMode.color:
        return l10n.colorLabel;
      case _CardSortMode.type:
        return l10n.typeLabel;
    }
  }

  Widget _buildSelectionBadge(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE9C46A) : const Color(0xFF1C1713),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFFE9C46A) : const Color(0xFF3A2F24),
          width: 1.5,
        ),
      ),
      child: Icon(
        selected ? Icons.check : Icons.circle_outlined,
        size: 14,
        color: selected ? const Color(0xFF1C1510) : const Color(0xFFBFAE95),
      ),
    );
  }

  bool _matchesAdvancedFilters(CollectionCardEntry entry) {
    if (_selectedRarities.isNotEmpty) {
      final rarity = entry.rarity.trim().toLowerCase();
      if (!_selectedRarities.contains(rarity)) {
        return false;
      }
    }
    if (_selectedSetCodes.isNotEmpty) {
      final code = entry.setCode.trim().toLowerCase();
      if (!_selectedSetCodes.contains(code)) {
        return false;
      }
    }
    if (_selectedColors.isNotEmpty) {
      final colors = _cardColors(entry);
      if (colors.intersection(_selectedColors).isEmpty) {
        return false;
      }
    }
    if (_selectedTypes.isNotEmpty) {
      final types = _cardTypes(entry);
      if (types.intersection(_selectedTypes).isEmpty) {
        return false;
      }
    }
    if (_manaValueMin != null || _manaValueMax != null) {
      final manaValue = _cardManaValue(entry);
      if (_manaValueMin != null && manaValue < _manaValueMin!) {
        return false;
      }
      if (_manaValueMax != null && manaValue > _manaValueMax!) {
        return false;
      }
    }
    return true;
  }

  Set<String> _cardColors(CollectionCardEntry entry) {
    return _parseColorSet(entry.colors, entry.colorIdentity);
  }

  Set<String> _cardTypes(CollectionCardEntry entry) {
    final typeLine = entry.typeLine.trim();
    if (typeLine.isEmpty) {
      return {};
    }
    const knownTypes = [
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
    final matches = <String>{};
    for (final type in knownTypes) {
      if (typeLine.toLowerCase().contains(type.toLowerCase())) {
        matches.add(type);
      }
    }
    return matches;
  }

  double _cardManaValue(CollectionCardEntry entry) {
    return entry.manaValue ?? 0;
  }

  bool _hasActiveAdvancedFilters() {
    return _selectedRarities.isNotEmpty ||
        _selectedSetCodes.isNotEmpty ||
        _selectedColors.isNotEmpty ||
        _selectedTypes.isNotEmpty ||
        _manaValueMin != null ||
        _manaValueMax != null;
  }

  String _setLabelForEntry(CollectionCardEntry entry) {
    if (entry.setName.trim().isNotEmpty) {
      return entry.setName.trim();
    }
    return entry.setCode.toUpperCase();
  }

  int? _setTotalForEntry(CollectionCardEntry entry) {
    final direct = entry.setTotal;
    if (direct != null && direct > 0) {
      return direct;
    }
    final code = entry.setCode.trim().toLowerCase();
    final fromMap = _setTotalsByCode[code];
    if (fromMap != null && fromMap > 0) {
      return fromMap;
    }
    if (widget.isSetCollection && _cards.isNotEmpty) {
      return _cards.length;
    }
    return null;
  }

  String _collectorProgressLabel(CollectionCardEntry entry) {
    final number = entry.collectorNumber.trim();
    if (number.isEmpty) {
      return '';
    }
    if (number.contains('/')) {
      return number;
    }
    final total = _setTotalForEntry(entry);
    if (total == null || total <= 0) {
      return number;
    }
    return '$number/$total';
  }

  String _subtitleLabel(CollectionCardEntry entry) {
    final setLabel = _setLabelForEntry(entry);
    final progress = _collectorProgressLabel(entry);
    if (setLabel.isEmpty) {
      return progress;
    }
    if (progress.isEmpty) {
      return setLabel;
    }
    return '$setLabel â€¢ $progress';
  }

  Future<void> _showAdvancedFilters() async {
    final base = _baseVisibleCards();
    final availableRarities = <String>{};
    final availableSetCodes = <String, String>{};
    final availableColors = <String>{};
    final availableTypes = <String>{};
    for (final entry in base) {
      if (entry.rarity.trim().isNotEmpty) {
        availableRarities.add(entry.rarity.trim().toLowerCase());
      }
      if (entry.setCode.trim().isNotEmpty) {
        availableSetCodes[entry.setCode.trim().toLowerCase()] =
            _setLabelForEntry(entry);
      }
      availableColors.addAll(_cardColors(entry));
      availableTypes.addAll(_cardTypes(entry));
    }

    final tempRarities = _selectedRarities.toSet();
    final tempSetCodes = _selectedSetCodes.toSet();
    final tempColors = _selectedColors.toSet();
    final tempTypes = _selectedTypes.toSet();
    final minController =
        TextEditingController(text: _manaValueMin?.toString() ?? '');
    final maxController =
        TextEditingController(text: _manaValueMax?.toString() ?? '');
    var setQuery = '';

    var applied = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final l10n = AppLocalizations.of(context)!;
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
                        onSelected: (_) => setSheetState(() => toggle(item)),
                      ),
                    )
                    .toList(),
              );
            }

            final rarityOrder = ['common', 'uncommon', 'rare', 'mythic'];
            final sortedRarities = availableRarities.toList()
              ..sort((a, b) {
                final ai = rarityOrder.indexOf(a);
                final bi = rarityOrder.indexOf(b);
                if (ai == -1 && bi == -1) {
                  return a.compareTo(b);
                }
                if (ai == -1) return 1;
                if (bi == -1) return -1;
                return ai.compareTo(bi);
              });
            final sortedSets = availableSetCodes.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value));
            final filteredSets = sortedSets.where((entry) {
              if (setQuery.isEmpty) {
                return true;
              }
              return entry.value.toLowerCase().contains(setQuery) ||
                  entry.key.toLowerCase().contains(setQuery);
            }).toList();
            const colorOrder = ['W', 'U', 'B', 'R', 'G', 'C'];
            final sortedColors = availableColors.toList()
              ..sort((a, b) =>
                  colorOrder.indexOf(a).compareTo(colorOrder.indexOf(b)));
            final sortedTypes = availableTypes.toList()..sort();

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.advancedFiltersTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (sortedRarities.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.rarity,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        sortedRarities,
                        (value) => tempRarities.contains(value),
                        (value) {
                          if (!tempRarities.add(value)) {
                            tempRarities.remove(value);
                          }
                        },
                        (value) => _formatRarity(value),
                      ),
                    ],
                    if (sortedSets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.setLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: l10n.searchSetHint,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            setQuery = value.trim().toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: sortedSets.length > 16 ? 200 : null,
                        child: SingleChildScrollView(
                          child: buildChipRow<MapEntry<String, String>>(
                            filteredSets,
                            (value) => tempSetCodes.contains(value.key),
                            (value) {
                              if (!tempSetCodes.add(value.key)) {
                                tempSetCodes.remove(value.key);
                              }
                            },
                            (value) => value.value,
                          ),
                        ),
                      ),
                    ],
                    if (sortedColors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.colorLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        sortedColors,
                        (value) => tempColors.contains(value),
                        (value) {
                          if (!tempColors.add(value)) {
                            tempColors.remove(value);
                          }
                        },
                        (value) => _colorLabel(value),
                      ),
                    ],
                    if (sortedTypes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.typeLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        sortedTypes,
                        (value) => tempTypes.contains(value),
                        (value) {
                          if (!tempTypes.add(value)) {
                            tempTypes.remove(value);
                          }
                        },
                        (value) => value,
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
                            controller: minController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: l10n.minLabel,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: l10n.maxLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sortedRarities.isEmpty &&
                        sortedSets.isEmpty &&
                        sortedColors.isEmpty &&
                        sortedTypes.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(l10n.noFiltersAvailableForList),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempRarities.clear();
                              tempSetCodes.clear();
                              tempColors.clear();
                              tempTypes.clear();
                              minController.clear();
                              maxController.clear();
                            });
                          },
                          child: Text(l10n.clear),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            applied = true;
                            Navigator.of(context).pop();
                          },
                          child: Text(l10n.apply),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || !applied) {
      return;
    }
    int? minValue = int.tryParse(minController.text.trim());
    int? maxValue = int.tryParse(maxController.text.trim());
    if (minValue != null && maxValue != null && minValue > maxValue) {
      final swap = minValue;
      minValue = maxValue;
      maxValue = swap;
    }
    setState(() {
      _selectedRarities
        ..clear()
        ..addAll(tempRarities);
      _selectedSetCodes
        ..clear()
        ..addAll(tempSetCodes);
      _selectedColors
        ..clear()
        ..addAll(tempColors);
      _selectedTypes
        ..clear()
        ..addAll(tempTypes);
      _manaValueMin = minValue;
      _manaValueMax = maxValue;
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

  Widget _buildSetHeader() {
    final ownedCount =
        _ownedCount ?? _cards.where((entry) => entry.quantity > 0).length;
    final missingCount =
        _missingCount ?? (_cards.length - ownedCount).clamp(0, _cards.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchCardsHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) {
              _searchDebounce?.cancel();
              final next = value.trim();
              _searchDebounce =
                  Timer(const Duration(milliseconds: 300), () {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _searchQuery = next;
                });
                _loadCards();
              });
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              FilterChip(
                label: Text(
                  AppLocalizations.of(context)!.ownedCount(ownedCount),
                ),
                selected: _showOwned,
                onSelected: (value) {
                  setState(() {
                    _showOwned = value;
                  });
                  _loadCards();
                },
              ),
              FilterChip(
                label: Text(
                  AppLocalizations.of(context)!.missingCount(missingCount),
                ),
                selected: _showMissing,
                onSelected: (value) {
                  setState(() {
                    _showMissing = value;
                  });
                  _loadCards();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickAddCard(CollectionCardEntry entry) async {
    final ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null) {
      return;
    }
    final nextQuantity = entry.quantity + 1;
    await ScryfallDatabase.instance.upsertCollectionCard(
      ownedCollectionId,
      entry.cardId,
      quantity: nextQuantity,
      foil: entry.foil,
      altArt: entry.altArt,
    );
    await _loadCards();
  }

  Future<void> _addCard(BuildContext context) async {
    final ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.allCardsCollectionNotFound,
      );
      return;
    }
    final mode = await _showAddCardEntryModePicker(context);
    if (!context.mounted || mode == null) {
      return;
    }
    if (mode == _AddCardEntryMode.byScan) {
      await _addCardByScan(context, ownedCollectionId);
      return;
    }
    await _addCardByName(context, ownedCollectionId);
  }

  Future<void> _addCardByName(
    BuildContext context,
    int ownedCollectionId, {
    String? initialQuery,
    String? initialSetCode,
    String? initialCollectorNumber,
  }) async {
    final selection = await showModalBottomSheet<_CardSearchSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CardSearchSheet(
        initialQuery: initialQuery,
        initialSetCode: initialSetCode,
        initialCollectorNumber: initialCollectorNumber,
      ),
    );

    if (selection == null) {
      return;
    }

    if (selection.isBulk) {
      await ScryfallDatabase.instance.addCardsToCollection(
        ownedCollectionId,
        selection.cardIds,
      );
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.addedCards(selection.count),
      );
    } else {
      await ScryfallDatabase.instance.addCardToCollection(
        ownedCollectionId,
        selection.cardIds.first,
      );
    }
    if (!mounted) {
      return;
    }
    await _loadCards();
  }

  Future<_AddCardEntryMode?> _showAddCardEntryModePicker(
    BuildContext context,
  ) async {
    return showModalBottomSheet<_AddCardEntryMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                l10n.addCard,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('By name'),
                subtitle: const Text('Search and add manually'),
                onTap: () =>
                    Navigator.of(context).pop(_AddCardEntryMode.byName),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('By scan'),
                subtitle: const Text('Live OCR card recognition'),
                onTap: () =>
                    Navigator.of(context).pop(_AddCardEntryMode.byScan),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addCardByScan(BuildContext context, int ownedCollectionId) async {
    final recognizedText = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _CardScannerPage(),
      ),
    );
    if (!context.mounted || recognizedText == null) {
      return;
    }
    final setCodes = await _fetchKnownSetCodesForScan();
    if (!context.mounted) {
      return;
    }
    final ocrSeed = _buildOcrSearchSeedForScan(
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
    final refinedSeed = await _refineOcrSeedForScan(ocrSeed);
    if (!context.mounted) {
      return;
    }
    await _addCardByName(
      context,
      ownedCollectionId,
      initialQuery: refinedSeed.query,
      initialSetCode: refinedSeed.setCode,
      initialCollectorNumber: refinedSeed.collectorNumber,
    );
  }

  Future<Set<String>> _fetchKnownSetCodesForScan() async {
    final sets = await ScryfallDatabase.instance.fetchAvailableSets();
    return sets
        .map((set) => set.code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  _OcrSearchSeed? _buildOcrSearchSeedForScan(
    String rawText, {
    required Set<String> knownSetCodes,
  }) {
    final text = rawText.trim();
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
    final bestName = _extractLikelyCardNameForScan(topLines);

    String? setCode;
    String? collectorNumber;
    final setAndCollector = _extractSetAndCollectorForScan(
      bottomLines,
      knownSetCodes: knownSetCodes,
    );
    setCode = setAndCollector.$1;
    collectorNumber = setAndCollector.$2;

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
          final detectedSet = _detectSetCodeFromTokenForScan(
            token,
            knownSetCodes: knownSetCodes,
          );
          if (detectedSet != null) {
            setCode = detectedSet;
          }
        }
        if (setCode != null) {
          final next = (i + 1 < tokens.length) ? tokens[i + 1] : null;
          final fromNext = _normalizeCollectorNumberForScan(next ?? '');
          collectorNumber =
              _pickBetterCollectorNumberForScan(collectorNumber, fromNext);
        }
        if (token.contains('/')) {
          final part = token.split('/').first;
          final normalized = _normalizeCollectorNumberForScan(part);
          collectorNumber = _pickBetterCollectorNumberForScan(
            collectorNumber,
            normalized,
          );
        }
        collectorNumber = _pickBetterCollectorNumberForScan(
          collectorNumber,
          _normalizeCollectorNumberForScan(token),
        );
      }
    }

    if (bestName.isEmpty && setCode == null && collectorNumber == null) {
      return null;
    }
    final fallbackQuery = bestName.isEmpty ? lines.first : bestName;
    final useCollectorQuery = collectorNumber != null &&
        collectorNumber.isNotEmpty &&
        setCode != null &&
        setCode.isNotEmpty &&
        !_isWeakCollectorNumberForScan(collectorNumber);
    final query = useCollectorQuery ? collectorNumber : fallbackQuery;
    return _OcrSearchSeed(
      query: query,
      cardName: bestName.isEmpty ? null : bestName,
      setCode: setCode,
      collectorNumber: collectorNumber,
    );
  }

  Future<_OcrSearchSeed> _refineOcrSeedForScan(_OcrSearchSeed seed) async {
    final query = seed.query.trim();
    final setCode = seed.setCode?.trim().toLowerCase();
    if (query.isEmpty || setCode == null || setCode.isEmpty) {
      return seed;
    }
    final strictCount = await ScryfallDatabase.instance.countCardsForFilterWithSearch(
      CollectionFilter(sets: {setCode}),
      searchQuery: query,
    );
    if (strictCount > 0) {
      return seed;
    }
    final onlineSeed = await _tryOnlineCardFallbackForScan(seed);
    if (onlineSeed != null) {
      return onlineSeed;
    }
    final fallbackName = seed.cardName?.trim();
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

  Future<_OcrSearchSeed?> _tryOnlineCardFallbackForScan(_OcrSearchSeed seed) async {
    final setCode = seed.setCode?.trim().toLowerCase();
    final collector = seed.collectorNumber?.trim().toLowerCase();
    if (setCode == null ||
        setCode.isEmpty ||
        collector == null ||
        collector.isEmpty ||
        _isWeakCollectorNumberForScan(collector)) {
      return null;
    }
    try {
      final uri = Uri.parse(
        'https://api.scryfall.com/cards/$setCode/${Uri.encodeComponent(collector)}',
      );
      final response = await http.get(uri);
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

  String _extractLikelyCardNameForScan(List<String> lines) {
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
      final normalized = _trimToNameSegmentForScan(
        _normalizePotentialCardNameForScan(lines[i]),
      );
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

  String _trimToNameSegmentForScan(String value) {
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

  (String?, String?) _extractSetAndCollectorForScan(
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
        setCode ??= _detectSetCodeFromTokenForScan(
          direct.group(1) ?? '',
          knownSetCodes: knownSetCodes,
        );
        collectorNumber ??= _normalizeCollectorNumberForScan(direct.group(2) ?? '');
      }
      final slash = collectorSlashRegex.firstMatch(upper);
      if (slash != null) {
        collectorNumber ??= _normalizeCollectorNumberForScan(slash.group(1) ?? '');
      }
      if (collectorNumber != null && setCode == null) {
        setCode = _findNearestSetCodeForScan(
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

  String? _findNearestSetCodeForScan(
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
        final detected = _detectSetCodeInLineForScan(
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

  String? _detectSetCodeInLineForScan(
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
      final set = _detectSetCodeFromTokenForScan(
        token,
        knownSetCodes: knownSetCodes,
      );
      if (set != null) {
        return set;
      }
    }
    return null;
  }

  String? _detectSetCodeFromTokenForScan(
    String token, {
    required Set<String> knownSetCodes,
  }) {
    final raw = token.trim().toLowerCase();
    if (raw.isEmpty) {
      return null;
    }
    final candidates = <String>{
      raw,
      raw
          .replaceAll('0', 'o')
          .replaceAll('1', 'i')
          .replaceAll('5', 's')
          .replaceAll('8', 'b'),
    };
    for (final candidate in candidates) {
      if (candidate.isNotEmpty && knownSetCodes.contains(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  String _normalizePotentialCardNameForScan(String input) {
    return input
        .replaceAll(RegExp(r"[^A-Za-z0-9'\-\s,]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _normalizeCollectorNumberForScan(String input) {
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
    return match.group(1);
  }

  String? _pickBetterCollectorNumberForScan(String? current, String? candidate) {
    if (candidate == null || candidate.isEmpty) {
      return current;
    }
    if (current == null || current.isEmpty) {
      return candidate;
    }
    final currentScore = _collectorConfidenceScoreForScan(current);
    final candidateScore = _collectorConfidenceScoreForScan(candidate);
    if (candidateScore > currentScore) {
      return candidate;
    }
    return current;
  }

  int _collectorConfidenceScoreForScan(String value) {
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

  bool _isWeakCollectorNumberForScan(String value) {
    return RegExp(r'^\d$').hasMatch(value.trim());
  }

  Future<void> _showCardDetails(CollectionCardEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final details = _parseCardDetails(l10n, entry);
    final typeLine = entry.typeLine.trim();
    final manaCost = entry.manaCost.trim();
    final oracleText = entry.oracleText.trim();
    final power = entry.power.trim();
    final toughness = entry.toughness.trim();
    final loyalty = entry.loyalty.trim();
    final stats = _joinStats(power, toughness);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSetIcon(entry.setCode, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _subtitleLabel(entry),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFBFAE95),
                            ),
                      ),
                      const Spacer(),
                      if (manaCost.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A221B),
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: const Color(0xFF3A2F24)),
                          ),
                          child: Text(
                            manaCost,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                  if (typeLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      typeLine,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFE3D4B8),
                          ),
                    ),
                  ],
                  if (oracleText.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF201A14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3A2F24)),
                      ),
                      child: Text(
                        oracleText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  if (stats.isNotEmpty || loyalty.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (stats.isNotEmpty) _buildBadge(stats),
                        if (loyalty.isNotEmpty)
                          _buildBadge(l10n.loyaltyLabel(loyalty)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (entry.imageUri != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        entry.imageUri!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  if (entry.imageUri != null &&
                      _subtitleLabel(entry).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _subtitleLabel(entry),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFBFAE95),
                          ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    l10n.details,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailGrid(details),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<_CardDetail> _parseCardDetails(
    AppLocalizations l10n,
    CollectionCardEntry entry,
  ) {
    final setLabel =
        entry.setName.isNotEmpty ? entry.setName : entry.setCode.toUpperCase();
    final details = <_CardDetail>[
      _CardDetail(l10n.detailSet, setLabel),
      _CardDetail(l10n.detailCollector, entry.collectorNumber),
    ];
    void add(String label, String value) {
      final text = value.trim();
      if (text.isEmpty) {
        return;
      }
      details.add(_CardDetail(label, text));
    }

    add(l10n.detailRarity, entry.rarity);
    add(l10n.detailSetName, entry.setName);
    add(l10n.detailLanguage, entry.lang);
    add(l10n.detailRelease, entry.releasedAt);
    add(l10n.detailArtist, entry.artist);
    return details.where((item) => item.value.isNotEmpty).toList();
  }

  String _joinStats(dynamic power, dynamic toughness) {
    final p = power?.toString().trim() ?? '';
    final t = toughness?.toString().trim() ?? '';
    if (p.isEmpty && t.isEmpty) {
      return '';
    }
    if (p.isEmpty) {
      return t;
    }
    if (t.isEmpty) {
      return p;
    }
    return '$p/$t';
  }

  Widget _buildDetailGrid(List<_CardDetail> details) {
    if (details.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: details
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _DetailRow(
                    label: item.label,
                    value: item.value,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _showCardActions(CollectionCardEntry entry) async {
    final ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.allCardsCollectionNotFound,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final quantityController =
            TextEditingController(text: entry.quantity.toString());
        var foil = entry.foil;
        var altArt = entry.altArt;
        final isFilterCollection = !widget.isAllCards;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    entry.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitleLabel(entry),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFFBFAE95)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.quantityLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: foil,
                    onChanged: (value) {
                      setSheetState(() {
                        foil = value ?? false;
                      });
                    },
                    title: Text(l10n.foilLabel),
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: altArt,
                    onChanged: (value) {
                      setSheetState(() {
                        altArt = value ?? false;
                      });
                    },
                    title: Text(l10n.altArtLabel),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          if (isFilterCollection) {
                            await ScryfallDatabase.instance.upsertCollectionCard(
                              ownedCollectionId,
                              entry.cardId,
                              quantity: 0,
                              foil: foil,
                              altArt: altArt,
                            );
                          } else {
                            await ScryfallDatabase.instance.deleteCollectionCard(
                              ownedCollectionId,
                              entry.cardId,
                            );
                          }
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                          if (!mounted) {
                            return;
                          }
                          await _loadCards();
                        },
                        child: Text(
                          isFilterCollection ? l10n.markMissing : l10n.delete,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          final parsed =
                              int.tryParse(quantityController.text.trim()) ??
                                  entry.quantity;
                          final quantity = isFilterCollection
                              ? (parsed < 0 ? 0 : parsed)
                              : (parsed < 1 ? 1 : parsed);
                          await ScryfallDatabase.instance.upsertCollectionCard(
                            ownedCollectionId,
                            entry.cardId,
                            quantity: quantity,
                            foil: foil,
                            altArt: altArt,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                          if (!mounted) {
                            return;
                          }
                          await _loadCards();
                        },
                        child: Text(l10n.save),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visibleCards = _sortedCards();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? l10n.selectedCardsCount(_selectedCardIds.length)
              : (widget.isAllCards ? '' : widget.name),
        ),
        bottom: _isFilterCollection
            ? PreferredSize(
                preferredSize: const Size.fromHeight(108),
                child: _buildSetHeader(),
              )
            : null,
        actions: [
          PopupMenuButton<_CardSortMode>(
            tooltip: l10n.sortBy,
            icon: const Icon(Icons.sort),
            onSelected: (mode) {
              setState(() {
                _sortMode = mode;
              });
            },
            itemBuilder: (context) {
              return _CardSortMode.values
                  .map(
                    (mode) => PopupMenuItem(
                      value: mode,
                      child: Row(
                        children: [
                          if (_sortMode == mode)
                            const Icon(Icons.check, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(_sortLabel(mode, l10n)),
                        ],
                      ),
                    ),
                  )
                  .toList();
            },
          ),
          IconButton(
            tooltip: _selectionMode ? l10n.cancel : l10n.selectCards,
            icon: Icon(_selectionMode ? Icons.close : Icons.check_box_outlined),
            onPressed: () {
              if (_selectionMode) {
                _exitSelection();
              } else {
                setState(() {
                  _selectionMode = true;
                  _selectedCardIds.clear();
                });
              }
            },
          ),
          if (_selectionMode)
            IconButton(
              tooltip: _areAllVisibleSelected(visibleCards)
                  ? l10n.deselectAll
                  : l10n.selectAll,
              icon: Icon(
                _areAllVisibleSelected(visibleCards)
                    ? Icons.remove_done
                    : Icons.select_all,
              ),
              onPressed: () => _toggleSelectAll(visibleCards),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _selectedCardIds.isEmpty ? null : _deleteSelected,
            ),
          IconButton(
            tooltip: _viewMode == CollectionViewMode.list
                ? l10n.gallery
                : l10n.list,
            icon: Icon(
              _viewMode == CollectionViewMode.list
                  ? Icons.grid_view
                  : Icons.list,
            ),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == CollectionViewMode.list
                    ? CollectionViewMode.gallery
                    : CollectionViewMode.list;
              });
              AppSettings.saveCollectionViewMode(_viewMode);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const _AppBackground(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (visibleCards.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(20),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.collections,
                        size: 36, color: Color(0xFFE9C46A)),
                    const SizedBox(height: 12),
                    Text(
                      widget.isAllCards
                          ? l10n.noOwnedCardsYet
                          : _isFilterCollection
                              ? l10n.noCardsMatchFilters
                              : l10n.noCardsYet,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isFilterCollection
                          ? l10n.tryEnablingOwnedOrMissing
                          : widget.isAllCards
                              ? l10n.addCardsHereOrAny
                              : l10n.addFirstCardToStartCollection,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFBFAE95),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (!widget.isSetCollection)
                      FilledButton.icon(
                        onPressed: () => _addCard(context),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addCard),
                      ),
                  ],
                ),
              ),
            )
          else
            _viewMode == CollectionViewMode.list
                ? ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount:
                        visibleCards.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= visibleCards.length) {
                        return _buildLoadMoreIndicator();
                      }
                      final entry = visibleCards[index];
                      final isMissing =
                          _isFilterCollection && entry.quantity == 0;
                      final hasCornerQuantity = entry.quantity > 1;
                      return GestureDetector(
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(entry);
                            return;
                          }
                          _showCardDetails(entry);
                        },
                        onLongPress: () {
                          if (_selectionMode) {
                            _toggleSelection(entry);
                            return;
                          }
                          _showCardActions(entry);
                        },
                        child: Opacity(
                          opacity: isMissing ? 0.45 : 1,
                          child: Stack(
                            children: [
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 108),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration:
                                      _cardTintDecoration(context, entry),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      _buildSetIcon(entry.setCode, size: 30),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Builder(
                                              builder: (context) {
                                                final setLabel =
                                                    _setLabelForEntry(entry);
                                                final progress =
                                                    _collectorProgressLabel(
                                                        entry);
                                                final hasRarity = entry.rarity
                                                    .trim()
                                                    .isNotEmpty;
                                                final leftLabel = setLabel
                                                        .isNotEmpty
                                                    ? setLabel
                                                    : progress;
                                                return Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        leftLabel,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: const Color(
                                                                  0xFFBFAE95),
                                                            ),
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (progress.isNotEmpty &&
                                                        setLabel
                                                            .isNotEmpty) ...[
                                                      Text(
                                                        progress,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: const Color(
                                                                  0xFFBFAE95),
                                                            ),
                                                      ),
                                                    ],
                                                    if (hasRarity) ...[
                                                      const SizedBox(width: 6),
                                                      _raritySquare(
                                                          entry.rarity),
                                                    ],
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_isFilterCollection ||
                                          widget.isAllCards) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: l10n.addOne,
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          color: const Color(0xFFE9C46A),
                                          onPressed: _selectionMode
                                              ? null
                                              : () => _quickAddCard(entry),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              if (_selectionMode || _isSelected(entry))
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: _buildSelectionBadge(
                                    _isSelected(entry),
                                  ),
                                ),
                              if (isMissing)
                                Positioned(
                                  top: 6,
                                  right: hasCornerQuantity ? 42 : 8,
                                  child: _buildBadge(l10n.missingLabel),
                                ),
                              if (entry.foil || entry.altArt)
                                Positioned(
                                  top: isMissing ? 42 : 6,
                                  right: hasCornerQuantity ? 42 : 8,
                                  child: Row(
                                    children: [
                                      if (entry.foil)
                                        _statusMiniBadge(icon: Icons.star),
                                      if (entry.foil && entry.altArt)
                                        const SizedBox(width: 6),
                                      if (entry.altArt)
                                        _statusMiniBadge(icon: Icons.brush),
                                    ],
                                  ),
                                ),
                              if (hasCornerQuantity)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child:
                                      _cornerQuantityBadge(l10n, entry.quantity),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.72,
                    ),
                    itemCount:
                        visibleCards.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= visibleCards.length) {
                        return _buildLoadMoreIndicator();
                      }
                      final entry = visibleCards[index];
                      final isMissing =
                          _isFilterCollection && entry.quantity == 0;
                      return GestureDetector(
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(entry);
                            return;
                          }
                          _showCardDetails(entry);
                        },
                        onLongPress: () {
                          if (_selectionMode) {
                            _toggleSelection(entry);
                            return;
                          }
                          _showCardActions(entry);
                        },
                        child: Opacity(
                          opacity: isMissing ? 0.45 : 1,
                          child: Stack(
                            children: [
                              Container(
                                decoration: _cardTintDecoration(context, entry),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            entry.imageUri == null
                                                ? Container(
                                                    color:
                                                        const Color(0xFF201A14),
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      color: Color(0xFFBFAE95),
                                                    ),
                                                  )
                                                : Image.network(
                                                    entry.imageUri!,
                                                    fit: BoxFit.cover,
                                                  ),
                                            if ((_isFilterCollection ||
                                                    widget.isAllCards) &&
                                                !_selectionMode)
                                              Positioned(
                                                top: 8,
                                                left: 8,
                                                child: Material(
                                                  color: const Color(0xFF1C1713)
                                                      .withValues(alpha: 0.9),
                                                  shape: const CircleBorder(),
                                                  child: InkWell(
                                                    customBorder:
                                                        const CircleBorder(),
                                                    onTap: () =>
                                                        _quickAddCard(entry),
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(9),
                                                      child: Icon(
                                                        Icons.add,
                                                        size: 22,
                                                        color:
                                                            Color(0xFFE9C46A),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (isMissing)
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child:
                                                    _buildBadge(l10n.missingLabel),
                                              ),
                                            if (entry.foil || entry.altArt)
                                              Positioned(
                                                bottom: 8,
                                                right: 8,
                                                child: Row(
                                                  children: [
                                                    if (entry.foil)
                                                      _statusMiniBadge(
                                                        icon: Icons.star,
                                                      ),
                                                    if (entry.foil &&
                                                        entry.altArt)
                                                      const SizedBox(width: 6),
                                                    if (entry.altArt)
                                                      _statusMiniBadge(
                                                        icon: Icons.brush,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: 44,
                                            child: Text(
                                              entry.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              _buildSetIcon(entry.setCode,
                                                  size: 22),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _setLabelForEntry(entry),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: const Color(
                                                                0xFFBFAE95),
                                                          ),
                                                    ),
                                                    Builder(
                                                      builder: (context) {
                                                        final progress =
                                                            _collectorProgressLabel(
                                                                entry);
                                                        final hasRarity = entry
                                                            .rarity
                                                            .trim()
                                                            .isNotEmpty;
                                                        if (!hasRarity &&
                                                            progress
                                                                .isEmpty) {
                                                          return const SizedBox
                                                              .shrink();
                                                        }
                                                        return Row(
                                                          children: [
                                                            const Spacer(),
                                                            if (progress
                                                                .isNotEmpty)
                                                              Text(
                                                                progress,
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      color: const Color(
                                                                          0xFFBFAE95),
                                                                    ),
                                                              ),
                                                            if (hasRarity) ...[
                                                              const SizedBox(
                                                                  width: 6),
                                                              _raritySquare(
                                                                  entry.rarity),
                                                            ],
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectionMode || _isSelected(entry))
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: _buildSelectionBadge(
                                    _isSelected(entry),
                                  ),
                                ),
                              if (entry.quantity > 1)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child:
                                      _cornerQuantityBadge(l10n, entry.quantity),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          if (!_loading)
            Positioned(
              left: 20,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: FloatingActionButton(
                heroTag: 'filters_fab',
                onPressed: _showAdvancedFilters,
                tooltip: l10n.filters,
                backgroundColor: _hasActiveAdvancedFilters()
                    ? const Color(0xFFE9C46A)
                    : null,
                foregroundColor: _hasActiveAdvancedFilters()
                    ? const Color(0xFF1C1510)
                    : null,
                child: Icon(
                  _hasActiveAdvancedFilters()
                      ? Icons.filter_list_alt
                      : Icons.filter_list,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCard(context),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.addCard),
      ),
    );
  }
}

