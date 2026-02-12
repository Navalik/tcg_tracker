import 'package:shared_preferences/shared_preferences.dart';

enum CollectionViewMode { list, gallery }

class AppSettings {
  static const _prefsKeySearchLanguages = 'search_languages';
  static const _prefsKeySearchAllLanguages = 'search_all_languages';
  static const _prefsKeyAvailableLanguages = 'available_languages';
  static const _prefsKeyCollectionViewMode = 'collection_view_mode';
  static const _prefsKeyBulkType = 'scryfall_bulk_type';
  static const _prefsKeyProUnlocked = 'pro_unlocked';
  static const _prefsKeyFreeScanDate = 'free_scan_date';
  static const _prefsKeyFreeScanCount = 'free_scan_count';

  static const List<String> languageCodes = [
    'en',
    'it',
    'fr',
    'de',
    'es',
    'pt',
    'ja',
    'ko',
    'ru',
    'zhs',
    'zht',
    'ar',
    'he',
    'la',
    'grc',
    'sa',
    'ph',
    'qya',
  ];

  static const List<String> defaultLanguages = [
    'en',
  ];

  static Future<Set<String>> loadSearchLanguages() async {
    return {'en'};
  }

  static Future<bool> loadSearchAllLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeySearchAllLanguages) ?? false;
  }

  static Future<void> saveSearchLanguages(Set<String> languages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeySearchLanguages, ['en']);
  }

  static Future<void> saveSearchAllLanguages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeySearchAllLanguages, value);
  }

  static Future<List<String>> loadAvailableLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKeyAvailableLanguages) ?? [];
  }

  static Future<void> saveAvailableLanguages(List<String> languages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKeyAvailableLanguages,
      languages.toList()..sort(),
    );
  }

  static Future<String?> loadBulkType() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKeyBulkType);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    const fallback = 'oracle_cards';
    await prefs.setString(_prefsKeyBulkType, fallback);
    return fallback;
  }

  static Future<void> saveBulkType(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyBulkType, value);
  }

  static Future<bool> loadProUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyProUnlocked) ?? false;
  }

  static Future<void> saveProUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyProUnlocked, value);
  }

  static String _todayKey([DateTime? now]) {
    final local = (now ?? DateTime.now()).toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static Future<int> loadTodayFreeScans({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(now);
    final storedDate = prefs.getString(_prefsKeyFreeScanDate);
    if (storedDate != today) {
      await prefs.setString(_prefsKeyFreeScanDate, today);
      await prefs.setInt(_prefsKeyFreeScanCount, 0);
      return 0;
    }
    return prefs.getInt(_prefsKeyFreeScanCount) ?? 0;
  }

  static Future<int> remainingFreeDailyScans({
    int limit = 20,
    DateTime? now,
  }) async {
    final used = await loadTodayFreeScans(now: now);
    final remaining = limit - used;
    return remaining > 0 ? remaining : 0;
  }

  static Future<bool> consumeFreeDailyScan({
    int limit = 20,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(now);
    final storedDate = prefs.getString(_prefsKeyFreeScanDate);
    var used = prefs.getInt(_prefsKeyFreeScanCount) ?? 0;
    if (storedDate != today) {
      used = 0;
      await prefs.setString(_prefsKeyFreeScanDate, today);
      await prefs.setInt(_prefsKeyFreeScanCount, 0);
    }
    if (used >= limit) {
      return false;
    }
    await prefs.setInt(_prefsKeyFreeScanCount, used + 1);
    return true;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeySearchLanguages);
    await prefs.remove(_prefsKeySearchAllLanguages);
    await prefs.remove(_prefsKeyAvailableLanguages);
    await prefs.remove(_prefsKeyCollectionViewMode);
    await prefs.remove(_prefsKeyBulkType);
    await prefs.remove(_prefsKeyProUnlocked);
    await prefs.remove(_prefsKeyFreeScanDate);
    await prefs.remove(_prefsKeyFreeScanCount);
  }

  static Future<CollectionViewMode> loadCollectionViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyCollectionViewMode);
    if (value == 'gallery') {
      return CollectionViewMode.gallery;
    }
    return CollectionViewMode.list;
  }

  static Future<void> saveCollectionViewMode(
    CollectionViewMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKeyCollectionViewMode,
      mode == CollectionViewMode.gallery ? 'gallery' : 'list',
    );
  }
}
