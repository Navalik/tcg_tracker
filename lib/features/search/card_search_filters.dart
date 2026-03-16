// ignore_for_file: invalid_use_of_protected_member, use_build_context_synchronously

part of 'package:tcg_tracker/main.dart';

extension _CardSearchFiltersSection on _CardSearchSheetState {
  bool _isItalianSearchUi() {
    return Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
      'it',
    );
  }

  String _originalCollectionFilterTitle() {
    return _isItalianSearchUi()
        ? 'Filtro originale della collection'
        : 'Original collection filter';
  }

  String _additionalFiltersTitle() {
    return _isItalianSearchUi() ? 'Filtri aggiuntivi' : 'Additional filters';
  }

  List<String> _requiredFilterSummaryLabels(
    CollectionFilter filter,
    Map<String, String> availableSetCodes,
  ) {
    final labels = <String>[];
    final name = filter.name?.trim();
    if (name != null && name.isNotEmpty) {
      labels.add(name);
    }
    final artist = filter.artist?.trim();
    if (artist != null && artist.isNotEmpty) {
      labels.add(
        _isItalianSearchUi() ? 'Artista: $artist' : 'Artist: $artist',
      );
    }
    final collector = filter.collectorNumber?.trim();
    if (collector != null && collector.isNotEmpty) {
      labels.add(
        _isItalianSearchUi()
            ? 'Numero: $collector'
            : 'Collector: $collector',
      );
    }
    final format = filter.format?.trim();
    if (format != null && format.isNotEmpty) {
      labels.add(
        _isItalianSearchUi() ? 'Formato: $format' : 'Format: $format',
      );
    }
    if (filter.manaMin != null || filter.manaMax != null) {
      final min = filter.manaMin?.toString() ?? '-';
      final max = filter.manaMax?.toString() ?? '-';
      labels.add(_isItalianSearchUi() ? 'Mana: $min-$max' : 'Mana: $min-$max');
    }
    if (filter.hpMin != null || filter.hpMax != null) {
      final min = filter.hpMin?.toString() ?? '-';
      final max = filter.hpMax?.toString() ?? '-';
      labels.add(_isItalianSearchUi() ? 'HP: $min-$max' : 'HP: $min-$max');
    }
    labels.addAll(
      filter.sets.map(
        (code) =>
            availableSetCodes[code] ??
            (code.trim().isEmpty ? code : code.toUpperCase()),
      ),
    );
    labels.addAll(filter.rarities.map((value) => _formatRarity(context, value)));
    labels.addAll(filter.colors.map(_colorLabel));
    labels.addAll(filter.types.map(_typeLabel));
    labels.addAll(filter.pokemonCategories.map(_typeLabel));
    labels.addAll(filter.pokemonSubtypes);
    labels.addAll(filter.pokemonRegulationMarks.map((value) => 'Reg. $value'));
    labels.addAll(filter.pokemonStages);
    return labels.where((value) => value.trim().isNotEmpty).toList();
  }

  Future<void> _showAdvancedFilters() async {
    final availableRarities = <String>{};
    final availableSetCodes = <String, String>{};
    final availableColors = <String>{};
    final availableTypes = <String>{};

    final fallbackRarities = _isPokemonSearch
        ? const [
            'common',
            'uncommon',
            'rare',
            'holo rare',
            'ultra rare',
            'promo',
          ]
        : const ['common', 'uncommon', 'rare', 'mythic'];
    final fallbackColors = _isPokemonSearch
        ? const ['G', 'R', 'L', 'U', 'B', 'F', 'D', 'W', 'C', 'M', 'N']
        : const ['W', 'U', 'B', 'R', 'G', 'C'];
    final fallbackTypes = _isPokemonSearch
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
        final names = await appRepositories.sets.fetchSetNamesForCodes(missing);
        for (final entry in names.entries) {
          availableSetCodes[entry.key
              .trim()
              .toLowerCase()] = entry.value.trim().isNotEmpty
              ? entry.value.trim()
              : entry.key.toUpperCase();
        }
      }
    }

    if (!mounted) {
      return;
    }

    final requiredFilter = widget.requiredFilter;
    final requiredRarities = (requiredFilter?.rarities ?? const <String>{})
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final requiredSetCodes = (requiredFilter?.sets ?? const <String>{})
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final requiredColors = (requiredFilter?.colors ?? const <String>{})
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final requiredTypes = (requiredFilter?.types ?? const <String>{})
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final requiredPokemonCategories =
        (requiredFilter?.pokemonCategories ?? const <String>{})
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet();
    final requiredPokemonRegulationMarks =
        (requiredFilter?.pokemonRegulationMarks ?? const <String>{})
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet();
    final requiredPokemonStages =
        (requiredFilter?.pokemonStages ?? const <String>{})
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet();
    final tempRarities = _selectedRarities
        .where((value) => !requiredRarities.contains(value.trim().toLowerCase()))
        .toSet();
    final tempSetCodes = _selectedSetCodes
        .where((value) => !requiredSetCodes.contains(value.trim().toLowerCase()))
        .toSet();
    final tempColors = _selectedColors
        .where((value) => !requiredColors.contains(value.trim().toUpperCase()))
        .toSet();
    final tempTypes = _selectedTypes
        .where((value) => !requiredTypes.contains(value.trim().toLowerCase()))
        .toSet();
    final tempPokemonCategories = _selectedPokemonCategories
        .where(
          (value) =>
              !requiredPokemonCategories.contains(value.trim().toLowerCase()),
        )
        .toSet();
    final tempPokemonRegulationMarks = _selectedPokemonRegulationMarks
        .where(
          (value) => !requiredPokemonRegulationMarks.contains(
            value.trim().toLowerCase(),
          ),
        )
        .toSet();
    final tempPokemonStages = _selectedPokemonStages
        .where(
          (value) => !requiredPokemonStages.contains(value.trim().toLowerCase()),
        )
        .toSet();
    final nameController = TextEditingController(text: _query);
    final collectorController = TextEditingController(
      text: _collectorNumberQuery,
    );
    final artistController = TextEditingController(text: _artistQuery);
    final subtypeController = TextEditingController(text: _pokemonSubtypeQuery);
    List<String> artistSuggestions = [];
    bool loadingArtists = false;
    Timer? artistDebounce;
    final minController = TextEditingController(
      text: _manaValueMin?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: _manaValueMax?.toString() ?? '',
    );
    final hpMinController = TextEditingController(
      text: _hpMin?.toString() ?? '',
    );
    final hpMaxController = TextEditingController(
      text: _hpMax?.toString() ?? '',
    );
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

            Widget buildInfoChipRow(List<String> labels) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: labels
                    .map(
                      (label) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF221B15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF5B4938)),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFFE9C46A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            }

            final rarityOrder = ['common', 'uncommon', 'rare', 'mythic'];
            final sortedRarities = availableRarities
                .where((value) => !requiredRarities.contains(value))
                .toList()
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
            final sortedSets = availableSetCodes.entries
                .where((entry) => !requiredSetCodes.contains(entry.key))
                .toList()
              ..sort((a, b) => a.value.compareTo(b.value));
            final filteredSets = sortedSets.where((entry) {
              if (setQuery.isEmpty) {
                return true;
              }
              return entry.value.toLowerCase().contains(setQuery) ||
                  entry.key.toLowerCase().contains(setQuery);
            }).toList();
            final colorOrder = _isPokemonSearch
                ? const ['G', 'R', 'L', 'U', 'B', 'F', 'D', 'W', 'C', 'M', 'N']
                : const ['W', 'U', 'B', 'R', 'G', 'C'];
            final sortedColors = availableColors
                .where(
                  (value) => !requiredColors.contains(value.trim().toUpperCase()),
                )
                .toList()
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
            final sortedTypes = availableTypes
                .where(
                  (value) => !requiredTypes.contains(value.trim().toLowerCase()),
                )
                .toList()
              ..sort();
            final filteredRarities = sortedRarities;
            final filteredColors = sortedColors;
            final filteredTypes = sortedTypes
                .where((value) => value.toLowerCase().contains(typeQuery))
                .toList();
            const pokemonCategories = <String>['Pokemon', 'Trainer', 'Energy'];
            const pokemonStages = <String>[
              'Basic',
              'Stage1',
              'Stage2',
              'VMAX',
              'VSTAR',
            ];
            const pokemonRegulationMarks = <String>[
              'A',
              'B',
              'C',
              'D',
              'E',
              'F',
              'G',
              'H',
            ];
            final requiredFilterLabels = requiredFilter == null
                ? const <String>[]
                : _requiredFilterSummaryLabels(requiredFilter, availableSetCodes);

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
                    if (requiredFilterLabels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18120E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF3A2F24)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _originalCollectionFilterTitle(),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isItalianSearchUi()
                                  ? 'La ricerca resta sempre dentro questo perimetro.'
                                  : 'Search always stays inside this scope.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFFBFAE95),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            buildInfoChipRow(requiredFilterLabels),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (requiredFilterLabels.isNotEmpty) ...[
                      Text(
                        _additionalFiltersTitle(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                    ],
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
                    if (_isPokemonSearch) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.detailCollector,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: collectorController,
                        decoration: InputDecoration(
                          hintText: l10n.detailCollector,
                          prefixIcon: const Icon(Icons.tag),
                        ),
                      ),
                    ],
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
                        (value) => _formatRarity(context, value),
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
                        _isPokemonSearch
                            ? l10n.pokemonEnergyTypeLabel
                            : l10n.colorLabel,
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
                    if (_isPokemonSearch) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.pokemonCardCategoryLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        pokemonCategories,
                        (value) => tempPokemonCategories.contains(value),
                        (value) {
                          if (!tempPokemonCategories.add(value)) {
                            tempPokemonCategories.remove(value);
                          }
                        },
                        (value) => _typeLabel(value),
                      ),
                    ],
                    if (sortedTypes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _isPokemonSearch ? 'Type' : l10n.typeLabel,
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
                    if (_isPokemonSearch) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Subtype',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: subtypeController,
                        decoration: const InputDecoration(
                          hintText: 'Basic, Item, Supporter...',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('HP', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: hpMinController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: l10n.minLabel,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: hpMaxController,
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
                        'Stage',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        pokemonStages,
                        (value) => tempPokemonStages.contains(value),
                        (value) {
                          if (!tempPokemonStages.add(value)) {
                            tempPokemonStages.remove(value);
                          }
                        },
                        (value) => value,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Regulation mark',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      buildChipRow<String>(
                        pokemonRegulationMarks,
                        (value) => tempPokemonRegulationMarks.contains(value),
                        (value) {
                          if (!tempPokemonRegulationMarks.add(value)) {
                            tempPokemonRegulationMarks.remove(value);
                          }
                        },
                        (value) => value,
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
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
                    ],
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
                        artistDebounce = Timer(
                          const Duration(milliseconds: 250),
                          () async {
                            setSheetState(() {
                              loadingArtists = true;
                            });
                            final results = _isPokemonSearch
                                ? const <String>[]
                                : await ScryfallDatabase.instance
                                      .fetchAvailableArtists(query: query);
                            setSheetState(() {
                              artistSuggestions = results;
                              loadingArtists = false;
                            });
                          },
                        );
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
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final artist = artistSuggestions[index];
                              return ListTile(
                                title: Text(artist),
                                onTap: () {
                                  setSheetState(() {
                                    artistController.text = artist;
                                    artistController.selection =
                                        TextSelection.collapsed(
                                          offset: artist.length,
                                        );
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

    artistDebounce?.cancel();
    if (!mounted || !applied) {
      return;
    }
    int? minValue = int.tryParse(minController.text.trim());
    int? maxValue = int.tryParse(maxController.text.trim());
    int? hpMinValue = int.tryParse(hpMinController.text.trim());
    int? hpMaxValue = int.tryParse(hpMaxController.text.trim());
    if (minValue != null && maxValue != null && minValue > maxValue) {
      final swap = minValue;
      minValue = maxValue;
      maxValue = swap;
    }
    if (hpMinValue != null && hpMaxValue != null && hpMinValue > hpMaxValue) {
      final swap = hpMinValue;
      hpMinValue = hpMaxValue;
      hpMaxValue = swap;
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
      _selectedPokemonCategories
        ..clear()
        ..addAll(tempPokemonCategories);
      _selectedPokemonRegulationMarks
        ..clear()
        ..addAll(tempPokemonRegulationMarks);
      _selectedPokemonStages
        ..clear()
        ..addAll(tempPokemonStages);
      _artistQuery = artistController.text.trim();
      _collectorNumberQuery = collectorController.text.trim();
      _pokemonSubtypeQuery = subtypeController.text.trim();
      _manaValueMin = minValue;
      _manaValueMax = maxValue;
      _hpMin = hpMinValue;
      _hpMax = hpMaxValue;
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
}
