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
  if (!isPokemonGame) {
    return imageUrl;
  }
  final host = uri.host.toLowerCase();
  if (host == 'assets.tcgdex.net') {
    final path = uri.path.trim();
    final lowerPath = path.toLowerCase();
    final hasKnownImageExtension =
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.webp');
    if (!hasKnownImageExtension) {
      final nextPath = path.endsWith('/')
          ? '${path}high.webp'
          : '$path/high.webp';
      return uri.replace(path: nextPath).toString();
    }
    return imageUrl;
  }
  if (host != 'images.pokemontcg.io') {
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
      border: Border.all(color: const Color(0xFF3A2F24)),
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

Widget _missingCardArtPlaceholder(
  String setCode, {
  String? label,
  bool compact = false,
}) {
  final iconSize = compact ? 38.0 : 54.0;
  final title = (label ?? '').trim().isEmpty
      ? 'Image unavailable'
      : label!.trim();
  return Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF241C15), Color(0xFF1A1510)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFF3A2F24)),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -18,
          right: -12,
          child: Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x10E9C46A),
              border: Border.all(color: const Color(0x18E9C46A)),
            ),
          ),
        ),
        Positioned(
          bottom: -16,
          left: -8,
          child: Container(
            width: compact ? 46 : 60,
            height: compact ? 46 : 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x0CE9C46A),
              border: Border.all(color: const Color(0x14E9C46A)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSetIcon(setCode, size: iconSize),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFBFAE95),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildBadge(String label, {bool inverted = false}) {
  final background = inverted
      ? const Color(0xFFE9C46A)
      : const Color(0xFF2A221B);
  final foreground = inverted
      ? const Color(0xFF2A221B)
      : const Color(0xFFE9C46A);
  final borderColor = inverted
      ? const Color(0xFFE9C46A)
      : const Color(0xFF3A2F24);
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

Widget _buildMissingCardChip(BuildContext context, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE9C46A),
      borderRadius: BorderRadius.circular(9999),
      border: Border.all(color: const Color(0xFFE9C46A)),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2A221B),
      ),
    ),
  );
}

Widget _buildCardCornerTextLabel(
  BuildContext context,
  String label, {
  Color color = const Color(0xFFE9C46A),
}) {
  return Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 13.5,
      color: color,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    ),
  );
}

Widget _statusMiniBadge({IconData? icon, String? label, double iconSize = 12}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF2A221B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF3A2F24)),
    ),
    child: icon != null
        ? Icon(icon, size: iconSize, color: const Color(0xFFE9C46A))
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

EdgeInsets _bottomSheetMenuMargin(BuildContext context) {
  final bottomInset = MediaQuery.of(context).viewPadding.bottom;
  return EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset);
}

String _formatRarity(BuildContext context, String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  final normalized = value.toLowerCase();
  final italian = Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('it');
  const localized = <String, ({String en, String it})>{
    'common': (en: 'Common', it: 'Comune'),
    'comune': (en: 'Common', it: 'Comune'),
    'uncommon': (en: 'Uncommon', it: 'Non comune'),
    'non comune': (en: 'Uncommon', it: 'Non comune'),
    'rare': (en: 'Rare', it: 'Rara'),
    'rara': (en: 'Rare', it: 'Rara'),
    'mythic': (en: 'Mythic', it: 'Mitica'),
    'mythic rare': (en: 'Mythic', it: 'Mitica'),
    'mitica': (en: 'Mythic', it: 'Mitica'),
    'ultra rare': (en: 'Ultra rare', it: 'Ultrarara'),
    'ultrarare': (en: 'Ultra rare', it: 'Ultrarara'),
    'ultrarara': (en: 'Ultra rare', it: 'Ultrarara'),
    'double rare': (en: 'Double rare', it: 'Rara doppia'),
    'rara doppia': (en: 'Double rare', it: 'Rara doppia'),
    'hyper rare': (en: 'Hyper rare', it: 'Rara iper'),
    'rara iper': (en: 'Hyper rare', it: 'Rara iper'),
    'special illustration rare': (
      en: 'Special illustration rare',
      it: 'Rara illustrazione speciale',
    ),
    'rara illustrazione speciale': (
      en: 'Special illustration rare',
      it: 'Rara illustrazione speciale',
    ),
    'illustration rare': (en: 'Illustration rare', it: 'Rara illustrazione'),
    'rara illustrazione': (en: 'Illustration rare', it: 'Rara illustrazione'),
    'ace spec rare': (en: 'Ace spec rare', it: 'Rara asso tattico'),
    'rara asso tattico': (en: 'Ace spec rare', it: 'Rara asso tattico'),
    'promo': (en: 'Promo', it: 'Promo'),
  };
  final mapped = localized[normalized];
  if (mapped != null) {
    return italian ? mapped.it : mapped.en;
  }
  return value[0].toUpperCase() + value.substring(1);
}

const String _latestReleaseNotesId = '0.5.1+11-smart-collection-fixes';

String _whatsNewLabel(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return l10n.whatsNewButtonLabel;
}

Future<void> _showLatestReleaseNotesPanel(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final title = l10n.whatsNewDialogTitle;
  final featureSectionTitle = l10n.whatsNewFeaturesTitle;
  final bugFixSectionTitle = l10n.whatsNewBugFixesTitle;
  final featureLines = <String>[
    l10n.whatsNewLine3,
    l10n.whatsNewLine4,
    l10n.whatsNewLine5,
    l10n.whatsNewLine6,
    l10n.whatsNewLine7,
  ].where((line) => line.trim().isNotEmpty).toList(growable: false);
  final bugFixLines = <String>[
    l10n.whatsNewLine1,
    l10n.whatsNewLine2,
    l10n.whatsNewLine8,
    l10n.whatsNewLine9,
  ].where((line) => line.trim().isNotEmpty).toList(growable: false);

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
              if (featureLines.isNotEmpty) ...[
                Text(
                  featureSectionTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in featureLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('- $line', style: textTheme.bodyMedium),
                  ),
              ],
              if (featureLines.isNotEmpty && bugFixLines.isNotEmpty)
                const SizedBox(height: 4),
              if (bugFixLines.isNotEmpty) ...[
                Text(
                  bugFixSectionTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in bugFixLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('- $line', style: textTheme.bodyMedium),
                  ),
              ],
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
