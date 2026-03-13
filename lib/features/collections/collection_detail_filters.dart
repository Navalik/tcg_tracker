// ignore_for_file: invalid_use_of_protected_member

part of 'package:tcg_tracker/main.dart';

extension _CollectionDetailFilterStateX on _CollectionDetailPageState {
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
                            ? l10n.pokemonEnergyTypeLabel
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
                          ? l10n.pokemonAttackEnergyCostLabel
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
}
