part of 'package:tcg_tracker/main.dart';

class _DeckSectionRow {
  const _DeckSectionRow.header({
    required this.typeKey,
    required this.label,
    required this.count,
  }) : entry = null;

  const _DeckSectionRow.card(this.entry)
    : typeKey = null,
      label = null,
      count = null;

  final String? typeKey;
  final String? label;
  final int? count;
  final CollectionCardEntry? entry;

  bool get isHeader => entry == null;
}

class _DeckSection {
  const _DeckSection({
    required this.typeKey,
    required this.label,
    required this.cards,
  });

  final String typeKey;
  final String label;
  final List<CollectionCardEntry> cards;
}

class _DeckStats {
  const _DeckStats({
    required this.total,
    required this.creatures,
    required this.lands,
    required this.other,
  });

  final int total;
  final int creatures;
  final int lands;
  final int other;
}

class _PokemonDeckStats {
  const _PokemonDeckStats({
    required this.total,
    required this.pokemon,
    required this.trainer,
    required this.energy,
    required this.basicPokemon,
    required this.overLimitNames,
  });

  final int total;
  final int pokemon;
  final int trainer;
  final int energy;
  final int basicPokemon;
  final int overLimitNames;
}

extension _CollectionDetailDeckStateX on _CollectionDetailPageState {
  bool _isBasicLandForMana(CollectionCardEntry entry, String mana) {
    final normalizedMana = mana.trim().toUpperCase();
    if (normalizedMana.isEmpty) {
      return false;
    }
    final typeLine = entry.typeLine.trim().toLowerCase();
    if (!typeLine.contains('land') || !typeLine.contains('basic')) {
      return false;
    }
    final colors = _cardColors(entry);
    return colors.length == 1 && colors.contains(normalizedMana);
  }

  Map<String, int> _basicLandCountsForCards(List<CollectionCardEntry> cards) {
    final counts = <String, int>{
      for (final mana in _CollectionDetailPageState._basicLandManaOrder)
        mana: 0,
    };
    for (final entry in cards) {
      if (entry.quantity <= 0) {
        continue;
      }
      for (final mana in _CollectionDetailPageState._basicLandManaOrder) {
        if (_isBasicLandForMana(entry, mana)) {
          counts[mana] = (counts[mana] ?? 0) + entry.quantity;
          break;
        }
      }
    }
    return counts;
  }

  CollectionCardEntry? _findBasicLandEntryForMana(
    List<CollectionCardEntry> cards,
    String mana,
  ) {
    for (final entry in cards) {
      if (entry.quantity > 0 && _isBasicLandForMana(entry, mana)) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _changeBasicLandInDeck(String mana, int delta) async {
    if (!widget.isDeckCollection || delta == 0) {
      return;
    }
    final ownedCollectionId = _ownedCollectionId ?? widget.collectionId;
    final preferredBasicCardId = await ScryfallDatabase.instance
        .fetchPreferredBasicLandCardId(mana);
    final preferredEntry = preferredBasicCardId == null
        ? null
        : await ScryfallDatabase.instance.fetchCardEntryById(
            preferredBasicCardId,
            printingId: null,
            collectionId: ownedCollectionId,
          );
    var existing = _findBasicLandEntryForMana(_cards, mana);
    existing ??= await ScryfallDatabase.instance
        .fetchFirstBasicLandEntryForCollection(ownedCollectionId, mana);
    if (delta < 0) {
      final entryToReduce =
          (preferredEntry != null && preferredEntry.quantity > 0)
          ? preferredEntry
          : existing;
      if (entryToReduce == null || entryToReduce.quantity <= 0) {
        return;
      }
      final nextQuantity = entryToReduce.quantity - 1;
      await ScryfallDatabase.instance.upsertCollectionCard(
        ownedCollectionId,
        entryToReduce.cardId,
        printingId: entryToReduce.printingId,
        quantity: nextQuantity,
        foil: entryToReduce.foil,
        altArt: entryToReduce.altArt,
      );
      await _loadCards();
      return;
    }

    CollectionCardEntry? targetEntry;
    if (preferredBasicCardId != null) {
      targetEntry = preferredEntry;
      targetEntry ??= await ScryfallDatabase.instance.fetchCardEntryById(
        preferredBasicCardId,
        printingId: null,
        collectionId: ownedCollectionId,
      );
    } else {
      targetEntry = existing;
    }
    if (targetEntry == null) {
      return;
    }

    final nextQuantity = targetEntry.quantity + 1;
    await ScryfallDatabase.instance.upsertCollectionCard(
      ownedCollectionId,
      targetEntry.cardId,
      printingId: targetEntry.printingId,
      quantity: nextQuantity,
      foil: false,
      altArt: false,
    );
    await _loadCards();
  }

  Color _basicLandColor(String mana) {
    switch (mana) {
      case 'W':
        return const Color(0xFFF0E6C8);
      case 'U':
        return const Color(0xFF74C0FC);
      case 'B':
        return const Color(0xFF6F5B8C);
      case 'R':
        return const Color(0xFFE53935);
      case 'G':
        return const Color(0xFF81C784);
      default:
        return const Color(0xFFE9C46A);
    }
  }

  String _deckFormatSummaryLabel(AppLocalizations l10n) {
    final italian = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('it');
    final prefix = italian ? 'Formato' : 'Format';
    final format = _deckFormatConstraint;
    if (format == null) {
      return italian ? '$prefix: nessun formato' : '$prefix: no format';
    }
    final normalized = format.trim();
    final titled = normalized.isEmpty
        ? normalized
        : normalized[0].toUpperCase() + normalized.substring(1);
    final hasNotLegalCard = _deckLegalityByCardId.values.any(
      (isLegal) => !isLegal,
    );
    final suffix = hasNotLegalCard ? ' (${l10n.notLegalLabel})' : '';
    return '$prefix: $titled$suffix';
  }

  Color _deckFormatSummaryColor() {
    final hasNotLegalCard = _deckLegalityByCardId.values.any(
      (isLegal) => !isLegal,
    );
    return hasNotLegalCard ? const Color(0xFFD06D5F) : const Color(0xFFBFAE95);
  }

  Future<void> _loadSideboardCards({int? requestId}) async {
    if (!widget.isDeckCollection) {
      return;
    }
    final sideboardCollectionId =
        _sideboardCollectionId ??
        await ScryfallDatabase.instance.ensureDeckSideboardCollectionId(
          widget.collectionId,
        );
    _sideboardCollectionId = sideboardCollectionId;
    final all = <CollectionCardEntry>[];
    var offset = 0;
    while (true) {
      final page = await ScryfallDatabase.instance.fetchCollectionCards(
        sideboardCollectionId,
        limit: _CollectionDetailPageState._pageSize,
        offset: offset,
      );
      if (page.isEmpty) {
        break;
      }
      all.addAll(page.where((entry) => entry.quantity > 0));
      if (page.length < _CollectionDetailPageState._pageSize) {
        break;
      }
      offset += page.length;
    }
    if (!mounted ||
        (requestId != null && requestId != _activeLoadRequestId)) {
      return;
    }
    // ignore: invalid_use_of_protected_member
    setState(() {
      _sideboardCards
        ..clear()
        ..addAll(all);
    });
    if (requestId != null && requestId != _activeLoadRequestId) {
      return;
    }
    await _refreshDeckLegalityForLoadedCards();
  }

  String _sideboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sideboard';
    }
    return 'Sideboard';
  }

  String _moveToSideboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sposta nel sideboard';
    }
    return 'Move to sideboard';
  }

  String _moveToMainboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sposta nel mainboard';
    }
    return 'Move to mainboard';
  }

  String _moveAllToMainboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sposta tutto nel mainboard';
    }
    return 'Move all to mainboard';
  }

  String _moveAllToSideboardLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode.startsWith('it')) {
      return 'Sposta tutto nel sideboard';
    }
    return 'Move all to sideboard';
  }

  Future<void> _moveCardBetweenMainAndSide(
    CollectionCardEntry entry, {
    required bool toSideboard,
    bool moveAll = false,
  }) async {
    if (!widget.isDeckCollection) {
      return;
    }
    final mainCollectionId = _ownedCollectionId ?? widget.collectionId;
    final sideCollectionId =
        _sideboardCollectionId ??
        await ScryfallDatabase.instance.ensureDeckSideboardCollectionId(
          widget.collectionId,
        );
    _sideboardCollectionId = sideCollectionId;
    final fromCollectionId = toSideboard ? mainCollectionId : sideCollectionId;
    final toCollectionId = toSideboard ? sideCollectionId : mainCollectionId;
    final fromEntry = await ScryfallDatabase.instance.fetchCardEntryById(
      entry.cardId,
      printingId: entry.printingId,
      collectionId: fromCollectionId,
    );
    final fromQty = fromEntry?.quantity ?? 0;
    if (fromQty <= 0) {
      return;
    }
    final delta = moveAll ? fromQty : 1;
    final toEntry = await ScryfallDatabase.instance.fetchCardEntryById(
      entry.cardId,
      printingId: entry.printingId,
      collectionId: toCollectionId,
    );
    final toQty = (toEntry?.quantity ?? 0) + delta;
    final nextFrom = fromQty - delta;
    await ScryfallDatabase.instance.upsertCollectionCard(
      fromCollectionId,
      entry.cardId,
      printingId: entry.printingId,
      quantity: nextFrom,
      foil: false,
      altArt: false,
    );
    await ScryfallDatabase.instance.upsertCollectionCard(
      toCollectionId,
      entry.cardId,
      printingId: entry.printingId,
      quantity: toQty,
      foil: false,
      altArt: false,
    );
    if (!mounted) {
      return;
    }
    await _loadCards();
  }

  Future<void> _showSideboardCardActions(
    CollectionCardEntry entry,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              Text(entry.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _subtitleLabel(entry),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFBFAE95)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _moveCardBetweenMainAndSide(
                    entry,
                    toSideboard: false,
                    moveAll: false,
                  );
                },
                icon: const Icon(Icons.move_up),
                label: Text(_moveToMainboardLabel()),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _moveCardBetweenMainAndSide(
                    entry,
                    toSideboard: false,
                    moveAll: true,
                  );
                },
                icon: const Icon(Icons.unarchive_outlined),
                label: Text(_moveAllToMainboardLabel()),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMainboardCardActions(
    CollectionCardEntry entry,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              Text(entry.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _subtitleLabel(entry),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFBFAE95)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _moveCardBetweenMainAndSide(
                    entry,
                    toSideboard: true,
                    moveAll: false,
                  );
                },
                icon: const Icon(Icons.move_down),
                label: Text(_moveToSideboardLabel()),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _moveCardBetweenMainAndSide(
                    entry,
                    toSideboard: true,
                    moveAll: true,
                  );
                },
                icon: const Icon(Icons.unarchive_outlined),
                label: Text(_moveAllToSideboardLabel()),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        );
      },
    );
  }

  String _deckPrimaryType(CollectionCardEntry entry) {
    if (_isPokemonDeck) {
      final types = _cardTypes(entry);
      if (types.contains('Pokemon')) {
        return 'Pokemon';
      }
      if (types.contains('Energy')) {
        return 'Energy';
      }
      if (types.contains('Trainer') ||
          types.contains('Item') ||
          types.contains('Supporter') ||
          types.contains('Stadium') ||
          types.contains('Tool')) {
        return 'Trainer';
      }
      return 'Other';
    }
    final types = _cardTypes(entry);
    for (final type in _activeDeckTypeOrder) {
      if (type == 'Other') {
        continue;
      }
      if (types.contains(type)) {
        return type;
      }
    }
    return 'Other';
  }

  String _deckSectionLabel(String typeKey, AppLocalizations l10n) {
    if (_isPokemonDeck) {
      switch (typeKey) {
        case 'Pokemon':
          return 'Pokemon';
        case 'Trainer':
          return l10n.pokemonTypeTrainer;
        case 'Energy':
          return l10n.pokemonTypeEnergy;
        default:
          return l10n.deckSectionOther;
      }
    }
    switch (typeKey) {
      case 'Creature':
        return l10n.deckSectionCreatures;
      case 'Instant':
        return l10n.deckSectionInstants;
      case 'Sorcery':
        return l10n.deckSectionSorceries;
      case 'Artifact':
        return l10n.deckSectionArtifacts;
      case 'Enchantment':
        return l10n.deckSectionEnchantments;
      case 'Planeswalker':
        return l10n.deckSectionPlaneswalkers;
      case 'Battle':
        return l10n.deckSectionBattles;
      case 'Land':
        return l10n.deckSectionLands;
      case 'Tribal':
        return l10n.deckSectionTribals;
      default:
        return l10n.deckSectionOther;
    }
  }

  List<_DeckSectionRow> _buildDeckSectionRows(
    List<CollectionCardEntry> cards,
    AppLocalizations l10n,
  ) {
    final grouped = <String, List<CollectionCardEntry>>{};
    for (final type in _activeDeckTypeOrder) {
      grouped[type] = <CollectionCardEntry>[];
    }
    for (final entry in cards) {
      final key = _deckPrimaryType(entry);
      grouped.putIfAbsent(key, () => <CollectionCardEntry>[]).add(entry);
    }
    final rows = <_DeckSectionRow>[];
    for (final type in _activeDeckTypeOrder) {
      final sectionCards = grouped[type] ?? const <CollectionCardEntry>[];
      if (sectionCards.isEmpty) {
        continue;
      }
      final count = _isPokemonDeck
          ? sectionCards.fold<int>(
              0,
              (sum, card) => sum + (card.quantity > 0 ? card.quantity : 0),
            )
          : sectionCards.length;
      rows.add(
        _DeckSectionRow.header(
          typeKey: type,
          label: _deckSectionLabel(type, l10n),
          count: count,
        ),
      );
      for (final entry in sectionCards) {
        rows.add(_DeckSectionRow.card(entry));
      }
    }
    return rows;
  }

  Widget _buildDeckSectionHeader(
    AppLocalizations l10n, {
    required String label,
    required int count,
    required bool first,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 24, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9C46A),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFEFE7D8),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              Text(
                l10n.cardCount(count),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD2C2A9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1.4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [Color(0xFFE9C46A), Color(0x553A2F24)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DeckSection> _buildDeckSections(
    List<CollectionCardEntry> cards,
    AppLocalizations l10n,
  ) {
    final grouped = <String, List<CollectionCardEntry>>{};
    for (final type in _activeDeckTypeOrder) {
      grouped[type] = <CollectionCardEntry>[];
    }
    for (final entry in cards) {
      final key = _deckPrimaryType(entry);
      grouped.putIfAbsent(key, () => <CollectionCardEntry>[]).add(entry);
    }
    final sections = <_DeckSection>[];
    for (final type in _activeDeckTypeOrder) {
      final sectionCards = grouped[type] ?? const <CollectionCardEntry>[];
      if (sectionCards.isEmpty) {
        continue;
      }
      sections.add(
        _DeckSection(
          typeKey: type,
          label: _deckSectionLabel(type, l10n),
          cards: sectionCards,
        ),
      );
    }
    return sections;
  }

  _DeckStats _buildDeckStats(List<CollectionCardEntry> cards) {
    var total = 0;
    var creatures = 0;
    var lands = 0;
    var other = 0;
    for (final entry in cards) {
      final qty = entry.quantity > 0 ? entry.quantity : 0;
      if (qty == 0) {
        continue;
      }
      total += qty;
      final types = _cardTypes(entry);
      if (types.contains('Creature')) {
        creatures += qty;
      } else if (types.contains('Land')) {
        lands += qty;
      } else {
        other += qty;
      }
    }
    return _DeckStats(
      total: total,
      creatures: creatures,
      lands: lands,
      other: other,
    );
  }

  bool _isPokemonBasicEnergy(CollectionCardEntry entry) {
    final types = _cardTypes(entry);
    if (!types.contains('Energy')) {
      return false;
    }
    final normalized = entry.typeLine.toLowerCase().replaceAll(
      'pokÃƒÂ©mon',
      'pokemon',
    );
    return normalized.contains('basic');
  }

  _PokemonDeckStats _buildPokemonDeckStats(List<CollectionCardEntry> cards) {
    var total = 0;
    var pokemon = 0;
    var trainer = 0;
    var energy = 0;
    var basicPokemon = 0;
    final quantitiesByName = <String, int>{};
    final basicEnergyNames = <String>{};
    for (final entry in cards) {
      final qty = entry.quantity > 0 ? entry.quantity : 0;
      if (qty == 0) {
        continue;
      }
      total += qty;
      final types = _cardTypes(entry);
      if (types.contains('Pokemon')) {
        pokemon += qty;
        final normalized = entry.typeLine.toLowerCase().replaceAll(
          'pokÃƒÂ©mon',
          'pokemon',
        );
        if (normalized.contains('basic')) {
          basicPokemon += qty;
        }
      } else if (types.contains('Energy')) {
        energy += qty;
      } else if (types.contains('Trainer') ||
          types.contains('Item') ||
          types.contains('Supporter') ||
          types.contains('Stadium') ||
          types.contains('Tool')) {
        trainer += qty;
      } else {
        trainer += qty;
      }
      final normalizedName = entry.name.trim().toLowerCase();
      if (normalizedName.isNotEmpty) {
        quantitiesByName[normalizedName] =
            (quantitiesByName[normalizedName] ?? 0) + qty;
        if (_isPokemonBasicEnergy(entry)) {
          basicEnergyNames.add(normalizedName);
        }
      }
    }
    var overLimitNames = 0;
    quantitiesByName.forEach((name, qty) {
      if (basicEnergyNames.contains(name)) {
        return;
      }
      if (qty > 4) {
        overLimitNames += 1;
      }
    });
    return _PokemonDeckStats(
      total: total,
      pokemon: pokemon,
      trainer: trainer,
      energy: energy,
      basicPokemon: basicPokemon,
      overLimitNames: overLimitNames,
    );
  }

  Widget _buildDeckStatsCard(
    List<CollectionCardEntry> cards,
    AppLocalizations l10n,
  ) {
    if (_isPokemonDeck) {
      return _buildPokemonDeckStatsCard(cards, l10n);
    }
    final stats = _buildDeckStats(cards);
    final basicLandCounts = _basicLandCountsForCards(cards);
    final languageCode = Localizations.localeOf(context).languageCode;
    final totalLabel = languageCode.toLowerCase().startsWith('it')
        ? 'Totale'
        : 'Total';
    Widget statCell(String label, int value) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0x221E1713),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x2FE9C46A)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFE9C46A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD2C2A9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget basicLandCell(String mana) {
      final count = basicLandCounts[mana] ?? 0;
      final manaColor = _basicLandColor(mana);
      Widget actionButton({
        required IconData icon,
        required VoidCallback onTap,
        required double alpha,
      }) {
        return Material(
          color: const Color(0xCC1C1510),
          shape: const CircleBorder(
            side: BorderSide(color: Color(0xFF5D4731), width: 1),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Icon(
                icon,
                size: 14,
                color: manaColor.withValues(alpha: alpha),
              ),
            ),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: manaColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: manaColor.withValues(alpha: 0.55)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            actionButton(
              icon: Icons.add,
              onTap: () => _changeBasicLandInDeck(mana, 1),
              alpha: 0.95,
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFFF5ECD9),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            actionButton(
              icon: Icons.remove,
              onTap: () => _changeBasicLandInDeck(mana, -1),
              alpha: 0.9,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4AE9C46A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 8,
            childAspectRatio: 3.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              statCell(totalLabel, stats.total),
              statCell(l10n.deckSectionCreatures, stats.creatures),
              statCell(l10n.deckSectionLands, stats.lands),
              statCell(l10n.deckSectionOther, stats.other),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.basicLandsLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFD2C2A9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _CollectionDetailPageState._basicLandManaOrder
                .map(basicLandCell)
                .toList(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _deckFormatSummaryLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _deckFormatSummaryColor(),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPokemonDeckStatsCard(
    List<CollectionCardEntry> cards,
    AppLocalizations l10n,
  ) {
    final stats = _buildPokemonDeckStats(cards);
    Widget statCell(String label, int value) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0x221E1713),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x2FE9C46A)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFE9C46A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD2C2A9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget ruleRow({
      required bool ok,
      required String okLabel,
      required String failLabel,
    }) {
      final bg = ok ? const Color(0x2A4BB26A) : const Color(0x4AA4463F);
      final border = ok ? const Color(0x884BB26A) : const Color(0x88D06D5F);
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(
          ok ? okLabel : failLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFFEFE7D8),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final totalOk = stats.total == 60;
    final hasBasicPokemon = stats.basicPokemon > 0;
    final copyLimitOk = stats.overLimitNames == 0;
    final totalFailLabel = stats.total < 60
        ? l10n.deckAddCardsToReach60(60 - stats.total)
        : l10n.deckRemoveCardsToReturn60(stats.total - 60);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4AE9C46A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 8,
            childAspectRatio: 3.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              statCell(l10n.totalLabel, stats.total),
              statCell('Pokemon', stats.pokemon),
              statCell(l10n.pokemonTypeTrainer, stats.trainer),
              statCell(l10n.pokemonEnergyPluralLabel, stats.energy),
            ],
          ),
          ruleRow(
            ok: totalOk,
            okLabel: l10n.deckRule60Ok,
            failLabel: totalFailLabel,
          ),
          ruleRow(
            ok: hasBasicPokemon,
            okLabel: l10n.deckBasicPokemonPresentOk,
            failLabel: l10n.deckBasicPokemonRequired,
          ),
          ruleRow(
            ok: copyLimitOk,
            okLabel: l10n.deckCopyLimitOk,
            failLabel: l10n.deckCopyLimitExceeded(stats.overLimitNames),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckTypeListView(
    List<CollectionCardEntry> visibleCards,
    AppLocalizations l10n,
  ) {
    final rows = _buildDeckSectionRows(visibleCards, l10n);
    final sideRows = _buildDeckSectionRows(_sideboardCards, l10n);
    final children = <Widget>[_buildDeckStatsCard(visibleCards, l10n)];
    final listBottomPadding = 112.0 + MediaQuery.of(context).padding.bottom;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      final row = rows[rowIndex];
      if (row.isHeader) {
        final previous = rowIndex > 0 ? rows[rowIndex - 1] : null;
        children.add(
          _buildDeckSectionHeader(
            l10n,
            label: row.label!,
            count: row.count!,
            first: rowIndex == 0 || previous?.isHeader == true,
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _buildListCardTile(row.entry!, l10n),
          ),
        );
      }
    }
    if (_sideboardCards.isNotEmpty) {
      children.add(
        _buildDeckSectionHeader(
          l10n,
          label: _sideboardLabel(),
          count: _sideboardCards.length,
          first: false,
        ),
      );
      for (var rowIndex = 0; rowIndex < sideRows.length; rowIndex += 1) {
        final row = sideRows[rowIndex];
        if (row.isHeader) {
          children.add(
            _buildDeckSectionHeader(
              l10n,
              label: row.label!,
              count: row.count!,
              first: false,
            ),
          );
        } else {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildReadOnlyListCardTile(row.entry!, l10n),
            ),
          );
        }
      }
    }
    if (_loadingMore) {
      children.add(_buildLoadMoreIndicator());
    }
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(20, 20, 20, listBottomPadding),
      children: children,
    );
  }

  Widget _buildDeckTypeGalleryView(
    List<CollectionCardEntry> visibleCards,
    AppLocalizations l10n,
  ) {
    final sections = _buildDeckSections(visibleCards, l10n);
    final children = <Widget>[_buildDeckStatsCard(visibleCards, l10n)];
    final listBottomPadding = 112.0 + MediaQuery.of(context).padding.bottom;
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      children.add(
        _buildDeckSectionHeader(
          l10n,
          label: section.label,
          count: section.cards.length,
          first: i == 0,
        ),
      );
      children.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.64,
          ),
          itemCount: section.cards.length,
          itemBuilder: (context, index) {
            final entry = section.cards[index];
            return _buildGalleryCardTile(entry, l10n);
          },
        ),
      );
    }
    if (_sideboardCards.isNotEmpty) {
      final sideSections = _buildDeckSections(_sideboardCards, l10n);
      children.add(
        _buildDeckSectionHeader(
          l10n,
          label: _sideboardLabel(),
          count: _sideboardCards.length,
          first: false,
        ),
      );
      for (final section in sideSections) {
        children.add(
          _buildDeckSectionHeader(
            l10n,
            label: section.label,
            count: section.cards.length,
            first: false,
          ),
        );
        children.add(
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.64,
            ),
            itemCount: section.cards.length,
            itemBuilder: (context, index) {
              final entry = section.cards[index];
              return _buildReadOnlyGalleryCardTile(entry, l10n);
            },
          ),
        );
      }
    }
    if (_loadingMore) {
      children.add(_buildLoadMoreIndicator());
    }
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(20, 16, 20, listBottomPadding),
      children: children,
    );
  }
}
