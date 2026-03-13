// ignore_for_file: invalid_use_of_protected_member

part of 'package:tcg_tracker/main.dart';

extension _CardSearchResultsSection on _CardSearchSheetState {
  Decoration _cardTintDecorationForSearch(CardSearchResult card) {
    final base = Theme.of(context).colorScheme.surface;
    final accents = _accentColorsForCard(
      colors: card.colors,
      colorIdentity: card.colorIdentity,
      typeLine: card.typeLine,
    );
    if (accents.isEmpty) {
      return BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    final tintStops = accents
        .map((color) => Color.lerp(base, color, 0.35) ?? base)
        .toList();
    return BoxDecoration(
      gradient: LinearGradient(
        colors: tintStops.length == 1 ? [base, tintStops.first] : tintStops,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Decoration _priceBadgeDecorationForSearch(CardSearchResult card) {
    final base = Theme.of(context).colorScheme.surface;
    final accents = _accentColorsForCard(
      colors: card.colors,
      colorIdentity: card.colorIdentity,
      typeLine: card.typeLine,
    );
    if (accents.isEmpty) {
      return BoxDecoration(
        color: Color.lerp(base, Colors.black, 0.08) ?? base,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x4A5D4731)),
      );
    }
    final tintStops = accents
        .map((color) => Color.lerp(base, color, 0.35) ?? base)
        .toList();
    return BoxDecoration(
      gradient: LinearGradient(
        colors: tintStops.length == 1 ? [base, tintStops.first] : tintStops,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x4A5D4731)),
    );
  }

  String _normalizePriceOrNa(String? value, String symbol) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'N/A';
    }
    return '$symbol$normalized';
  }

  _SearchPriceData _searchPriceDataForCard(CardSearchResult card) {
    final cached = _priceDataByCardId[card.id];
    if (cached != null) {
      return cached;
    }
    final currency = _priceCurrency.trim().toLowerCase() == 'usd'
        ? 'usd'
        : 'eur';
    final symbol = currency == 'usd' ? r'$' : '\u20AC';
    return _SearchPriceData(
      base: _normalizePriceOrNa(
        currency == 'usd' ? card.priceUsd : card.priceEur,
        symbol,
      ),
      foil: _normalizePriceOrNa(
        currency == 'usd' ? card.priceUsdFoil : card.priceEurFoil,
        symbol,
      ),
    );
  }

  void _refreshSearchResultPrices(List<CardSearchResult> cards) {
    if (!_showPrices || cards.isEmpty) {
      return;
    }
    final ids = <String>[];
    for (final card in cards) {
      if (_priceDataByCardId.containsKey(card.id) ||
          _priceRefreshQueued.contains(card.id)) {
        continue;
      }
      _priceRefreshQueued.add(card.id);
      ids.add(card.id);
      if (ids.length >= 20) {
        break;
      }
    }
    if (ids.isEmpty) {
      return;
    }
    unawaited(_refreshSearchResultPricesInternal(ids));
  }

  Future<void> _refreshSearchResultPricesInternal(List<String> cardIds) async {
    final nextData = <String, _SearchPriceData>{};
    try {
      for (final cardId in cardIds) {
        await PriceRepository.instance.ensurePricesFresh(cardId);
        final entry = await ScryfallDatabase.instance.fetchCardEntryById(
          cardId,
          collectionId: widget.ownershipCollectionId,
        );
        if (entry == null) {
          continue;
        }
        final currency = _priceCurrency.trim().toLowerCase() == 'usd'
            ? 'usd'
            : 'eur';
        final symbol = currency == 'usd' ? r'$' : '\u20AC';
        nextData[cardId] = _SearchPriceData(
          base: _normalizePriceOrNa(
            currency == 'usd' ? entry.priceUsd : entry.priceEur,
            symbol,
          ),
          foil: _normalizePriceOrNa(
            currency == 'usd' ? entry.priceUsdFoil : entry.priceEurFoil,
            symbol,
          ),
        );
      }
      if (!mounted || nextData.isEmpty) {
        return;
      }
      setState(() {
        _priceDataByCardId.addAll(nextData);
      });
    } catch (_) {
      // Ignore price badge refresh failures.
    } finally {
      for (final cardId in cardIds) {
        _priceRefreshQueued.remove(cardId);
      }
    }
  }

  String _setLabelForSearch(CardSearchResult card) {
    final name = card.setName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    final code = card.setCode.trim();
    return code.isEmpty ? '' : code.toUpperCase();
  }

  Widget _buildResultTile(CardSearchResult card, AppLocalizations l10n) {
    final isMissing = _isMissingCard(card);
    final statusBadge = _statusBadgeLabel(card, l10n);
    final hasStatusBadge = statusBadge != null;
    final canSelectCards = widget.selectionEnabled;
    final setLabel = _setLabelForSearch(card);
    final collectorNumber = card.collectorNumber.trim();
    final hasRarity = card.rarity.trim().isNotEmpty;
    final showAdd = !canSelectCards && widget.ownershipCollectionId != null;
    final showRightActions = showAdd || canSelectCards || hasStatusBadge;
    final quickAddButtonKey = GlobalKey();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_showPrices)
          Positioned(
            left: 16,
            right: showRightActions ? 64 : 16,
            bottom: -6,
            child: Opacity(
              opacity: isMissing ? 0.6 : 1.0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 3),
                decoration: _priceBadgeDecorationForSearch(card),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    '${l10n.priceLabel(_searchPriceDataForCard(card).base)} • ${l10n.foilLabel} ${_searchPriceDataForCard(card).foil}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFEFE7D8),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        Opacity(
          opacity: isMissing ? 0.6 : 1.0,
          child: InkWell(
            onTap: () => _onResultTap(card),
            onLongPress: () => _showPreview(card),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: EdgeInsets.only(bottom: _showPrices ? 18 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: _cardTintDecorationForSearch(card),
              child: SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildSetIcon(card.setCode, size: 60)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            card.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final leftLabel = setLabel.isNotEmpty
                                  ? setLabel
                                  : collectorNumber;
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
                                  if (collectorNumber.isNotEmpty &&
                                      setLabel.isNotEmpty) ...[
                                    Text(
                                      collectorNumber,
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
                                    _raritySquare(card.rarity),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    if (showRightActions) ...[
                      const SizedBox(width: 8),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasStatusBadge) ...[
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _buildBadge(statusBadge, inverted: true),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (showAdd)
                              IconButton(
                                key: quickAddButtonKey,
                                tooltip: l10n.addOne,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                visualDensity: VisualDensity.compact,
                                iconSize: 32,
                                icon: const Icon(Icons.add_circle, size: 32),
                                color: const Color(0xFFE9C46A),
                                onPressed: _addingFromPreview
                                    ? null
                                    : () => _addCardFromPreview(
                                        card,
                                        anchorKey: quickAddButtonKey,
                                      ),
                              )
                            else if (canSelectCards)
                              const Icon(
                                Icons.add_circle,
                                size: 32,
                                color: Color(0xFFE9C46A),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryCard(CardSearchResult card, AppLocalizations l10n) {
    final isMissing = _isMissingCard(card);
    final statusBadge = _statusBadgeLabel(card, l10n);
    final hasStatusBadge = statusBadge != null;
    final canSelectCards = widget.selectionEnabled;
    final showAdd = !canSelectCards && widget.ownershipCollectionId != null;
    final showMissingQuickAdd = isMissing && showAdd;
    final quickAddButtonKey = GlobalKey();
    final imageUrl = _normalizeCardImageUrlForDisplay(card.imageUri);
    final setLabel = _setLabelForSearch(card);
    final hasRarity = card.rarity.trim().isNotEmpty;
    return Stack(
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
                decoration: _priceBadgeDecorationForSearch(card),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Builder(
                    builder: (context) {
                      final priceData = _searchPriceDataForCard(card);
                      final accentStyle = Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFFE9C46A));
                      final valueStyle = accentStyle?.copyWith(
                        color: const Color(0xFFEFE7D8),
                        fontWeight: FontWeight.w500,
                      );
                      return SizedBox(
                        width: double.infinity,
                        child: Text(
                          l10n.priceLabel(priceData.base),
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
          child: InkWell(
            onTap: () => _onResultTap(card),
            onLongPress: () => _showPreview(card),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: EdgeInsets.only(bottom: _showPrices ? 18 : 0),
              decoration: _cardTintDecorationForSearch(card),
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
                          imageUrl.isEmpty
                              ? Container(
                                  color: const Color(0xFF201A14),
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Color(0xFFBFAE95),
                                  ),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: const Color(0xFF201A14),
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Color(0xFFBFAE95),
                                        ),
                                      ),
                                ),
                          if (showMissingQuickAdd)
                            Positioned(
                              bottom: 2,
                              left: 2,
                              child: IconButton(
                                key: quickAddButtonKey,
                                tooltip: l10n.addOne,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                visualDensity: VisualDensity.compact,
                                iconSize: 32,
                                icon: const Icon(Icons.add_circle, size: 32),
                                color: const Color(0xFFE9C46A),
                                onPressed: _addingFromPreview
                                    ? null
                                    : () => _addCardFromPreview(
                                        card,
                                        anchorKey: quickAddButtonKey,
                                      ),
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
                            card.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildSetIcon(card.setCode, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                setLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFFBFAE95)),
                              ),
                            ),
                            if (hasRarity) ...[
                              const SizedBox(width: 6),
                              _raritySquare(card.rarity),
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
        ),
        if (hasStatusBadge)
          Align(
            alignment: const Alignment(1, 0.0),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildBadge(statusBadge, inverted: true),
            ),
          ),
      ],
    );
  }
}
