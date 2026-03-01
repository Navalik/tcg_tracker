part of 'package:tcg_tracker/main.dart';

enum _CardSortMode { name, color, type }

enum _AddCardEntryMode { byName, byScan, byFilter }

class _DeckSectionRow {
  const _DeckSectionRow.header({
    required this.typeKey,
    required this.label,
    required this.count,
  }) : entry = null;

  const _DeckSectionRow.card(this.entry)
    : typeKey = null,
      label = null,
      count = null;

  final String? typeKey;
  final String? label;
  final int? count;
  final CollectionCardEntry? entry;

  bool get isHeader => entry == null;
}

class _DeckSection {
  const _DeckSection({
    required this.typeKey,
    required this.label,
    required this.cards,
  });

  final String typeKey;
  final String label;
  final List<CollectionCardEntry> cards;
}

class _DeckStats {
  const _DeckStats({
    required this.total,
    required this.creatures,
    required this.lands,
    required this.other,
  });

  final int total;
  final int creatures;
  final int lands;
  final int other;
}

class _PokemonDeckStats {
  const _PokemonDeckStats({
    required this.total,
    required this.pokemon,
    required this.trainer,
    required this.energy,
    required this.basicPokemon,
    required this.overLimitNames,
  });

  final int total;
  final int pokemon;
  final int trainer;
  final int energy;
  final int basicPokemon;
  final int overLimitNames;
}

class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    required this.name,
    this.isAllCards = false,
    this.isSetCollection = false,
    this.isWishlistCollection = false,
    this.isDeckCollection = false,
    this.isBasicLandsCollection = false,
    this.setCode,
    this.filter,
    this.autoOpenAddCard = false,
  });

  final int collectionId;
  final String name;
  final bool isAllCards;
  final bool isSetCollection;
  final bool isWishlistCollection;
  final bool isDeckCollection;
  final bool isBasicLandsCollection;
  final String? setCode;
  final CollectionFilter? filter;
  final bool autoOpenAddCard;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  static const int _pageSize = 120;
  static const int _freeDailyScanLimit = 20;
  static const List<String> _mtgDeckTypeOrder = [
    'Creature',
    'Planeswalker',
    'Battle',
    'Artifact',
    'Enchantment',
    'Instant',
    'Sorcery',
    'Land',
    'Tribal',
    'Other',
  ];
  static const List<String> _pokemonDeckTypeOrder = [
    'Pokemon',
    'Trainer',
    'Energy',
    'Other',
  ];
  final List<CollectionCardEntry> _cards = [];
  final List<CollectionCardEntry> _sideboardCards = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _loadedOffset = 0;
  int? _ownedCollectionId;
  int? _allCardsCollectionId;
  int? _sideboardCollectionId;
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
  final Set<String> _quickAddAnimating = {};
  final Set<String> _quickRemoveAnimating = {};
  final Set<String> _priceRefreshQueued = {};
  Set<String>? _cachedKnownSetCodesForScan;
  String _priceCurrency = 'eur';
  bool _showPrices = true;
  static const List<String> _basicLandManaOrder = ['W', 'U', 'B', 'R', 'G'];

  bool get _isFilterCollection =>
      !widget.isAllCards &&
      !widget.isDeckCollection &&
      (widget.filter != null || widget.isSetCollection);
  bool get _isPokemonActive =>
      TcgEnvironmentController.instance.currentGame == TcgGame.pokemon;
  bool get _isMissingStyleCollection =>
      _isFilterCollection || widget.isWishlistCollection;
  bool get _isPokemonDeck => widget.isDeckCollection && _isPokemonActive;
  List<String> get _activeDeckTypeOrder =>
      _isPokemonDeck ? _pokemonDeckTypeOrder : _mtgDeckTypeOrder;

  bool _isBasicLandForMana(CollectionCardEntry entry, String mana) {
    final normalizedMana = mana.trim().toUpperCase();
    if (normalizedMana.isEmpty) {
      return false;
    }
    final typeLine = entry.typeLine.trim().toLowerCase();
    if (!typeLine.contains('land') || !typeLine.contains('basic')) {
      return false;
    }
    final colors = _cardColors(entry);
    return colors.length == 1 && colors.contains(normalizedMana);
  }

  Map<String, int> _basicLandCountsForCards(List<CollectionCardEntry> cards) {
    final counts = <String, int>{
      for (final mana in _basicLandManaOrder) mana: 0,
    };
    for (final entry in cards) {
      if (entry.quantity <= 0) {
        continue;
      }
      for (final mana in _basicLandManaOrder) {
        if (_isBasicLandForMana(entry, mana)) {
          counts[mana] = (counts[mana] ?? 0) + entry.quantity;
          break;
        }
      }
    }
    return counts;
  }

  CollectionCardEntry? _findBasicLandEntryForMana(
    List<CollectionCardEntry> cards,
    String mana,
  ) {
    for (final entry in cards) {
      if (entry.quantity > 0 && _isBasicLandForMana(entry, mana)) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _changeBasicLandInDeck(String mana, int delta) async {
    if (!widget.isDeckCollection || delta == 0) {
      return;
    }
    final ownedCollectionId = _ownedCollectionId ?? widget.collectionId;
    final preferredBasicCardId = await ScryfallDatabase.instance
        .fetchPreferredBasicLandCardId(mana);
    final preferredEntry = preferredBasicCardId == null
        ? null
        : await ScryfallDatabase.instance.fetchCardEntryById(
            preferredBasicCardId,
            collectionId: ownedCollectionId,
          );
    var existing = _findBasicLandEntryForMana(_cards, mana);
    existing ??= await ScryfallDatabase.instance
        .fetchFirstBasicLandEntryForCollection(ownedCollectionId, mana);
    if (delta < 0) {
      final entryToReduce =
          (preferredEntry != null && preferredEntry.quantity > 0)
          ? preferredEntry
          : existing;
      if (entryToReduce == null || entryToReduce.quantity <= 0) {
        return;
      }
      final nextQuantity = entryToReduce.quantity - 1;
      await ScryfallDatabase.instance.upsertCollectionCard(
        ownedCollectionId,
        entryToReduce.cardId,
        quantity: nextQuantity,
        foil: entryToReduce.foil,
        altArt: entryToReduce.altArt,
      );
      await _loadCards();
      return;
    }

    CollectionCardEntry? targetEntry;
    if (preferredBasicCardId != null) {
      targetEntry = preferredEntry;
      targetEntry ??= await ScryfallDatabase.instance.fetchCardEntryById(
        preferredBasicCardId,
        collectionId: ownedCollectionId,
      );
    } else {
      targetEntry = existing;
    }
    if (targetEntry == null) {
      return;
    }

    final nextQuantity = targetEntry.quantity + 1;
    await ScryfallDatabase.instance.upsertCollectionCard(
      ownedCollectionId,
      targetEntry.cardId,
      quantity: nextQuantity,
      foil: false,
      altArt: false,
    );
    await _loadCards();
  }

  Color _basicLandColor(String mana) {
    switch (mana) {
      case 'W':
        return const Color(0xFFF0E6C8);
      case 'U':
        return const Color(0xFF74C0FC);
      case 'B':
        return const Color(0xFF6F5B8C);
      case 'R':
        return const Color(0xFFE53935);
      case 'G':
        return const Color(0xFF81C784);
      default:
        return const Color(0xFFE9C46A);
    }
  }

  @override
  void initState() {
    super.initState();
    _initialize();
    _loadViewMode();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initialize() async {
    final priceCurrency = await AppSettings.loadPriceCurrency();
    final showPrices = await AppSettings.loadShowPrices();
    if (mounted) {
      setState(() {
        _priceCurrency = priceCurrency;
        _showPrices = showPrices;
      });
    }
    if (widget.isAllCards) {
      _ownedCollectionId = widget.collectionId;
      _allCardsCollectionId = widget.collectionId;
    } else {
      _allCardsCollectionId = await ScryfallDatabase.instance
          .ensureAllCardsCollectionId();
      _ownedCollectionId = widget.isDeckCollection
          ? widget.collectionId
          : _allCardsCollectionId;
      if (widget.isDeckCollection) {
        _sideboardCollectionId = await ScryfallDatabase.instance
            .ensureDeckSideboardCollectionId(widget.collectionId);
      }
    }
    if (!mounted) {
      return;
    }
    if (widget.autoOpenAddCard && !widget.isSetCollection && !_autoAddShown) {
      _autoAddShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _addCard(context);
      });
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
      _sideboardCards.clear();
      _setTotalsByCode = {};
      _selectionMode = false;
      _selectedCardIds.clear();
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _refreshCounts();
    await _loadMoreCards(initial: true);
    await _loadSideboardCards();
  }

  Future<void> _loadSideboardCards() async {
    if (!widget.isDeckCollection) {
      return;
    }
    final sideboardCollectionId =
        _sideboardCollectionId ??
        await ScryfallDatabase.instance.ensureDeckSideboardCollectionId(
          widget.collectionId,
        );
    _sideboardCollectionId = sideboardCollectionId;
    final all = <CollectionCardEntry>[];
    var offset = 0;
    while (true) {
      final page = await ScryfallDatabase.instance.fetchCollectionCards(
        sideboardCollectionId,
        limit: _pageSize,
        offset: offset,
      );
      if (page.isEmpty) {
        break;
      }
      all.addAll(page.where((entry) => entry.quantity > 0));
      if (page.length < _pageSize) {
        break;
      }
      offset += page.length;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _sideboardCards
        ..clear()
        ..addAll(all);
    });
  }

  String _sideboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sideboard';
    }
    return 'Sideboard';
  }

  String _moveToSideboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sposta nel sideboard';
    }
    return 'Move to sideboard';
  }

  String _moveToMainboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sposta nel mainboard';
    }
    return 'Move to mainboard';
  }

  String _moveAllToMainboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sposta tutto nel mainboard';
    }
    return 'Move all to mainboard';
  }

  String _moveAllToSideboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sposta tutto nel sideboard';
    }
    return 'Move all to sideboard';
  }

  Future<void> _moveCardBetweenMainAndSide(
    CollectionCardEntry entry, {
    required bool toSideboard,
    bool moveAll = false,
  }) async {
    if (!widget.isDeckCollection) {
      return;
    }
    final mainCollectionId = _ownedCollectionId ?? widget.collectionId;
    final sideCollectionId =
        _sideboardCollectionId ??
        await ScryfallDatabase.instance.ensureDeckSideboardCollectionId(
          widget.collectionId,
        );
    _sideboardCollectionId = sideCollectionId;
    final fromCollectionId = toSideboard ? mainCollectionId : sideCollectionId;
    final toCollectionId = toSideboard ? sideCollectionId : mainCollectionId;
    final fromEntry = await ScryfallDatabase.instance.fetchCardEntryById(
      entry.cardId,
      collectionId: fromCollectionId,
    );
    final fromQty = fromEntry?.quantity ?? 0;
    if (fromQty <= 0) {
      return;
    }
    final delta = moveAll ? fromQty : 1;
    final toEntry = await ScryfallDatabase.instance.fetchCardEntryById(
      entry.cardId,
      collectionId: toCollectionId,
    );
    final toQty = (toEntry?.quantity ?? 0) + delta;
    final nextFrom = fromQty - delta;
    await ScryfallDatabase.instance.upsertCollectionCard(
      fromCollectionId,
      entry.cardId,
      quantity: nextFrom,
      foil: false,
      altArt: false,
    );
    await ScryfallDatabase.instance.upsertCollectionCard(
      toCollectionId,
      entry.cardId,
      quantity: toQty,
      foil: false,
      altArt: false,
    );
    if (!mounted) {
      return;
    }
    await _loadCards();
  }

  Future<void> _showSideboardCardActions(
    CollectionCardEntry entry,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              Text(entry.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _subtitleLabel(entry),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFBFAE95)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _moveCardBetweenMainAndSide(
                    entry,
                    toSideboard: false,
                    moveAll: false,
                  );
                },
                icon: const Icon(Icons.move_up),
                label: Text(_moveToMainboardLabel()),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _moveCardBetweenMainAndSide(
                    entry,
                    toSideboard: false,
                    moveAll: true,
                  );
                },
                icon: const Icon(Icons.unarchive_outlined),
                label: Text(_moveAllToMainboardLabel()),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMainboardCardActions(
    CollectionCardEntry entry,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              Text(entry.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _subtitleLabel(entry),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFBFAE95)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _moveCardBetweenMainAndSide(
                    entry,
                    toSideboard: true,
                    moveAll: false,
                  );
                },
                icon: const Icon(Icons.move_down),
                label: Text(_moveToSideboardLabel()),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _moveCardBetweenMainAndSide(
                    entry,
                    toSideboard: true,
                    moveAll: true,
                  );
                },
                icon: const Icon(Icons.unarchive_outlined),
                label: Text(_moveAllToSideboardLabel()),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        );
      },
    );
  }

  CollectionFilter? _effectiveFilter() {
    if (widget.isDeckCollection) {
      return null;
    }
    final fallbackFilter =
        widget.isSetCollection && (widget.setCode?.trim().isNotEmpty ?? false)
        ? CollectionFilter(sets: {widget.setCode!.trim().toLowerCase()})
        : null;
    return widget.filter ?? fallbackFilter;
  }

  CollectionFilter? _requiredSearchFilter() {
    if (!widget.isDeckCollection) {
      return null;
    }
    final format = widget.filter?.format?.trim().toLowerCase();
    if (format == null || format.isEmpty) {
      return null;
    }
    return CollectionFilter(format: format);
  }

  Future<void> _refreshCounts() async {
    if (!mounted) {
      return;
    }
    if (widget.isWishlistCollection) {
      final total = await ScryfallDatabase.instance.countCollectionCards(
        widget.collectionId,
        searchQuery: _searchQuery,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ownedCount = 0;
        _missingCount = total;
      });
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
        .countOwnedCardsForFilterWithSearch(filter, searchQuery: _searchQuery);
    final total = await ScryfallDatabase.instance.countCardsForFilterWithSearch(
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
      _refreshListPrices(cards);
      _maybePrefetchIfShort();
    } catch (_) {
      debugPrint('CollectionDetailPage _loadMoreCards failed');
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
    if (_selectedCardIds.isEmpty) {
      return;
    }
    if (ownedCollectionId == null &&
        (widget.isAllCards || _isFilterCollection)) {
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
    final isFilterCollection = _isFilterCollection;
    for (final cardId in ids) {
      if (isFilterCollection) {
        await ScryfallDatabase.instance.upsertCollectionCard(
          ownedCollectionId!,
          cardId,
          quantity: 0,
          foil: false,
          altArt: false,
        );
      } else {
        await ScryfallDatabase.instance.deleteCollectionCard(
          widget.isWishlistCollection
              ? widget.collectionId
              : ownedCollectionId!,
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
    return _parseColorSet(entry.colors, entry.colorIdentity, entry.typeLine);
  }

  Set<String> _cardTypes(CollectionCardEntry entry) {
    final typeLine = entry.typeLine.trim();
    if (typeLine.isEmpty) {
      return {};
    }
    if (_isPokemonActive) {
      final normalized = typeLine.toLowerCase().replaceAll(
        'pokémon',
        'pokemon',
      );
      final matches = <String>{};
      bool containsAny(List<String> values) {
        for (final value in values) {
          if (normalized.contains(value)) {
            return true;
          }
        }
        return false;
      }

      if (containsAny(const ['pokemon'])) {
        matches.add('Pokemon');
      }
      if (containsAny(const ['trainer', 'allenatore'])) {
        matches.add('Trainer');
      }
      if (containsAny(const ['energy', 'energia'])) {
        matches.add('Energy');
      }
      if (containsAny(const ['item', 'oggetto'])) {
        matches.add('Item');
      }
      if (containsAny(const ['supporter', 'aiuto'])) {
        matches.add('Supporter');
      }
      if (containsAny(const ['stadium', 'stadio'])) {
        matches.add('Stadium');
      }
      if (containsAny(const ['tool', 'strumento'])) {
        matches.add('Tool');
      }
      return matches;
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

  String _typeLabel(String value) {
    if (!_isPokemonActive) {
      return value;
    }
    final isIt = _isItalianUi();
    switch (value) {
      case 'Pokemon':
        return 'Pokemon';
      case 'Trainer':
        return isIt ? 'Allenatore' : 'Trainer';
      case 'Energy':
        return isIt ? 'Energia' : 'Energy';
      case 'Item':
        return isIt ? 'Oggetto' : 'Item';
      case 'Supporter':
        return isIt ? 'Aiuto' : 'Supporter';
      case 'Stadium':
        return isIt ? 'Stadio' : 'Stadium';
      case 'Tool':
        return isIt ? 'Strumento Pokemon' : 'Pokemon Tool';
      default:
        return value;
    }
  }

  String _deckPrimaryType(CollectionCardEntry entry) {
    if (_isPokemonDeck) {
      final types = _cardTypes(entry);
      if (types.contains('Pokemon')) {
        return 'Pokemon';
      }
      if (types.contains('Energy')) {
        return 'Energy';
      }
      if (types.contains('Trainer') ||
          types.contains('Item') ||
          types.contains('Supporter') ||
          types.contains('Stadium') ||
          types.contains('Tool')) {
        return 'Trainer';
      }
      return 'Other';
    }
    final types = _cardTypes(entry);
    for (final type in _activeDeckTypeOrder) {
      if (type == 'Other') {
        continue;
      }
      if (types.contains(type)) {
        return type;
      }
    }
    return 'Other';
  }

  String _deckSectionLabel(String typeKey, AppLocalizations l10n) {
    if (_isPokemonDeck) {
      final isIt = _isItalianUi();
      switch (typeKey) {
        case 'Pokemon':
          return 'Pokemon';
        case 'Trainer':
          return isIt ? 'Allenatore' : 'Trainer';
        case 'Energy':
          return isIt ? 'Energia' : 'Energy';
        default:
          return l10n.deckSectionOther;
      }
    }
    switch (typeKey) {
      case 'Creature':
        return l10n.deckSectionCreatures;
      case 'Instant':
        return l10n.deckSectionInstants;
      case 'Sorcery':
        return l10n.deckSectionSorceries;
      case 'Artifact':
        return l10n.deckSectionArtifacts;
      case 'Enchantment':
        return l10n.deckSectionEnchantments;
      case 'Planeswalker':
        return l10n.deckSectionPlaneswalkers;
      case 'Battle':
        return l10n.deckSectionBattles;
      case 'Land':
        return l10n.deckSectionLands;
      case 'Tribal':
        return l10n.deckSectionTribals;
      default:
        return l10n.deckSectionOther;
    }
  }

  List<_DeckSectionRow> _buildDeckSectionRows(
    List<CollectionCardEntry> cards,
    AppLocalizations l10n,
  ) {
    final grouped = <String, List<CollectionCardEntry>>{};
    for (final type in _activeDeckTypeOrder) {
      grouped[type] = <CollectionCardEntry>[];
    }
    for (final entry in cards) {
      final key = _deckPrimaryType(entry);
      grouped.putIfAbsent(key, () => <CollectionCardEntry>[]).add(entry);
    }
    final rows = <_DeckSectionRow>[];
    for (final type in _activeDeckTypeOrder) {
      final sectionCards = grouped[type] ?? const <CollectionCardEntry>[];
      if (sectionCards.isEmpty) {
        continue;
      }
      final count = _isPokemonDeck
          ? sectionCards.fold<int>(
              0,
              (sum, card) => sum + (card.quantity > 0 ? card.quantity : 0),
            )
          : sectionCards.length;
      rows.add(
        _DeckSectionRow.header(
          typeKey: type,
          label: _deckSectionLabel(type, l10n),
          count: count,
        ),
      );
      for (final entry in sectionCards) {
        rows.add(_DeckSectionRow.card(entry));
      }
    }
    return rows;
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

  String _collectorProgressLabel(CollectionCardEntry entry) {
    return entry.collectorNumber.trim();
  }

  Widget _cardImageOrPlaceholder(String? rawImageUri) {
    final imageUrl = (rawImageUri ?? '').trim();
    if (imageUrl.isEmpty) {
      return Container(
        color: const Color(0xFF201A14),
        child: const Icon(Icons.image_not_supported, color: Color(0xFFBFAE95)),
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF201A14),
          child: const Icon(
            Icons.image_not_supported,
            color: Color(0xFFBFAE95),
          ),
        );
      },
    );
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
    return '$setLabel • $progress';
  }

  (String, String) _listPriceLabels(CollectionCardEntry entry) {
    final currency = _priceCurrency.trim().toLowerCase() == 'usd'
        ? 'usd'
        : 'eur';
    final symbol = currency == 'usd' ? r'$' : '€';
    final baseValue = _normalizePriceValue(
      currency == 'usd' ? entry.priceUsd : entry.priceEur,
    );
    final foilValue = _normalizePriceValue(
      currency == 'usd' ? entry.priceUsdFoil : entry.priceEurFoil,
    );
    final baseLabel = baseValue == null ? 'N/A' : '$symbol$baseValue';
    final foilLabel = foilValue == null ? 'N/A' : '$symbol$foilValue';
    return (baseLabel, foilLabel);
  }

  bool _needsPriceRefresh(CollectionCardEntry entry) {
    final currency = _priceCurrency.trim().toLowerCase() == 'usd'
        ? 'usd'
        : 'eur';
    if (currency == 'usd') {
      return _normalizePriceValue(entry.priceUsd) == null &&
          _normalizePriceValue(entry.priceUsdFoil) == null;
    }
    return _normalizePriceValue(entry.priceEur) == null &&
        _normalizePriceValue(entry.priceEurFoil) == null;
  }

  void _refreshListPrices(List<CollectionCardEntry> entries) {
    if (!_showPrices) {
      return;
    }
    final cardIds = <String>[];
    for (final entry in entries) {
      if (!_needsPriceRefresh(entry)) {
        continue;
      }
      if (_priceRefreshQueued.contains(entry.cardId)) {
        continue;
      }
      _priceRefreshQueued.add(entry.cardId);
      cardIds.add(entry.cardId);
      if (cardIds.length >= 16) {
        break;
      }
    }
    if (cardIds.isEmpty) {
      return;
    }
    unawaited(_refreshListPricesInternal(cardIds));
  }

  Future<void> _refreshListPricesInternal(List<String> cardIds) async {
    try {
      for (final cardId in cardIds) {
        await PriceRepository.instance.ensurePricesFresh(cardId);
      }
      final lookupCollectionId =
          widget.isAllCards || widget.isWishlistCollection
          ? widget.collectionId
          : (_ownedCollectionId ?? -1);
      final refreshedEntries = await Future.wait(
        cardIds.map(
          (cardId) => ScryfallDatabase.instance.fetchCardEntryById(
            cardId,
            collectionId: lookupCollectionId,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      final refreshedById = <String, CollectionCardEntry>{};
      for (final refreshed in refreshedEntries) {
        if (refreshed != null) {
          refreshedById[refreshed.cardId] = refreshed;
        }
      }
      if (refreshedById.isEmpty) {
        return;
      }
      setState(() {
        for (var i = 0; i < _cards.length; i += 1) {
          final replacement = refreshedById[_cards[i].cardId];
          if (replacement != null) {
            _cards[i] = replacement;
          }
        }
      });
    } catch (_) {
      // Ignore refresh failures for list-row price badges.
    } finally {
      for (final cardId in cardIds) {
        _priceRefreshQueued.remove(cardId);
      }
    }
  }

  Future<void> _refreshCardEntryInPlace(String cardId) async {
    final lookupCollectionId = widget.isAllCards || widget.isWishlistCollection
        ? widget.collectionId
        : (_ownedCollectionId ?? -1);
    final refreshed = await ScryfallDatabase.instance.fetchCardEntryById(
      cardId,
      collectionId: lookupCollectionId,
    );
    if (!mounted || refreshed == null) {
      return;
    }
    setState(() {
      final index = _cards.indexWhere((item) => item.cardId == cardId);
      if (index != -1) {
        _cards[index] = refreshed;
      }
    });
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
    final minController = TextEditingController(
      text: _manaValueMin?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: _manaValueMax?.toString() ?? '',
    );
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
              const chipText = Color(0xFFE9C46A);
              const chipSelectedText = Color(0xFF1C1510);
              const chipBorder = Color(0xFF3A2F24);
              const chipBackground = Color(0xFF2A221B);
              const chipSelectedBackground = Color(0xFFE9C46A);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) {
                  final selected = isSelected(item);
                  return FilterChip(
                    label: Text(label(item)),
                    selected: selected,
                    showCheckmark: false,
                    backgroundColor: chipBackground,
                    selectedColor: chipSelectedBackground,
                    side: const BorderSide(color: chipBorder),
                    labelStyle: TextStyle(
                      color: selected ? chipSelectedText : chipText,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setSheetState(() => toggle(item)),
                  );
                }).toList(),
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
            final colorOrder = _isPokemonActive
                ? const ['G', 'R', 'L', 'U', 'B', 'F', 'D', 'W', 'C', 'M', 'N']
                : const ['W', 'U', 'B', 'R', 'G', 'C'];
            final sortedColors = availableColors.toList()
              ..sort((a, b) {
                final ai = colorOrder.indexOf(a);
                final bi = colorOrder.indexOf(b);
                if (ai == -1 && bi == -1) {
                  return a.compareTo(b);
                }
                if (ai == -1) {
                  return 1;
                }
                if (bi == -1) {
                  return -1;
                }
                return ai.compareTo(bi);
              });
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
                        _isPokemonActive
                            ? (_isItalianUi() ? 'Tipo energia' : 'Energy type')
                            : l10n.colorLabel,
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
                        (value) => _typeLabel(value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _isPokemonActive
                          ? (_isItalianUi()
                                ? 'Costo energia (attacco)'
                                : 'Attack energy cost')
                          : l10n.manaValue,
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
                        Material(
                          color: Colors.transparent,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFB85A5A), Color(0xFF7A2E2E)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () {
                                setSheetState(() {
                                  tempRarities.clear();
                                  tempSetCodes.clear();
                                  tempColors.clear();
                                  tempTypes.clear();
                                  minController.clear();
                                  maxController.clear();
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                child: Text(
                                  l10n.clear,
                                  style: const TextStyle(
                                    color: Color(0xFFF6E8D7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
    if (_isPokemonActive) {
      switch (code.toUpperCase()) {
        case 'G':
          return _isItalianUi() ? 'Erba' : 'Grass';
        case 'R':
          return _isItalianUi() ? 'Fuoco' : 'Fire';
        case 'U':
          return _isItalianUi() ? 'Acqua' : 'Water';
        case 'L':
          return _isItalianUi() ? 'Lampo' : 'Lightning';
        case 'B':
          return _isItalianUi() ? 'Psico/Oscurita' : 'Psychic/Darkness';
        case 'F':
          return _isItalianUi() ? 'Lotta' : 'Fighting';
        case 'D':
          return _isItalianUi() ? 'Drago' : 'Dragon';
        case 'W':
          return _isItalianUi() ? 'Folletto' : 'Fairy';
        case 'C':
          return _isItalianUi() ? 'Incolore' : 'Colorless';
        case 'M':
          return _isItalianUi() ? 'Metallo' : 'Metal';
        case 'N':
          return _isItalianUi() ? 'Nessuno' : 'None';
        default:
          return code.toUpperCase();
      }
    }
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

  bool _isItalianUi() {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return code.startsWith('it');
  }

  Widget _buildSearchHeader({required bool showOwnedMissing}) {
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
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
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
          if (showOwnedMissing)
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

  Future<void> _quickAddCard(
    CollectionCardEntry entry, {
    BuildContext? anchorContext,
  }) async {
    final ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null) {
      return;
    }
    if (widget.isWishlistCollection) {
      await ScryfallDatabase.instance.claimCardFromWishlist(
        wishlistCollectionId: widget.collectionId,
        ownedCollectionId: ownedCollectionId,
        cardId: entry.cardId,
      );
    } else {
      final nextQuantity = entry.quantity + 1;
      await ScryfallDatabase.instance.upsertCollectionCard(
        ownedCollectionId,
        entry.cardId,
        quantity: nextQuantity,
        foil: widget.isDeckCollection ? false : entry.foil,
        altArt: entry.altArt,
      );
    }
    if (mounted) {
      setState(() {
        _quickAddAnimating.add(entry.cardId);
      });
      if (anchorContext != null && anchorContext.mounted) {
        _showMiniToastForContext(anchorContext, '+1');
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        setState(() {
          _quickAddAnimating.remove(entry.cardId);
        });
      }
    }
    await _loadCards();
  }

  Future<void> _quickRemoveCard(
    CollectionCardEntry entry, {
    BuildContext? anchorContext,
  }) async {
    final ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null ||
        widget.isWishlistCollection ||
        entry.quantity <= 0) {
      return;
    }
    final nextQuantity = entry.quantity - 1;
    await ScryfallDatabase.instance.upsertCollectionCard(
      ownedCollectionId,
      entry.cardId,
      quantity: nextQuantity,
      foil: widget.isDeckCollection
          ? false
          : (nextQuantity == 0 ? false : entry.foil),
      altArt: nextQuantity == 0 ? false : entry.altArt,
    );
    if (mounted) {
      setState(() {
        _quickRemoveAnimating.add(entry.cardId);
      });
      if (anchorContext != null && anchorContext.mounted) {
        _showMiniToastForContext(anchorContext, '-1');
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        setState(() {
          _quickRemoveAnimating.remove(entry.cardId);
        });
      }
    }
    await _loadCards();
  }

  Future<void> _addCard(BuildContext context) async {
    if (widget.isBasicLandsCollection) {
      return;
    }
    var ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null && widget.isAllCards) {
      ownedCollectionId = await ScryfallDatabase.instance
          .ensureAllCardsCollectionId();
      if (!context.mounted) {
        return;
      }
      _ownedCollectionId = ownedCollectionId;
      _allCardsCollectionId ??= ownedCollectionId;
    }
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
    if (mode == _AddCardEntryMode.byFilter) {
      await _addCardsByFilter(context, ownedCollectionId);
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CardSearchSheet(
        initialQuery: initialQuery,
        initialSetCode: initialSetCode,
        initialCollectorNumber: initialCollectorNumber,
        selectionEnabled: false,
        ownershipCollectionId: ownedCollectionId,
        alsoAddToCollectionId: null,
        requiredFilter: _requiredSearchFilter(),
        addMissingToCollectionId: widget.isWishlistCollection
            ? widget.collectionId
            : null,
        showFilterButton: false,
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadCards();
  }

  CollectionFilter _mergeFilters(
    CollectionFilter base,
    CollectionFilter? required,
  ) {
    if (required == null) {
      return base;
    }
    return CollectionFilter(
      name: base.name ?? required.name,
      artist: base.artist ?? required.artist,
      manaMin: base.manaMin ?? required.manaMin,
      manaMax: base.manaMax ?? required.manaMax,
      format: base.format ?? required.format,
      sets: {...required.sets, ...base.sets},
      rarities: {...required.rarities, ...base.rarities},
      colors: {...required.colors, ...base.colors},
      types: {...required.types, ...base.types},
    );
  }

  Future<List<String>> _collectCardIdsForFilter(
    CollectionFilter filter, {
    int pageSize = 400,
  }) async {
    final cardIds = <String>{};
    var offset = 0;
    while (true) {
      final batch = await ScryfallDatabase.instance.fetchFilteredCardPreviews(
        filter,
        limit: pageSize,
        offset: offset,
      );
      if (batch.isEmpty) {
        break;
      }
      for (final card in batch) {
        cardIds.add(card.id);
      }
      if (batch.length < pageSize) {
        break;
      }
      offset += batch.length;
    }
    return cardIds.toList(growable: false);
  }

  Future<void> _addCardsByFilter(
    BuildContext context,
    int ownedCollectionId,
  ) async {
    final title = _isItalianUi()
        ? 'Aggiungi piu carte da filtro'
        : 'Add multiple cards by filter';
    final selectedFilter = await Navigator.of(context).push<CollectionFilter>(
      MaterialPageRoute(
        builder: (_) => _CollectionFilterBuilderPage(
          name: title,
          submitLabel: _isItalianUi() ? 'Aggiungi' : 'Add',
        ),
      ),
    );
    if (!context.mounted || selectedFilter == null) {
      return;
    }
    final filter = _mergeFilters(selectedFilter, _requiredSearchFilter());
    if (!context.mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    List<String> cardIds = const [];
    try {
      cardIds = await _collectCardIdsForFilter(filter);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      if (cardIds.isEmpty) {
        showAppSnackBar(context, AppLocalizations.of(context)!.noResultsFound);
        return;
      }
      await ScryfallDatabase.instance.addCardsToCollection(
        ownedCollectionId,
        cardIds,
      );
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.addedCards(cardIds.length),
      );
      await _loadCards();
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.downloadFailedGeneric,
        );
      }
    }
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
                title: Text(l10n.addByNameTitle),
                subtitle: Text(l10n.addByNameSubtitle),
                onTap: () =>
                    Navigator.of(context).pop(_AddCardEntryMode.byName),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: Text(l10n.addByScanTitle),
                subtitle: Text(l10n.addByScanSubtitle),
                onTap: () =>
                    Navigator.of(context).pop(_AddCardEntryMode.byScan),
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text(
                  _isItalianUi()
                      ? 'Aggiungi piu carte da filtro'
                      : 'Add multiple cards by filter',
                ),
                subtitle: Text(
                  _isItalianUi()
                      ? 'Seleziona filtri e aggiungi tutte le carte trovate'
                      : 'Apply filters and add all matching cards',
                ),
                onTap: () =>
                    Navigator.of(context).pop(_AddCardEntryMode.byFilter),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addCardByScan(
    BuildContext context,
    int ownedCollectionId,
  ) async {
    final canStart = await _canStartScanForCollection();
    if (!canStart || !context.mounted) {
      return;
    }
    final recognizedText = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _CardScannerPage()));
    if (!context.mounted || recognizedText == null) {
      return;
    }
    final consumed = await _consumeFreeScanForCollection();
    if (!consumed || !context.mounted) {
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
        AppLocalizations.of(context)!.noCardTextRecognizedTryLightFocus,
      );
      return;
    }
    final hasCardName = ocrSeed.cardName?.trim().isNotEmpty ?? false;
    final refinedSeed = hasCardName
        // Fast path: when OCR already has a card name, open printings picker
        // immediately instead of waiting for network fallbacks.
        ? ocrSeed
        : await _refineOcrSeedForScan(ocrSeed);
    if (!context.mounted) {
      return;
    }
    final resolvedSeed = await _resolveSeedWithPrintingPickerForScan(
      context,
      refinedSeed,
    );
    if (!context.mounted) {
      return;
    }
    await _addCardByName(
      context,
      ownedCollectionId,
      initialQuery: resolvedSeed.query,
      initialSetCode: resolvedSeed.setCode,
      initialCollectorNumber: resolvedSeed.collectorNumber,
    );
  }

  Future<bool> _canStartScanForCollection() async {
    if (PurchaseManager.instance.isPro) {
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
    await _showScanLimitDialogForCollection();
    return false;
  }

  Future<bool> _consumeFreeScanForCollection() async {
    if (PurchaseManager.instance.isPro) {
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
    await _showScanLimitDialogForCollection();
    return false;
  }

  Future<void> _showScanLimitDialogForCollection() async {
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

  Future<_OcrSearchSeed> _resolveSeedWithPrintingPickerForScan(
    BuildContext context,
    _OcrSearchSeed seed,
  ) async {
    final cardName = seed.cardName?.trim();
    if (cardName == null || cardName.isEmpty) {
      return seed;
    }
    final picked = await _pickCardPrintingForName(
      context,
      cardName,
      preferredSetCode: seed.setCode,
      preferredCollectorNumber: seed.collectorNumber,
    );
    if (picked == null) {
      return _OcrSearchSeed(
        query: cardName,
        cardName: cardName,
        setCode: seed.setCode,
        collectorNumber: seed.collectorNumber,
      );
    }
    return _OcrSearchSeed(
      query: picked.name,
      cardName: picked.name,
      setCode: picked.setCode.trim().isEmpty
          ? null
          : picked.setCode.trim().toLowerCase(),
      collectorNumber: picked.collectorNumber.trim().isEmpty
          ? null
          : picked.collectorNumber.trim().toLowerCase(),
    );
  }

  Future<Set<String>> _fetchKnownSetCodesForScan() async {
    final cached = _cachedKnownSetCodesForScan;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final sets = await ScryfallDatabase.instance.fetchAvailableSets();
    final known = sets
        .map((set) => set.code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    _cachedKnownSetCodesForScan = known;
    return known;
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
          collectorNumber = _pickBetterCollectorNumberForScan(
            collectorNumber,
            fromNext,
          );
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
    final useCollectorQuery =
        collectorNumber != null &&
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
    final fallbackName = seed.cardName?.trim();
    if (query.isEmpty) {
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final onlineByName = await _tryOnlineCardFallbackByNameForScan(
          fallbackName,
        );
        if (onlineByName != null) {
          return onlineByName;
        }
      }
      return seed;
    }
    if (setCode == null || setCode.isEmpty) {
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final onlineByName = await _tryOnlineCardFallbackByNameForScan(
          fallbackName,
        );
        if (onlineByName != null) {
          return onlineByName;
        }
      }
      return seed;
    }
    final strictCount = await ScryfallDatabase.instance
        .countCardsForFilterWithSearch(
          CollectionFilter(sets: {setCode}),
          searchQuery: query,
        );
    if (strictCount > 0) {
      if (fallbackName != null && fallbackName.isNotEmpty) {
        final nameInSetCount = await ScryfallDatabase.instance
            .countCardsForFilterWithSearch(
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
    final onlineSeed = await _tryOnlineCardFallbackForScan(seed);
    if (onlineSeed != null) {
      return onlineSeed;
    }
    if (fallbackName != null && fallbackName.isNotEmpty) {
      final onlineByName = await _tryOnlineCardFallbackByNameForScan(
        fallbackName,
      );
      if (onlineByName != null) {
        return onlineByName;
      }
    }
    if (fallbackName != null && fallbackName.isNotEmpty) {
      final nameInSetCount = await ScryfallDatabase.instance
          .countCardsForFilterWithSearch(
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

  Future<_OcrSearchSeed?> _tryOnlineCardFallbackByNameForScan(
    String cardName,
  ) async {
    final name = cardName.trim();
    if (name.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse(
        'https://api.scryfall.com/cards/named?exact=${Uri.encodeQueryComponent(name)}',
      );
      final response = await ScryfallApiClient.instance.get(
        uri,
        timeout: const Duration(seconds: 4),
        maxRetries: 2,
      );
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
      final fetchedCollector = (payload['collector_number'] as String?)
          ?.trim()
          .toLowerCase();
      return _OcrSearchSeed(
        query: (fetchedName != null && fetchedName.isNotEmpty)
            ? fetchedName
            : name,
        cardName: fetchedName ?? name,
        setCode: fetchedSet?.isNotEmpty == true ? fetchedSet : null,
        collectorNumber: fetchedCollector?.isNotEmpty == true
            ? fetchedCollector
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_OcrSearchSeed?> _tryOnlineCardFallbackForScan(
    _OcrSearchSeed seed,
  ) async {
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
      final response = await ScryfallApiClient.instance.get(
        uri,
        timeout: const Duration(seconds: 4),
        maxRetries: 2,
      );
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
      final fetchedCollector = (payload['collector_number'] as String?)
          ?.trim()
          .toLowerCase();
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
      final oracleHits = wordsList
          .where((w) => oracleLikeWords.contains(w))
          .length;
      final digits = RegExp(r'\d').allMatches(normalized).length;
      if (digits > normalized.length * 0.25) {
        continue;
      }
      final digitPenalty = digits * 2;
      final oraclePenalty = oracleHits * 5;
      final longSentencePenalty = wordsList.length >= 6 ? 4 : 0;
      final topBonus = (8 - i);
      final score =
          (normalized.length.clamp(0, 30)) +
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
    final setCollectorRegex = RegExp(
      r'\b([A-Z0-9]{2,5})\s+([0-9]{1,5}[A-Z]?)\b',
    );
    final collectorSlashRegex = RegExp(
      r'\b([0-9]{1,5}[A-Z]?)\s*/\s*[0-9]{1,5}\b',
    );
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
        collectorNumber ??= _normalizeCollectorNumberForScan(
          direct.group(2) ?? '',
        );
      }
      final slash = collectorSlashRegex.firstMatch(upper);
      if (slash != null) {
        collectorNumber ??= _normalizeCollectorNumberForScan(
          slash.group(1) ?? '',
        );
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

  String? _pickBetterCollectorNumberForScan(
    String? current,
    String? candidate,
  ) {
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

  List<String> _manaTokens(String manaCost) {
    final source = manaCost.trim();
    if (source.isEmpty) {
      return const [];
    }
    final matches = RegExp(r'\{([^}]+)\}').allMatches(source).toList();
    if (matches.isEmpty) {
      return [source];
    }
    return matches
        .map((match) => (match.group(1) ?? '').trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  Color _manaPipColor(String token) {
    switch (token) {
      case 'W':
        return const Color(0xFFF3E6B2);
      case 'U':
        return const Color(0xFF7DB7FF);
      case 'B':
        return const Color(0xFF5C5C66);
      case 'R':
        return const Color(0xFFE27A5E);
      case 'G':
        return const Color(0xFF74B77F);
      case 'C':
        return const Color(0xFF9AA2AD);
      default:
        if (RegExp(r'^\d+$').hasMatch(token)) {
          return const Color(0xFF8F949C);
        }
        return const Color(0xFF7A8088);
    }
  }

  Widget _buildManaCostPips(String manaCost) {
    final tokens = _manaTokens(manaCost);
    if (tokens.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tokens
          .map((token) {
            final color = _manaPipColor(token);
            final isColoredSingle = const {
              'W',
              'U',
              'B',
              'R',
              'G',
            }.contains(token);
            final label = isColoredSingle ? '' : token;
            return Container(
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3A2F24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: label.isEmpty
                  ? null
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF1A1714),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _showCardDetails(CollectionCardEntry entry) async {
    var detailEntry = entry;
    final lookupCollectionId = widget.isAllCards || widget.isWishlistCollection
        ? widget.collectionId
        : (_ownedCollectionId ?? -1);
    try {
      await PriceRepository.instance.ensurePricesFresh(entry.cardId);
      final refreshed = await ScryfallDatabase.instance.fetchCardEntryById(
        entry.cardId,
        collectionId: lookupCollectionId,
      );
      if (refreshed != null) {
        detailEntry = refreshed;
        if (mounted) {
          final index = _cards.indexWhere(
            (item) => item.cardId == entry.cardId,
          );
          if (index != -1) {
            setState(() {
              _cards[index] = refreshed;
            });
          }
        }
      }
    } catch (_) {
      // Keep showing available card details even if price refresh fails.
    }
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final priceCurrency = await AppSettings.loadPriceCurrency();
    List<String> legalFormats = const [];
    try {
      legalFormats = await ScryfallDatabase.instance.fetchCardLegalFormats(
        detailEntry.cardId,
      );
    } catch (_) {
      legalFormats = const [];
    }
    final details = _parseCardDetails(
      l10n,
      detailEntry,
      priceCurrency,
      legalFormats,
    );
    final typeLine = detailEntry.typeLine.trim();
    final manaCost = detailEntry.manaCost.trim();
    final oracleText = detailEntry.oracleText.trim();
    final power = detailEntry.power.trim();
    final toughness = detailEntry.toughness.trim();
    final loyalty = detailEntry.loyalty.trim();
    final stats = _joinStats(power, toughness);
    final addButtonKey = GlobalKey();
    var showCheck = false;
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handleAdd() async {
              await _quickAddCard(
                entry,
                anchorContext: addButtonKey.currentContext,
              );
              if (!mounted) {
                return;
              }
              _showMiniToast(addButtonKey, '+1');
              setModalState(() {
                showCheck = true;
              });
              await Future<void>.delayed(const Duration(milliseconds: 700));
              if (!mounted) {
                return;
              }
              setModalState(() {
                showCheck = false;
              });
            }

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
                          if (manaCost.isNotEmpty) _buildManaCostPips(manaCost),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              detailEntry.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          FilledButton(
                            key: addButtonKey,
                            onPressed: handleAdd,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  ),
                              child: showCheck
                                  ? const Icon(
                                      Icons.check,
                                      key: ValueKey('check'),
                                    )
                                  : const Icon(Icons.add, key: ValueKey('add')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildSetIcon(detailEntry.setCode, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _subtitleLabel(detailEntry),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFFBFAE95)),
                          ),
                        ],
                      ),
                      if (typeLine.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          typeLine,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFE3D4B8)),
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
                      if ((entry.imageUri ?? '').trim().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            entry.imageUri!.trim(),
                            fit: BoxFit.contain,
                          ),
                        ),
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
      },
    );
  }

  void _showMiniToast(GlobalKey targetKey, String label) {
    final overlay = Overlay.of(context);
    final box = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx + (size.width / 2) - 18,
          top: position.dy - 28,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE9C46A),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF1C1510),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      entry.remove();
    });
  }

  void _showMiniToastForContext(BuildContext targetContext, String label) {
    final overlay = Overlay.of(context);
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx + (size.width / 2) - 18,
          top: position.dy - 28,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE9C46A),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF1C1510),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      entry.remove();
    });
  }

  List<_CardDetail> _parseCardDetails(
    AppLocalizations l10n,
    CollectionCardEntry entry,
    String priceCurrency,
    List<String> legalFormats,
  ) {
    final setLabel = entry.setName.isNotEmpty
        ? entry.setName
        : entry.setCode.toUpperCase();
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
    final legalFormatLabels = _normalizeFormatLabels(legalFormats);
    if (legalFormatLabels.isNotEmpty) {
      add(l10n.detailFormat, legalFormatLabels.join(', '));
    } else {
      final deckFormat = widget.filter?.format?.trim().toLowerCase();
      if (widget.isDeckCollection &&
          deckFormat != null &&
          deckFormat.isNotEmpty) {
        add(l10n.detailFormat, deckFormatLabel(deckFormat));
      }
    }
    final normalizedCurrency = priceCurrency.trim().toLowerCase();
    if (normalizedCurrency == 'usd') {
      add('Price (USD)', _displayUsdPrice(entry));
    } else {
      add('Price (EUR)', _displayEurPrice(entry));
    }
    return details.where((item) => item.value.isNotEmpty).toList();
  }

  String _displayEurPrice(CollectionCardEntry entry) {
    final base = _normalizePriceValue(entry.priceEur);
    final foil = _normalizePriceValue(entry.priceEurFoil);
    final selected = entry.foil ? (foil ?? base) : base;
    if (selected == null) {
      return '—';
    }
    return 'EUR $selected';
  }

  String _displayUsdPrice(CollectionCardEntry entry) {
    final base = _normalizePriceValue(entry.priceUsd);
    final foil = _normalizePriceValue(entry.priceUsdFoil);
    final selected = entry.foil ? (foil ?? base) : base;
    if (selected == null) {
      return '—';
    }
    return 'USD $selected';
  }

  String? _normalizePriceValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  List<String> _normalizeFormatLabels(List<String> rawFormats) {
    final normalized = <String>{};
    for (final item in rawFormats) {
      final value = item.trim().toLowerCase();
      if (value.isNotEmpty) {
        normalized.add(value);
      }
    }
    final values = normalized.toList();
    values.sort((a, b) {
      final ai = kSupportedDeckFormats.indexOf(a);
      final bi = kSupportedDeckFormats.indexOf(b);
      if (ai == -1 && bi == -1) {
        return a.compareTo(b);
      }
      if (ai == -1) {
        return 1;
      }
      if (bi == -1) {
        return -1;
      }
      return ai.compareTo(bi);
    });
    return values.map(deckFormatLabel).toList();
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
                  child: _DetailRow(label: item.label, value: item.value),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _showCardActions(CollectionCardEntry entry) async {
    final ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null &&
        (widget.isAllCards || _isFilterCollection)) {
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
        final quantityController = TextEditingController(
          text: entry.quantity.toString(),
        );
        var foil = entry.foil;
        final altArt = entry.altArt;
        final isFilterCollection = _isFilterCollection;
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBFAE95),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.quantityLabel),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          if (isFilterCollection) {
                            await ScryfallDatabase.instance
                                .upsertCollectionCard(
                                  ownedCollectionId!,
                                  entry.cardId,
                                  quantity: 0,
                                  foil: foil,
                                  altArt: altArt,
                                );
                          } else if (widget.isWishlistCollection) {
                            await ScryfallDatabase.instance
                                .deleteCollectionCard(
                                  widget.collectionId,
                                  entry.cardId,
                                );
                          } else {
                            await ScryfallDatabase.instance
                                .deleteCollectionCard(
                                  ownedCollectionId!,
                                  entry.cardId,
                                );
                          }
                          if (!context.mounted) {
                            return;
                          }
                          await _refreshCardEntryInPlace(entry.cardId);
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
                              : widget.isWishlistCollection
                              ? 0
                              : (parsed < 1 ? 1 : parsed);
                          final targetCollectionId = widget.isWishlistCollection
                              ? widget.collectionId
                              : ownedCollectionId!;
                          await ScryfallDatabase.instance.upsertCollectionCard(
                            targetCollectionId,
                            entry.cardId,
                            quantity: quantity,
                            foil: widget.isWishlistCollection ? false : foil,
                            altArt: widget.isWishlistCollection
                                ? false
                                : altArt,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          await _refreshCardEntryInPlace(entry.cardId);
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

  Widget _buildDeckSectionHeader(
    AppLocalizations l10n, {
    required String label,
    required int count,
    required bool first,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 24, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9C46A),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFEFE7D8),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              Text(
                l10n.cardCount(count),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD2C2A9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1.4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [Color(0xFFE9C46A), Color(0x553A2F24)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DeckSection> _buildDeckSections(
    List<CollectionCardEntry> cards,
    AppLocalizations l10n,
  ) {
    final grouped = <String, List<CollectionCardEntry>>{};
    for (final type in _activeDeckTypeOrder) {
      grouped[type] = <CollectionCardEntry>[];
    }
    for (final entry in cards) {
      final key = _deckPrimaryType(entry);
      grouped.putIfAbsent(key, () => <CollectionCardEntry>[]).add(entry);
    }
    final sections = <_DeckSection>[];
    for (final type in _activeDeckTypeOrder) {
      final sectionCards = grouped[type] ?? const <CollectionCardEntry>[];
      if (sectionCards.isEmpty) {
        continue;
      }
      sections.add(
        _DeckSection(
          typeKey: type,
          label: _deckSectionLabel(type, l10n),
          cards: sectionCards,
        ),
      );
    }
    return sections;
  }

  _DeckStats _buildDeckStats(List<CollectionCardEntry> cards) {
    var total = 0;
    var creatures = 0;
    var lands = 0;
    var other = 0;
    for (final entry in cards) {
      final qty = entry.quantity > 0 ? entry.quantity : 0;
      if (qty == 0) {
        continue;
      }
      total += qty;
      final types = _cardTypes(entry);
      if (types.contains('Creature')) {
        creatures += qty;
      } else if (types.contains('Land')) {
        lands += qty;
      } else {
        other += qty;
      }
    }
    return _DeckStats(
      total: total,
      creatures: creatures,
      lands: lands,
      other: other,
    );
  }

  bool _isPokemonBasicEnergy(CollectionCardEntry entry) {
    final types = _cardTypes(entry);
    if (!types.contains('Energy')) {
      return false;
    }
    final normalized = entry.typeLine.toLowerCase().replaceAll(
      'pokÃ©mon',
      'pokemon',
    );
    return normalized.contains('basic');
  }

  _PokemonDeckStats _buildPokemonDeckStats(List<CollectionCardEntry> cards) {
    var total = 0;
    var pokemon = 0;
    var trainer = 0;
    var energy = 0;
    var basicPokemon = 0;
    final quantitiesByName = <String, int>{};
    final basicEnergyNames = <String>{};
    for (final entry in cards) {
      final qty = entry.quantity > 0 ? entry.quantity : 0;
      if (qty == 0) {
        continue;
      }
      total += qty;
      final types = _cardTypes(entry);
      if (types.contains('Pokemon')) {
        pokemon += qty;
        final normalized = entry.typeLine.toLowerCase().replaceAll(
          'pokÃ©mon',
          'pokemon',
        );
        if (normalized.contains('basic')) {
          basicPokemon += qty;
        }
      } else if (types.contains('Energy')) {
        energy += qty;
      } else if (types.contains('Trainer') ||
          types.contains('Item') ||
          types.contains('Supporter') ||
          types.contains('Stadium') ||
          types.contains('Tool')) {
        trainer += qty;
      } else {
        trainer += qty;
      }
      final normalizedName = entry.name.trim().toLowerCase();
      if (normalizedName.isNotEmpty) {
        quantitiesByName[normalizedName] =
            (quantitiesByName[normalizedName] ?? 0) + qty;
        if (_isPokemonBasicEnergy(entry)) {
          basicEnergyNames.add(normalizedName);
        }
      }
    }
    var overLimitNames = 0;
    quantitiesByName.forEach((name, qty) {
      if (basicEnergyNames.contains(name)) {
        return;
      }
      if (qty > 4) {
        overLimitNames += 1;
      }
    });
    return _PokemonDeckStats(
      total: total,
      pokemon: pokemon,
      trainer: trainer,
      energy: energy,
      basicPokemon: basicPokemon,
      overLimitNames: overLimitNames,
    );
  }

  Widget _buildDeckStatsCard(
    List<CollectionCardEntry> cards,
    AppLocalizations l10n,
  ) {
    if (_isPokemonDeck) {
      return _buildPokemonDeckStatsCard(cards, l10n);
    }
    final stats = _buildDeckStats(cards);
    final basicLandCounts = _basicLandCountsForCards(cards);
    final languageCode = Localizations.localeOf(context).languageCode;
    final totalLabel = languageCode.toLowerCase().startsWith('it')
        ? 'Totale'
        : 'Total';
    Widget statCell(String label, int value) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0x221E1713),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x2FE9C46A)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFE9C46A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD2C2A9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget basicLandCell(String mana) {
      final count = basicLandCounts[mana] ?? 0;
      final manaColor = _basicLandColor(mana);
      return Container(
        decoration: BoxDecoration(
          color: manaColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: manaColor.withValues(alpha: 0.55)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => _changeBasicLandInDeck(mana, 1),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.add,
                  size: 14,
                  color: manaColor.withValues(alpha: 0.95),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFFF5ECD9),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            InkWell(
              onTap: () => _changeBasicLandInDeck(mana, -1),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.remove,
                  size: 14,
                  color: manaColor.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4AE9C46A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 8,
            childAspectRatio: 3.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              statCell(totalLabel, stats.total),
              statCell(l10n.deckSectionCreatures, stats.creatures),
              statCell(l10n.deckSectionLands, stats.lands),
              statCell(l10n.deckSectionOther, stats.other),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.basicLandsLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFD2C2A9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _basicLandManaOrder.map(basicLandCell).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPokemonDeckStatsCard(
    List<CollectionCardEntry> cards,
    AppLocalizations l10n,
  ) {
    final stats = _buildPokemonDeckStats(cards);
    final isIt = _isItalianUi();
    Widget statCell(String label, int value) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0x221E1713),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x2FE9C46A)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFE9C46A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD2C2A9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget ruleRow({
      required bool ok,
      required String okLabel,
      required String failLabel,
    }) {
      final bg = ok ? const Color(0x2A4BB26A) : const Color(0x4AA4463F);
      final border = ok ? const Color(0x884BB26A) : const Color(0x88D06D5F);
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(
          ok ? okLabel : failLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFFEFE7D8),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final totalOk = stats.total == 60;
    final hasBasicPokemon = stats.basicPokemon > 0;
    final copyLimitOk = stats.overLimitNames == 0;
    final totalFailLabel = stats.total < 60
        ? (isIt
              ? 'Mancano ${60 - stats.total} carte per arrivare a 60.'
              : 'Add ${60 - stats.total} cards to reach 60.')
        : (isIt
              ? 'Rimuovi ${stats.total - 60} carte per tornare a 60.'
              : 'Remove ${stats.total - 60} cards to get back to 60.');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4AE9C46A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 8,
            childAspectRatio: 3.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              statCell(isIt ? 'Totale' : 'Total', stats.total),
              statCell('Pokemon', stats.pokemon),
              statCell(isIt ? 'Allenatore' : 'Trainer', stats.trainer),
              statCell(isIt ? 'Energie' : 'Energy', stats.energy),
            ],
          ),
          ruleRow(
            ok: totalOk,
            okLabel: isIt ? 'Regola 60 carte: OK' : '60-card rule: OK',
            failLabel: totalFailLabel,
          ),
          ruleRow(
            ok: hasBasicPokemon,
            okLabel: isIt
                ? 'Pokemon Base presente: OK'
                : 'Basic Pokemon present: OK',
            failLabel: isIt
                ? 'Manca almeno 1 Pokemon Base.'
                : 'At least 1 Basic Pokemon is required.',
          ),
          ruleRow(
            ok: copyLimitOk,
            okLabel: isIt ? 'Limite copie: OK' : 'Copy limit: OK',
            failLabel: isIt
                ? '${stats.overLimitNames} carte superano 4 copie (escluse Energie Base).'
                : '${stats.overLimitNames} card names exceed 4 copies (Basic Energy excluded).',
          ),
        ],
      ),
    );
  }

  Widget _buildDeckTypeListView(
    List<CollectionCardEntry> visibleCards,
    AppLocalizations l10n,
  ) {
    final rows = _buildDeckSectionRows(visibleCards, l10n);
    final sideRows = _buildDeckSectionRows(_sideboardCards, l10n);
    final children = <Widget>[_buildDeckStatsCard(visibleCards, l10n)];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      final row = rows[rowIndex];
      if (row.isHeader) {
        final previous = rowIndex > 0 ? rows[rowIndex - 1] : null;
        children.add(
          _buildDeckSectionHeader(
            l10n,
            label: row.label!,
            count: row.count!,
            first: rowIndex == 0 || previous?.isHeader == true,
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _buildListCardTile(row.entry!, l10n),
          ),
        );
      }
    }
    if (_sideboardCards.isNotEmpty) {
      children.add(
        _buildDeckSectionHeader(
          l10n,
          label: _sideboardLabel(),
          count: _sideboardCards.length,
          first: false,
        ),
      );
      for (var rowIndex = 0; rowIndex < sideRows.length; rowIndex += 1) {
        final row = sideRows[rowIndex];
        if (row.isHeader) {
          children.add(
            _buildDeckSectionHeader(
              l10n,
              label: row.label!,
              count: row.count!,
              first: false,
            ),
          );
        } else {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildReadOnlyListCardTile(row.entry!, l10n),
            ),
          );
        }
      }
    }
    if (_loadingMore) {
      children.add(_buildLoadMoreIndicator());
    }
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      children: children,
    );
  }

  Widget _buildListCardTile(CollectionCardEntry entry, AppLocalizations l10n) {
    final isMissing =
        _isMissingStyleCollection &&
        !widget.isWishlistCollection &&
        entry.quantity == 0;
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
        if (widget.isDeckCollection) {
          _showMainboardCardActions(entry, l10n);
          return;
        }
        _showCardActions(entry);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_showPrices)
            Positioned(
              left: 16,
              right: (_isMissingStyleCollection || widget.isAllCards)
                  ? 132
                  : 122,
              bottom: -6,
              child: Opacity(
                opacity: isMissing ? 0.6 : 1.0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 2),
                  decoration: _priceBadgeDecoration(context, entry),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Builder(
                      builder: (context) {
                        final labels = _listPriceLabels(entry);
                        final accentStyle = Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: const Color(0xFFE9C46A));
                        final valueStyle = accentStyle?.copyWith(
                          color: const Color(0xFFEFE7D8),
                          fontWeight: FontWeight.w500,
                        );
                        return Text(
                          '${l10n.priceLabel(labels.$1)} • ${l10n.foilLabel} ${labels.$2}',
                          style: valueStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          Opacity(
            opacity: isMissing ? 0.6 : 1.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: _cardTintDecoration(context, entry),
              child: SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildSetIcon(entry.setCode, size: 60)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Builder(
                            builder: (context) {
                              final setLabel = _setLabelForEntry(entry);
                              final progress = _collectorProgressLabel(entry);
                              final hasRarity = entry.rarity.trim().isNotEmpty;
                              final leftLabel = setLabel.isNotEmpty
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
                                            color: const Color(0xFFBFAE95),
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (progress.isNotEmpty &&
                                      setLabel.isNotEmpty) ...[
                                    Text(
                                      progress,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFFBFAE95),
                                          ),
                                    ),
                                  ],
                                  if (hasRarity) ...[
                                    const SizedBox(width: 6),
                                    _raritySquare(entry.rarity),
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
              ),
            ),
          ),
          if (_isMissingStyleCollection || widget.isAllCards)
            Positioned(
              right: 12,
              top: 10,
              height: 80,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMissing) ...[
                      _buildBadge(l10n.missingLabel, inverted: true),
                      const SizedBox(width: 6),
                    ],
                    Builder(
                      builder: (buttonContext) {
                        final isAnimating = _quickAddAnimating.contains(
                          entry.cardId,
                        );
                        return IconButton(
                          tooltip: l10n.addOne,
                          iconSize: 36,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                            child: isAnimating
                                ? const Icon(
                                    Icons.check_circle,
                                    key: ValueKey('check'),
                                    size: 36,
                                  )
                                : const Icon(
                                    Icons.add_circle,
                                    key: ValueKey('add'),
                                    size: 36,
                                  ),
                          ),
                          color: const Color(0xFFE9C46A),
                          onPressed: _selectionMode
                              ? null
                              : () => _quickAddCard(
                                  entry,
                                  anchorContext: buttonContext,
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (_selectionMode || _isSelected(entry))
            Positioned(
              top: 6,
              left: 6,
              child: _buildSelectionBadge(_isSelected(entry)),
            ),
          if (entry.foil || entry.altArt)
            Positioned(
              top: isMissing ? 42 : 6,
              right: hasCornerQuantity ? 42 : 8,
              child: Row(
                children: [
                  if (entry.foil) _statusMiniBadge(icon: Icons.star),
                  if (entry.foil && entry.altArt) const SizedBox(width: 6),
                  if (entry.altArt) _statusMiniBadge(icon: Icons.brush),
                ],
              ),
            ),
          if (hasCornerQuantity)
            Positioned(
              top: 0,
              right: 0,
              child: _cornerQuantityBadge(l10n, entry.quantity),
            ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyListCardTile(
    CollectionCardEntry entry,
    AppLocalizations l10n,
  ) {
    return GestureDetector(
      onTap: () => _showCardDetails(entry),
      onLongPress: () => _showSideboardCardActions(entry, l10n),
      child: AbsorbPointer(
        absorbing: true,
        child: _buildListCardTile(entry, l10n),
      ),
    );
  }

  Widget _buildGalleryCardTile(
    CollectionCardEntry entry,
    AppLocalizations l10n,
  ) {
    final isMissing =
        _isMissingStyleCollection &&
        !widget.isWishlistCollection &&
        entry.quantity == 0;
    final hasCornerQuantity = entry.quantity > 1;
    final showQuickAdd =
        widget.isWishlistCollection ||
        widget.isAllCards ||
        (!isMissing && entry.quantity > 0);
    final showMissingQuickAdd = isMissing && _ownedCollectionId != null;
    final showQuickRemove = !widget.isWishlistCollection && entry.quantity > 0;
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
        if (widget.isDeckCollection) {
          _showMainboardCardActions(entry, l10n);
          return;
        }
        _showCardActions(entry);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_showPrices)
            Positioned(
              left: 10,
              right: 10,
              bottom: -6,
              child: Opacity(
                opacity: isMissing ? 0.6 : 1.0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 9, 14, 3),
                  decoration: _priceBadgeDecoration(context, entry),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Builder(
                      builder: (context) {
                        final labels = _listPriceLabels(entry);
                        final accentStyle = Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: const Color(0xFFE9C46A));
                        final valueStyle = accentStyle?.copyWith(
                          color: const Color(0xFFEFE7D8),
                          fontWeight: FontWeight.w500,
                        );
                        final selectedPrice = entry.foil
                            ? labels.$2
                            : labels.$1;
                        return SizedBox(
                          width: double.infinity,
                          child: Text(
                            l10n.priceLabel(selectedPrice),
                            style: valueStyle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          Opacity(
            opacity: isMissing ? 0.6 : 1.0,
            child: Container(
              margin: EdgeInsets.only(bottom: _showPrices ? 18 : 0),
              decoration: _cardTintDecoration(context, entry),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _cardImageOrPlaceholder(entry.imageUri),
                          if (entry.altArt)
                            Positioned(
                              top: 6,
                              right: hasCornerQuantity ? 42 : 8,
                              child: _statusMiniBadge(icon: Icons.brush),
                            ),
                          if (entry.foil && !widget.isDeckCollection)
                            const Positioned(
                              top: 30,
                              right: 2,
                              child: Icon(
                                Icons.star,
                                size: 32,
                                color: Color(0xFFE9C46A),
                              ),
                            ),
                          if (showQuickRemove)
                            Positioned(
                              bottom: 2,
                              left: 2,
                              child: Builder(
                                builder: (buttonContext) {
                                  final isAnimating = _quickRemoveAnimating
                                      .contains(entry.cardId);
                                  return IconButton(
                                    tooltip: '-1',
                                    iconSize: 32,
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          ),
                                      child: isAnimating
                                          ? const Icon(
                                              Icons.check_circle,
                                              key: ValueKey('check'),
                                              size: 32,
                                            )
                                          : const Icon(
                                              Icons.remove_circle_outline,
                                              key: ValueKey('remove'),
                                              size: 32,
                                            ),
                                    ),
                                    color: const Color(0xFFE9C46A),
                                    onPressed: _selectionMode
                                        ? null
                                        : () => _quickRemoveCard(
                                            entry,
                                            anchorContext: buttonContext,
                                          ),
                                  );
                                },
                              ),
                            ),
                          if (showMissingQuickAdd)
                            Positioned(
                              bottom: 2,
                              left: 2,
                              child: Builder(
                                builder: (buttonContext) {
                                  final isAnimating = _quickAddAnimating
                                      .contains(entry.cardId);
                                  return IconButton(
                                    tooltip: l10n.addOne,
                                    iconSize: 32,
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          ),
                                      child: isAnimating
                                          ? const Icon(
                                              Icons.check_circle,
                                              key: ValueKey(
                                                'check_missing_add',
                                              ),
                                              size: 32,
                                            )
                                          : const Icon(
                                              Icons.add_circle,
                                              key: ValueKey('missing_add'),
                                              size: 32,
                                            ),
                                    ),
                                    color: const Color(0xFFE9C46A),
                                    onPressed: _selectionMode
                                        ? null
                                        : () => _quickAddCard(
                                            entry,
                                            anchorContext: buttonContext,
                                          ),
                                  );
                                },
                              ),
                            ),
                          if (showQuickAdd)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Builder(
                                builder: (buttonContext) {
                                  final isAnimating = _quickAddAnimating
                                      .contains(entry.cardId);
                                  return IconButton(
                                    tooltip: l10n.addOne,
                                    iconSize: 32,
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          ),
                                      child: isAnimating
                                          ? const Icon(
                                              Icons.check_circle,
                                              key: ValueKey('check'),
                                              size: 32,
                                            )
                                          : const Icon(
                                              Icons.add_circle,
                                              key: ValueKey('add'),
                                              size: 32,
                                            ),
                                    ),
                                    color: const Color(0xFFE9C46A),
                                    onPressed: _selectionMode
                                        ? null
                                        : () => _quickAddCard(
                                            entry,
                                            anchorContext: buttonContext,
                                          ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 38,
                          child: Text(
                            entry.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildSetIcon(entry.setCode, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _setLabelForEntry(entry),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFFBFAE95)),
                              ),
                            ),
                            if (entry.rarity.trim().isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _raritySquare(entry.rarity),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMissing)
            Align(
              alignment: const Alignment(1, 0.0),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildBadge(l10n.missingLabel, inverted: true),
              ),
            ),
          if (_selectionMode || _isSelected(entry))
            Positioned(
              top: 8,
              left: 8,
              child: _buildSelectionBadge(_isSelected(entry)),
            ),
          if (hasCornerQuantity)
            Positioned(
              top: 0,
              right: 0,
              child: _cornerQuantityBadge(l10n, entry.quantity),
            ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyGalleryCardTile(
    CollectionCardEntry entry,
    AppLocalizations l10n,
  ) {
    return GestureDetector(
      onTap: () => _showCardDetails(entry),
      onLongPress: () => _showSideboardCardActions(entry, l10n),
      child: AbsorbPointer(
        absorbing: true,
        child: _buildGalleryCardTile(entry, l10n),
      ),
    );
  }

  Widget _buildDeckTypeGalleryView(
    List<CollectionCardEntry> visibleCards,
    AppLocalizations l10n,
  ) {
    final sections = _buildDeckSections(visibleCards, l10n);
    final children = <Widget>[_buildDeckStatsCard(visibleCards, l10n)];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      children.add(
        _buildDeckSectionHeader(
          l10n,
          label: section.label,
          count: section.cards.length,
          first: i == 0,
        ),
      );
      children.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: section.cards.length,
          itemBuilder: (context, index) {
            final entry = section.cards[index];
            return _buildGalleryCardTile(entry, l10n);
          },
        ),
      );
    }
    if (_sideboardCards.isNotEmpty) {
      final sideSections = _buildDeckSections(_sideboardCards, l10n);
      children.add(
        _buildDeckSectionHeader(
          l10n,
          label: _sideboardLabel(),
          count: _sideboardCards.length,
          first: false,
        ),
      );
      for (final section in sideSections) {
        children.add(
          _buildDeckSectionHeader(
            l10n,
            label: section.label,
            count: section.cards.length,
            first: false,
          ),
        );
        children.add(
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: section.cards.length,
            itemBuilder: (context, index) {
              final entry = section.cards[index];
              return _buildReadOnlyGalleryCardTile(entry, l10n);
            },
          ),
        );
      }
    }
    if (_loadingMore) {
      children.add(_buildLoadMoreIndicator());
    }
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: children,
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
        bottom: (_isMissingStyleCollection || widget.isAllCards)
            ? PreferredSize(
                preferredSize: Size.fromHeight(
                  _isMissingStyleCollection ? 108 : 68,
                ),
                child: _buildSearchHeader(
                  showOwnedMissing: _isFilterCollection,
                ),
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
                    const Icon(
                      Icons.collections,
                      size: 36,
                      color: Color(0xFFE9C46A),
                    ),
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
                    if (!widget.isSetCollection &&
                        !widget.isBasicLandsCollection)
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
                ? (widget.isDeckCollection
                      ? _buildDeckTypeListView(visibleCards, l10n)
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount:
                              visibleCards.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 18),
                          itemBuilder: (context, index) {
                            if (index >= visibleCards.length) {
                              return _buildLoadMoreIndicator();
                            }
                            final entry = visibleCards[index];
                            return _buildListCardTile(entry, l10n);
                          },
                        ))
                : (widget.isDeckCollection
                      ? _buildDeckTypeGalleryView(visibleCards, l10n)
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
                            return _buildGalleryCardTile(entry, l10n);
                          },
                        )),
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
      floatingActionButton: widget.isBasicLandsCollection
          ? null
          : FloatingActionButton(
              heroTag: 'collection_add_fab',
              onPressed: () => _addCard(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}
