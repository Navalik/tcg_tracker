part of 'package:tcg_tracker/main.dart';

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)}KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)}MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)}GB';
}

String _setIconUrl(String setCode) {
  final code = setCode.trim().toLowerCase();
  if (code.isEmpty) {
    return '';
  }
  return 'https://svgs.scryfall.io/sets/$code.svg';
}

Widget _buildSetIcon(String setCode, {double size = 28}) {
  if (setCode.trim().isEmpty) {
    return _emptySetIcon(size);
  }
  return Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFF201A14),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: const Color(0xFF3A2F24),
      ),
    ),
    child: SvgPicture.network(
      _setIconUrl(setCode),
      fit: BoxFit.contain,
      colorFilter: const ColorFilter.mode(
        Color(0xFFE9C46A),
        BlendMode.srcIn,
      ),
      placeholderBuilder: (_) => _emptySetIcon(size - 12),
      errorBuilder: (_, _, _) => _emptySetIcon(size - 12),
    ),
  );
}

Widget _emptySetIcon(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF201A14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3A2F24)),
      ),
    ),
  );
}

Widget _buildBadge(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF2A221B),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFF3A2F24)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        color: Color(0xFFE9C46A),
      ),
    ),
  );
}

Widget _statusMiniBadge({IconData? icon, String? label}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF2A221B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF3A2F24)),
    ),
    child: icon != null
        ? Icon(
            icon,
            size: 12,
            color: const Color(0xFFE9C46A),
          )
        : Text(
            label ?? '',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE9C46A),
            ),
          ),
  );
}

String _formatRarity(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  return value[0].toUpperCase() + value.substring(1);
}
