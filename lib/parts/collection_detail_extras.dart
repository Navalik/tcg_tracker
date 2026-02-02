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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFBFAE95),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
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
  if (colors.length == 1 && colors.contains('C')) {
    return const [Color(0xFFB9B1A5)];
  }
  return colors.map(_manaColorFromCode).toList();
}

Set<String> _parseColorSet(String colors, String colorIdentity) {
  final values = <String>{};
  void addFrom(String raw) {
    if (raw.trim().isEmpty) {
      return;
    }
    for (final part in raw.split(',')) {
      final value = part.trim().toUpperCase();
      if (value.isNotEmpty) {
        values.add(value);
      }
    }
  }

  addFrom(colors);
  addFrom(colorIdentity);
  if (values.isEmpty) {
    return {'C'};
  }
  return values;
}

Color _manaColorFromCode(String code) {
  switch (code.toUpperCase()) {
    case 'W':
      return const Color(0xFFF5EED3);
    case 'U':
      return const Color(0xFF7FB4FF);
    case 'B':
      return const Color(0xFF8A7CA8);
    case 'R':
      return const Color(0xFFEF8A5A);
    case 'G':
      return const Color(0xFF7FCF9B);
    default:
      return const Color(0xFFB9B1A5);
  }
}

Decoration _cardTintDecoration(BuildContext context, CollectionCardEntry entry) {
  final base = Theme.of(context).colorScheme.surface;
  final accents = _manaAccentColors(
    _parseColorSet(entry.colors, entry.colorIdentity),
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

