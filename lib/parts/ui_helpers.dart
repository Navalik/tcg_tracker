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

Widget _buildBadge(String label, {bool inverted = false}) {
  final background =
      inverted ? const Color(0xFFE9C46A) : const Color(0xFF2A221B);
  final foreground =
      inverted ? const Color(0xFF2A221B) : const Color(0xFFE9C46A);
  final borderColor =
      inverted ? const Color(0xFFE9C46A) : const Color(0xFF3A2F24);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(9999),
      border: Border.all(color: borderColor),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );
}

Widget _statusMiniBadge({
  IconData? icon,
  String? label,
  double iconSize = 12,
}) {
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
            size: iconSize,
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

const String _latestReleaseNotesId = '0.4.5+6';

String _whatsNewLabel(BuildContext context) {
  final languageCode = Localizations.localeOf(context).languageCode.toLowerCase();
  if (languageCode.startsWith('it')) {
    return 'Novita';
  }
  return "What's new";
}

Future<void> _showLatestReleaseNotesPanel(BuildContext context) async {
  final languageCode = Localizations.localeOf(context).languageCode.toLowerCase();
  final isItalian = languageCode.startsWith('it');
  final title = isItalian ? 'Novita versione 0.4.5' : "What's new in 0.4.5";
  final lines = isItalian
      ? const <String>[
          'Wishlist migliorata: le carte non sono piu marcate come Mancanti.',
          'Vista galleria: aggiunti tasti rapidi + e - per gestire le quantita piu velocemente.',
          'Nei mazzi i tasti rapidi non applicano il foil.',
          "Export Arena piu compatibile: rimossa la riga 'Sideboard'.",
          'Scansione OCR piu fluida: ridotta l\'attesa prima della scelta stampa.',
        ]
      : const <String>[
          'Wishlist improved: cards are no longer shown as Missing.',
          'Gallery view: quick + and - actions to manage quantities faster.',
          'In decks, quick actions do not apply foil.',
          "Arena export compatibility improved: removed the 'Sideboard' line.",
          'OCR scanning feels faster before opening the printing picker.',
        ];
  final closeLabel = isItalian ? 'Chiudi' : 'Close';

  await showDialog<void>(
    context: context,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('- $line', style: textTheme.bodyMedium),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(closeLabel),
          ),
        ],
      );
    },
  );
  await AppSettings.saveLastSeenReleaseNotesId(_latestReleaseNotesId);
}
