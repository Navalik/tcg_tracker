// ignore_for_file: invalid_use_of_protected_member, use_build_context_synchronously

part of 'package:tcg_tracker/main.dart';

extension _CardSearchDetailsSection on _CardSearchSheetState {
  Future<void> _showCardDetailsForSearch(CardSearchResult card) async {
    final entry = await ScryfallDatabase.instance.fetchCardEntryById(
      card.id,
      printingId: card.printingId,
      collectionId: widget.ownershipCollectionId,
    );
    if (!mounted) {
      return;
    }
    if (entry != null) {
      await _showEntryDetails(entry);
      return;
    }
    final ensured = await _ensureCardStored(card);
    if (!mounted) {
      return;
    }
    if (!ensured) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.networkErrorTryAgain,
      );
      return;
    }
    final refreshed = await ScryfallDatabase.instance.fetchCardEntryById(
      card.id,
      printingId: card.printingId,
      collectionId: widget.ownershipCollectionId,
    );
    if (!mounted) {
      return;
    }
    if (refreshed == null) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.networkErrorTryAgain,
      );
      return;
    }
    await _showEntryDetails(refreshed);
  }

  Future<void> _showEntryDetails(CollectionCardEntry entry) async {
    List<String> legalFormats = const [];
    try {
      legalFormats = await ScryfallDatabase.instance.fetchCardLegalFormats(
        entry.cardId,
      );
    } catch (_) {
      legalFormats = const [];
    }
    Map<String, dynamic>? cardJsonPayload;
    try {
      cardJsonPayload = await ScryfallDatabase.instance.fetchCardJsonPayload(
        entry.cardId,
      );
    } catch (_) {
      cardJsonPayload = null;
    }
    if (!mounted) {
      return;
    }
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final addButtonKey = GlobalKey();
        var showCheck = false;
        final l10n = AppLocalizations.of(context)!;
        final details = _parseCardDetails(
          l10n,
          entry,
          legalFormats,
          cardJsonPayload,
        );
        final typeLine = entry.typeLine.trim();
        final manaCost = entry.manaCost.trim();
        final oracleText = entry.oracleText.trim();
        final power = entry.power.trim();
        final toughness = entry.toughness.trim();
        final loyalty = entry.loyalty.trim();
        final stats = _joinStats(power, toughness);
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handleAdd() async {
              await _addCardFromDetails(entry);
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

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                          if (widget.ownershipCollectionId != null)
                            FilledButton(
                              key: addButtonKey,
                              onPressed: _addingFromPreview ? null : handleAdd,
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
                                    : const Icon(
                                        Icons.add,
                                        key: ValueKey('add'),
                                      ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildSetIcon(entry.setCode, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _subtitleLabelForEntry(entry),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFFBFAE95)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: Image.network(
                              _normalizeCardImageUrlForDisplay(entry.imageUri),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  SizedBox(
                                    height: 220,
                                    child: _missingCardArtPlaceholder(
                                      entry.setCode,
                                      compact: false,
                                    ),
                                  ),
                            ),
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _subtitleLabelForEntry(CollectionCardEntry entry) {
    final setLabel = entry.setName.trim().isNotEmpty
        ? entry.setName.trim()
        : entry.setCode.toUpperCase();
    final progress = entry.collectorNumber.trim();
    if (setLabel.isEmpty) {
      return progress;
    }
    if (progress.isEmpty) {
      return setLabel;
    }
    return '$setLabel • $progress';
  }

  List<_CardDetail> _parseCardDetails(
    AppLocalizations l10n,
    CollectionCardEntry entry,
    List<String> legalFormats,
    Map<String, dynamic>? cardJsonPayload,
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

    add(l10n.detailRarity, _formatRarity(context, entry.rarity));
    final pokemonDetails = _parsePokemonCardDetails(cardJsonPayload);
    if (pokemonDetails != null) {
      add(l10n.pokemonCardCategoryLabel, pokemonDetails.category);
      add('HP', pokemonDetails.hp);
      add(l10n.pokemonEnergyTypeLabel, pokemonDetails.types);
      add(
        _localizedInlineLabel(context, it: 'Stadio', en: 'Stage'),
        pokemonDetails.stage,
      );
      add(
        _localizedInlineLabel(context, it: 'Evolve da', en: 'Evolves from'),
        pokemonDetails.evolvesFrom,
      );
      add(
        _localizedInlineLabel(context, it: 'Marchio reg.', en: 'Regulation'),
        pokemonDetails.regulationMark,
      );
      add(
        _localizedInlineLabel(context, it: 'Debolezze', en: 'Weaknesses'),
        pokemonDetails.weaknesses,
      );
      add(
        _localizedInlineLabel(context, it: 'Resistenze', en: 'Resistances'),
        pokemonDetails.resistances,
      );
      add(
        _localizedInlineLabel(context, it: 'Costo ritirata', en: 'Retreat'),
        pokemonDetails.retreatCost,
      );
    }
    add(l10n.detailSetName, entry.setName);
    add(l10n.detailLanguage, entry.lang);
    add(l10n.detailRelease, entry.releasedAt);
    add(l10n.detailArtist, entry.artist);
    final legalFormatLabels = _normalizeFormatLabels(legalFormats);
    if (legalFormatLabels.isNotEmpty) {
      add(l10n.detailFormat, legalFormatLabels.join(', '));
    } else {
      final deckFormat = _deckFormatConstraint;
      if (deckFormat != null && deckFormat.isNotEmpty) {
        add(l10n.detailFormat, deckFormatLabel(deckFormat));
      }
    }
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
                  child: _DetailRow(label: item.label, value: item.value),
                ),
              )
              .toList(),
        );
      },
    );
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

  void _showPreview(CardSearchResult card) {
    final imageUrl = _normalizeCardImageUrlForDisplay(card.imageUri);
    if (imageUrl.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    _hidePreview(immediate: true);

    final overlay = Overlay.of(context, rootOverlay: true);

    _previewController.value = 0;
    _previewEntry = OverlayEntry(
      builder: (context) {
        final quickAddButtonKey = GlobalKey();
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
                      border: Border.all(color: const Color(0xFF3A2F24)),
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
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 48,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (widget.ownershipCollectionId != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    12,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      key: quickAddButtonKey,
                                      onPressed: _addingFromPreview
                                          ? null
                                          : () => _addCardFromPreview(
                                              card,
                                              anchorKey: quickAddButtonKey,
                                            ),
                                      icon: const Icon(Icons.add),
                                      label: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.addToCollection,
                                      ),
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
                                tooltip: AppLocalizations.of(
                                  context,
                                )!.closePreview,
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

  Future<void> _addCardFromPreview(
    CardSearchResult card, {
    GlobalKey? anchorKey,
    BuildContext? anchorContext,
  }) async {
    final ownedCollectionId = widget.ownershipCollectionId;
    final customMembershipCollectionId = widget.customMembershipCollectionId;
    final missingCollectionId = widget.addMissingToCollectionId;
    if ((ownedCollectionId == null &&
            missingCollectionId == null &&
            customMembershipCollectionId == null) ||
        _addingFromPreview) {
      return;
    }
    setState(() {
      _addingFromPreview = true;
    });
    try {
      final ensured = await _ensureCardStored(card);
      if (!ensured) {
        if (mounted) {
          showAppSnackBar(
            context,
            AppLocalizations.of(context)!.networkErrorTryAgain,
          );
        }
        return;
      }
      if (missingCollectionId != null) {
        final ownedQty = await InventoryService.instance.currentInventoryQty(
          card.id,
          printingId: card.printingId,
        );
        if (ownedQty > 0) {
          if (mounted) {
            showAppSnackBar(
              context,
              Localizations.localeOf(
                    context,
                  ).languageCode.toLowerCase().startsWith('it')
                  ? 'Carta gia posseduta.'
                  : 'Card already owned.',
            );
          }
          return;
        }
        await ScryfallDatabase.instance.addCardToCollectionAsMissing(
          missingCollectionId,
          card.id,
          printingId: card.printingId,
        );
      } else if (customMembershipCollectionId != null) {
        await InventoryService.instance.addToInventory(
          card.id,
          printingId: card.printingId,
          deltaQty: 1,
        );
        await ScryfallDatabase.instance.upsertCollectionMembership(
          customMembershipCollectionId,
          card.id,
          printingId: card.printingId,
        );
      } else if (ownedCollectionId != null) {
        if (widget.addToOwnershipCollectionDirectly) {
          final currentQty = _ownedQuantitiesByCardId[card.id] ?? 0;
          await ScryfallDatabase.instance.upsertCollectionCard(
            ownedCollectionId,
            card.id,
            printingId: card.printingId,
            quantity: currentQty + 1,
            foil: false,
            altArt: false,
          );
        } else {
          await InventoryService.instance.addToInventory(
            card.id,
            printingId: card.printingId,
            deltaQty: 1,
          );
        }
      }
      if (!mounted) {
        return;
      }
      if (missingCollectionId != null) {
        _hideCardFromWishlistSearch(card.id);
      }
      if (missingCollectionId == null &&
          (customMembershipCollectionId != null || ownedCollectionId != null)) {
        final current = _ownedQuantitiesByCardId[card.id] ?? 0;
        setState(() {
          _ownedQuantitiesByCardId = {
            ..._ownedQuantitiesByCardId,
            card.id: current + 1,
          };
        });
      }
      if (anchorKey != null) {
        _showMiniToast(anchorKey, '+1');
      } else if (anchorContext != null && anchorContext.mounted) {
        _showMiniToastForContext(anchorContext, '+1');
      }
      await _hidePreview(immediate: false);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'card_search_details',
          context: ErrorDescription('while adding a card from search preview'),
        ),
      );
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.networkErrorTryAgain,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _addingFromPreview = false;
        });
      }
    }
  }

  Future<void> _addCardFromDetails(CollectionCardEntry entry) async {
    final ownedCollectionId = widget.ownershipCollectionId;
    final customMembershipCollectionId = widget.customMembershipCollectionId;
    final missingCollectionId = widget.addMissingToCollectionId;
    if ((ownedCollectionId == null &&
            missingCollectionId == null &&
            customMembershipCollectionId == null) ||
        _addingFromPreview) {
      return;
    }
    setState(() {
      _addingFromPreview = true;
    });
    try {
      if (missingCollectionId != null) {
        final ownedQty = await InventoryService.instance.currentInventoryQty(
          entry.cardId,
          printingId: entry.printingId,
        );
        if (ownedQty > 0) {
          if (mounted) {
            showAppSnackBar(
              context,
              Localizations.localeOf(
                    context,
                  ).languageCode.toLowerCase().startsWith('it')
                  ? 'Carta gia posseduta.'
                  : 'Card already owned.',
            );
          }
          return;
        }
        await ScryfallDatabase.instance.addCardToCollectionAsMissing(
          missingCollectionId,
          entry.cardId,
          printingId: entry.printingId,
        );
      } else if (customMembershipCollectionId != null) {
        await InventoryService.instance.addToInventory(
          entry.cardId,
          printingId: entry.printingId,
          deltaQty: 1,
        );
        await ScryfallDatabase.instance.upsertCollectionMembership(
          customMembershipCollectionId,
          entry.cardId,
          printingId: entry.printingId,
        );
      } else if (ownedCollectionId != null) {
        if (widget.addToOwnershipCollectionDirectly) {
          final currentQty = _ownedQuantitiesByCardId[entry.cardId] ?? 0;
          await ScryfallDatabase.instance.upsertCollectionCard(
            ownedCollectionId,
            entry.cardId,
            printingId: entry.printingId,
            quantity: currentQty + 1,
            foil: false,
            altArt: false,
          );
        } else {
          await InventoryService.instance.addToInventory(
            entry.cardId,
            printingId: entry.printingId,
            deltaQty: 1,
          );
        }
      }
      if (!mounted) {
        return;
      }
      if (missingCollectionId != null) {
        _hideCardFromWishlistSearch(entry.cardId);
      }
      if (missingCollectionId == null &&
          (customMembershipCollectionId != null || ownedCollectionId != null)) {
        final current =
            _ownedQuantitiesByCardId[entry.cardId] ?? entry.quantity;
        setState(() {
          _ownedQuantitiesByCardId = {
            ..._ownedQuantitiesByCardId,
            entry.cardId: current + 1,
          };
        });
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'card_search_details',
          context: ErrorDescription('while adding a card from search details'),
        ),
      );
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context)!.networkErrorTryAgain,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _addingFromPreview = false;
        });
      }
    }
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

  void _showMiniToastForContext(BuildContext anchorContext, String label) {
    final overlay = Overlay.of(context);
    final box = anchorContext.findRenderObject() as RenderBox?;
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
}
