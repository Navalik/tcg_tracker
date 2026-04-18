part of 'package:tcg_tracker/main.dart';

class _BulkOption {
  const _BulkOption({required this.type});

  final String type;
}

const String _allCardsCollectionName = 'All cards';
const String _legacyMyCollectionName = 'My collection';
const String _setPrefix = 'Set: ';
const String _basicLandsCollectionName = '__basic_lands__';

const List<_BulkOption> _bulkOptions = [
  _BulkOption(type: 'all_cards'),
  _BulkOption(type: 'default_cards'),
  _BulkOption(type: 'oracle_cards'),
  _BulkOption(type: 'unique_artwork'),
];

String _bulkTypeFileName(String type) {
  final sanitized = type.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  return 'scryfall_$sanitized.json';
}

Future<int> _cleanupMtgBulkFilesKeepingType(String keepType) async {
  final directory = await getApplicationDocumentsDirectory();
  final keepFileName = _bulkTypeFileName(keepType);
  var deleted = 0;
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final pathValue = entity.path;
    final fileName = pathValue.split(RegExp(r'[\\/]')).last.toLowerCase();
    final isMtgBulkFile =
        fileName.startsWith('scryfall_') &&
        (fileName.endsWith('.json') || fileName.endsWith('.download'));
    if (!isMtgBulkFile) {
      continue;
    }
    if (fileName == keepFileName.toLowerCase()) {
      continue;
    }
    try {
      await entity.delete();
      deleted += 1;
    } catch (_) {}
  }
  return deleted;
}

bool _isLimitedPrintCoverage(String? bulkType) {
  return bulkType != null &&
      bulkType.isNotEmpty &&
      bulkType.trim().toLowerCase() != 'all_cards';
}
