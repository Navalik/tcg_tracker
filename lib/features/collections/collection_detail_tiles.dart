// ignore_for_file: invalid_use_of_protected_member

part of 'package:tcg_tracker/main.dart';

extension _CollectionDetailTileStateX on _CollectionDetailPageState {
  bool _matchesCollectionEntry(
    CollectionCardEntry a,
    CollectionCardEntry b,
  ) {
    return a.cardId == b.cardId &&
        (a.printingId?.trim() ?? '') == (b.printingId?.trim() ?? '');
  }

  CollectionCardEntry _copyCollectionEntryWithQuantity(
    CollectionCardEntry entry,
    int quantity,
  ) {
    return CollectionCardEntry(
      cardId: entry.cardId,
      printingId: entry.printingId,
      name: entry.name,
      setCode: entry.setCode,
      setName: entry.setName,
      setTotal: entry.setTotal,
      collectorNumber: entry.collectorNumber,
      rarity: entry.rarity,
      typeLine: entry.typeLine,
      manaCost: entry.manaCost,
      oracleText: entry.oracleText,
      manaValue: entry.manaValue,
      lang: entry.lang,
      artist: entry.artist,
      power: entry.power,
      toughness: entry.toughness,
      loyalty: entry.loyalty,
      colors: entry.colors,
      colorIdentity: entry.colorIdentity,
      releasedAt: entry.releasedAt,
      quantity: quantity,
      foil: entry.foil,
      altArt: entry.altArt,
      priceUsd: entry.priceUsd,
      priceUsdFoil: entry.priceUsdFoil,
      priceUsdEtched: entry.priceUsdEtched,
      priceEur: entry.priceEur,
      priceEurFoil: entry.priceEurFoil,
      priceTix: entry.priceTix,
      pricesUpdatedAt: entry.pricesUpdatedAt,
      imageUri: entry.imageUri,
    );
  }

  void _applyQuickInventoryUpdateLocally(
    CollectionCardEntry entry, {
    required int nextQuantity,
    bool removeFromList = false,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      final index = _cards.indexWhere((item) => _matchesCollectionEntry(item, entry));
      final previousQuantity = index == -1 ? entry.quantity : _cards[index].quantity;
      final wasOwned = previousQuantity > 0;
      final isOwned = nextQuantity > 0;

      if (_isFilterCollection && wasOwned != isOwned) {
        if (isOwned) {
          _ownedCount = (_ownedCount ?? 0) + 1;
          if (_missingCount != null && _missingCount! > 0) {
            _missingCount = _missingCount! - 1;
          }
        } else {
          if (_ownedCount != null && _ownedCount! > 0) {
            _ownedCount = _ownedCount! - 1;
          }
          _missingCount = (_missingCount ?? 0) + 1;
        }
      }

      if (_isWishlistCollection && removeFromList) {
        if (index != -1) {
          _cards.removeAt(index);
        }
        if (_missingCount != null && _missingCount! > 0) {
          _missingCount = _missingCount! - 1;
        }
        return;
      }

      final shouldRemainVisible =
          (_showOwned && _showMissing) ||
          (_showOwned && isOwned) ||
          (_showMissing && !isOwned);
      final shouldRemoveWhenEmpty =
          !_isFilterCollection && !_isWishlistCollection && nextQuantity <= 0;

      if (index == -1) {
        return;
      }
      if (!shouldRemainVisible || removeFromList || shouldRemoveWhenEmpty) {
        _cards.removeAt(index);
        return;
      }
      _cards[index] = _copyCollectionEntryWithQuantity(entry, nextQuantity);
    });

    unawaited(_refreshCounts());
    if (_hasMore && _cards.length < _CollectionDetailPageState._pageSize) {
      unawaited(_loadMoreCards());
    }
  }

  Future<void> _quickAddCard(
    CollectionCardEntry entry, {
    BuildContext? anchorContext,
  }) async {
    final ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null) {
      return;
    }
    if (_isWishlistCollection) {
      await ScryfallDatabase.instance.deleteCollectionCard(
        widget.collectionId,
        entry.cardId,
        printingId: entry.printingId,
      );
      await _inventoryService.addToInventory(
        entry.cardId,
        printingId: entry.printingId,
        deltaQty: 1,
      );
      _applyQuickInventoryUpdateLocally(entry, nextQuantity: 0, removeFromList: true);
    } else if (widget.isDeckCollection) {
      final nextQuantity = entry.quantity + 1;
      await ScryfallDatabase.instance.upsertCollectionCard(
        ownedCollectionId,
        entry.cardId,
        printingId: entry.printingId,
        quantity: nextQuantity,
        foil: false,
        altArt: entry.altArt,
      );
      _applyQuickInventoryUpdateLocally(entry, nextQuantity: nextQuantity);
    } else {
      await _inventoryService.addToInventory(
        entry.cardId,
        printingId: entry.printingId,
        deltaQty: 1,
      );
      _applyQuickInventoryUpdateLocally(
        entry,
        nextQuantity: entry.quantity + 1,
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
  }

  Future<void> _quickRemoveCard(
    CollectionCardEntry entry, {
    BuildContext? anchorContext,
  }) async {
    final ownedCollectionId = _ownedCollectionId;
    if (ownedCollectionId == null ||
        _isWishlistCollection ||
        entry.quantity <= 0) {
      return;
    }
    if (widget.isDeckCollection) {
      final nextQuantity = entry.quantity - 1;
      await ScryfallDatabase.instance.upsertCollectionCard(
        ownedCollectionId,
        entry.cardId,
        printingId: entry.printingId,
        quantity: nextQuantity,
        foil: false,
        altArt: nextQuantity == 0 ? false : entry.altArt,
      );
      _applyQuickInventoryUpdateLocally(entry, nextQuantity: nextQuantity);
    } else {
      await _inventoryService.removeFromInventory(
        entry.cardId,
        printingId: entry.printingId,
        deltaQty: 1,
      );
      _applyQuickInventoryUpdateLocally(
        entry,
        nextQuantity: entry.quantity - 1,
      );
    }
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
  }

  static const double _galleryActionHeight = 42;

  ButtonStyle _galleryQuickActionStyle() {
    return IconButton.styleFrom(
      backgroundColor: const Color(0xCC1C1510),
      foregroundColor: const Color(0xFFE9C46A),
      disabledBackgroundColor: const Color(0x991C1510),
      disabledForegroundColor: const Color(0xFF8A7A62),
      side: const BorderSide(color: Color(0xFF5D4731), width: 1),
      shape: const CircleBorder(),
      padding: EdgeInsets.zero,
      minimumSize: const Size(_galleryActionHeight, _galleryActionHeight),
      fixedSize: const Size(_galleryActionHeight, _galleryActionHeight),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _galleryMissingBadge(AppLocalizations l10n) {
    return IgnorePointer(
      child: Container(
        height: _galleryActionHeight,
        constraints: const BoxConstraints(minWidth: 92),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xCC1C1510),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF5D4731), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          l10n.missingLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFFE9C46A),
            fontWeight: FontWeight.w800,
            fontSize: 15,
            height: 1,
            letterSpacing: 0.35,
          ),
        ),
      ),
    );
  }

  Widget _buildListCardTile(CollectionCardEntry entry, AppLocalizations l10n) {
    final isMissing =
        _isMissingStyleCollection &&
        !_isWishlistCollection &&
        entry.quantity == 0;
    final deckLegality = widget.isDeckCollection
        ? _deckLegalityByCardId[entry.cardId]
        : null;
    final cornerStatusLabel = isMissing
        ? l10n.missingLabel
        : (widget.isDeckCollection && deckLegality != null
              ? (deckLegality ? l10n.legalLabel : l10n.notLegalLabel)
              : null);
    final cornerStatusColor = isMissing
        ? const Color(0xFFE9C46A)
        : (deckLegality ?? true)
        ? const Color(0xFFE9C46A)
        : const Color(0xFFD06D5F);
    final cornerStatusDx = deckLegality == null
        ? 0.0
        : (deckLegality ? -6.0 : -2.0);
    final showQuickAddButton =
        widget.isDeckCollection ||
        _isMissingStyleCollection ||
        widget.isAllCards;
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
              right: showQuickAddButton ? 132 : 122,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(child: _buildSetIcon(entry.setCode, size: 60)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: showQuickAddButton ? 56 : 0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w500,
                                          height: 1.05,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Builder(
                              builder: (context) {
                                final setLabel = _setLabelForEntry(entry);
                                final progress = _collectorProgressLabel(entry);
                                final hasRarity = entry.rarity
                                    .trim()
                                    .isNotEmpty;
                                final leftLabel = setLabel.isNotEmpty
                                    ? setLabel
                                    : progress;
                                final metaStyle = Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFFBFAE95),
                                      fontSize: 21,
                                      fontWeight: FontWeight.w400,
                                      height: 1.0,
                                    );
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        leftLabel,
                                        style: metaStyle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (progress.isNotEmpty &&
                                        setLabel.isNotEmpty)
                                      Text(progress, style: metaStyle),
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
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showQuickAddButton)
            Positioned(
              right: 12,
              top: 10,
              height: 80,
              child: Align(
                alignment: Alignment.centerRight,
                child: Builder(
                  builder: (buttonContext) {
                    final isAnimating = _quickAddAnimating.contains(
                      entry.cardId,
                    );
                    return IconButton(
                      tooltip: l10n.addOne,
                      style: _galleryQuickActionStyle(),
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
              ),
            ),
          if (cornerStatusLabel != null)
            Positioned(
              right: deckLegality != null ? 0 : 16,
              bottom: 24,
              child: SizedBox(
                width: deckLegality != null ? 64 : null,
                child: Transform.translate(
                  offset: Offset(cornerStatusDx, 0),
                  child: Align(
                    alignment: Alignment.center,
                    child: _buildCardCornerTextLabel(
                      context,
                      cornerStatusLabel,
                      color: cornerStatusColor,
                    ),
                  ),
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
        !_isWishlistCollection &&
        entry.quantity == 0;
    final deckLegality = widget.isDeckCollection
        ? _deckLegalityByCardId[entry.cardId]
        : null;
    final deckLegalityLabel = deckLegality == null
        ? null
        : (deckLegality ? l10n.legalLabel : l10n.notLegalLabel);
    final hasCornerQuantity = entry.quantity > 1;
    final showQuickAdd =
        _isWishlistCollection ||
        widget.isAllCards ||
        (!isMissing && entry.quantity > 0);
    final showMissingQuickAdd = isMissing && _ownedCollectionId != null;
    final showQuickRemove = !_isWishlistCollection && entry.quantity > 0;
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
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 2),
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
                          if (deckLegalityLabel != null)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: deckLegality == true
                                  ? _buildBadge(
                                      deckLegalityLabel,
                                      inverted: true,
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xCC3A1613),
                                        borderRadius: BorderRadius.circular(
                                          9999,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFD06D5F),
                                        ),
                                      ),
                                      child: Text(
                                        deckLegalityLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFFF8A7A),
                                            ),
                                      ),
                                    ),
                            ),
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
                                    style: _galleryQuickActionStyle(),
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
                                    style: _galleryQuickActionStyle(),
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
                                    style: _galleryQuickActionStyle(),
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
                          if (isMissing && !showQuickAdd)
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: _galleryMissingBadge(l10n),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 22,
                          child: Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _buildSetIcon(entry.setCode, size: 20),
                            const SizedBox(width: 6),
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
}
