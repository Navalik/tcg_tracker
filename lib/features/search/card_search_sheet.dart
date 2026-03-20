part of 'package:tcg_tracker/main.dart';

class _CardSearchSelection {
  _CardSearchSelection.single(CardSearchResult card)
    : cards = [card],
      isBulk = false,
      count = 1,
      cardIds = [card.id];

  _CardSearchSelection.bulk(this.cards)
    : isBulk = true,
      count = cards.length,
      cardIds = cards.map((card) => card.id).toList(growable: false);

  final List<CardSearchResult> cards;
  final bool isBulk;
  final int count;
  final List<String> cardIds;
}

class _SearchPriceData {
  const _SearchPriceData({required this.base, required this.foil});

  final String base;
  final String foil;
}

class _CardSearchSheet extends StatefulWidget {
  const _CardSearchSheet({
    this.initialQuery,
    this.initialSetCode,
    this.initialCollectorNumber,
    this.selectionEnabled = true,
    this.addToOwnershipCollectionDirectly = false,
    this.ownershipCollectionId,
    this.customMembershipCollectionId,
    this.addMissingToCollectionId,
    this.requiredFilter,
    this.deckFormatConstraint,
    this.showFilterButton = true,
  });

  final String? initialQuery;
  final String? initialSetCode;
  final String? initialCollectorNumber;
  final bool selectionEnabled;
  final bool addToOwnershipCollectionDirectly;
  final int? ownershipCollectionId;
  final int? customMembershipCollectionId;
  final int? addMissingToCollectionId;
  final CollectionFilter? requiredFilter;
  final String? deckFormatConstraint;
  final bool showFilterButton;

  @override
  State<_CardSearchSheet> createState() => _CardSearchSheetState();
}

class _CardSearchSheetState extends State<_CardSearchSheet>
    with TickerProviderStateMixin {
  static const int _pageSize = 100;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  List<CardSearchResult> _results = [];
  String _query = '';
  OverlayEntry? _previewEntry;
  late final AnimationController _previewController;
  late final Animation<double> _previewOpacity;
  late final Animation<double> _previewScale;
  late final AnimationController _searchLoadingController;
  bool _searching = false;
  String _artistQuery = '';
  String? _pendingQuery;
  bool _pendingFilterRefresh = false;
  final Set<String> _selectedRarities = {};
  final Set<String> _selectedSetCodes = {};
  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedColors = {};
  final Set<String> _selectedTypes = {};
  final Set<String> _selectedPokemonCategories = {};
  final Set<String> _selectedPokemonRegulationMarks = {};
  final Set<String> _selectedPokemonStages = {};
  String _collectorNumberQuery = '';
  String _pokemonSubtypeQuery = '';
  int? _hpMin;
  int? _hpMax;
  int? _manaValueMin;
  int? _manaValueMax;
  bool _showResults = true;
  bool _countLoading = false;
  int? _filterTotalCount;
  Map<String, String>? _availableSetCodesCache;
  Map<String, int> _ownedQuantitiesByCardId = const {};
  Map<String, int> _missingCollectionQuantitiesByCardId = const {};
  bool _galleryView = false;
  bool _artworkSearchEnabled = false;
  bool _ownedOnlyFilter = false;
  bool _hideNotLegalFilter = false;
  bool _onlineArtworkLoading = false;
  bool _addingFromPreview = false;
  bool _limitedPrintCoverage = false;
  AppTcgGame _activeSearchGame = AppTcgGame.mtg;
  bool _showPrices = true;
  String _priceCurrency = 'eur';
  List<String> _searchLanguages = const ['en'];
  final Map<String, _SearchPriceData> _priceDataByCardId = {};
  final Set<String> _priceRefreshQueued = {};
  Map<String, bool> _deckLegalityByCardId = const {};

  String? get _deckFormatConstraint {
    final explicit = widget.deckFormatConstraint?.trim().toLowerCase();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final format = widget.requiredFilter?.format?.trim().toLowerCase();
    if (format == null || format.isEmpty) {
      return null;
    }
    return format;
  }

  bool get _isDeckContext => widget.addToOwnershipCollectionDirectly;

  bool get _isDeckSearch => _deckFormatConstraint != null;

  bool get _isPokemonSearch => _activeSearchGame == AppTcgGame.pokemon;

  bool get _shouldAutoLoadInitialResults {
    return _query.trim().isNotEmpty || _hasRequiredAdvancedFilters();
  }

  @override
  void initState() {
    super.initState();
    _previewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _previewOpacity = CurvedAnimation(
      parent: _previewController,
      curve: Curves.easeOut,
    );
    _previewScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _previewController, curve: Curves.easeOutBack),
    );
    _searchLoadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _focusNode.requestFocus();
    _controller.addListener(_onQueryChanged);
    final initialSetCode = widget.initialSetCode?.trim().toLowerCase();
    if (initialSetCode != null && initialSetCode.isNotEmpty) {
      _selectedSetCodes.add(initialSetCode);
    }
    final initialQuery = widget.initialQuery?.trim();
    final initialCollector = widget.initialCollectorNumber?.trim();
    final seedQuery = (initialQuery != null && initialQuery.isNotEmpty)
        ? initialQuery
        : ((initialCollector != null && initialCollector.isNotEmpty)
              ? initialCollector
              : null);
    if (seedQuery != null) {
      _controller.text = seedQuery;
      _query = seedQuery;
    }
    unawaited(_loadBulkCoverageState());
    unawaited(_loadPricePreferences());
    _loadSearchLanguages();
  }

  Future<void> _loadBulkCoverageState() async {
    final runtimeGame =
        TcgEnvironmentController.instance.currentGame == TcgGame.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    final bulkType = await AppSettings.loadBulkTypeForGame(runtimeGame);
    final cardLanguages = await AppSettings.loadCardLanguagesForGame(
      runtimeGame,
    );
    if (!mounted) {
      return;
    }
    final isPokemonRuntime = runtimeGame == AppTcgGame.pokemon;
    setState(() {
      _activeSearchGame = runtimeGame;
      _limitedPrintCoverage = isPokemonRuntime
          ? false
          : _isLimitedPrintCoverage(bulkType);
      _searchLanguages = cardLanguages;
    });
    if (_shouldAutoLoadInitialResults) {
      await _runSearch(forceRefresh: true);
    }
  }

  Future<void> _loadPricePreferences() async {
    final showPrices = await AppSettings.loadShowPrices();
    final priceCurrency = await AppSettings.loadPriceCurrency();
    if (!mounted) {
      return;
    }
    setState(() {
      _showPrices = showPrices;
      _priceCurrency = priceCurrency;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hidePreview(immediate: true);
    _searchLoadingController.dispose();
    _previewController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final value = _controller.text;
    if (value == _query) {
      return;
    }
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch({bool forceRefresh = false}) async {
    final trimmedQuery = _query.trim();
    final meetsMinQueryLength = _query.length >= 2;
    final shouldFetchByFilters =
        _hasActiveAdvancedFilters() &&
        (_hasNarrowingFilters() || trimmedQuery.isNotEmpty);
    if (!meetsMinQueryLength && !shouldFetchByFilters) {
      if (mounted) {
        setState(() {
          _results = [];
          _loading = false;
          _onlineArtworkLoading = false;
          _deckLegalityByCardId = const {};
        });
      }
      return;
    }
    if (!_showResults && _hasActiveAdvancedFilters()) {
      await _refreshFilterCount();
      return;
    }
    if (_searching) {
      _pendingQuery = _query;
      if (forceRefresh) {
        _pendingFilterRefresh = true;
      }
      return;
    }
    _hidePreview(immediate: false);
    _searching = true;
    _offset = 0;
    _hasMore = true;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _onlineArtworkLoading = false;
      _results = [];
      _ownedQuantitiesByCardId = const {};
      _deckLegalityByCardId = const {};
      _priceDataByCardId.clear();
    });

    final currentQuery = _query;
    try {
      await _loadNextPage(currentQuery, replace: true);
      if (mounted && _hasActiveAdvancedFilters()) {
        await _refreshFilterCount();
      }
    } finally {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
        });
      }
      _searching = false;
    }
    if (!mounted) {
      return;
    }
    if (_pendingQuery != null && _pendingQuery != currentQuery) {
      _pendingQuery = null;
      await _runSearch(forceRefresh: true);
    } else {
      _pendingQuery = null;
    }
    if (_pendingFilterRefresh) {
      _pendingFilterRefresh = false;
      await _runSearch();
    }
  }

  Future<void> _refreshFilterCount() async {
    if (!mounted) {
      return;
    }
    if (!_hasActiveAdvancedFilters()) {
      setState(() {
        _filterTotalCount = null;
        _countLoading = false;
      });
      return;
    }
    if (_isPokemonSearch) {
      setState(() {
        _filterTotalCount = null;
        _countLoading = false;
      });
      return;
    }
    setState(() {
      _countLoading = true;
    });
    final filter = _effectiveAdvancedFilter();
    final trimmedQuery = _query.trim();
    final total = trimmedQuery.isEmpty
        ? await appRepositories.search.countCardsForFilterWithSearch(
            filter,
            gameId: _isPokemonSearch ? TcgGameId.pokemon : TcgGameId.mtg,
            searchQuery: null,
            languages: _effectiveLanguages(),
          )
        : await _countExactAdvancedFilterMatches(filter, trimmedQuery);
    if (!mounted) {
      return;
    }
    setState(() {
      _filterTotalCount = total;
      _countLoading = false;
    });
  }

  Future<int> _countExactAdvancedFilterMatches(
    CollectionFilter filter,
    String query,
  ) async {
    const pageSize = 400;
    var offset = 0;
    var total = 0;
    while (true) {
      var page = await appRepositories.search.fetchCardsForAdvancedFilters(
        filter,
        gameId: _isPokemonSearch ? TcgGameId.pokemon : TcgGameId.mtg,
        searchQuery: query,
        languages: _effectiveLanguages(),
        limit: pageSize,
        offset: offset,
      );
      final rawPageCount = page.length;
      if (page.isEmpty) {
        break;
      }
      page = _applyPrefixWordFilter(page, query);
      total += page.length;
      if (rawPageCount < pageSize) {
        break;
      }
      offset += pageSize;
    }
    return total;
  }

  List<String> _effectiveLanguages() {
    return _searchLanguages;
  }

  Future<void> _loadNextPage(String query, {bool replace = false}) async {
    if (_loadingMore || !_hasMore) {
      return;
    }
    if (mounted) {
      setState(() {
        _loadingMore = !replace;
      });
    }
    List<CardSearchResult> page;
    var hasMorePages = true;
    final hasAdvancedFilters = _hasActiveAdvancedFilters();
    if (!widget.selectionEnabled &&
        _artworkSearchEnabled &&
        query.isNotEmpty &&
        !hasAdvancedFilters) {
      final localResults = await appRepositories.search.searchCardsByName(
        query,
        languages: _effectiveLanguages(),
        limit: 400,
        offset: 0,
      );
      final trimmedLocalQuery = query.trim();
      var filteredLocal = localResults;
      if (trimmedLocalQuery.isNotEmpty) {
        filteredLocal = _applyPrefixWordFilter(localResults, trimmedLocalQuery);
      }

      final ownershipCollectionId = widget.ownershipCollectionId;
      Map<String, int> localOwnedQuantities = const {};
      Map<String, int> localMissingQuantities = const {};
      Map<String, bool> localDeckLegality = const {};
      if (!_isDeckContext &&
          ownershipCollectionId != null &&
          filteredLocal.isNotEmpty) {
        localOwnedQuantities = await ScryfallDatabase.instance
            .fetchCollectionQuantities(
              ownershipCollectionId,
              filteredLocal.map((card) => card.id).toList(growable: false),
            );
        if (_ownedOnlyFilter) {
          filteredLocal = filteredLocal
              .where((card) => (localOwnedQuantities[card.id] ?? 0) > 0)
              .toList(growable: false);
        }
      }
      if (!_isDeckContext && filteredLocal.isNotEmpty) {
        localMissingQuantities = await _fetchMissingCollectionQuantities(
          filteredLocal,
        );
        filteredLocal = _excludeAlreadyMissingCards(
          filteredLocal,
          localMissingQuantities,
        );
      }
      final deckFormat = _deckFormatConstraint;
      if (deckFormat != null && filteredLocal.isNotEmpty) {
        localDeckLegality = await ScryfallDatabase.instance
            .fetchCardLegalityForFormat(
              filteredLocal.map((card) => card.id).toList(growable: false),
              format: deckFormat,
            );
        if (_hideNotLegalFilter) {
          filteredLocal = filteredLocal
              .where((card) => localDeckLegality[card.id] ?? false)
              .toList(growable: false);
        }
      }
      if (!mounted || query != _query) {
        return;
      }
      setState(() {
        _results = filteredLocal;
        _ownedQuantitiesByCardId = localOwnedQuantities;
        _missingCollectionQuantitiesByCardId = localMissingQuantities;
        _deckLegalityByCardId = localDeckLegality;
        _loading = false;
        _loadingMore = false;
        _onlineArtworkLoading = true;
        _hasMore = false;
      });

      final onlineResults = await _fetchOnlinePrintings(query);
      if (!mounted || query != _query) {
        return;
      }
      page = _mergeUniquePrintings(localResults, onlineResults);
      hasMorePages = false;
    } else if (hasAdvancedFilters) {
      final filter = _effectiveAdvancedFilter();
      page = await appRepositories.search.fetchCardsForAdvancedFilters(
        filter,
        searchQuery: query.isEmpty ? null : query,
        languages: _effectiveLanguages(),
        limit: _pageSize,
        offset: _offset,
      );
    } else if (query.isEmpty) {
      page = await appRepositories.search.fetchCardsForFilters(
        setCodes: _selectedSetCodes,
        rarities: _selectedRarities,
        types: _selectedTypes,
        languages: _effectiveLanguages(),
        limit: _pageSize,
        offset: _offset,
      );
    } else {
      page = await appRepositories.search.searchCardsByName(
        query,
        languages: _effectiveLanguages(),
        limit: _pageSize,
        offset: _offset,
      );
    }
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      page = _applyPrefixWordFilter(page, trimmedQuery);
    }
    final rawPageCount = page.length;
    Map<String, int> ownedQuantities = const {};
    Map<String, int> missingQuantities = const {};
    Map<String, bool> deckLegality = const {};
    final ownershipCollectionId = widget.ownershipCollectionId;
    if (!_isDeckContext && ownershipCollectionId != null && page.isNotEmpty) {
      ownedQuantities = await ScryfallDatabase.instance
          .fetchCollectionQuantities(
            ownershipCollectionId,
            page.map((card) => card.id).toList(growable: false),
          );
      if (_ownedOnlyFilter) {
        page = page
            .where((card) => (ownedQuantities[card.id] ?? 0) > 0)
            .toList(growable: false);
      }
    }
    if (!_isDeckContext && page.isNotEmpty) {
      missingQuantities = await _fetchMissingCollectionQuantities(page);
      page = _excludeAlreadyMissingCards(page, missingQuantities);
    }
    final deckFormat = _deckFormatConstraint;
    if (deckFormat != null && page.isNotEmpty) {
      deckLegality = await ScryfallDatabase.instance.fetchCardLegalityForFormat(
        page.map((card) => card.id).toList(growable: false),
        format: deckFormat,
      );
      if (_hideNotLegalFilter) {
        page = page
            .where((card) => deckLegality[card.id] ?? false)
            .toList(growable: false);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (replace) {
        _results = page;
        _ownedQuantitiesByCardId = ownedQuantities;
        _missingCollectionQuantitiesByCardId = missingQuantities;
        _deckLegalityByCardId = deckLegality;
      } else {
        _results = [..._results, ...page];
        _ownedQuantitiesByCardId = {
          ..._ownedQuantitiesByCardId,
          ...ownedQuantities,
        };
        _missingCollectionQuantitiesByCardId = {
          ..._missingCollectionQuantitiesByCardId,
          ...missingQuantities,
        };
        _deckLegalityByCardId = {..._deckLegalityByCardId, ...deckLegality};
      }
      _loading = false;
      _loadingMore = false;
      _onlineArtworkLoading = false;
      _offset += rawPageCount;
      _hasMore = hasMorePages && rawPageCount == _pageSize;
    });
    _refreshSearchResultPrices(page);
  }

  Future<List<CardSearchResult>> _fetchOnlinePrintings(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    try {
      final collected = <CardSearchResult>[];
      final normalizedTokens = _tokenizeSearch(trimmed);
      final normalizedQuery = normalizedTokens.join(' ').trim();
      final namedLookupQuery = normalizedQuery.isNotEmpty
          ? normalizedQuery
          : trimmed;
      final namedUri = Uri.parse(
        'https://api.scryfall.com/cards/named?fuzzy=${Uri.encodeQueryComponent(namedLookupQuery)}',
      );
      final namedResponse = await ScryfallApiClient.instance.get(
        namedUri,
        timeout: const Duration(seconds: 4),
        maxRetries: 2,
      );
      String? oracleId;
      var resolvedName = '';
      if (namedResponse.statusCode == 200) {
        final namedPayload = jsonDecode(namedResponse.body);
        if (namedPayload is Map<String, dynamic>) {
          oracleId = (namedPayload['oracle_id'] as String?)?.trim();
          resolvedName = ((namedPayload['name'] as String?) ?? '')
              .trim()
              .replaceAll('"', '\\"');
        }
      }

      final rawEscaped = trimmed.replaceAll('"', '\\"');
      final prefixTokens = normalizedTokens;
      final prefixQuery = prefixTokens.map((token) => 'name:$token*').join(' ');
      if (resolvedName.isNotEmpty && oracleId != null && oracleId.isNotEmpty) {
        final strict = await _fetchScryfallSearchResults(
          '!"$resolvedName" oracleid:$oracleId include:extras',
          maxPages: 20,
        );
        collected.addAll(strict);
      }

      final queryCandidates = <String>[];
      if (prefixQuery.isNotEmpty) {
        queryCandidates.add(prefixQuery);
      }
      queryCandidates.add(rawEscaped);
      if (normalizedQuery.isNotEmpty &&
          normalizedQuery.toLowerCase() != trimmed.toLowerCase()) {
        queryCandidates.add(normalizedQuery.replaceAll('"', '\\"'));
      }
      if (resolvedName.isNotEmpty && oracleId != null && oracleId.isNotEmpty) {
        queryCandidates.add(
          '!"$resolvedName" oracleid:$oracleId include:extras',
        );
      }
      if (resolvedName.isNotEmpty) {
        queryCandidates.add('!"$resolvedName"');
      }
      if (oracleId != null && oracleId.isNotEmpty) {
        queryCandidates.add('oracleid:$oracleId');
      }

      for (final q in queryCandidates) {
        final pageResults = await _fetchScryfallSearchResults(q, maxPages: 12);
        collected.addAll(pageResults);
      }

      return collected;
    } catch (_) {
      return const [];
    }
  }

  Future<List<CardSearchResult>> _fetchScryfallSearchResults(
    String query, {
    int maxPages = 4,
  }) async {
    final allowMultilingual = _effectiveLanguages().any((lang) => lang != 'en');
    Uri buildSearchUri(String q) {
      return Uri.https('api.scryfall.com', '/cards/search', {
        'q': q,
        'order': 'released',
        'dir': 'desc',
        'unique': 'prints',
        'include_extras': 'true',
        'include_multilingual': allowMultilingual ? 'true' : 'false',
        'include_variations': 'true',
      });
    }

    var nextUri = buildSearchUri(query);
    final results = <CardSearchResult>[];
    var page = 0;
    while (page < maxPages) {
      final response = await ScryfallApiClient.instance.get(
        nextUri,
        timeout: const Duration(seconds: 10),
        maxRetries: 2,
      );
      if (response.statusCode != 200) {
        break;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        break;
      }
      final data = payload['data'];
      if (data is List) {
        for (final item in data) {
          final parsed = _cardFromScryfallJson(item);
          if (parsed != null) {
            results.add(parsed);
          }
        }
      }
      if (payload['has_more'] != true) {
        break;
      }
      final nextPage = payload['next_page'];
      if (nextPage is! String || nextPage.isEmpty) {
        break;
      }
      nextUri = Uri.parse(nextPage);
      page += 1;
    }
    return results;
  }

  CardSearchResult? _cardFromScryfallJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final allowedLanguages = _effectiveLanguages()
        .map((lang) => lang.trim().toLowerCase())
        .where((lang) => lang.isNotEmpty)
        .toSet();
    if (allowedLanguages.isEmpty) {
      allowedLanguages.add('en');
    }
    final lang = (raw['lang'] as String?)?.trim().toLowerCase();
    final effectiveLang = (lang == null || lang.isEmpty) ? 'en' : lang;
    if (!allowedLanguages.contains(effectiveLang)) {
      return null;
    }
    final id = (raw['id'] as String?)?.trim() ?? '';
    final name = (raw['name'] as String?)?.trim() ?? '';
    final printedName = (raw['printed_name'] as String?)?.trim() ?? '';
    final displayName = printedName.isNotEmpty ? printedName : name;
    final setCode = (raw['set'] as String?)?.trim().toLowerCase() ?? '';
    final collector = (raw['collector_number'] as String?)?.trim() ?? '';
    if (id.isEmpty ||
        displayName.isEmpty ||
        setCode.isEmpty ||
        collector.isEmpty) {
      return null;
    }
    final setName = (raw['set_name'] as String?)?.trim() ?? '';
    final rarity = (raw['rarity'] as String?)?.trim().toLowerCase() ?? '';
    final typeLine = (raw['type_line'] as String?)?.trim() ?? '';
    final colors = _codesToCsv(raw['colors']);
    final colorIdentity = _codesToCsv(raw['color_identity']);
    final prices = raw['prices'] as Map<String, dynamic>?;
    final setTotal = _extractSetTotal(raw);
    return CardSearchResult(
      id: id,
      name: displayName,
      setCode: setCode,
      setName: setName,
      setTotal: setTotal,
      collectorNumber: collector,
      rarity: rarity,
      typeLine: typeLine,
      colors: colors,
      colorIdentity: colorIdentity,
      priceUsd: _asPriceString(prices?['usd']),
      priceUsdFoil: _asPriceString(prices?['usd_foil']),
      priceEur: _asPriceString(prices?['eur']),
      priceEurFoil: _asPriceString(prices?['eur_foil']),
      imageUri: _extractScryfallImageUri(raw),
    );
  }

  String? _asPriceString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  int? _extractSetTotal(Map<String, dynamic> card) {
    final direct = card['printed_total'] ?? card['set_total'];
    if (direct is num) {
      return direct.toInt();
    }
    if (direct is String) {
      return int.tryParse(direct.trim());
    }
    final setData = card['set'];
    if (setData is Map<String, dynamic>) {
      final nested = setData['printed_total'] ?? setData['set_total'];
      if (nested is num) {
        return nested.toInt();
      }
      if (nested is String) {
        return int.tryParse(nested.trim());
      }
    }
    return null;
  }

  String _codesToCsv(Object? rawCodes) {
    if (rawCodes is! List) {
      return '';
    }
    final codes = rawCodes
        .whereType<String>()
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toList(growable: false);
    return codes.join(',');
  }

  String? _extractScryfallImageUri(Map<String, dynamic> raw) {
    final imageUris = raw['image_uris'];
    if (imageUris is Map<String, dynamic>) {
      final normal = (imageUris['normal'] as String?)?.trim();
      if (normal != null && normal.isNotEmpty) {
        return normal;
      }
      final large = (imageUris['large'] as String?)?.trim();
      if (large != null && large.isNotEmpty) {
        return large;
      }
      final small = (imageUris['small'] as String?)?.trim();
      if (small != null && small.isNotEmpty) {
        return small;
      }
    }
    final faces = raw['card_faces'];
    if (faces is List && faces.isNotEmpty) {
      for (final face in faces) {
        if (face is! Map<String, dynamic>) {
          continue;
        }
        final nested = face['image_uris'];
        if (nested is! Map<String, dynamic>) {
          continue;
        }
        final normal = (nested['normal'] as String?)?.trim();
        if (normal != null && normal.isNotEmpty) {
          return normal;
        }
      }
    }
    return null;
  }

  List<CardSearchResult> _mergeUniquePrintings(
    List<CardSearchResult> local,
    List<CardSearchResult> online,
  ) {
    final merged = <String, CardSearchResult>{};
    for (final card in [...local, ...online]) {
      final key = card.id.trim().toLowerCase();
      merged.putIfAbsent(key, () => card);
    }
    final values = merged.values.toList(growable: false);
    values.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) {
        return byName;
      }
      final bySet = a.setCode.toLowerCase().compareTo(b.setCode.toLowerCase());
      if (bySet != 0) {
        return bySet;
      }
      return _collectorSortKey(
        a.collectorNumber,
      ).compareTo(_collectorSortKey(b.collectorNumber));
    });
    return values;
  }

  String _collectorSortKey(String raw) {
    final value = raw.trim().toLowerCase();
    final match = RegExp(r'^0*(\d+)([a-z]?)$').firstMatch(value);
    if (match == null) {
      return value;
    }
    final number = int.tryParse(match.group(1) ?? '');
    final suffix = match.group(2) ?? '';
    if (number == null) {
      return value;
    }
    return '${number.toString().padLeft(6, '0')}$suffix';
  }

  CollectionFilter _buildAdvancedFilter() {
    final artist = _artistQuery.trim();
    return CollectionFilter(
      name: null,
      artist: artist.isEmpty ? null : artist,
      manaMin: _manaValueMin,
      manaMax: _manaValueMax,
      hpMin: _hpMin,
      hpMax: _hpMax,
      collectorNumber: _collectorNumberQuery.trim().isEmpty
          ? null
          : _collectorNumberQuery.trim(),
      languages: _selectedLanguages,
      sets: _selectedSetCodes,
      rarities: _selectedRarities,
      colors: _selectedColors,
      types: _selectedTypes,
      pokemonCategories: _selectedPokemonCategories,
      pokemonSubtypes: _pokemonSubtypeQuery.trim().isEmpty
          ? const <String>{}
          : _pokemonSubtypeQuery
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toSet(),
      pokemonRegulationMarks: _selectedPokemonRegulationMarks,
      pokemonStages: _selectedPokemonStages,
    );
  }

  CollectionFilter _effectiveAdvancedFilter() {
    final base = _buildAdvancedFilter();
    final required = widget.requiredFilter;
    if (required == null) {
      return base;
    }
    final effectiveLanguages = required.languages.isNotEmpty
        ? (base.languages.isEmpty ? required.languages : base.languages)
        : base.languages;
    return CollectionFilter(
      name: base.name ?? required.name,
      artist: base.artist ?? required.artist,
      manaMin: base.manaMin ?? required.manaMin,
      manaMax: base.manaMax ?? required.manaMax,
      hpMin: base.hpMin ?? required.hpMin,
      hpMax: base.hpMax ?? required.hpMax,
      format: base.format ?? required.format,
      collectorNumber: base.collectorNumber ?? required.collectorNumber,
      languages: effectiveLanguages,
      sets: {...required.sets, ...base.sets},
      rarities: {...required.rarities, ...base.rarities},
      colors: {...required.colors, ...base.colors},
      types: {...required.types, ...base.types},
      pokemonCategories: {
        ...required.pokemonCategories,
        ...base.pokemonCategories,
      },
      pokemonSubtypes: {...required.pokemonSubtypes, ...base.pokemonSubtypes},
      pokemonRegulationMarks: {
        ...required.pokemonRegulationMarks,
        ...base.pokemonRegulationMarks,
      },
      pokemonStages: {...required.pokemonStages, ...base.pokemonStages},
    );
  }

  bool _hasRequiredAdvancedFilters() {
    final required = widget.requiredFilter;
    if (required == null) {
      return false;
    }
    return (required.name?.trim().isNotEmpty ?? false) ||
        (required.artist?.trim().isNotEmpty ?? false) ||
        required.manaMin != null ||
        required.manaMax != null ||
        required.hpMin != null ||
        required.hpMax != null ||
        (required.format?.trim().isNotEmpty ?? false) ||
        (required.collectorNumber?.trim().isNotEmpty ?? false) ||
        required.languages.isNotEmpty ||
        required.sets.isNotEmpty ||
        required.rarities.isNotEmpty ||
        required.colors.isNotEmpty ||
        required.types.isNotEmpty ||
        required.pokemonCategories.isNotEmpty ||
        required.pokemonSubtypes.isNotEmpty ||
        required.pokemonRegulationMarks.isNotEmpty ||
        required.pokemonStages.isNotEmpty;
  }

  Future<Map<String, String>> _getAvailableSetCodes() async {
    final cached = _availableSetCodesCache;
    if (cached != null) {
      return cached;
    }
    final sets = await appRepositories.sets.fetchAvailableSets();
    final map = <String, String>{};
    for (final set in sets) {
      map[set.code.trim().toLowerCase()] = set.name.trim().isNotEmpty
          ? set.name.trim()
          : set.code.toUpperCase();
    }
    _availableSetCodesCache = map;
    return map;
  }

  Future<void> _loadSearchLanguages() async {
    if (!mounted) {
      return;
    }
    if (_query.isNotEmpty) {
      await _runSearch();
    }
  }

  List<CardSearchResult> _filteredResults() {
    final results = _results
        .where(
          (card) => !_missingCollectionQuantitiesByCardId.containsKey(card.id),
        )
        .toList(growable: false);
    if (_hasActiveAdvancedFilters()) {
      return results;
    }
    return results;
  }

  Future<Map<String, int>> _fetchMissingCollectionQuantities(
    List<CardSearchResult> cards,
  ) async {
    final missingCollectionId = widget.addMissingToCollectionId;
    if (missingCollectionId == null || cards.isEmpty) {
      return const {};
    }
    return ScryfallDatabase.instance.fetchCollectionQuantities(
      missingCollectionId,
      cards.map((card) => card.id).toList(growable: false),
    );
  }

  List<CardSearchResult> _excludeAlreadyMissingCards(
    List<CardSearchResult> cards,
    Map<String, int> missingQuantities,
  ) {
    if (missingQuantities.isEmpty) {
      return cards;
    }
    return cards
        .where((card) => !missingQuantities.containsKey(card.id))
        .toList(growable: false);
  }

  void _hideCardFromWishlistSearch(String cardId) {
    setState(() {
      _results = _results
          .where((card) => card.id != cardId)
          .toList(growable: false);
      _missingCollectionQuantitiesByCardId = {
        ..._missingCollectionQuantitiesByCardId,
        cardId: 1,
      };
    });
  }

  List<CardSearchResult> _applyPrefixWordFilter(
    List<CardSearchResult> input,
    String query,
  ) {
    if (_isPokemonSearch) {
      return input;
    }
    final queryTokens = _tokenizeSearch(query);
    if (queryTokens.isEmpty) {
      return input;
    }
    return input
        .where((card) => _matchesPrefixWordQuery(card, queryTokens))
        .toList(growable: false);
  }

  bool _matchesPrefixWordQuery(
    CardSearchResult card,
    List<String> queryTokens,
  ) {
    final nameTokens = _tokenizeSearch(card.name);
    final collector = card.collectorNumber.trim().toLowerCase();
    for (final token in queryTokens) {
      final matchesName = nameTokens.any((word) => word.startsWith(token));
      final matchesCollector = collector.startsWith(token);
      if (!matchesName && !matchesCollector) {
        return false;
      }
    }
    return true;
  }

  List<String> _tokenizeSearch(String value) {
    final normalized = _foldLatinDiacritics(value)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return const [];
    }
    return normalized.split(' ');
  }

  String _foldLatinDiacritics(String value) {
    const replacements = <String, String>{
      '\u00E0': 'a',
      '\u00E1': 'a',
      '\u00E2': 'a',
      '\u00E4': 'a',
      '\u00E3': 'a',
      '\u00E5': 'a',
      '\u00E7': 'c',
      '\u00E8': 'e',
      '\u00E9': 'e',
      '\u00EA': 'e',
      '\u00EB': 'e',
      '\u00EC': 'i',
      '\u00ED': 'i',
      '\u00EE': 'i',
      '\u00EF': 'i',
      '\u00F1': 'n',
      '\u00F2': 'o',
      '\u00F3': 'o',
      '\u00F4': 'o',
      '\u00F6': 'o',
      '\u00F5': 'o',
      '\u00F9': 'u',
      '\u00FA': 'u',
      '\u00FB': 'u',
      '\u00FC': 'u',
      '\u00FD': 'y',
      '\u00FF': 'y',
      '\u00C0': 'a',
      '\u00C1': 'a',
      '\u00C2': 'a',
      '\u00C4': 'a',
      '\u00C3': 'a',
      '\u00C5': 'a',
      '\u00C7': 'c',
      '\u00C8': 'e',
      '\u00C9': 'e',
      '\u00CA': 'e',
      '\u00CB': 'e',
      '\u00CC': 'i',
      '\u00CD': 'i',
      '\u00CE': 'i',
      '\u00CF': 'i',
      '\u00D1': 'n',
      '\u00D2': 'o',
      '\u00D3': 'o',
      '\u00D4': 'o',
      '\u00D6': 'o',
      '\u00D5': 'o',
      '\u00D9': 'u',
      '\u00DA': 'u',
      '\u00DB': 'u',
      '\u00DC': 'u',
      '\u00DD': 'y',
    };
    if (value.isEmpty) {
      return value;
    }
    final buffer = StringBuffer();
    for (final char in value.split('')) {
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }

  String _resultRarity(CardSearchResult card) {
    return card.rarity.trim().toLowerCase();
  }

  Set<String> _resultColors(CardSearchResult card) {
    return _parseColorSet(card.colors, card.colorIdentity, card.typeLine);
  }

  Set<String> _resultTypes(CardSearchResult card) {
    final typeLine = card.typeLine;
    if (typeLine.isEmpty) {
      return {};
    }
    final knownTypes = _isPokemonSearch
        ? const [
            'Pokemon',
            'Trainer',
            'Energy',
            'Item',
            'Supporter',
            'Stadium',
            'Tool',
            'Grass',
            'Fire',
            'Water',
            'Lightning',
            'Psychic',
            'Fighting',
            'Darkness',
            'Metal',
            'Dragon',
            'Fairy',
            'Colorless',
          ]
        : const [
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

  bool _hasActiveAdvancedFilters() {
    return _hasRequiredAdvancedFilters() ||
        _selectedLanguages.isNotEmpty ||
        _selectedRarities.isNotEmpty ||
        _selectedSetCodes.isNotEmpty ||
        _selectedColors.isNotEmpty ||
        _selectedTypes.isNotEmpty ||
        _selectedPokemonCategories.isNotEmpty ||
        _selectedPokemonRegulationMarks.isNotEmpty ||
        _selectedPokemonStages.isNotEmpty ||
        _collectorNumberQuery.trim().isNotEmpty ||
        _pokemonSubtypeQuery.trim().isNotEmpty ||
        _artistQuery.trim().isNotEmpty ||
        _manaValueMin != null ||
        _manaValueMax != null ||
        _hpMin != null ||
        _hpMax != null;
  }

  bool _hasNarrowingFilters() {
    return _hasRequiredAdvancedFilters() ||
        _selectedLanguages.isNotEmpty ||
        _selectedRarities.isNotEmpty ||
        _selectedSetCodes.isNotEmpty ||
        _selectedTypes.isNotEmpty ||
        _selectedColors.isNotEmpty ||
        _selectedPokemonCategories.isNotEmpty ||
        _selectedPokemonRegulationMarks.isNotEmpty ||
        _selectedPokemonStages.isNotEmpty ||
        _collectorNumberQuery.trim().isNotEmpty ||
        _pokemonSubtypeQuery.trim().isNotEmpty ||
        _artistQuery.trim().isNotEmpty;
  }

  String _colorLabel(String code) {
    final l10n = AppLocalizations.of(context)!;
    if (_isPokemonSearch) {
      switch (code.toUpperCase()) {
        case 'G':
          return l10n.pokemonEnergyGrass;
        case 'R':
          return l10n.pokemonEnergyFire;
        case 'U':
          return l10n.pokemonEnergyWater;
        case 'L':
          return l10n.pokemonEnergyLightning;
        case 'B':
          return l10n.pokemonEnergyPsychicDarkness;
        case 'F':
          return l10n.pokemonEnergyFighting;
        case 'D':
          return l10n.pokemonEnergyDragon;
        case 'W':
          return l10n.pokemonEnergyFairy;
        case 'C':
          return l10n.pokemonEnergyColorless;
        case 'M':
          return l10n.pokemonEnergyMetal;
        case 'N':
          return l10n.pokemonEnergyNone;
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

  String _typeLabel(String value) {
    if (!_isPokemonSearch) {
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

  Future<void> _bulkAddByFilters() async {
    if (!widget.selectionEnabled) {
      return;
    }
    if (!_hasActiveAdvancedFilters()) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.selectFiltersFirst,
      );
      return;
    }
    if (!_hasNarrowingFilters()) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.selectSetRarityTypeToNarrow,
      );
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final filter = _effectiveAdvancedFilter();
      final allResults = <CardSearchResult>[];
      const pageSize = 200;
      var offset = 0;
      while (true) {
        var page = await appRepositories.search.fetchCardsForAdvancedFilters(
          filter,
          gameId: _isPokemonSearch ? TcgGameId.pokemon : TcgGameId.mtg,
          searchQuery: _query.isEmpty ? null : _query,
          languages: _effectiveLanguages(),
          limit: pageSize,
          offset: offset,
        );
        final rawPageCount = page.length;
        final trimmedQuery = _query.trim();
        if (trimmedQuery.isNotEmpty) {
          page = _applyPrefixWordFilter(page, trimmedQuery);
        }
        if (page.isEmpty) {
          break;
        }
        allResults.addAll(page);
        if (rawPageCount < pageSize) {
          break;
        }
        offset += rawPageCount;
      }
      final filtered = allResults;
      if (!mounted) {
        return;
      }
      if (filtered.isEmpty) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.noCardsMatchFilters,
        );
        return;
      }
      final confirmed = await _confirmBulkAdd(filtered.length);
      if (!confirmed || !mounted) {
        return;
      }
      Navigator.of(context).pop(_CardSearchSelection.bulk(filtered));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<bool> _confirmBulkAdd(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.addAllResultsTitle),
          content: Text(l10n.addAllResultsBody(count)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.addAll),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Widget _buildSearchLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _searchLoadingController,
            builder: (context, _) {
              final t = _searchLoadingController.value * 3;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final delta = (t - index).abs();
                  final opacity = (1 - delta).clamp(0.25, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: opacity,
                      child: const Icon(
                        Icons.circle,
                        size: 8,
                        color: Color(0xFFE9C46A),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLimitedCoverageBadge() {
    final message = _limitedCoverageMessage();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x332A1E10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFB07C2A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFEFDDBA),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _limitedCoverageMessage() {
    final isItalian = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('it');
    final langs =
        _effectiveLanguages()
            .map((lang) => lang.trim().toLowerCase())
            .where((lang) => lang.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final readableLangs = langs.map((lang) => lang.toUpperCase()).join(', ');
    if (isItalian) {
      return 'Copertura locale limitata ($readableLangs). '
          'Per Pokemon, aggiorna o reimporta il catalogo locale per completare le lingue attive.';
    }
    return 'Limited local coverage ($readableLangs). '
        'For Pokemon, refresh or reimport the local catalog to complete the active languages.';
  }

  bool _isMissingCard(CardSearchResult card) {
    if (widget.ownershipCollectionId == null || _isDeckContext) {
      return false;
    }
    final quantity = _ownedQuantitiesByCardId[card.id] ?? 0;
    return quantity <= 0;
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

  String? _statusBadgeLabel(CardSearchResult card, AppLocalizations l10n) {
    final deckFormat = _deckFormatConstraint;
    if (deckFormat != null) {
      final isLegal = _deckLegalityByCardId[card.id] ?? false;
      return isLegal ? l10n.legalLabel : l10n.notLegalLabel;
    }
    return _isMissingCard(card) ? l10n.missingLabel : null;
  }

  void _onResultTap(CardSearchResult card) {
    if (widget.selectionEnabled) {
      Navigator.of(context).pop(_CardSearchSelection.single(card));
      return;
    }
    _showCardDetailsForSearch(card);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context)!;
    final sheetHeight = mediaQuery.size.height * 0.78;
    final listBottomPadding = widget.showFilterButton
        ? 112.0 + mediaQuery.padding.bottom
        : 80.0;
    final visibleResults = _filteredResults();
    final filtersActive = _hasActiveAdvancedFilters();
    final canSelectCards = widget.selectionEnabled;
    final showSummary = canSelectCards && filtersActive && !_showResults;
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF14110F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: sheetHeight,
            child: Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B3229),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.searchCardTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (!canSelectCards)
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _galleryView = !_galleryView;
                                });
                              },
                              icon: Icon(
                                _galleryView
                                    ? Icons.view_agenda_outlined
                                    : Icons.grid_view_rounded,
                              ),
                            ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    if (_limitedPrintCoverage)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                        child: Align(
                          alignment: Alignment.center,
                          child: _buildLimitedCoverageBadge(),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: l10n.typeCardNameHint,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _onlineArtworkLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    if (!canSelectCards)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (!_isPokemonSearch)
                                FilterChip(
                                  selected: _artworkSearchEnabled,
                                  onSelected: (value) async {
                                    setState(() {
                                      _artworkSearchEnabled = value;
                                    });
                                    if (_query.trim().isNotEmpty) {
                                      await _runSearch(forceRefresh: true);
                                    }
                                  },
                                  avatar: const Icon(
                                    Icons.star_outline_rounded,
                                    size: 18,
                                  ),
                                  label: Text(l10n.allArtworks),
                                ),
                              if (!_isPokemonSearch) const SizedBox(width: 10),
                              if (widget.ownershipCollectionId != null &&
                                  !_isDeckSearch)
                                FilterChip(
                                  selected: _ownedOnlyFilter,
                                  onSelected: (value) async {
                                    setState(() {
                                      _ownedOnlyFilter = value;
                                    });
                                    await _runSearch(forceRefresh: true);
                                  },
                                  avatar: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 18,
                                  ),
                                  label: Text(l10n.ownedLabel),
                                ),
                              if (widget.ownershipCollectionId != null &&
                                  _deckFormatConstraint != null)
                                const SizedBox(width: 10),
                              if (_deckFormatConstraint != null)
                                FilterChip(
                                  selected: _hideNotLegalFilter,
                                  onSelected: (value) async {
                                    setState(() {
                                      _hideNotLegalFilter = value;
                                    });
                                    await _runSearch(forceRefresh: true);
                                  },
                                  avatar: const Icon(
                                    Icons.gavel_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Legal'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (_onlineArtworkLoading)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.searchingOnlinePrintings,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFBFAE95)),
                            ),
                          ],
                        ),
                      ),
                    if (!showSummary &&
                        (_query.isNotEmpty ||
                            (filtersActive && _query.isEmpty)) &&
                        filtersActive &&
                        _filterTotalCount != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.filteredResultsSummary(
                            visibleResults.length,
                            _filterTotalCount!,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFBFAE95)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (!_loading && filtersActive && canSelectCards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: _bulkAddByFilters,
                          icon: const Icon(Icons.playlist_add_check),
                          label: Text(l10n.addFilteredCards),
                        ),
                      ),
                    Expanded(
                      child: _loading
                          ? _buildSearchLoadingState()
                          : visibleResults.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _query.isEmpty
                                        ? (filtersActive
                                              ? l10n.noCardsMatchFilters
                                              : l10n.startTypingToSearch)
                                        : l10n.noResultsFound,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_query.isNotEmpty ||
                                      (filtersActive && _query.isEmpty)) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      filtersActive
                                          ? l10n.tryRemovingChangingFilters
                                          : l10n.tryDifferentNameOrSpelling,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFFBFAE95),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : showSummary
                          ? Center(
                              child: Container(
                                margin: const EdgeInsets.all(24),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C1713),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF322A22),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.filteredResultsTitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    if (_countLoading)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        _filterTotalCount == null
                                            ? '-'
                                            : _filterTotalCount!.toString(),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineMedium,
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.filteredCardsCountLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFFBFAE95),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: _countLoading
                                                ? null
                                                : _bulkAddByFilters,
                                            child: Text(l10n.addAll),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _countLoading
                                                ? null
                                                : () async {
                                                    setState(() {
                                                      _showResults = true;
                                                    });
                                                    await _runSearch();
                                                  },
                                            child: Text(l10n.viewResults),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _galleryView
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                90,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.72,
                                  ),
                              itemCount: visibleResults.length,
                              itemBuilder: (context, index) {
                                final card = visibleResults[index];
                                return _buildGalleryCard(card, l10n);
                              },
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                listBottomPadding,
                              ),
                              itemCount:
                                  visibleResults.length +
                                  ((_loadingMore ||
                                          (!_loading &&
                                              _hasMore &&
                                              visibleResults.isNotEmpty))
                                      ? 1
                                      : 0),
                              separatorBuilder: (_, _) =>
                                  SizedBox(height: _showPrices ? 18 : 12),
                              itemBuilder: (context, index) {
                                if (index >= visibleResults.length) {
                                  if (_loadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Center(
                                    child: TextButton.icon(
                                      onPressed: _loading || !_hasMore
                                          ? null
                                          : () => _loadNextPage(_query),
                                      icon: const Icon(Icons.expand_more),
                                      label: Text(
                                        AppLocalizations.of(context)!.loadMore,
                                      ),
                                    ),
                                  );
                                }
                                final card = visibleResults[index];
                                return _buildResultTile(card, l10n);
                              },
                            ),
                    ),
                  ],
                ),
                if (widget.showFilterButton)
                  Positioned(
                    left: 20,
                    bottom: 16 + mediaQuery.padding.bottom,
                    child: FloatingActionButton(
                      heroTag: 'search_filters_fab',
                      onPressed: _showAdvancedFilters,
                      tooltip: l10n.filters,
                      backgroundColor: filtersActive
                          ? const Color(0xFFE9C46A)
                          : null,
                      foregroundColor: filtersActive
                          ? const Color(0xFF1C1510)
                          : null,
                      child: Icon(
                        filtersActive
                            ? Icons.filter_list_alt
                            : Icons.filter_list,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _ensureCardStored(CardSearchResult card) async {
    final existing = await ScryfallDatabase.instance.fetchCardEntryById(
      card.id,
      printingId: card.printingId,
    );
    if (existing != null) {
      return true;
    }
    final fetched = await _fetchAndUpsertCardById(card.id);
    if (fetched) {
      return true;
    }
    try {
      await ScryfallDatabase.instance.upsertCardFromScryfall(
        _minimalCardPayload(card),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _fetchAndUpsertCardById(String cardId) async {
    try {
      final uri = Uri.parse('https://api.scryfall.com/cards/$cardId');
      final response = await ScryfallApiClient.instance.get(
        uri,
        timeout: const Duration(seconds: 6),
        maxRetries: 2,
      );
      if (response.statusCode != 200) {
        return false;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return false;
      }
      await ScryfallDatabase.instance.upsertCardFromScryfall(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _minimalCardPayload(CardSearchResult card) {
    final colors = _splitColorCsv(card.colors);
    final colorIdentity = _splitColorCsv(card.colorIdentity);
    return {
      'id': card.id,
      'name': card.name,
      'set': card.setCode,
      'set_name': card.setName,
      'printed_total': card.setTotal,
      'collector_number': card.collectorNumber,
      'rarity': card.rarity,
      'type_line': card.typeLine,
      'colors': colors,
      'color_identity': colorIdentity,
      'image_uris': card.imageUri == null ? null : {'normal': card.imageUri},
      'lang': 'en',
    };
  }

  List<String> _splitColorCsv(String value) {
    if (value.trim().isEmpty) {
      return const [];
    }
    return value
        .split(',')
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
