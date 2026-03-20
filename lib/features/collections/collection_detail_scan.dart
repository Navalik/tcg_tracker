part of 'package:tcg_tracker/main.dart';

enum _AddCardEntryMode { byName, byScan, byFilter }

extension _CollectionDetailScanStateX on _CollectionDetailPageState {
  CollectionFilter? _requiredSearchFilter() {
    if (widget.isDeckCollection) {
      final format = widget.filter?.format?.trim().toLowerCase();
      if (format == null || format.isEmpty) {
        return null;
      }
      return CollectionFilter(format: format);
    }
    if (_isFilterCollection) {
      return _effectiveFilter();
    }
    return null;
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
        addToOwnershipCollectionDirectly: widget.isDeckCollection,
        ownershipCollectionId: widget.isDeckCollection
            ? ownedCollectionId
            : (_allCardsCollectionId ?? ownedCollectionId),
        customMembershipCollectionId: _isDirectCustomCollection
            ? widget.collectionId
            : null,
        requiredFilter: _requiredSearchFilter(),
        addMissingToCollectionId: _isWishlistCollection
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
      hpMin: base.hpMin ?? required.hpMin,
      hpMax: base.hpMax ?? required.hpMax,
      format: base.format ?? required.format,
      collectorNumber: base.collectorNumber ?? required.collectorNumber,
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

  Future<List<CardSearchResult>> _collectCardsForFilter(
    CollectionFilter filter, {
    int pageSize = 400,
  }) async {
    final cardsByPrintingKey = <String, CardSearchResult>{};
    var offset = 0;
    while (true) {
      final entries = await ScryfallDatabase.instance.fetchFilteredCollectionCards(
        filter,
        limit: pageSize,
        offset: offset,
      );
      if (entries.isEmpty) {
        break;
      }
      final batch = entries
          .map(
            (entry) => CardSearchResult(
              id: entry.cardId,
              printingId: entry.printingId,
              name: entry.name,
              setCode: entry.setCode,
              setName: entry.setName,
              collectorNumber: entry.collectorNumber,
              setTotal: entry.setTotal,
              rarity: entry.rarity,
              typeLine: entry.typeLine,
              colors: entry.colors,
              colorIdentity: entry.colorIdentity,
              priceUsd: entry.priceUsd,
              priceUsdFoil: entry.priceUsdFoil,
              priceEur: entry.priceEur,
              priceEurFoil: entry.priceEurFoil,
              imageUri: entry.imageUri,
            ),
          )
          .toList(growable: false);
      for (final card in batch) {
        final key = card.printingId ?? '${card.id}::legacy';
        cardsByPrintingKey[key] = card;
      }
      if (entries.length < pageSize) {
        break;
      }
      offset += entries.length;
    }
    return cardsByPrintingKey.values.toList(growable: false);
  }

  String _filterSelectionSummary(
    BuildContext context,
    int selectedCount,
    int totalCount,
  ) {
    final isItalian = Localizations.localeOf(context).languageCode == 'it';
    if (isItalian) {
      return 'Selezionate: $selectedCount / Totali: $totalCount';
    }
    return 'Selected: $selectedCount / Total: $totalCount';
  }

  Future<void> _showFilterCardImagePreview(
    BuildContext context,
    CardSearchResult card,
  ) async {
    final imageUrl = _normalizeCardImageUrlForDisplay(card.imageUri);
    if (imageUrl.isEmpty) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: theme.colorScheme.surface,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => SizedBox(
                          width: 220,
                          height: 300,
                          child: Icon(
                            Icons.style,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<CardSearchResult>?> _confirmCardsForFilterAdd(
    BuildContext context,
    List<CardSearchResult> cards,
  ) async {
    final result = await showDialog<List<CardSearchResult>>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final theme = Theme.of(dialogContext);
        final selectedKeys = <String>{
          for (final card in cards) card.printingId ?? card.id,
        };
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.addAllResultsTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.addAllResultsBody(cards.length)),
                const SizedBox(height: 12),
                Text(
                  _filterSelectionSummary(
                    dialogContext,
                    selectedKeys.length,
                    cards.length,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: selectedKeys.length == cards.length
                          ? null
                          : () {
                              setDialogState(() {
                                selectedKeys
                                  ..clear()
                                  ..addAll(
                                    cards.map((card) => card.printingId ?? card.id),
                                  );
                              });
                            },
                      child: Text(
                        Localizations.localeOf(dialogContext).languageCode == 'it'
                            ? 'Seleziona tutto'
                            : 'Select all',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: selectedKeys.isEmpty
                          ? null
                          : () {
                              setDialogState(() {
                                selectedKeys.clear();
                              });
                            },
                      child: Text(
                        Localizations.localeOf(dialogContext).languageCode == 'it'
                            ? 'Deseleziona tutto'
                            : 'Clear all',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Scrollbar(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: cards.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: theme.dividerColor.withValues(alpha: 0.35),
                        ),
                        itemBuilder: (itemContext, index) {
                          final card = cards[index];
                          final key = card.printingId ?? card.id;
                          final isSelected = selectedKeys.contains(key);
                          final imageUrl = _normalizeCardImageUrlForDisplay(
                            card.imageUri,
                          );
                          return ListTile(
                            dense: true,
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selectedKeys.remove(key);
                                } else {
                                  selectedKeys.add(key);
                                }
                              });
                            },
                            leading: GestureDetector(
                              onTap: () async {
                                await _showFilterCardImagePreview(
                                  dialogContext,
                                  card,
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: 36,
                                  height: 50,
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.style,
                                      size: 18,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              card.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${card.setName} • ${card.collectorProgressLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (_) {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedKeys.remove(key);
                                  } else {
                                    selectedKeys.add(key);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: selectedKeys.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(
                        cards
                            .where(
                              (card) => selectedKeys.contains(
                                card.printingId ?? card.id,
                              ),
                            )
                            .toList(growable: false),
                      ),
              child: Text(l10n.addLabel),
            ),
          ],
        ));
      },
    );
    return result;
  }

  Future<void> _addCardsByFilter(
    BuildContext context,
    int ownedCollectionId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.addMultipleCardsByFilterTitle;
    final selectedFilter = await Navigator.of(context).push<CollectionFilter>(
      MaterialPageRoute(
        builder: (_) => _CollectionFilterBuilderPage(
          name: title,
          submitLabel: l10n.addLabel,
          initialFilter: null,
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
    List<CardSearchResult> cards = const [];
    try {
      cards = await _collectCardsForFilter(filter);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      if (cards.isEmpty) {
        showAppSnackBar(context, AppLocalizations.of(context)!.noResultsFound);
        return;
      }
      final confirmedCards = await _confirmCardsForFilterAdd(context, cards);
      if (!context.mounted || confirmedCards == null) {
        return;
      }
      cards = confirmedCards;
      if (cards.isEmpty) {
        return;
      }
      if (_isWishlistCollection) {
        var added = 0;
        for (final card in cards) {
          final ownedQty = await _inventoryService.currentInventoryQty(
            card.id,
            printingId: card.printingId,
          );
          if (ownedQty > 0) {
            continue;
          }
          await ScryfallDatabase.instance.upsertCollectionMembership(
            widget.collectionId,
            card.id,
            printingId: card.printingId,
          );
          added += 1;
        }
        if (!context.mounted) {
          return;
        }
        showAppSnackBar(
          context,
          added > 0
              ? AppLocalizations.of(context)!.addedCards(added)
              : l10n.allSelectedCardsOwned,
        );
        await _loadCards();
        return;
      }
      if (_isDirectCustomCollection) {
        var added = 0;
        var skipped = 0;
        for (final card in cards) {
          await _inventoryService.addToInventory(
            card.id,
            printingId: card.printingId,
            deltaQty: 1,
          );
          await ScryfallDatabase.instance.upsertCollectionMembership(
            widget.collectionId,
            card.id,
            printingId: card.printingId,
          );
          added += 1;
        }
        if (!context.mounted) {
          return;
        }
        showAppSnackBar(
          context,
          skipped > 0
              ? '${l10n.addedCards(added)} • : $skipped'
              : l10n.addedCards(added),
        );
        await _loadCards();
        return;
      }
      var added = 0;
      for (final card in cards) {
        await _inventoryService.addToInventory(
          card.id,
          printingId: card.printingId,
          deltaQty: 1,
        );
        added += 1;
      }
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(context, AppLocalizations.of(context)!.addedCards(added));
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
        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            margin: _bottomSheetMenuMargin(context),
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
                  title: Text(l10n.addMultipleCardsByFilterTitle),
                  subtitle: Text(l10n.addMultipleCardsByFilterSubtitle),
                  onTap: () =>
                      Navigator.of(context).pop(_AddCardEntryMode.byFilter),
                ),
              ],
            ),
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
      limit: _CollectionDetailPageState._freeDailyScanLimit,
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
      limit: _CollectionDetailPageState._freeDailyScanLimit,
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
    if (_isPokemonActive) {
      final resolution = await PokemonScannerResolver.resolve(
        seed: ScannerOcrSeed(
          query: seed.query,
          cardName: seed.cardName,
          setCode: seed.setCode,
          collectorNumber: seed.collectorNumber,
          scannerLanguageCode: seed.scannerLanguageCode,
          isFoil: seed.isFoil,
        ),
        searchRepository: appRepositories.search,
      );
      if (!mounted || !context.mounted || resolution.candidates.isEmpty) {
        return seed;
      }
      final picked = await _pickCardPrintingForName(
        context,
        cardName,
        languages: seed.scannerLanguageCode == null
            ? const <String>['en']
            : <String>[seed.scannerLanguageCode!.trim().toLowerCase(), 'en'],
        preferredSetCode: seed.setCode,
        preferredCollectorNumber: seed.collectorNumber,
        candidatesOverride: resolution.candidates,
      );
      if (picked == null) {
        return _OcrSearchSeed(
          query: cardName,
          cardName: cardName,
          setCode: seed.setCode,
          collectorNumber: seed.collectorNumber,
          scannerLanguageCode: seed.scannerLanguageCode,
          isFoil: seed.isFoil,
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
        scannerLanguageCode: seed.scannerLanguageCode,
        isFoil: seed.isFoil,
      );
    }
    final activeGame =
        TcgEnvironmentController.instance.currentGame == TcgGame.pokemon
        ? AppTcgGame.pokemon
        : AppTcgGame.mtg;
    final cardLanguages = await AppSettings.loadCardLanguagesForGame(
      activeGame,
    );
    final fallbackScanLanguages = _scannerOnlineFallbackLanguagesForCollection(
      cardLanguages,
      scannerLanguageCode: seed.scannerLanguageCode,
    );
    final localBeforeSync = await ScryfallDatabase.instance
        .fetchCardsForAdvancedFilters(
          CollectionFilter(name: cardName),
          languages: fallbackScanLanguages,
          limit: 250,
        );
    final normalizedName = _normalizeCardNameForMatch(cardName);
    final localBeforeSyncKeys = localBeforeSync
        .where(
          (card) => _normalizeCardNameForMatch(card.name) == normalizedName,
        )
        .map(_printingKeyForCard)
        .toSet();
    if (localBeforeSyncKeys.length < 4) {
      await _syncOnlinePrintsByNameForCollectionScan(
        cardName,
        preferredLanguages: fallbackScanLanguages,
        timeBudget: const Duration(seconds: 2),
      );
    }
    if (!mounted || !context.mounted) {
      return seed;
    }
    var picked = await _pickCardPrintingForName(
      context,
      cardName,
      languages: fallbackScanLanguages,
      preferredSetCode: seed.setCode,
      preferredCollectorNumber: seed.collectorNumber,
      localPrintingKeys: localBeforeSyncKeys,
    );
    if (picked == null) {
      await _syncOnlinePrintsByNameForCollectionScan(
        cardName,
        preferredLanguages: fallbackScanLanguages,
        timeBudget: const Duration(seconds: 3),
      );
      if (mounted && context.mounted) {
        picked = await _pickCardPrintingForName(
          context,
          cardName,
          languages: fallbackScanLanguages,
          preferredSetCode: seed.setCode,
          preferredCollectorNumber: seed.collectorNumber,
          localPrintingKeys: localBeforeSyncKeys,
        );
      }
    }
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
    final sets = await appRepositories.sets.fetchAvailableSets();
    final known = sets
        .map((set) => set.code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    _cachedKnownSetCodesForScan = known;
    return known;
  }

  List<String> _scannerOnlineFallbackLanguagesForCollection(
    List<String> baseLanguages, {
    String? scannerLanguageCode,
  }) {
    final normalized = <String>{};
    for (final value in baseLanguages) {
      final language = value.trim().toLowerCase();
      if (language.isNotEmpty) {
        normalized.add(language);
      }
    }
    final scanner = scannerLanguageCode?.trim().toLowerCase();
    if (scanner != null && scanner.isNotEmpty) {
      normalized.add(scanner);
    }
    normalized.add('en');
    normalized.add('it');
    return normalized.toList(growable: false);
  }

  String _scryfallLanguageClauseForCollectionScan(List<String> languages) {
    final allowed = AppSettings.languageCodes
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final normalized = languages
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty && allowed.contains(value))
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return '(lang:en)';
    }
    return '(${normalized.map((lang) => 'lang:$lang').join(' or ')})';
  }

  Future<void> _syncOnlinePrintsByNameForCollectionScan(
    String cardName, {
    required List<String> preferredLanguages,
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
      final namedResponse = await ScryfallApiClient.instance.get(
        namedUri,
        timeout: const Duration(seconds: 2),
        maxRetries: 2,
      );
      String? oracleId;
      if (namedResponse.statusCode == 200) {
        final namedPayload = jsonDecode(namedResponse.body);
        if (namedPayload is Map<String, dynamic>) {
          await ScryfallDatabase.instance.upsertCardFromScryfall(namedPayload);
          oracleId = (namedPayload['oracle_id'] as String?)
              ?.trim()
              .toLowerCase();
        }
      }
      final languageClause = _scryfallLanguageClauseForCollectionScan(
        preferredLanguages,
      );
      Uri searchUri;
      if (oracleId != null && oracleId.isNotEmpty) {
        searchUri = Uri.parse(
          'https://api.scryfall.com/cards/search?q=${Uri.encodeQueryComponent('oracleid:$oracleId $languageClause unique:prints')}&order=released&dir=desc',
        );
      } else {
        searchUri = Uri.parse(
          'https://api.scryfall.com/cards/search?q=${Uri.encodeQueryComponent('!"$name" $languageClause unique:prints')}&order=released&dir=desc',
        );
      }
      await _importScryfallSearchPagesForCollectionScan(
        searchUri,
        deadline: deadline,
        maxPages: 2,
        maxImported: 120,
      );
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _importScryfallSearchPagesForCollectionScan(
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
      final response = await ScryfallApiClient.instance.get(
        nextUri,
        timeout: const Duration(seconds: 2),
        maxRetries: 2,
      );
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

  _OcrSearchSeed? _buildOcrSearchSeedForScan(
    String rawText, {
    required Set<String> knownSetCodes,
  }) {
    if (_isPokemonActive) {
      final parsed = PokemonScannerResolver.parseSeed(
        rawText,
        knownSetCodes: knownSetCodes,
      );
      if (parsed == null) {
        return null;
      }
      return _OcrSearchSeed(
        query: parsed.query,
        cardName: parsed.cardName,
        setCode: parsed.setCode,
        collectorNumber: parsed.collectorNumber,
        scannerLanguageCode: parsed.scannerLanguageCode,
        isFoil: parsed.isFoil,
      );
    }
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
    if (_isPokemonActive) {
      return seed;
    }
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
}
