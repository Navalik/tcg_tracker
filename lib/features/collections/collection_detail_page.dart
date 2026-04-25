part of 'package:tcg_tracker/main.dart';

enum _CardSortMode { name, color, type }

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
  CollectionType? _resolvedCollectionType;
  Timer? _searchDebounce;
  CollectionViewMode _viewMode = CollectionViewMode.list;
  bool _showOwned = true;
  bool _showMissing = true;
  String _searchQuery = '';
  final Set<String> _selectedRarities = {};
  final Set<String> _selectedSetCodes = {};
  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedColors = {};
  final Set<String> _selectedTypes = {};
  int? _manaValueMin;
  int? _manaValueMax;
  int? _ownedCount;
  int? _missingCount;
  bool _autoAddShown = false;
  Map<String, int> _setTotalsByCode = {};
  Map<String, String> _localizedSetNamesByCode = {};
  _CardSortMode _sortMode = _CardSortMode.name;
  bool _selectionMode = false;
  final Set<String> _selectedCardIds = {};
  final Set<String> _quickAddAnimating = {};
  final Set<String> _quickRemoveAnimating = {};
  final Set<String> _priceRefreshQueued = {};
  Map<String, bool> _deckLegalityByCardId = const {};
  Set<String>? _cachedKnownSetCodesForScan;
  String _priceCurrency = 'eur';
  bool _showPrices = true;
  bool _showOfflineLanguageDbWarning = false;
  CollectionFilter? _collectionFilterOverride;
  int _activeLoadRequestId = 0;
  static const List<String> _basicLandManaOrder = ['W', 'U', 'B', 'R', 'G'];
  InventoryService get _inventoryService => InventoryService.instance;

  bool get _isWishlistCollection =>
      widget.isWishlistCollection ||
      _resolvedCollectionType == CollectionType.wishlist;
  bool get _isFilterCollection =>
      !widget.isAllCards &&
      !widget.isDeckCollection &&
      !_isWishlistCollection &&
      (widget.filter != null || widget.isSetCollection);
  bool get _isDirectCustomCollection =>
      !widget.isAllCards &&
      !widget.isDeckCollection &&
      !_isWishlistCollection &&
      !_isFilterCollection;
  bool get _isPokemonActive =>
      TcgEnvironmentController.instance.currentGame == TcgGame.pokemon;
  bool get _isMissingStyleCollection =>
      _isFilterCollection || _isWishlistCollection;
  bool get _isPokemonDeck => widget.isDeckCollection && _isPokemonActive;
  List<String> get _activeDeckTypeOrder =>
      _isPokemonDeck ? _pokemonDeckTypeOrder : _mtgDeckTypeOrder;
  String? get _deckFormatConstraint {
    final format = widget.filter?.format?.trim().toLowerCase();
    if (format == null || format.isEmpty) {
      return null;
    }
    return format;
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
    await _refreshOfflineLanguageDbWarning();
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
      _resolvedCollectionType = await ScryfallDatabase.instance
          .fetchCollectionTypeById(widget.collectionId);
      _allCardsCollectionId = await ScryfallDatabase.instance
          .ensureAllCardsCollectionId();
      final useAllCardsAsOwnership =
          _isFilterCollection || _isWishlistCollection;
      _ownedCollectionId = widget.isDeckCollection
          ? widget.collectionId
          : (useAllCardsAsOwnership
                ? _allCardsCollectionId
                : widget.collectionId);
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

  Future<void> _refreshOfflineLanguageDbWarning() async {
    final filter = _effectiveFilter();
    final normalizedLanguages = (filter?.languages ?? const <String>{})
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final requiresAdditionalLanguage = normalizedLanguages.any(
      (value) => value != 'en',
    );
    if (!requiresAdditionalLanguage || _isPokemonActive) {
      _showOfflineLanguageDbWarning = false;
      return;
    }
    final mtgBulkType = await AppSettings.loadBulkTypeForGame(AppTcgGame.mtg);
    final normalizedBulk = (mtgBulkType ?? '').trim().toLowerCase();
    _showOfflineLanguageDbWarning = normalizedBulk != 'all_cards';
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
    final requestId = ++_activeLoadRequestId;
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
      _localizedSetNamesByCode = {};
      _selectionMode = false;
      _selectedCardIds.clear();
      _deckLegalityByCardId = const {};
      _ownedCount = null;
      _missingCount = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _loadMoreCards(initial: true);
    if (!mounted || requestId != _activeLoadRequestId) {
      return;
    }
    unawaited(_refreshCounts(requestId: requestId));
    unawaited(_loadSideboardCards(requestId: requestId));
  }

  CollectionFilter? _effectiveFilter() {
    if (widget.isDeckCollection) {
      return null;
    }
    if (_isWishlistCollection) {
      // Wishlist is membership-driven only, never catalog-filter-driven.
      return null;
    }
    final fallbackFilter =
        widget.isSetCollection && (widget.setCode?.trim().isNotEmpty ?? false)
        ? CollectionFilter(sets: {widget.setCode!.trim().toLowerCase()})
        : null;
    return _collectionFilterOverride ?? widget.filter ?? fallbackFilter;
  }

  String _languageLabelForCode(AppLocalizations l10n, String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized == 'it') {
      return l10n.languageItalian;
    }
    return l10n.languageEnglish;
  }

  bool get _isSetCollectionUsingNonEnglishLanguage {
    if (!widget.isSetCollection) {
      return false;
    }
    final languages = (_effectiveFilter()?.languages ?? const <String>{})
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    return languages.any((value) => value != 'en');
  }

  String _collectionCardsLoadFailedLabel(Object error) {
    final raw = error.toString().toLowerCase();
    final italian = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('it');
    if (raw.contains('sqliteexception') || raw.contains('database')) {
      return italian
          ? 'Errore nel caricamento dei dati locali delle carte.'
          : 'Failed to load local card data.';
    }
    return italian
        ? 'Errore nel caricamento delle carte della collezione.'
        : 'Failed to load collection cards.';
  }

  Future<void> _applySetCollectionLanguage(String languageCode) async {
    final normalizedNext = languageCode.trim().toLowerCase();
    if (normalizedNext.isEmpty) {
      return;
    }
    final currentFilter = _effectiveFilter();
    final currentLang =
        (currentFilter?.languages.toList() ?? const <String>['en'])
            .map((value) => value.trim().toLowerCase())
            .firstWhere((value) => value.isNotEmpty, orElse: () => 'en');
    if (currentLang == normalizedNext) {
      return;
    }
    final fallbackSetCode = widget.setCode?.trim().toLowerCase();
    final nextSets = (currentFilter?.sets.isNotEmpty ?? false)
        ? currentFilter!.sets
        : (fallbackSetCode == null || fallbackSetCode.isEmpty)
        ? const <String>{}
        : <String>{fallbackSetCode};
    final nextFilter = CollectionFilter(
      name: currentFilter?.name,
      artist: currentFilter?.artist,
      manaMin: currentFilter?.manaMin,
      manaMax: currentFilter?.manaMax,
      hpMin: currentFilter?.hpMin,
      hpMax: currentFilter?.hpMax,
      format: currentFilter?.format,
      collectorNumber: currentFilter?.collectorNumber,
      languages: <String>{normalizedNext},
      sets: nextSets,
      rarities: currentFilter?.rarities ?? const <String>{},
      colors: currentFilter?.colors ?? const <String>{},
      types: currentFilter?.types ?? const <String>{},
      pokemonCategories: currentFilter?.pokemonCategories ?? const <String>{},
      pokemonSubtypes: currentFilter?.pokemonSubtypes ?? const <String>{},
      pokemonRegulationMarks:
          currentFilter?.pokemonRegulationMarks ?? const <String>{},
      pokemonStages: currentFilter?.pokemonStages ?? const <String>{},
    );
    await ScryfallDatabase.instance.updateCollectionFilter(
      widget.collectionId,
      filter: nextFilter,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _collectionFilterOverride = nextFilter;
      _loading = true;
      _cards.clear();
      _loadedOffset = 0;
      _hasMore = true;
    });
    await _refreshOfflineLanguageDbWarning();
    await _loadCards();
  }

  Future<void> _changeSetCollectionLanguage() async {
    if (!widget.isSetCollection) {
      return;
    }
    final selectedGame = _isPokemonActive ? AppTcgGame.pokemon : AppTcgGame.mtg;
    final available =
        (await AppSettings.loadCardLanguagesForGame(selectedGame))
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet()
          ..add('en');
    final options = available.toList()..sort();
    if (!mounted) {
      return;
    }
    if (options.length <= 1) {
      showAppSnackBar(
        context,
        Localizations.localeOf(
              context,
            ).languageCode.toLowerCase().startsWith('it')
            ? 'Solo inglese disponibile per questa configurazione.'
            : 'Only English is available for this setup.',
      );
      return;
    }
    final currentFilter = _effectiveFilter();
    final currentLang =
        (currentFilter?.languages.toList() ?? const <String>['en'])
            .map((value) => value.trim().toLowerCase())
            .firstWhere((value) => value.isNotEmpty, orElse: () => 'en');
    var selected = options.contains(currentLang) ? currentLang : options.first;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: Text(
              Localizations.localeOf(
                    context,
                  ).languageCode.toLowerCase().startsWith('it')
                  ? 'Lingua della collezione'
                  : 'Collection language',
            ),
            content: RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setModalState(() {
                  selected = value;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map(
                      (code) => RadioListTile<String>(
                        value: code,
                        title: Text(_languageLabelForCode(l10n, code)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selected),
                child: Text(l10n.continueLabel),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || picked == null) {
      return;
    }
    await _applySetCollectionLanguage(picked);
  }

  Future<void> _refreshCounts({int? requestId}) async {
    if (!mounted) {
      return;
    }
    if (_isWishlistCollection) {
      final total = await ScryfallDatabase.instance.countWishlistCards(
        widget.collectionId,
        searchQuery: _searchQuery,
      );
      if (!mounted || (requestId != null && requestId != _activeLoadRequestId)) {
        return;
      }
      setState(() {
        _ownedCount = 0;
        _missingCount = total;
      });
      return;
    }
    if (!_isFilterCollection) {
      final total = _isDirectCustomCollection
          ? await ScryfallDatabase.instance.countCustomCollectionOwnedCards(
              widget.collectionId,
              searchQuery: _searchQuery,
            )
          : await ScryfallDatabase.instance.countCollectionCards(
              widget.collectionId,
              searchQuery: _searchQuery,
            );
      if (!mounted || (requestId != null && requestId != _activeLoadRequestId)) {
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
      if (!mounted || (requestId != null && requestId != _activeLoadRequestId)) {
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
    if (!mounted || (requestId != null && requestId != _activeLoadRequestId)) {
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
          : _isDirectCustomCollection
          ? await ScryfallDatabase.instance.fetchCustomCollectionOwnedCards(
              widget.collectionId,
              searchQuery: _searchQuery,
              limit: _pageSize,
              offset: _loadedOffset,
            )
          : _isWishlistCollection
          ? await ScryfallDatabase.instance
                .fetchWishlistCardsWithOwnedQuantities(
                  widget.collectionId,
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
              searchQuery: _searchQuery,
              limit: _pageSize,
              offset: _loadedOffset,
            );

      final newSetCodes = cards
          .map((entry) => entry.setCode.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .where((code) => !_setTotalsByCode.containsKey(code))
          .toSet()
          .toList();
      Map<String, int> totals = <String, int>{};
      if (newSetCodes.isNotEmpty) {
        try {
          totals = await ScryfallDatabase.instance.fetchSetTotalsForCodes(
            newSetCodes,
          );
        } catch (_) {
          totals = <String, int>{};
        }
      }
      Map<String, String> localizedSetNames = const <String, String>{};
      if (newSetCodes.isNotEmpty) {
        try {
          localizedSetNames = await appRepositories.sets.fetchSetNamesForCodes(
            newSetCodes,
            gameId: _isPokemonActive ? TcgGameId.pokemon : TcgGameId.mtg,
          );
        } catch (_) {
          localizedSetNames = const <String, String>{};
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _cards.addAll(cards);
        _setTotalsByCode.addAll(totals);
        _localizedSetNamesByCode.addAll(
          localizedSetNames.map(
            (code, name) => MapEntry(code.trim().toLowerCase(), name.trim()),
          ),
        );
        _loadedOffset += cards.length;
        _hasMore = cards.length == _pageSize;
        _loadingMore = false;
        _loading = false;
      });
      await _refreshDeckLegalityForLoadedCards();
      _refreshListPrices(cards);
      _maybePrefetchIfShort();
    } catch (error) {
      debugPrint(
        '[collection-detail] load more failed '
        'collection=${widget.collectionId} '
        'name=${widget.name} '
        'isSet=${widget.isSetCollection} '
        'isPokemon=$_isPokemonActive '
        'search=$_searchQuery '
        'offset=$_loadedOffset '
        'owned=$_showOwned missing=$_showMissing '
        'filter=${_effectiveFilter()?.toJson()} '
        'error=$error',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
        _loading = false;
        _hasMore = false;
      });
      showAppSnackBar(context, _collectionCardsLoadFailedLabel(error));
    }
  }

  Future<void> _refreshDeckLegalityForLoadedCards() async {
    final format = _deckFormatConstraint;
    if (!widget.isDeckCollection || _isPokemonDeck || format == null) {
      return;
    }
    final cardIds = {
      ..._cards.map((entry) => entry.cardId.trim()),
      ..._sideboardCards.map((entry) => entry.cardId.trim()),
    }.where((id) => id.isNotEmpty).toList(growable: false);
    if (cardIds.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _deckLegalityByCardId = const {};
      });
      return;
    }
    final legalities = await ScryfallDatabase.instance
        .fetchCardLegalityForFormat(cardIds, format: format);
    if (!mounted) {
      return;
    }
    setState(() {
      _deckLegalityByCardId = legalities;
    });
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
        _selectedLanguages.isEmpty &&
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
      if (isFilterCollection || widget.isAllCards) {
        final printingId = _cards
            .cast<CollectionCardEntry?>()
            .firstWhere((item) => item?.cardId == cardId, orElse: () => null)
            ?.printingId;
        await _inventoryService.setInventoryQty(
          cardId,
          0,
          printingId: printingId,
        );
      } else if (_isDirectCustomCollection) {
        await ScryfallDatabase.instance.deleteCollectionCard(
          widget.collectionId,
          cardId,
          printingId: _cards
              .cast<CollectionCardEntry?>()
              .firstWhere((item) => item?.cardId == cardId, orElse: () => null)
              ?.printingId,
        );
      } else {
        await ScryfallDatabase.instance.deleteCollectionCard(
          _isWishlistCollection ? widget.collectionId : ownedCollectionId!,
          cardId,
          printingId: _cards
              .cast<CollectionCardEntry?>()
              .firstWhere((item) => item?.cardId == cardId, orElse: () => null)
              ?.printingId,
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
    if (_selectedLanguages.isNotEmpty) {
      final language = entry.lang.trim().toLowerCase();
      if (!_selectedLanguages.contains(language)) {
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
        'pokÃ©mon',
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
    final l10n = AppLocalizations.of(context)!;
    switch (value) {
      case 'Pokemon':
        return 'Pokemon';
      case 'Trainer':
        return l10n.pokemonTypeTrainer;
      case 'Energy':
        return l10n.pokemonTypeEnergy;
      case 'Item':
        return l10n.pokemonTypeItem;
      case 'Supporter':
        return l10n.pokemonTypeSupporter;
      case 'Stadium':
        return l10n.pokemonTypeStadium;
      case 'Tool':
        return l10n.pokemonTypeTool;
      default:
        return value;
    }
  }

  double _cardManaValue(CollectionCardEntry entry) {
    return entry.manaValue ?? 0;
  }

  bool _hasActiveAdvancedFilters() {
    return _selectedRarities.isNotEmpty ||
        _selectedSetCodes.isNotEmpty ||
        _selectedLanguages.isNotEmpty ||
        _selectedColors.isNotEmpty ||
        _selectedTypes.isNotEmpty ||
        _manaValueMin != null ||
        _manaValueMax != null;
  }

  String _setLabelForEntry(CollectionCardEntry entry) {
    final code = entry.setCode.trim().toLowerCase();
    final localized = _localizedSetNamesByCode[code];
    if (localized != null && localized.isNotEmpty) {
      return localized;
    }
    if (entry.setName.trim().isNotEmpty) {
      return entry.setName.trim();
    }
    return entry.setCode.toUpperCase();
  }

  String _collectorProgressLabel(CollectionCardEntry entry) {
    return entry.collectorNumber.trim();
  }

  Widget _cardImageOrPlaceholder(String? rawImageUri) {
    final imageUrl = _normalizeCardImageUrlForDisplay(rawImageUri);
    if (imageUrl.isEmpty) {
      return _missingCardArtPlaceholder('', compact: true);
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stackTrace) {
        return _missingCardArtPlaceholder('', compact: true);
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
    final symbol = currency == 'usd' ? r'$' : '\u20AC';
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
      final lookupCollectionId = widget.isAllCards || _isWishlistCollection
          ? widget.collectionId
          : (_ownedCollectionId ?? -1);
      final refreshedEntries = await Future.wait(
        cardIds.map(
          (cardId) => ScryfallDatabase.instance.fetchCardEntryById(
            cardId,
            printingId: _cards
                .cast<CollectionCardEntry?>()
                .firstWhere(
                  (item) => item?.cardId == cardId,
                  orElse: () => null,
                )
                ?.printingId,
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
    final lookupCollectionId = widget.isAllCards || _isWishlistCollection
        ? widget.collectionId
        : (_ownedCollectionId ?? -1);
    final refreshed = await ScryfallDatabase.instance.fetchCardEntryById(
      cardId,
      printingId: _cards
          .cast<CollectionCardEntry?>()
          .firstWhere((item) => item?.cardId == cardId, orElse: () => null)
          ?.printingId,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visibleCards = _sortedCards();
    final listBottomPadding = 112.0 + MediaQuery.of(context).padding.bottom;
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
          if (widget.isSetCollection)
            IconButton(
              tooltip:
                  Localizations.localeOf(
                    context,
                  ).languageCode.toLowerCase().startsWith('it')
                  ? 'Cambia lingua collezione'
                  : 'Change collection language',
              icon: const Icon(Icons.translate_rounded),
              onPressed: _changeSetCollectionLanguage,
            ),
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
                    : Icons.done_all,
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
          else if (widget.isDeckCollection && visibleCards.isEmpty)
            _viewMode == CollectionViewMode.list
                ? _buildDeckTypeListView(visibleCards, l10n)
                : _buildDeckTypeGalleryView(visibleCards, l10n)
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
                      _showOfflineLanguageDbWarning
                          ? (Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase().startsWith('it')
                                ? 'Nessun risultato locale con questo database'
                                : 'No local results with this database')
                          : (widget.isAllCards
                                ? l10n.noOwnedCardsYet
                                : _isFilterCollection
                                ? l10n.noCardsMatchFilters
                                : l10n.noCardsYet),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _showOfflineLanguageDbWarning
                          ? (Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase().startsWith('it')
                                ? 'Questa collezione usa lingue aggiuntive (es. IT). Reimporta il bundle Firebase dopo aver abilitato la lingua.'
                                : 'This collection uses additional languages (for example IT). Reimport the Firebase bundle after enabling the language.')
                          : (_isFilterCollection
                                ? l10n.tryEnablingOwnedOrMissing
                                : widget.isAllCards
                                ? l10n.addCardsHereOrAny
                                : l10n.addFirstCardToStartCollection),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFBFAE95),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_showOfflineLanguageDbWarning)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings_rounded),
                        label: Text(
                          Localizations.localeOf(
                                context,
                              ).languageCode.toLowerCase().startsWith('it')
                              ? 'Apri impostazioni database'
                              : 'Open database settings',
                        ),
                      ),
                    if (_showOfflineLanguageDbWarning &&
                        _isSetCollectionUsingNonEnglishLanguage) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => _applySetCollectionLanguage('en'),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text(
                          Localizations.localeOf(
                                context,
                              ).languageCode.toLowerCase().startsWith('it')
                              ? 'Passa a Inglese'
                              : 'Switch to English',
                        ),
                      ),
                    ],
                    if (_showOfflineLanguageDbWarning)
                      const SizedBox(height: 10),
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
                          padding: EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            listBottomPadding,
                          ),
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
                                childAspectRatio: 0.64,
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
