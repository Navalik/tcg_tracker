part of 'package:tcg_tracker/main.dart';

class _CollectionFilterBuilderPage extends StatefulWidget {
  const _CollectionFilterBuilderPage({
    required this.name,
    this.submitLabel,
    this.initialFilter,
  });

  final String name;
  final String? submitLabel;
  final CollectionFilter? initialFilter;

  @override
  State<_CollectionFilterBuilderPage> createState() =>
      _CollectionFilterBuilderPageState();
}

class _CollectionFilterBuilderPageState
    extends State<_CollectionFilterBuilderPage> {
  static const int _countDebounceMs = 350;
  static const int _pokemonCountDebounceMs = 550;

  bool get _isPokemonActive =>
      TcgEnvironmentController.instance.currentGame == TcgGame.pokemon;

  Duration get _countDebounceDuration => Duration(
    milliseconds: _isPokemonActive
        ? _pokemonCountDebounceMs
        : _countDebounceMs,
  );

  List<String> get _knownTypes => _isPokemonActive
      ? const [
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

  List<String> get _rarityOrder => _isPokemonActive
      ? const ['common', 'uncommon', 'rare', 'holo rare', 'ultra rare', 'promo']
      : const ['common', 'uncommon', 'rare', 'mythic'];

  List<String> get _colorOrder => _isPokemonActive
      ? const ['G', 'R', 'L', 'U', 'B', 'F', 'D', 'W', 'C', 'M', 'N']
      : const ['W', 'U', 'B', 'R', 'G', 'C'];

  List<String> get _knownPokemonCategories => const [
    'Pokemon',
    'Trainer',
    'Energy',
  ];

  List<String> get _knownPokemonStages => const [
    'Basic',
    'Stage1',
    'Stage2',
    'VMAX',
    'VSTAR',
  ];

  List<String> get _knownPokemonRegulationMarks => const [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _collectorNumberController =
      TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _manaMinController = TextEditingController();
  final TextEditingController _manaMaxController = TextEditingController();
  final TextEditingController _hpMinController = TextEditingController();
  final TextEditingController _hpMaxController = TextEditingController();
  final TextEditingController _pokemonSubtypeController =
      TextEditingController();

  final Set<String> _selectedSets = {};
  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedRarities = {};
  final Set<String> _selectedColors = {};
  final Set<String> _selectedTypes = {};
  final Set<String> _selectedPokemonCategories = {};
  final Set<String> _selectedPokemonRegulationMarks = {};
  final Set<String> _selectedPokemonStages = {};

  List<SetInfo> _availableSets = [];
  bool _loadingSets = true;
  String _setQuery = '';

  bool _impactCountLoading = false;
  int? _impactCount;

  Timer? _countDebounce;
  Timer? _artistDebounce;
  List<String> _artistSuggestions = [];
  bool _loadingArtists = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFilter;
    if (initial != null) {
      _nameController.text = initial.name?.trim() ?? '';
      _collectorNumberController.text = initial.collectorNumber?.trim() ?? '';
      _artistController.text = initial.artist?.trim() ?? '';
      if (initial.manaMin != null) {
        _manaMinController.text = initial.manaMin!.toString();
      }
      if (initial.manaMax != null) {
        _manaMaxController.text = initial.manaMax!.toString();
      }
      if (initial.hpMin != null) {
        _hpMinController.text = initial.hpMin!.toString();
      }
      if (initial.hpMax != null) {
        _hpMaxController.text = initial.hpMax!.toString();
      }
      _selectedSets.addAll(
        initial.sets.map((value) => value.trim().toLowerCase()),
      );
      _selectedLanguages.addAll(
        initial.languages
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty),
      );
      _selectedRarities.addAll(
        initial.rarities.map((value) => value.trim().toLowerCase()),
      );
      _selectedColors.addAll(
        initial.colors.map((value) => value.trim().toUpperCase()),
      );
      _selectedTypes.addAll(
        initial.types
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
      _selectedPokemonCategories.addAll(
        initial.pokemonCategories
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
      _selectedPokemonRegulationMarks.addAll(
        initial.pokemonRegulationMarks
            .map((value) => value.trim().toUpperCase())
            .where((value) => value.isNotEmpty),
      );
      _selectedPokemonStages.addAll(
        initial.pokemonStages
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
      _pokemonSubtypeController.text = initial.pokemonSubtypes.join(', ');
    }
    _loadSets();
    _scheduleCountUpdate();
  }

  @override
  void dispose() {
    _countDebounce?.cancel();
    _artistDebounce?.cancel();
    _nameController.dispose();
    _collectorNumberController.dispose();
    _artistController.dispose();
    _manaMinController.dispose();
    _manaMaxController.dispose();
    _hpMinController.dispose();
    _hpMaxController.dispose();
    _pokemonSubtypeController.dispose();
    super.dispose();
  }

  Future<void> _loadSets() async {
    final sets = await appRepositories.sets.fetchAvailableSets();
    if (!mounted) {
      return;
    }
    setState(() {
      _availableSets = sets;
      _loadingSets = false;
    });
  }

  void _scheduleCountUpdate() {
    _countDebounce?.cancel();
    final filter = _buildFilter();
    if (_hasCriteria(filter)) {
      if (!_impactCountLoading) {
        setState(() {
          _impactCountLoading = true;
        });
      }
    } else if (_impactCountLoading || _impactCount != null) {
      setState(() {
        _impactCountLoading = false;
        _impactCount = null;
      });
    }
    _countDebounce = Timer(_countDebounceDuration, () async {
      await _refreshImpactCount();
    });
  }

  void _onArtistChanged(String value) {
    _artistDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _artistSuggestions = [];
        _loadingArtists = false;
      });
      _scheduleCountUpdate();
      return;
    }
    _artistDebounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() {
        _loadingArtists = true;
      });
      final results = _isPokemonActive
          ? const <String>[]
          : await ScryfallDatabase.instance.fetchAvailableArtists(query: query);
      if (!mounted) {
        return;
      }
      setState(() {
        _artistSuggestions = results;
        _loadingArtists = false;
      });
    });
    _scheduleCountUpdate();
  }

  CollectionFilter _buildFilter() {
    int? minValue = int.tryParse(_manaMinController.text.trim());
    int? maxValue = int.tryParse(_manaMaxController.text.trim());
    if (minValue != null && maxValue != null && minValue > maxValue) {
      final swap = minValue;
      minValue = maxValue;
      maxValue = swap;
    }
    final name = _nameController.text.trim();
    final artist = _artistController.text.trim();
    return CollectionFilter(
      name: name.isEmpty ? null : name,
      artist: artist.isEmpty ? null : artist,
      manaMin: minValue,
      manaMax: maxValue,
      hpMin: int.tryParse(_hpMinController.text.trim()),
      hpMax: int.tryParse(_hpMaxController.text.trim()),
      collectorNumber: _collectorNumberController.text.trim().isEmpty
          ? null
          : _collectorNumberController.text.trim(),
      languages: _selectedLanguages,
      sets: _selectedSets,
      rarities: _selectedRarities,
      colors: _selectedColors,
      types: _selectedTypes,
      pokemonCategories: _selectedPokemonCategories,
      pokemonSubtypes: _pokemonSubtypeController.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet(),
      pokemonRegulationMarks: _selectedPokemonRegulationMarks,
      pokemonStages: _selectedPokemonStages,
    );
  }

  bool _hasCriteria(CollectionFilter filter) {
    return (filter.name?.trim().isNotEmpty ?? false) ||
        (filter.artist?.trim().isNotEmpty ?? false) ||
        filter.manaMin != null ||
        filter.manaMax != null ||
        filter.hpMin != null ||
        filter.hpMax != null ||
        (filter.collectorNumber?.trim().isNotEmpty ?? false) ||
        filter.languages.isNotEmpty ||
        filter.sets.isNotEmpty ||
        filter.rarities.isNotEmpty ||
        filter.colors.isNotEmpty ||
        filter.types.isNotEmpty ||
        filter.pokemonCategories.isNotEmpty ||
        filter.pokemonSubtypes.isNotEmpty ||
        filter.pokemonRegulationMarks.isNotEmpty ||
        filter.pokemonStages.isNotEmpty;
  }

  bool _shouldTriggerCount(CollectionFilter filter) {
    final name = filter.name?.trim() ?? '';
    final collector = filter.collectorNumber?.trim() ?? '';
    final artist = filter.artist?.trim() ?? '';
    final minNameLength = _isPokemonActive ? 3 : 2;
    if (name.length >= minNameLength ||
        collector.isNotEmpty ||
        artist.length >= 2) {
      return true;
    }
    return filter.sets.isNotEmpty ||
        filter.languages.isNotEmpty ||
        filter.rarities.isNotEmpty ||
        filter.colors.isNotEmpty ||
        filter.types.isNotEmpty ||
        filter.pokemonCategories.isNotEmpty ||
        filter.pokemonSubtypes.isNotEmpty ||
        filter.pokemonRegulationMarks.isNotEmpty ||
        filter.pokemonStages.isNotEmpty ||
        filter.manaMin != null ||
        filter.manaMax != null ||
        filter.hpMin != null ||
        filter.hpMax != null;
  }

  Future<void> _refreshImpactCount() async {
    final filter = _buildFilter();
    if (!_hasCriteria(filter) || !_shouldTriggerCount(filter)) {
      setState(() {
        _impactCountLoading = false;
        _impactCount = null;
      });
      return;
    }
    final total = await ScryfallDatabase.instance.countCardsForFilter(filter);
    if (!mounted) {
      return;
    }
    setState(() {
      _impactCount = total;
      _impactCountLoading = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _nameController.clear();
      _collectorNumberController.clear();
      _artistController.clear();
      _manaMinController.clear();
      _manaMaxController.clear();
      _hpMinController.clear();
      _hpMaxController.clear();
      _pokemonSubtypeController.clear();
      _selectedSets.clear();
      _selectedLanguages.clear();
      _selectedRarities.clear();
      _selectedColors.clear();
      _selectedTypes.clear();
      _selectedPokemonCategories.clear();
      _selectedPokemonRegulationMarks.clear();
      _selectedPokemonStages.clear();
      _setQuery = '';
      _artistSuggestions = [];
      _loadingArtists = false;
      _impactCount = null;
      _impactCountLoading = false;
    });
    _scheduleCountUpdate();
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

  String _typeLabel(String value) {
    if (!_isPokemonActive) {
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

  bool _isItalianUi() {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return code.startsWith('it');
  }

  List<String> _supportedLanguageCodes() {
    return AppSettings.languageCodes
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList()
      ..sort((a, b) => _languageLabel(a).compareTo(_languageLabel(b)));
  }

  String _languageLabel(String code) {
    final l10n = AppLocalizations.of(context)!;
    switch (code.trim().toLowerCase()) {
      case 'en':
        return l10n.languageEnglish;
      case 'it':
        return l10n.languageItalian;
      case 'fr':
        return l10n.languageFrench;
      case 'de':
        return l10n.languageGerman;
      case 'es':
        return l10n.languageSpanish;
      case 'pt':
        return l10n.languagePortuguese;
      case 'ja':
        return l10n.languageJapanese;
      case 'ko':
        return l10n.languageKorean;
      case 'ru':
        return l10n.languageRussian;
      case 'zh-hans':
        return l10n.languageChineseSimplified;
      case 'zh-hant':
        return l10n.languageChineseTraditional;
      case 'ar':
        return l10n.languageArabic;
      case 'he':
        return l10n.languageHebrew;
      case 'la':
        return l10n.languageLatin;
      case 'grc':
      case 'el':
        return l10n.languageGreek;
      case 'sa':
        return l10n.languageSanskrit;
      case 'ph':
      case 'x-phyr':
        return l10n.languagePhyrexian;
      case 'qya':
        return l10n.languageQuenya;
      default:
        return code.trim().toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filterDefinitions = filterDefinitionsForGame(
      _isPokemonActive ? TcgGameId.pokemon : TcgGameId.mtg,
    );
    bool hasDefinition(String key) =>
        filterDefinitions.any((definition) => definition.key == key);
    final filteredSets = _setQuery.isEmpty
        ? <SetInfo>[]
        : _availableSets
              .where(
                (set) =>
                    set.name.toLowerCase().contains(_setQuery.toLowerCase()) ||
                    set.code.toLowerCase().contains(_setQuery.toLowerCase()),
              )
              .toList();
    final sortedLanguages = _supportedLanguageCodes();
    final sortedRarities = _rarityOrder;
    final sortedColors = _colorOrder;

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
                onSelected: (_) => setState(() => toggle(item)),
              ),
            )
            .toList(),
      );
    }

    Widget buildSelectedChips(
      Iterable<String> items,
      void Function(String) remove,
    ) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (item) => InputChip(
                label: Text(item),
                onDeleted: () => setState(() => remove(item)),
              ),
            )
            .toList(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: Text(l10n.reset),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_buildFilter()),
              child: Text(widget.submitLabel ?? l10n.create),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.searchCardsHint,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isItalianUi()
                        ? 'Carte nel filtro: ${_impactCount?.toString() ?? "-"}'
                        : 'Cards in filter: ${_impactCount?.toString() ?? "-"}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFE9C46A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_impactCountLoading) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFE9C46A),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: l10n.typeCardNameHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) => _scheduleCountUpdate(),
          ),
          if (_isPokemonActive && hasDefinition('collector_number')) ...[
            const SizedBox(height: 16),
            Text(
              l10n.detailCollector,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _collectorNumberController,
              decoration: InputDecoration(
                hintText: l10n.detailCollector,
                prefixIcon: const Icon(Icons.tag),
              ),
              onChanged: (_) => _scheduleCountUpdate(),
            ),
          ],
          const SizedBox(height: 16),
          Text(l10n.setLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_selectedSets.isNotEmpty) ...[
            buildSelectedChips(_selectedSets, (value) {
              _selectedSets.remove(value);
              _scheduleCountUpdate();
            }),
            const SizedBox(height: 8),
          ],
          TextField(
            decoration: InputDecoration(
              hintText: l10n.searchSetHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _setQuery = value.trim();
              });
            },
          ),
          if (_setQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (_loadingSets)
              const Center(child: CircularProgressIndicator())
            else if (filteredSets.isEmpty)
              Text(l10n.noResultsFound)
            else
              SizedBox(
                height: filteredSets.length > 8 ? 200 : null,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredSets.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final set = filteredSets[index];
                    return ListTile(
                      title: Text(set.name),
                      subtitle: Text(set.code.toUpperCase()),
                      onTap: () {
                        setState(() {
                          _selectedSets.add(set.code.toLowerCase());
                          _setQuery = '';
                        });
                        _scheduleCountUpdate();
                      },
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.searchLanguages,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          buildChipRow<String>(
            sortedLanguages,
            (value) => _selectedLanguages.contains(value),
            (value) {
              if (!_selectedLanguages.add(value)) {
                _selectedLanguages.remove(value);
              }
              _scheduleCountUpdate();
            },
            _languageLabel,
          ),
          const SizedBox(height: 16),
          Text(l10n.rarity, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          buildChipRow<String>(
            sortedRarities,
            (value) => _selectedRarities.contains(value),
            (value) {
              if (!_selectedRarities.add(value)) {
                _selectedRarities.remove(value);
              }
              _scheduleCountUpdate();
            },
            (value) => _formatRarity(context, value),
          ),
          const SizedBox(height: 16),
          Text(
            _isPokemonActive ? l10n.pokemonEnergyTypeLabel : l10n.colorLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          buildChipRow<String>(
            sortedColors,
            (value) => _selectedColors.contains(value),
            (value) {
              if (!_selectedColors.add(value)) {
                _selectedColors.remove(value);
              }
              _scheduleCountUpdate();
            },
            (value) => _colorLabel(value),
          ),
          const SizedBox(height: 16),
          if (_isPokemonActive && hasDefinition('pokemon.category')) ...[
            Text(
              l10n.pokemonCardCategoryLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            buildChipRow<String>(
              _knownPokemonCategories,
              (value) => _selectedPokemonCategories.contains(value),
              (value) {
                if (!_selectedPokemonCategories.add(value)) {
                  _selectedPokemonCategories.remove(value);
                }
                _scheduleCountUpdate();
              },
              (value) => _typeLabel(value),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            _isPokemonActive ? 'Type' : l10n.typeLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          buildChipRow<String>(
            _knownTypes,
            (value) => _selectedTypes.contains(value),
            (value) {
              if (!_selectedTypes.add(value)) {
                _selectedTypes.remove(value);
              }
              _scheduleCountUpdate();
            },
            (value) => _typeLabel(value),
          ),
          if (_isPokemonActive && hasDefinition('pokemon.subtypes')) ...[
            const SizedBox(height: 16),
            Text('Subtype', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _pokemonSubtypeController,
              decoration: const InputDecoration(
                hintText: 'Basic, Item, Supporter...',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              onChanged: (_) => _scheduleCountUpdate(),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _isPokemonActive
                ? (_isItalianUi()
                      ? 'Costo energia (attacco)'
                      : 'Attack energy cost')
                : l10n.manaValue,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manaMinController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: l10n.minLabel),
                  onChanged: (_) => _scheduleCountUpdate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _manaMaxController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: l10n.maxLabel),
                  onChanged: (_) => _scheduleCountUpdate(),
                ),
              ),
            ],
          ),
          if (_isPokemonActive && hasDefinition('hp')) ...[
            const SizedBox(height: 16),
            Text('HP', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hpMinController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: l10n.minLabel),
                    onChanged: (_) => _scheduleCountUpdate(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hpMaxController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: l10n.maxLabel),
                    onChanged: (_) => _scheduleCountUpdate(),
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
            controller: _artistController,
            decoration: InputDecoration(
              hintText: l10n.typeArtistNameHint,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            onChanged: _onArtistChanged,
          ),
          if (_isPokemonActive && hasDefinition('pokemon.regulation_mark')) ...[
            const SizedBox(height: 16),
            Text(
              'Regulation mark',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            buildChipRow<String>(
              _knownPokemonRegulationMarks,
              (value) => _selectedPokemonRegulationMarks.contains(value),
              (value) {
                if (!_selectedPokemonRegulationMarks.add(value)) {
                  _selectedPokemonRegulationMarks.remove(value);
                }
                _scheduleCountUpdate();
              },
              (value) => value,
            ),
          ],
          if (_isPokemonActive && hasDefinition('pokemon.stage')) ...[
            const SizedBox(height: 16),
            Text('Stage', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            buildChipRow<String>(
              _knownPokemonStages,
              (value) => _selectedPokemonStages.contains(value),
              (value) {
                if (!_selectedPokemonStages.add(value)) {
                  _selectedPokemonStages.remove(value);
                }
                _scheduleCountUpdate();
              },
              (value) => value,
            ),
          ],
          if (_artistController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            if (_loadingArtists)
              const Center(child: CircularProgressIndicator())
            else if (_artistSuggestions.isNotEmpty)
              SizedBox(
                height: _artistSuggestions.length > 6 ? 180 : null,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _artistSuggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final artist = _artistSuggestions[index];
                    return ListTile(
                      title: Text(artist),
                      onTap: () {
                        setState(() {
                          _artistController.text = artist;
                          _artistController.selection = TextSelection.collapsed(
                            offset: artist.length,
                          );
                          _artistSuggestions = [];
                        });
                        _scheduleCountUpdate();
                      },
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
