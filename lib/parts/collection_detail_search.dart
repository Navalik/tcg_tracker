part of 'package:tcg_tracker/main.dart';

class _CardSearchSelection {
  _CardSearchSelection.single(CardSearchResult card)
      : cards = const [],
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

class _CardSearchSheet extends StatefulWidget {
  const _CardSearchSheet({
    this.initialQuery,
    this.initialSetCode,
    this.initialCollectorNumber,
    this.selectionEnabled = true,
    this.ownershipCollectionId,
  });

  final String? initialQuery;
  final String? initialSetCode;
  final String? initialCollectorNumber;
  final bool selectionEnabled;
  final int? ownershipCollectionId;

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
  final Set<String> _selectedColors = {};
  final Set<String> _selectedTypes = {};
  int? _manaValueMin;
  int? _manaValueMax;
  bool _showResults = true;
  bool _countLoading = false;
  int? _filterTotalCount;
  Map<String, String>? _availableSetCodesCache;
  Map<String, int> _ownedQuantitiesByCardId = const {};
  bool _galleryView = false;
  bool _artworkSearchEnabled = false;
  bool _ownedOnlyFilter = false;
  bool _onlineArtworkLoading = false;
  bool _addingFromPreview = false;

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
    _loadSearchLanguages();
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
    final value = _controller.text.trim();
    if (value == _query) {
      return;
    }
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final shouldFetchByFilters =
        _query.isEmpty && _hasActiveAdvancedFilters() && _hasNarrowingFilters();
    if (_query.isEmpty && !shouldFetchByFilters) {
      if (mounted) {
        setState(() {
          _results = [];
          _loading = false;
          _onlineArtworkLoading = false;
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
      await _runSearch();
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
    setState(() {
      _countLoading = true;
    });
    final filter = _buildAdvancedFilter();
    final total =
        await ScryfallDatabase.instance.countCardsForFilterWithSearch(
      filter,
      searchQuery: _query.isEmpty ? null : _query,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _filterTotalCount = total;
      _countLoading = false;
    });
  }

  List<String> _effectiveLanguages() {
    return const ['en'];
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
      final localResults = await ScryfallDatabase.instance.searchCardsByName(
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
      if (ownershipCollectionId != null && filteredLocal.isNotEmpty) {
        localOwnedQuantities = await ScryfallDatabase.instance.fetchCollectionQuantities(
          ownershipCollectionId,
          filteredLocal.map((card) => card.id).toList(growable: false),
        );
        if (_ownedOnlyFilter) {
          filteredLocal = filteredLocal
              .where((card) => (localOwnedQuantities[card.id] ?? 0) > 0)
              .toList(growable: false);
        }
      }
      if (!mounted || query != _query) {
        return;
      }
      setState(() {
        _results = filteredLocal;
        _ownedQuantitiesByCardId = localOwnedQuantities;
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
      final filter = _buildAdvancedFilter();
      page = await ScryfallDatabase.instance.fetchCardsForAdvancedFilters(
        filter,
        searchQuery: query.isEmpty ? null : query,
        languages: _effectiveLanguages(),
        limit: _pageSize,
        offset: _offset,
      );
    } else if (query.isEmpty) {
      page = await ScryfallDatabase.instance.fetchCardsForFilters(
        setCodes: _selectedSetCodes.toList(),
        rarities: _selectedRarities.toList(),
        types: _selectedTypes.toList(),
        languages: _effectiveLanguages(),
        limit: _pageSize,
        offset: _offset,
      );
    } else {
      page = await ScryfallDatabase.instance.searchCardsByName(
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
    final ownershipCollectionId = widget.ownershipCollectionId;
    if (ownershipCollectionId != null && page.isNotEmpty) {
      ownedQuantities = await ScryfallDatabase.instance.fetchCollectionQuantities(
        ownershipCollectionId,
        page.map((card) => card.id).toList(growable: false),
      );
      if (_ownedOnlyFilter) {
        page = page
            .where((card) => (ownedQuantities[card.id] ?? 0) > 0)
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
      } else {
        _results = [..._results, ...page];
        _ownedQuantitiesByCardId = {
          ..._ownedQuantitiesByCardId,
          ...ownedQuantities,
        };
      }
      _loading = false;
      _loadingMore = false;
      _onlineArtworkLoading = false;
      _offset += rawPageCount;
      _hasMore = hasMorePages && rawPageCount == _pageSize;
    });
  }

  Future<List<CardSearchResult>> _fetchOnlinePrintings(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    try {
      final collected = <CardSearchResult>[];
      final namedUri = Uri.parse(
        'https://api.scryfall.com/cards/named?fuzzy=${Uri.encodeQueryComponent(trimmed)}',
      );
      final namedResponse =
          await http.get(namedUri).timeout(const Duration(seconds: 4));
      String? oracleId;
      var resolvedName = '';
      if (namedResponse.statusCode == 200) {
        final namedPayload = jsonDecode(namedResponse.body);
        if (namedPayload is Map<String, dynamic>) {
          oracleId = (namedPayload['oracle_id'] as String?)?.trim();
          resolvedName =
              ((namedPayload['name'] as String?) ?? '').trim().replaceAll('"', '\\"');
        }
      }

      final rawEscaped = trimmed.replaceAll('"', '\\"');
      final prefixTokens = _tokenizeSearch(trimmed);
      final prefixQuery = prefixTokens
          .map((token) => 'name:$token*')
          .join(' ');
      if (resolvedName.isNotEmpty &&
          oracleId != null &&
          oracleId.isNotEmpty) {
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
      if (resolvedName.isNotEmpty &&
          oracleId != null &&
          oracleId.isNotEmpty) {
        queryCandidates
            .add('!"$resolvedName" oracleid:$oracleId include:extras');
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
    Uri buildSearchUri(String q) {
      return Uri.https('api.scryfall.com', '/cards/search', {
        'q': q,
        'order': 'released',
        'dir': 'desc',
        'unique': 'prints',
        'include_extras': 'true',
        'include_multilingual': 'false',
        'include_variations': 'true',
      });
    }

    var nextUri = buildSearchUri(query);
    final results = <CardSearchResult>[];
    var page = 0;
    while (page < maxPages) {
      final response = await http.get(nextUri).timeout(const Duration(seconds: 10));
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
    final lang = (raw['lang'] as String?)?.trim().toLowerCase();
    if (lang != null && lang.isNotEmpty && lang != 'en') {
      return null;
    }
    final id = (raw['id'] as String?)?.trim() ?? '';
    final name = (raw['name'] as String?)?.trim() ?? '';
    final setCode = (raw['set'] as String?)?.trim().toLowerCase() ?? '';
    final collector = (raw['collector_number'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty || setCode.isEmpty || collector.isEmpty) {
      return null;
    }
    final setName = (raw['set_name'] as String?)?.trim() ?? '';
    final rarity = (raw['rarity'] as String?)?.trim().toLowerCase() ?? '';
    final typeLine = (raw['type_line'] as String?)?.trim() ?? '';
    final colors = _codesToCsv(raw['colors']);
    final colorIdentity = _codesToCsv(raw['color_identity']);
    return CardSearchResult(
      id: id,
      name: name,
      setCode: setCode,
      setName: setName,
      collectorNumber: collector,
      rarity: rarity,
      typeLine: typeLine,
      colors: colors,
      colorIdentity: colorIdentity,
      imageUri: _extractScryfallImageUri(raw),
    );
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
      return _collectorSortKey(a.collectorNumber)
          .compareTo(_collectorSortKey(b.collectorNumber));
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
      sets: _selectedSetCodes,
      rarities: _selectedRarities,
      colors: _selectedColors,
      types: _selectedTypes,
    );
  }

  Future<Map<String, String>> _getAvailableSetCodes() async {
    final cached = _availableSetCodesCache;
    if (cached != null) {
      return cached;
    }
    final sets = await ScryfallDatabase.instance.fetchAvailableSets();
    final map = <String, String>{};
    for (final set in sets) {
      map[set.code.trim().toLowerCase()] =
          set.name.trim().isNotEmpty ? set.name.trim() : set.code.toUpperCase();
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
    if (_hasActiveAdvancedFilters()) {
      return _results;
    }
    return _results;
  }

  List<CardSearchResult> _applyPrefixWordFilter(
    List<CardSearchResult> input,
    String query,
  ) {
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
    final normalized = value
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

  String _resultRarity(CardSearchResult card) {
    return card.rarity.trim().toLowerCase();
  }

  Set<String> _resultColors(CardSearchResult card) {
    return _parseColorSet(card.colors, card.colorIdentity);
  }

  Set<String> _resultTypes(CardSearchResult card) {
    final typeLine = card.typeLine;
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

  bool _hasActiveAdvancedFilters() {
    return _selectedRarities.isNotEmpty ||
        _selectedSetCodes.isNotEmpty ||
        _selectedColors.isNotEmpty ||
        _selectedTypes.isNotEmpty ||
        _artistQuery.trim().isNotEmpty ||
        _manaValueMin != null ||
        _manaValueMax != null;
  }

  bool _hasNarrowingFilters() {
    return _selectedRarities.isNotEmpty ||
        _selectedSetCodes.isNotEmpty ||
        _selectedTypes.isNotEmpty ||
        _selectedColors.isNotEmpty ||
        _artistQuery.trim().isNotEmpty;
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

  Future<void> _showAdvancedFilters() async {
    final availableRarities = <String>{};
    final availableSetCodes = <String, String>{};
    final availableColors = <String>{};
    final availableTypes = <String>{};

    const fallbackRarities = ['common', 'uncommon', 'rare', 'mythic'];
    const fallbackColors = ['W', 'U', 'B', 'R', 'G', 'C'];
    const fallbackTypes = [
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

    if (_results.isEmpty) {
      availableRarities.addAll(fallbackRarities);
      availableColors.addAll(fallbackColors);
      availableTypes.addAll(fallbackTypes);
    } else {
      for (final card in _results) {
        final rarity = _resultRarity(card);
        if (rarity.isNotEmpty) {
          availableRarities.add(rarity);
        }
        availableColors.addAll(_resultColors(card));
        availableTypes.addAll(_resultTypes(card));
      }
    }

    final sets = await _getAvailableSetCodes();
    availableSetCodes.addAll(sets);

    if (_selectedSetCodes.isNotEmpty) {
      final missing = _selectedSetCodes
          .where((code) => !availableSetCodes.containsKey(code))
          .toList();
      if (missing.isNotEmpty) {
        final names =
            await ScryfallDatabase.instance.fetchSetNamesForCodes(missing);
        for (final entry in names.entries) {
          availableSetCodes[entry.key.trim().toLowerCase()] =
              entry.value.trim().isNotEmpty
                  ? entry.value.trim()
                  : entry.key.toUpperCase();
        }
      }
    }

    if (!mounted) {
      return;
    }

    final tempRarities = _selectedRarities.toSet();
    final tempSetCodes = _selectedSetCodes.toSet();
    final tempColors = _selectedColors.toSet();
    final tempTypes = _selectedTypes.toSet();
    final nameController = TextEditingController(text: _query);
    final artistController = TextEditingController(text: _artistQuery);
    List<String> artistSuggestions = [];
    bool loadingArtists = false;
    Timer? artistDebounce;
    final minController =
        TextEditingController(text: _manaValueMin?.toString() ?? '');
    final maxController =
        TextEditingController(text: _manaValueMax?.toString() ?? '');
    var setQuery = '';
    var typeQuery = '';

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
            final filteredRarities = sortedRarities;
            final filteredColors = sortedColors;
            final filteredTypes = sortedTypes
                .where((value) => value.toLowerCase().contains(typeQuery))
                .toList();

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
                    const SizedBox(height: 8),
                    Text(
                      l10n.cardName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: l10n.typeCardNameHint,
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    if (sortedRarities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.rarity,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        filteredRarities,
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
                        filteredColors,
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
                      TextField(
                        decoration: InputDecoration(
                          hintText: l10n.searchHint,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            typeQuery = value.trim().toLowerCase();
                          });
                        },
                      ),
                      if (typeQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        buildChipRow<String>(
                          filteredTypes,
                          (value) => tempTypes.contains(value),
                          (value) {
                            if (!tempTypes.add(value)) {
                              tempTypes.remove(value);
                            }
                          },
                          (value) => value,
                        ),
                      ],
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
                    const SizedBox(height: 16),
                    Text(
                      l10n.detailArtist,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: artistController,
                      decoration: InputDecoration(
                        hintText: l10n.typeArtistNameHint,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      onChanged: (value) {
                        artistDebounce?.cancel();
                        final query = value.trim();
                        if (query.isEmpty) {
                          setSheetState(() {
                            artistSuggestions = [];
                            loadingArtists = false;
                          });
                          return;
                        }
                        artistDebounce =
                            Timer(const Duration(milliseconds: 250), () async {
                          setSheetState(() {
                            loadingArtists = true;
                          });
                          final results = await ScryfallDatabase.instance
                              .fetchAvailableArtists(query: query);
                          setSheetState(() {
                            artistSuggestions = results;
                            loadingArtists = false;
                          });
                        });
                      },
                    ),
                    if (artistController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      if (loadingArtists)
                        const Center(child: CircularProgressIndicator())
                      else if (artistSuggestions.isNotEmpty)
                        SizedBox(
                          height: artistSuggestions.length > 6 ? 180 : null,
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: artistSuggestions.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final artist = artistSuggestions[index];
                              return ListTile(
                                title: Text(artist),
                                onTap: () {
                                  setSheetState(() {
                                    artistController.text = artist;
                                    artistController.selection =
                                        TextSelection.collapsed(
                                            offset: artist.length);
                                    artistSuggestions = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                    ],
                    if (sortedRarities.isEmpty &&
                        sortedSets.isEmpty &&
                        sortedColors.isEmpty &&
                        sortedTypes.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(l10n.noFiltersAvailable),
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
                              nameController.clear();
                              artistController.clear();
                              artistSuggestions = [];
                              loadingArtists = false;
                              minController.clear();
                              maxController.clear();
                              setQuery = '';
                              typeQuery = '';
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

    artistDebounce?.cancel();
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
      _artistQuery = artistController.text.trim();
      _manaValueMin = minValue;
      _manaValueMax = maxValue;
    });
    final nameValue = nameController.text.trim();
    if (_controller.text.trim() != nameValue) {
      _controller.value = _controller.value.copyWith(
        text: nameValue,
        selection: TextSelection.collapsed(offset: nameValue.length),
      );
    }
    _query = nameValue;
    _showResults = true;
    await _runSearch();
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
      final filter = _buildAdvancedFilter();
      final allResults = <CardSearchResult>[];
      const pageSize = 200;
      var offset = 0;
      while (true) {
        final page =
            await ScryfallDatabase.instance.fetchCardsForAdvancedFilters(
          filter,
          searchQuery: _query.isEmpty ? null : _query,
          languages: _effectiveLanguages(),
          limit: pageSize,
          offset: offset,
        );
        if (page.isEmpty) {
          break;
        }
        allResults.addAll(page);
        if (page.length < pageSize) {
          break;
        }
        offset += page.length;
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

  bool _isMissingCard(CardSearchResult card) {
    if (widget.ownershipCollectionId == null) {
      return false;
    }
    final quantity = _ownedQuantitiesByCardId[card.id] ?? 0;
    return quantity <= 0;
  }

  void _onResultTap(CardSearchResult card) {
    if (widget.selectionEnabled) {
      Navigator.of(context).pop(_CardSearchSelection.single(card));
      return;
    }
    _showPreview(card);
  }

  Widget _buildGalleryCard(CardSearchResult card, AppLocalizations l10n) {
    final isMissing = _isMissingCard(card);
    final imageUrl = card.imageUri?.trim() ?? '';
    return InkWell(
      onTap: () => _onResultTap(card),
      onLongPress: () => _showPreview(card),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1713),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF322A22)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Positioned.fill(
                child: (imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0x221C1713),
                          alignment: Alignment.center,
                          child: _buildSetIcon(card.setCode, size: 30),
                        ),
                      )
                    : Container(
                        color: const Color(0x221C1713),
                        alignment: Alignment.center,
                        child: _buildSetIcon(card.setCode, size: 30),
                      ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xCC14110F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    card.subtitleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFE6D2B6),
                        ),
                  ),
                ),
              ),
              if (!widget.selectionEnabled && isMissing)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC7A2222),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x99D96C6C)),
                    ),
                    child: Text(
                      l10n.missingLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFFFB3B3),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context)!;
    final sheetHeight = mediaQuery.size.height * 0.78;
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                if (!canSelectCards)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          selected: _artworkSearchEnabled,
                          onSelected: (value) async {
                            setState(() {
                              _artworkSearchEnabled = value;
                            });
                            if (_query.trim().isNotEmpty) {
                              await _runSearch();
                            }
                          },
                          avatar: const Icon(Icons.style_outlined, size: 18),
                          label: const Text('Artwork (online)'),
                        ),
                        if (widget.ownershipCollectionId != null)
                          FilterChip(
                            selected: _ownedOnlyFilter,
                            onSelected: (value) async {
                              setState(() {
                                _ownedOnlyFilter = value;
                              });
                              await _runSearch();
                            },
                            avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                            label: const Text('Owned'),
                          ),
                      ],
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
                          'Searching online printings...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFBFAE95),
                              ),
                        ),
                      ],
                    ),
                  ),
                if (!showSummary &&
                    (_query.isNotEmpty || (filtersActive && _query.isEmpty)) &&
                    filtersActive &&
                    _filterTotalCount != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.filteredResultsSummary(
                        visibleResults.length,
                        _filterTotalCount!,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFBFAE95),
                          ),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
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
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium,
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
                                        16,
                                        0,
                                        16,
                                        90,
                                      ),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 63.5 / 88.9,
                                      ),
                                      itemCount: visibleResults.length,
                                      itemBuilder: (context, index) {
                                        final card = visibleResults[index];
                                        return _buildGalleryCard(card, l10n);
                                      },
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        80,
                                      ),
                                      itemCount: visibleResults.length +
                                          ((_loadingMore ||
                                                      (!_loading &&
                                                          _hasMore &&
                                                          visibleResults.isNotEmpty))
                                                  ? 1
                                                  : 0),
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 10),
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
                                                  : () => _loadNextPage(
                                                        _query,
                                                      ),
                                              icon: const Icon(Icons.expand_more),
                                              label: Text(
                                                AppLocalizations.of(context)!.loadMore,
                                              ),
                                            ),
                                          );
                                        }
                                        final card = visibleResults[index];
                                        final isMissing = _isMissingCard(card);
                                        return InkWell(
                                          onTap: () => _onResultTap(card),
                                          onLongPress: () => _showPreview(card),
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1C1713),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFF322A22),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                _buildSetIcon(card.setCode, size: 24),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        card.name,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        card.subtitleLabel,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: const Color(
                                                                0xFFBFAE95,
                                                              ),
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (canSelectCards)
                                                  const Icon(
                                                    Icons.add,
                                                    color: Color(0xFFE9C46A),
                                                  )
                                                else if (isMissing)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0x33D96C6C),
                                                      borderRadius:
                                                          BorderRadius.circular(999),
                                                      border: Border.all(
                                                        color: const Color(0x66D96C6C),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      l10n.missingLabel,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                const Color(0xFFFFA6A6),
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                  )
                                                else
                                                  const Icon(
                                                    Icons.visibility_outlined,
                                                    color: Color(0xFFBFAE95),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                ),
                    ],
                  ),
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
                        filtersActive ? Icons.filter_list_alt : Icons.filter_list,
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

  void _showPreview(CardSearchResult card) {
    final imageUrl = card.imageUri ?? '';
    if (imageUrl.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    _hidePreview(immediate: true);

    final overlay = Overlay.of(context, rootOverlay: true);

    _previewController.value = 0;
    _previewEntry = OverlayEntry(
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final maxWidth = size.width * 0.82;
        final maxHeight = size.height * 0.82;

        return Material(
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(
            child: FadeTransition(
              opacity: _previewOpacity,
              child: ScaleTransition(
                scale: _previewScale,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth.clamp(240, 460),
                    maxHeight: maxHeight.clamp(360, 760),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0C0A),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF3A2F24),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) {
                                      return child;
                                    }
                                    return const SizedBox(
                                      height: 420,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox(
                                      height: 420,
                                      child: Center(
                                        child: Icon(Icons.broken_image, size: 48),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (widget.ownershipCollectionId != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _addingFromPreview
                                          ? null
                                          : () => _addCardFromPreview(card),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add to collection'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: const Color(0xB314110F),
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: 'Close preview',
                                onPressed: () => _hidePreview(immediate: false),
                                icon: const Icon(Icons.close),
                              ),
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
      },
    );

    overlay.insert(_previewEntry!);
    _previewController.forward();
  }

  Future<void> _hidePreview({required bool immediate}) async {
    if (_previewEntry == null) {
      return;
    }
    if (!immediate) {
      await _previewController.reverse();
    }
    _previewEntry?.remove();
    _previewEntry = null;
  }

  Future<void> _addCardFromPreview(CardSearchResult card) async {
    final collectionId = widget.ownershipCollectionId;
    if (collectionId == null || _addingFromPreview) {
      return;
    }
    setState(() {
      _addingFromPreview = true;
    });
    try {
      await ScryfallDatabase.instance.addCardToCollection(collectionId, card.id);
      if (!mounted) {
        return;
      }
      final current = _ownedQuantitiesByCardId[card.id] ?? 0;
      setState(() {
        _ownedQuantitiesByCardId = {
          ..._ownedQuantitiesByCardId,
          card.id: current + 1,
        };
      });
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.addedCards(1),
      );
      await _hidePreview(immediate: false);
    } finally {
      if (mounted) {
        setState(() {
          _addingFromPreview = false;
        });
      }
    }
  }
}

