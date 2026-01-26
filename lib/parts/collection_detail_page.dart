part of 'package:tcg_tracker/main.dart';

class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    required this.name,
    this.isAllCards = false,
    this.isSetCollection = false,
    this.setCode,
    this.autoOpenAddCard = false,
  });

  final int collectionId;
  final String name;
  final bool isAllCards;
  final bool isSetCollection;
  final String? setCode;
  final bool autoOpenAddCard;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}



class _CollectionDetailPageState extends State<CollectionDetailPage> {
  static const int _pageSize = 120;
  final List<CollectionCardEntry> _cards = [];
  final Map<String, Map<String, dynamic>?> _cardJsonCache = {};
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _loadedOffset = 0;
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
  bool _autoAddShown = false;
  Map<String, int> _setTotalsByCode = {};

  @override
  void initState() {
    super.initState();
    _loadCards();
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
      _cardJsonCache.clear();
      _setTotalsByCode = {};
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _loadMoreCards(initial: true);
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
    final cards = widget.isAllCards
        ? await ScryfallDatabase.instance.fetchOwnedCards(
            limit: _pageSize,
            offset: _loadedOffset,
          )
        : widget.isSetCollection
            ? await ScryfallDatabase.instance.fetchSetCollectionCards(
                widget.collectionId,
                widget.setCode ?? '',
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
    if (!widget.isSetCollection) {
      return _cards;
    }
    if (_searchQuery.isEmpty && _showOwned && _showMissing) {
      return _cards;
    }
    final queryLower = _searchQuery.toLowerCase();
    return _cards.where((entry) {
      if (queryLower.isNotEmpty) {
        final haystack =
            '${entry.name} ${entry.collectorNumber}'.toLowerCase();
        if (!haystack.contains(queryLower)) {
          return false;
        }
      }
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
    final data = _decodeCardJson(entry);
    if (data == null) {
      return {'C'};
    }
    final colors = (data['colors'] as List?)?.whereType<String>().toList() ??
        (data['color_identity'] as List?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    if (colors.isEmpty) {
      return {'C'};
    }
    return colors.map((code) => code.toUpperCase()).toSet();
  }

  Set<String> _cardTypes(CollectionCardEntry entry) {
    final data = _decodeCardJson(entry);
    final typeLine = data?['type_line']?.toString() ?? '';
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
    final data = _decodeCardJson(entry);
    final value = data?['cmc'];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
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
    final data = _decodeCardJson(entry);
    int? parseTotal(dynamic raw) {
      if (raw is num) {
        final value = raw.toInt();
        return value > 0 ? value : null;
      }
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
      return null;
    }

    if (data != null) {
      final direct = [
        data['printed_total'],
        data['set_total'],
        data['printedTotal'],
        data['setTotal'],
        data['total'],
      ];
      for (final raw in direct) {
        final parsed = parseTotal(raw);
        if (parsed != null) {
          return parsed;
        }
      }

      final setData = data['set'];
      if (setData is Map<String, dynamic>) {
        final nested = [
          setData['printed_total'],
          setData['set_total'],
          setData['printedTotal'],
          setData['setTotal'],
          setData['total'],
        ];
        for (final raw in nested) {
          final parsed = parseTotal(raw);
          if (parsed != null) {
            return parsed;
          }
        }
      }
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
    final ownedCount = _cards.where((entry) => entry.quantity > 0).length;
    final missingCount = _cards.length - ownedCount;
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
              setState(() {
                _searchQuery = value.trim();
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
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickAddCard(CollectionCardEntry entry) async {
    if (widget.isSetCollection) {
      final nextQuantity = entry.quantity + 1;
      await ScryfallDatabase.instance.upsertCollectionCard(
        widget.collectionId,
        entry.cardId,
        quantity: nextQuantity,
        foil: entry.foil,
        altArt: entry.altArt,
      );
    } else if (widget.isAllCards) {
      await ScryfallDatabase.instance
          .addCardToCollection(widget.collectionId, entry.cardId);
      await _syncAllCardsQuantities([entry.cardId]);
    } else {
      return;
    }
    await _loadCards();
  }

  Future<void> _applyQuantityToCollection(
    int collectionId,
    String cardId,
    int quantity, {
    required bool exists,
    required bool allowInsert,
  }) async {
    if (quantity <= 0) {
      await ScryfallDatabase.instance.deleteCollectionCard(
        collectionId,
        cardId,
      );
      return;
    }
    if (exists) {
      await ScryfallDatabase.instance.updateCollectionCard(
        collectionId,
        cardId,
        quantity: quantity,
      );
      return;
    }
    if (!allowInsert) {
      return;
    }
    await ScryfallDatabase.instance.upsertCollectionCard(
      collectionId,
      cardId,
      quantity: quantity,
      foil: false,
      altArt: false,
    );
  }

  Future<void> _syncAllCardsQuantities(List<String> cardIds) async {
    if (!widget.isAllCards || cardIds.isEmpty) {
      return;
    }
    final uniqueIds = cardIds.toSet().toList();
    final quantities = await ScryfallDatabase.instance.fetchCollectionQuantities(
      widget.collectionId,
      uniqueIds,
    );
    final setCodes =
        await ScryfallDatabase.instance.fetchSetCodesForCardIds(uniqueIds);
    final collections = await ScryfallDatabase.instance.fetchCollections();
    final setCollectionsByCode = <String, int>{};
    final isSetById = <int, bool>{};
    for (final collection in collections) {
      final isSet = collection.name.startsWith(_setPrefix);
      isSetById[collection.id] = isSet;
      if (!isSet) {
        continue;
      }
      final code =
          collection.name.substring(_setPrefix.length).trim().toLowerCase();
      if (code.isNotEmpty) {
        setCollectionsByCode[code] = collection.id;
      }
    }
    final existingByCard =
        await ScryfallDatabase.instance.fetchCollectionIdsForCardIds(uniqueIds);
    final setCollectionIds = isSetById.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();
    for (final cardId in uniqueIds) {
      final quantity = quantities[cardId] ?? 0;
      final setCode = setCodes[cardId]?.trim().toLowerCase();
      final setCollectionId = (setCode == null || setCode.isEmpty)
          ? null
          : setCollectionsByCode[setCode];
      if (setCollectionId != null) {
        final exists =
            (existingByCard[cardId] ?? const []).contains(setCollectionId);
        await _applyQuantityToCollection(
          setCollectionId,
          cardId,
          quantity,
          exists: exists,
          allowInsert: true,
        );
      }
      final existingIds = existingByCard[cardId] ?? const [];
      for (final collectionId in existingIds) {
        if (collectionId == widget.collectionId) {
          continue;
        }
        if (setCollectionId != null && collectionId == setCollectionId) {
          continue;
        }
        if (setCollectionIds.contains(collectionId)) {
          continue;
        }
        await _applyQuantityToCollection(
          collectionId,
          cardId,
          quantity,
          exists: true,
          allowInsert: false,
        );
      }
    }
  }

  Future<void> _addCard(BuildContext context) async {
    if (widget.isSetCollection) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.useListToSetOwnedQuantities,
      );
      return;
    }
    final selection = await showModalBottomSheet<_CardSearchSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CardSearchSheet(),
    );

    if (selection == null) {
      return;
    }

    if (selection.isBulk) {
      await ScryfallDatabase.instance.addCardsToCollection(
        widget.collectionId,
        selection.cardIds,
      );
      await _syncAllCardsQuantities(selection.cardIds);
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.addedCards(selection.count),
      );
    } else {
      await ScryfallDatabase.instance.addCardToCollection(
        widget.collectionId,
        selection.cardIds.first,
      );
      await _syncAllCardsQuantities([selection.cardIds.first]);
    }
    if (!mounted) {
      return;
    }
    await _loadCards();
  }

  Future<void> _showCardDetails(CollectionCardEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final details = _parseCardDetails(l10n, entry);
    final cardData = _decodeCardJson(entry);
    final typeLine = _safeCardField(cardData, 'type_line');
    final manaCost = _safeCardField(cardData, 'mana_cost');
    final oracleText = _safeCardField(cardData, 'oracle_text');
    final power = _safeCardField(cardData, 'power');
    final toughness = _safeCardField(cardData, 'toughness');
    final loyalty = _safeCardField(cardData, 'loyalty');
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
    final data = _decodeCardJson(entry);
    if (data == null) {
      return details.where((item) => item.value.isNotEmpty).toList();
    }
    void add(String label, dynamic value) {
      if (value == null) {
        return;
      }
      final text = value.toString().trim();
      if (text.isEmpty) {
        return;
      }
      details.add(_CardDetail(label, text));
    }

    add(l10n.detailRarity, data['rarity']);
    add(l10n.detailSetName, data['set_name']);
    add(l10n.detailLanguage, data['lang']);
    add(l10n.detailRelease, data['released_at']);
    add(l10n.detailArtist, data['artist']);
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

  Map<String, dynamic>? _decodeCardJson(CollectionCardEntry entry) {
    final cached = _cardJsonCache[entry.cardId];
    if (cached != null || _cardJsonCache.containsKey(entry.cardId)) {
      return cached;
    }
    final raw = entry.cardJson;
    if (raw == null || raw.isEmpty) {
      _cardJsonCache[entry.cardId] = null;
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _cardJsonCache[entry.cardId] = decoded;
        return decoded;
      }
    } catch (_) {
      // Ignore invalid JSON and cache the miss to avoid repeated work.
    }
    _cardJsonCache[entry.cardId] = null;
    return null;
  }

  String _safeCardField(Map<String, dynamic>? data, String key) {
    if (data == null) {
      return '';
    }
    final value = data[key];
    if (value == null) {
      return '';
    }
    return value.toString().trim();
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final quantityController =
            TextEditingController(text: entry.quantity.toString());
        var foil = entry.foil;
        var altArt = entry.altArt;
        final isSetCollection = widget.isSetCollection;
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
                          if (isSetCollection) {
                            await ScryfallDatabase.instance.upsertCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                              quantity: 0,
                              foil: foil,
                              altArt: altArt,
                            );
                          } else {
                            await ScryfallDatabase.instance.deleteCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                            );
                            if (widget.isAllCards) {
                              await _syncAllCardsQuantities([entry.cardId]);
                            }
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
                          isSetCollection ? l10n.markMissing : l10n.delete,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          final parsed =
                              int.tryParse(quantityController.text.trim()) ??
                                  entry.quantity;
                          final quantity = isSetCollection
                              ? (parsed < 0 ? 0 : parsed)
                              : (parsed < 1 ? 1 : parsed);
                          if (isSetCollection) {
                            await ScryfallDatabase.instance
                                .upsertCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                              quantity: quantity,
                              foil: foil,
                              altArt: altArt,
                            );
                          } else if (widget.isAllCards) {
                            await ScryfallDatabase.instance
                                .upsertCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                              quantity: quantity,
                              foil: foil,
                              altArt: altArt,
                            );
                            await _syncAllCardsQuantities([entry.cardId]);
                          } else {
                            await ScryfallDatabase.instance.updateCollectionCard(
                              widget.collectionId,
                              entry.cardId,
                              quantity: quantity,
                              foil: foil,
                              altArt: altArt,
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
    final visibleCards = _filteredCards();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.name),
        bottom: widget.isSetCollection
            ? PreferredSize(
                preferredSize: const Size.fromHeight(108),
                child: _buildSetHeader(),
              )
            : null,
        actions: [
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
                      widget.isSetCollection
                          ? l10n.noCardsMatchFilters
                          : widget.isAllCards
                              ? l10n.noOwnedCardsYet
                              : l10n.noCardsYet,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isSetCollection
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
                          widget.isSetCollection && entry.quantity == 0;
                      final hasCornerQuantity = entry.quantity > 1;
                      return GestureDetector(
                        onTap: () => _showCardDetails(entry),
                        onLongPress: () => _showCardActions(entry),
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
                                      if (widget.isSetCollection ||
                                          widget.isAllCards) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: l10n.addOne,
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          color: const Color(0xFFE9C46A),
                                          onPressed: () =>
                                              _quickAddCard(entry),
                                        ),
                                      ],
                                    ],
                                  ),
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
                          widget.isSetCollection && entry.quantity == 0;
                      return GestureDetector(
                        onTap: () => _showCardDetails(entry),
                        onLongPress: () => _showCardActions(entry),
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
                                            if (widget.isSetCollection ||
                                                widget.isAllCards)
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
      floatingActionButton: widget.isSetCollection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addCard(context),
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.addCard),
            ),
    );
  }
}

