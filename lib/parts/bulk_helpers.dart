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
      return AlertDialog(
        title: Text(l10n.chooseCardDatabaseTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _bulkOptions
              .map(
                (option) => ListTile(
                  title: Text(_bulkTypeTitle(l10n, option.type)),
                  subtitle: Text(_bulkTypeDescription(l10n, option.type)),
                  trailing: option.type == selectedType
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () => Navigator.of(context).pop(option.type),
                ),
              )
              .toList(),
        ),
        actions: allowCancel
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ]
            : null,
      );
    },
  );
}
