part of 'package:tcg_tracker/main.dart';

class _CardDetail {
  const _CardDetail(this.label, this.value);

  final String label;
  final String value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: const Color(0xFFBFAE95)),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

Widget _cornerQuantityBadge(AppLocalizations l10n, int quantity) {
  return CustomPaint(
    painter: _CornerBadgePainter(),
    child: SizedBox(
      width: 36,
      height: 36,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, right: 6),
          child: Text(
            l10n.quantityMultiplier(quantity),
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFE9C46A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _CornerBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2A221B);
    final border = Paint()
      ..color = const Color(0xFF3A2F24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<Color> _manaAccentColors(Set<String> colors) {
  if (colors.isEmpty) {
    return const [];
  }
  if (colors.length == 1 && (colors.contains('C') || colors.contains('N'))) {
    return const [Color(0xFFB9B1A5)];
  }
  return colors.map(_manaColorFromCode).toList();
}

List<Color> _accentColorsForCard({
  required String colors,
  required String colorIdentity,
  required String typeLine,
}) {
  if (TcgEnvironmentController.instance.currentGame == TcgGame.pokemon) {
    return _pokemonAccentColors(
      _parsePokemonTypeTokens(
        colors: colors,
        colorIdentity: colorIdentity,
        typeLine: typeLine,
      ),
    );
  }
  return _manaAccentColors(_parseColorSet(colors, colorIdentity, typeLine));
}

Set<String> _parseColorSet(
  String colors,
  String colorIdentity, [
  String typeLine = '',
]) {
  final values = <String>{};
  void addFrom(String raw) {
    if (raw.trim().isEmpty) {
      return;
    }
    for (final part in raw.split(',')) {
      final code = _normalizeTcgColorCode(part);
      if (code != null) {
        values.add(code);
      }
    }
  }

  addFrom(colors);
  addFrom(colorIdentity);
  if (values.isEmpty) {
    for (final token in typeLine.split(RegExp(r'[^A-Za-z]+'))) {
      final code = _normalizeTcgColorCode(token);
      if (code != null) {
        values.add(code);
      }
    }
  }
  if (values.isEmpty) {
    if (TcgEnvironmentController.instance.currentGame == TcgGame.pokemon) {
      return const {'N'};
    }
    return const {'C'};
  }
  return values;
}

String? _normalizeTcgColorCode(String raw) {
  final token = raw.trim().toUpperCase();
  if (token.isEmpty) {
    return null;
  }
  switch (token) {
    case 'W':
    case 'U':
    case 'B':
    case 'F':
    case 'D':
    case 'R':
    case 'G':
    case 'L':
    case 'C':
    case 'M':
    case 'N':
      return token;
  }
  final clean = token.replaceAll(RegExp(r'[^A-Z]'), '');
  switch (clean) {
    case 'WHITE':
    case 'FAIRY':
      return 'W';
    case 'BLUE':
    case 'WATER':
    case 'ICE':
      return 'U';
    case 'BLACK':
    case 'DARK':
    case 'DARKNESS':
    case 'PSYCHIC':
      return 'B';
    case 'RED':
    case 'FIRE':
      return 'R';
    case 'FIGHTING':
      return 'F';
    case 'DRAGON':
      return 'D';
    case 'ELECTRIC':
    case 'LIGHTNING':
      return 'L';
    case 'GREEN':
    case 'GRASS':
      return 'G';
    case 'COLORLESS':
      return 'C';
    case 'METAL':
    case 'STEEL':
      return 'M';
    case 'NONE':
    case 'NOENERGY':
      return 'N';
    default:
      return null;
  }
}

Set<String> _parsePokemonTypeTokens({
  required String colors,
  required String colorIdentity,
  required String typeLine,
}) {
  final values = <String>{};

  void addToken(String raw) {
    final normalized = _normalizePokemonTypeToken(raw);
    if (normalized != null) {
      values.add(normalized);
    }
  }

  void addFromRaw(String raw) {
    if (raw.trim().isEmpty) {
      return;
    }
    for (final part in raw.split(',')) {
      addToken(part);
    }
    for (final token in raw.split(RegExp(r'[^A-Za-z]+'))) {
      addToken(token);
    }
  }

  addFromRaw(typeLine);
  addFromRaw(colors);
  addFromRaw(colorIdentity);
  if (values.isEmpty) {
    values.add('none');
  }
  return values;
}

String? _normalizePokemonTypeToken(String raw) {
  final token = raw.trim().toLowerCase();
  if (token.isEmpty) {
    return null;
  }
  switch (token) {
    case 'grass':
      return 'grass';
    case 'fire':
      return 'fire';
    case 'water':
      return 'water';
    case 'lightning':
    case 'electric':
      return 'lightning';
    case 'psychic':
      return 'psychic';
    case 'fighting':
      return 'fighting';
    case 'darkness':
    case 'dark':
      return 'darkness';
    case 'metal':
    case 'steel':
      return 'metal';
    case 'fairy':
      return 'fairy';
    case 'dragon':
      return 'dragon';
    case 'colorless':
      return 'colorless';
    case 'ice':
      return 'ice';
    case 'ghost':
      return 'ghost';
    case 'l':
      return 'lightning';
    case 'u':
      return 'water';
    case 'g':
      return 'grass';
    case 'b':
      return 'psychic';
    case 'f':
      return 'fighting';
    case 'd':
      return 'dragon';
    case 'w':
      return 'fairy';
    case 'c':
      return 'colorless';
    case 'n':
    case 'none':
      return 'none';
    case 'r':
      return 'fire';
    default:
      return null;
  }
}

const List<String> _pokemonTypeOrder = <String>[
  'grass',
  'fire',
  'water',
  'lightning',
  'psychic',
  'fighting',
  'darkness',
  'metal',
  'fairy',
  'dragon',
  'ice',
  'ghost',
  'colorless',
  'none',
];

List<Color> _pokemonAccentColors(Set<String> types) {
  final normalized = types.isEmpty ? {'colorless'} : types;
  final sorted = normalized.toList(growable: false)
    ..sort((a, b) {
      final ai = _pokemonTypeOrder.indexOf(a);
      final bi = _pokemonTypeOrder.indexOf(b);
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
  return sorted.map(_pokemonColorFromType).toList(growable: false);
}

Color _pokemonColorFromType(String type) {
  switch (type) {
    case 'grass':
      return const Color(0xFF6DBF5B);
    case 'fire':
      return const Color(0xFFF0803C);
    case 'water':
      return const Color(0xFF4A90E2);
    case 'lightning':
      return const Color(0xFFF2C94C);
    case 'psychic':
      return const Color(0xFFA66DD4);
    case 'fighting':
      return const Color(0xFFC26A4A);
    case 'darkness':
      return const Color(0xFF4F5663);
    case 'metal':
      return const Color(0xFF9AA5B1);
    case 'fairy':
      return const Color(0xFFE68ACF);
    case 'dragon':
      return const Color(0xFF6F5BD6);
    case 'ice':
      return const Color(0xFF7EC8E3);
    case 'ghost':
      return const Color(0xFF5C4B8A);
    default:
      return const Color(0xFFB9B1A5);
  }
}

Color _manaColorFromCode(String code) {
  switch (code.toUpperCase()) {
    case 'W':
      return const Color(0xFFF5EED3);
    case 'U':
      return const Color(0xFF7FB4FF);
    case 'B':
      return const Color(0xFF8A7CA8);
    case 'F':
      return const Color(0xFFC26A4A);
    case 'D':
      return const Color(0xFF6F5BD6);
    case 'R':
      return const Color(0xFFEF8A5A);
    case 'L':
      return const Color(0xFFF2D35A);
    case 'G':
      return const Color(0xFF7FCF9B);
    default:
      return const Color(0xFFB9B1A5);
  }
}

Decoration _cardTintDecoration(
  BuildContext context,
  CollectionCardEntry entry,
) {
  final base = Theme.of(context).colorScheme.surface;
  final accents = _accentColorsForCard(
    colors: entry.colors,
    colorIdentity: entry.colorIdentity,
    typeLine: entry.typeLine,
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

Decoration _priceBadgeDecoration(
  BuildContext context,
  CollectionCardEntry entry,
) {
  final base = Theme.of(context).colorScheme.surface;
  final accents = _accentColorsForCard(
    colors: entry.colors,
    colorIdentity: entry.colorIdentity,
    typeLine: entry.typeLine,
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

Color _rarityColor(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'common':
      return const Color(0xFFB8B1A5);
    case 'uncommon':
      return const Color(0xFF7FB98E);
    case 'rare':
      return const Color(0xFFE2C26A);
    case 'mythic':
    case 'mythic rare':
      return const Color(0xFFEA8A5C);
    default:
      return const Color(0xFFBFAE95);
  }
}

Widget _raritySquare(String raw) {
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: _rarityColor(raw),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: const Color(0xFF3A2F24)),
    ),
  );
}

class _PokemonCardDetailsSnapshot {
  const _PokemonCardDetailsSnapshot({
    required this.category,
    required this.hp,
    required this.types,
    required this.stage,
    required this.evolvesFrom,
    required this.regulationMark,
    required this.weaknesses,
    required this.resistances,
    required this.retreatCost,
  });

  final String category;
  final String hp;
  final String types;
  final String stage;
  final String evolvesFrom;
  final String regulationMark;
  final String weaknesses;
  final String resistances;
  final String retreatCost;
}

_PokemonCardDetailsSnapshot? _parsePokemonCardDetails(
  Map<String, dynamic>? payload,
) {
  if (payload == null) {
    return null;
  }
  final rawPokemon = payload['pokemon'];
  final pokemon = rawPokemon is Map<String, dynamic>
      ? rawPokemon
      : rawPokemon is Map
      ? Map<String, dynamic>.from(rawPokemon)
      : payload;
  final category = (pokemon['category'] as String?)?.trim() ?? '';
  final hp = pokemon['hp']?.toString().trim() ?? '';
  final stage = (pokemon['stage'] as String?)?.trim() ?? '';
  final evolvesFrom =
      ((pokemon['evolves_from'] ?? pokemon['evolvesFrom']) as String?)
          ?.trim() ??
      '';
  final regulationMark =
      (pokemon['regulation_mark'] as String?)?.trim() ??
      (pokemon['regulationMark'] as String?)?.trim() ??
      '';
  final retreatCost = pokemon['retreat_cost']?.toString().trim() ?? '';

  List<String> readStringList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String formatTypedValues(Object? raw) {
    if (raw is! List) {
      return '';
    }
    final values = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final entry = <String, dynamic>{...item};
        final type = (entry['type'] as String?)?.trim() ?? '';
        final value = (entry['value'] as String?)?.trim() ?? '';
        final text = [type, value]
            .where((part) => part.isNotEmpty)
            .join(' ');
        if (text.isNotEmpty) {
          values.add(text);
        }
      }
    }
    return values.join(', ');
  }

  final types = {
    ...readStringList(pokemon['types']),
    ...readStringList(payload['types']),
  }.join(', ');

  if (category.isEmpty &&
      hp.isEmpty &&
      types.isEmpty &&
      stage.isEmpty &&
      evolvesFrom.isEmpty &&
      regulationMark.isEmpty &&
      retreatCost.isEmpty) {
    return null;
  }

  return _PokemonCardDetailsSnapshot(
    category: category,
    hp: hp,
    types: types,
    stage: stage,
    evolvesFrom: evolvesFrom,
    regulationMark: regulationMark,
    weaknesses: formatTypedValues(pokemon['weaknesses']),
    resistances: formatTypedValues(pokemon['resistances']),
    retreatCost: retreatCost,
  );
}

String _localizedInlineLabel(
  BuildContext context, {
  required String it,
  required String en,
}) {
  final code = Localizations.localeOf(context).languageCode.toLowerCase();
  return code.startsWith('it') ? it : en;
}
