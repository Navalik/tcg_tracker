part of 'package:tcg_tracker/main.dart';

class _BulkOption {
  const _BulkOption({
    required this.type,
  });

  final String type;
}

const String _allCardsCollectionName = 'All cards';
const String _legacyMyCollectionName = 'My collection';
const String _setPrefix = 'Set: ';

const List<_BulkOption> _bulkOptions = [
  _BulkOption(
    type: 'default_cards',
  ),
  _BulkOption(
    type: 'oracle_cards',
  ),
  _BulkOption(
    type: 'unique_artwork',
  ),
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

Future<String?> _showBulkTypePicker(
  BuildContext context, {
  required bool allowCancel,
  String? selectedType,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: allowCancel,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                  const Icon(Icons.storage_rounded, color: Color(0xFFE9C46A)),
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
                l10n.cardDatabaseSubtitle,
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
                              l10n: l10n,
                              option: option,
                              selected: option.type == selectedType,
                              onTap: () =>
                                  Navigator.of(context).pop(option.type),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              if (allowCancel)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildBulkOptionTile({
  required BuildContext context,
  required AppLocalizations l10n,
  required _BulkOption option,
  required bool selected,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final borderColor =
      selected ? const Color(0xFFE9C46A) : const Color(0xFF3A2F24);
  final backgroundColor =
      selected ? const Color(0x332A1E10) : const Color(0x221D1712);

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? const Color(0xFFE9C46A) : const Color(0xFFBFAE95),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bulkTypeTitle(l10n, option.type),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _bulkTypeDescription(l10n, option.type),
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
