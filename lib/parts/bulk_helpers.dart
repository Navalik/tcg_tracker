part of 'package:tcg_tracker/main.dart';

class _BulkOption {
  const _BulkOption({required this.type});

  final String type;
}

const String _allCardsCollectionName = 'All cards';
const String _legacyMyCollectionName = 'My collection';
const String _setPrefix = 'Set: ';
const String _basicLandsCollectionName = '__basic_lands__';
const String _bulkPickerResetAction = '__reset_db__';

const List<_BulkOption> _bulkOptions = [
  _BulkOption(type: 'default_cards'),
  _BulkOption(type: 'oracle_cards'),
  _BulkOption(type: 'unique_artwork'),
];

const List<String> _pokemonDatasetProfiles = [
  'starter',
  'standard',
  'expanded',
  'full',
];

String _bulkTypeLabel(AppLocalizations l10n, String? type) {
  if (type == null) {
    return l10n.notSelected;
  }
  for (final option in _bulkOptions) {
    if (option.type == type) {
      return _bulkTypeTitle(l10n, option.type);
    }
  }
  return type;
}

String _bulkTypeTitle(AppLocalizations l10n, String type) {
  switch (type) {
    case 'default_cards':
      return l10n.bulkAllPrintingsTitle;
    case 'oracle_cards':
      return l10n.bulkOracleCardsTitle;
    case 'unique_artwork':
      return l10n.bulkUniqueArtworkTitle;
    default:
      return type;
  }
}

String _bulkTypeDescription(AppLocalizations l10n, String type) {
  switch (type) {
    case 'default_cards':
      return l10n.bulkAllPrintingsDescription;
    case 'oracle_cards':
      return l10n.bulkOracleCardsDescription;
    case 'unique_artwork':
      return l10n.bulkUniqueArtworkDescription;
    default:
      return '';
  }
}

String _bulkTypeFileName(String type) {
  final sanitized = type.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  return 'scryfall_$sanitized.json';
}

bool _isLimitedPrintCoverage(String? bulkType) {
  return bulkType != null &&
      bulkType.isNotEmpty &&
      bulkType.trim().toLowerCase() != 'default_cards';
}

String _pokemonDatasetProfileTitle(BuildContext context, String profile) {
  final l10n = AppLocalizations.of(context)!;
  switch (profile.trim().toLowerCase()) {
    case 'full':
      return l10n.pokemonDbProfileFullTitle;
    case 'expanded':
      return l10n.pokemonDbProfileExpandedTitle;
    case 'standard':
      return l10n.pokemonDbProfileStandardTitle;
    case 'starter':
    default:
      return l10n.pokemonDbProfileStarterTitle;
  }
}

String _pokemonDatasetProfileDescription(BuildContext context, String profile) {
  final l10n = AppLocalizations.of(context)!;
  switch (profile.trim().toLowerCase()) {
    case 'full':
      return l10n.pokemonDbProfileFullDescription;
    case 'expanded':
      return l10n.pokemonDbProfileExpandedDescription;
    case 'standard':
      return l10n.pokemonDbProfileStandardDescription;
    case 'starter':
    default:
      return l10n.pokemonDbProfileStarterDescription;
  }
}

Future<String?> _showPokemonDatasetProfilePicker(
  BuildContext context, {
  required bool allowCancel,
  String? selectedProfile,
  bool requireConfirmation = true,
  String? confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: allowCancel,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final validInitial = _pokemonDatasetProfiles.contains(selectedProfile);
      String currentSelection = validInitial
          ? selectedProfile!
          : _pokemonDatasetProfiles.first;
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF171411),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3A2F24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storage_rounded,
                        color: Color(0xFFE9C46A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.pokemonDbPickerTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.pokemonDbPickerSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBFAE95),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: _pokemonDatasetProfiles
                            .map(
                              (profile) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildSelectableInfoTile(
                                  context: context,
                                  title: _pokemonDatasetProfileTitle(
                                    context,
                                    profile,
                                  ),
                                  description: _pokemonDatasetProfileDescription(
                                    context,
                                    profile,
                                  ),
                                  selected: profile == currentSelection,
                                  onTap: () {
                                    setModalState(() {
                                      currentSelection = profile;
                                    });
                                    if (!requireConfirmation) {
                                      Navigator.of(context).pop(profile);
                                    }
                                  },
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                  if (requireConfirmation) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE9C46A),
                          foregroundColor: const Color(0xFF1C1510),
                        ),
                        onPressed: currentSelection.isEmpty
                            ? null
                            : () =>
                                  Navigator.of(context).pop(currentSelection),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(confirmLabel ?? l10n.downloadUpdate),
                      ),
                    ),
                  ],
                  if (allowCancel) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> _showBulkTypePicker(
  BuildContext context, {
  required bool allowCancel,
  String? selectedType,
  bool requireConfirmation = true,
  String? confirmLabel,
  bool allowResetAction = false,
  String? resetLabel,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: allowCancel,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final isItalian = Localizations.localeOf(context)
          .languageCode
          .toLowerCase()
          .startsWith('it');
      final isPokemonActive =
          TcgEnvironmentController.instance.currentGame == TcgGame.pokemon;
      final subtitle = isPokemonActive
          ? (isItalian
                ? 'Database Pokemon: scegli quale versione scaricare da Scryfall.'
                : 'Pokemon database: choose which version to download from Scryfall.')
          : (isItalian
                ? 'Database Magic: scegli quale versione scaricare da Scryfall.'
                : 'Magic database: choose which version to download from Scryfall.');
      String currentSelection =
          selectedType ??
          (_bulkOptions.isNotEmpty ? _bulkOptions.first.type : '');
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF171411),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3A2F24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storage_rounded,
                        color: Color(0xFFE9C46A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.chooseCardDatabaseTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBFAE95),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: _bulkOptions
                            .map(
                              (option) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildBulkOptionTile(
                                  context: context,
                                  option: option,
                                  selected: option.type == currentSelection,
                                  onTap: () {
                                    setModalState(() {
                                      currentSelection = option.type;
                                    });
                                    if (!requireConfirmation) {
                                      Navigator.of(context).pop(option.type);
                                    }
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  if (requireConfirmation) ...[
                    const SizedBox(height: 8),
                    if (allowResetAction) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF5D4731)),
                            foregroundColor: const Color(0xFFE9C46A),
                          ),
                          onPressed: () =>
                              Navigator.of(context).pop(_bulkPickerResetAction),
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: Text(
                            resetLabel ??
                                (Localizations.localeOf(context).languageCode
                                        .toLowerCase()
                                        .startsWith('it')
                                    ? 'Reset database'
                                    : 'Reset database'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE9C46A),
                          foregroundColor: const Color(0xFF1C1510),
                        ),
                        onPressed: currentSelection.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(currentSelection),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(confirmLabel ?? l10n.downloadUpdate),
                      ),
                    ),
                  ],
                  if (allowCancel) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildBulkOptionTile({
  required BuildContext context,
  required _BulkOption option,
  required bool selected,
  required VoidCallback onTap,
}) {
  final l10n = AppLocalizations.of(context)!;
  return _buildSelectableInfoTile(
    context: context,
    title: _bulkTypeTitle(l10n, option.type),
    description: _bulkTypeDescription(l10n, option.type),
    selected: selected,
    onTap: onTap,
  );
}

Widget _buildSelectableInfoTile({
  required BuildContext context,
  required String title,
  required String description,
  required bool selected,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final borderColor = selected
      ? const Color(0xFFE9C46A)
      : const Color(0xFF3A2F24);
  final backgroundColor = selected
      ? const Color(0x332A1E10)
      : const Color(0x221D1712);

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 17,
              color: selected
                  ? const Color(0xFFE9C46A)
                  : const Color(0xFFBFAE95),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBFAE95),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
