part of 'package:tcg_tracker/main.dart';

final Map<String, Future<String?>> _mtgSetIconSvgCache =
    <String, Future<String?>>{};
final RegExp _setCodeSafePattern = RegExp(r'^[a-z0-9]+$');

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
  final encoded = Uri.encodeComponent(code);
  if (TcgEnvironmentController.instance.currentGame == TcgGame.pokemon) {
    return 'https://images.pokemontcg.io/$encoded/symbol.png';
  }
  return 'https://svgs.scryfall.io/sets/$encoded.svg';
}

String _normalizeCardImageUrlForDisplay(String? rawImageUri) {
  final imageUrl = (rawImageUri ?? '').trim();
  if (imageUrl.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(imageUrl);
  if (uri == null) {
    return imageUrl;
  }
  final isPokemonGame =
      TcgEnvironmentController.instance.currentGame == TcgGame.pokemon;
  if (!isPokemonGame || uri.host.toLowerCase() != 'images.pokemontcg.io') {
    return imageUrl;
  }
  if (uri.pathSegments.isEmpty) {
    return imageUrl;
  }
  final segments = uri.pathSegments.toList(growable: false);
  final fileName = segments.last;
  if (!fileName.toLowerCase().endsWith('_hires.png')) {
    return imageUrl;
  }
  final normalizedFileName = fileName.replaceFirst(
    RegExp(r'_hires\.png$', caseSensitive: false),
    '.png',
  );
  final updated = List<String>.from(segments);
  updated[updated.length - 1] = normalizedFileName;
  return uri.replace(pathSegments: updated).toString();
}

Future<String?> _loadMtgSetSvg(String setCode) {
  return _mtgSetIconSvgCache.putIfAbsent(setCode, () async {
    try {
      final response = await http
          .get(Uri.parse(_setIconUrl(setCode)))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        return null;
      }
      final body = response.body.trimLeft();
      if (!body.startsWith('<svg')) {
        return null;
      }
      return body;
    } catch (_) {
      return null;
    }
  });
}

Widget _buildSetIcon(String setCode, {double size = 28}) {
  final code = setCode.trim().toLowerCase();
  if (code.isEmpty || !_setCodeSafePattern.hasMatch(code)) {
    return _emptySetIcon(size);
  }
  final isPokemonGame =
      TcgEnvironmentController.instance.currentGame == TcgGame.pokemon;
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
    child: isPokemonGame
        ? ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0xFFE9C46A),
              BlendMode.srcIn,
            ),
            child: Image.network(
              _setIconUrl(code),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _emptySetIcon(size - 12),
            ),
          )
        : FutureBuilder<String?>(
            future: _loadMtgSetSvg(code),
            builder: (context, snapshot) {
              final svg = snapshot.data;
              if (svg == null || svg.isEmpty) {
                return _emptySetIcon(size - 12);
              }
              return SvgPicture.string(
                svg,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFE9C46A),
                  BlendMode.srcIn,
                ),
              );
            },
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

const String _latestReleaseNotesId = '0.4.7+8';

String _whatsNewLabel(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return l10n.whatsNewButtonLabel;
}

Future<void> _showLatestReleaseNotesPanel(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final title = l10n.whatsNewDialogTitle;
  final lines = <String>[
    l10n.whatsNewLine1,
    l10n.whatsNewLine2,
    l10n.whatsNewLine3,
    l10n.whatsNewLine4,
    l10n.whatsNewLine5,
    l10n.whatsNewLine6,
    l10n.whatsNewLine7,
    l10n.whatsNewLine8,
    l10n.whatsNewLine9,
  ];

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
            child: Text(l10n.closeLabel),
          ),
        ],
      );
    },
  );
  await AppSettings.saveLastSeenReleaseNotesId(_latestReleaseNotesId);
}
