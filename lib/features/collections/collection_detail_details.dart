// ignore_for_file: invalid_use_of_protected_member, use_build_context_synchronously

part of 'package:tcg_tracker/main.dart';

extension _CollectionDetailDetailsStateX on _CollectionDetailPageState {
  Future<void> _showCardDetails(CollectionCardEntry entry) async {
    var detailEntry = entry;
    final lookupCollectionId = widget.isAllCards || _isWishlistCollection
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
    } catch (_) {}
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
    } catch (_) {}
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
                      if (_normalizeCardImageUrlForDisplay(
                            entry.imageUri,
                          ).trim().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _normalizeCardImageUrlForDisplay(entry.imageUri),
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
    final toastTopOffset = widget.isDeckCollection ? 44.0 : 34.0;
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx + (size.width / 2) - 18,
          top: position.dy - toastTopOffset,
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
    Future<void>.delayed(const Duration(milliseconds: 900), entry.remove);
  }

  void _showMiniToastForContext(BuildContext targetContext, String label) {
    final overlay = Overlay.of(context);
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;
    final toastTopOffset = widget.isDeckCollection ? 44.0 : 34.0;
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx + (size.width / 2) - 18,
          top: position.dy - toastTopOffset,
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
    Future<void>.delayed(const Duration(milliseconds: 900), entry.remove);
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
      return '\u2014';
    }
    return 'EUR $selected';
  }

  String _displayUsdPrice(CollectionCardEntry entry) {
    final base = _normalizePriceValue(entry.priceUsd);
    final foil = _normalizePriceValue(entry.priceUsdFoil);
    final selected = entry.foil ? (foil ?? base) : base;
    if (selected == null) {
      return '\u2014';
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
                            await _inventoryService.setInventoryQty(
                              entry.cardId,
                              0,
                            );
                          } else if (_isWishlistCollection ||
                              _isDirectCustomCollection) {
                            await ScryfallDatabase.instance
                                .deleteCollectionCard(
                                  widget.collectionId,
                                  entry.cardId,
                                );
                          } else if (widget.isDeckCollection) {
                            await ScryfallDatabase.instance
                                .deleteCollectionCard(
                                  ownedCollectionId!,
                                  entry.cardId,
                                );
                          } else {
                            await _inventoryService.setInventoryQty(
                              entry.cardId,
                              0,
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
                              : _isWishlistCollection
                              ? 0
                              : (parsed < 1 ? 1 : parsed);
                          if (_isWishlistCollection) {
                            await ScryfallDatabase.instance
                                .upsertCollectionMembership(
                                  widget.collectionId,
                                  entry.cardId,
                                );
                          } else if (_isDirectCustomCollection) {
                            if (quantity <= 0) {
                              await ScryfallDatabase.instance
                                  .deleteCollectionCard(
                                    widget.collectionId,
                                    entry.cardId,
                                  );
                            } else {
                              await _inventoryService.setInventoryQty(
                                entry.cardId,
                                quantity,
                              );
                              await ScryfallDatabase.instance
                                  .upsertCollectionMembership(
                                    widget.collectionId,
                                    entry.cardId,
                                  );
                            }
                          } else if (widget.isDeckCollection) {
                            await ScryfallDatabase.instance
                                .upsertCollectionCard(
                                  ownedCollectionId!,
                                  entry.cardId,
                                  quantity: quantity,
                                  foil: false,
                                  altArt: altArt,
                                );
                          } else {
                            await _inventoryService.setInventoryQty(
                              entry.cardId,
                              quantity,
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
}
