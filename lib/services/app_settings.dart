import 'package:shared_preferences/shared_preferences.dart';

enum CollectionViewMode { list, gallery }

class AppSettings {
  static const _prefsKeyUserTier = 'user_tier';
  static const _prefsKeyOwnedTcgs = 'owned_tcgs';
  static const _prefsKeySearchLanguages = 'search_languages';
  static const _prefsKeySearchAllLanguages = 'search_all_languages';
  static const _prefsKeyAvailableLanguages = 'available_languages';
  static const _prefsKeyCollectionViewMode = 'collection_view_mode';
  static const _prefsKeyBulkType = 'scryfall_bulk_type';
  static const _prefsKeyPriceCurrency = 'price_currency';
  static const _prefsKeyShowPrices = 'show_prices';
  static const _prefsKeyAppLocale = 'app_locale';
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
  static const List<String> supportedAppLocales = [
    'en',
    'it',
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

  static Future<String> loadPriceCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKeyPriceCurrency)?.trim().toLowerCase();
    if (stored == 'usd') {
      return 'usd';
    }
    if (stored == 'eur') {
      return 'eur';
    }
    const fallback = 'eur';
    await prefs.setString(_prefsKeyPriceCurrency, fallback);
    return fallback;
  }

  static Future<void> savePriceCurrency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = value.trim().toLowerCase() == 'usd' ? 'usd' : 'eur';
    await prefs.setString(_prefsKeyPriceCurrency, normalized);
  }

  static Future<bool> loadShowPrices() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_prefsKeyShowPrices);
    if (stored != null) {
      return stored;
    }
    const fallback = true;
    await prefs.setBool(_prefsKeyShowPrices, fallback);
    return fallback;
  }

  static Future<void> saveShowPrices(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyShowPrices, value);
  }

  static Future<String> loadAppLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyAppLocale)?.trim().toLowerCase();
    if (value != null && supportedAppLocales.contains(value)) {
      return value;
    }
    const fallback = 'en';
    await prefs.setString(_prefsKeyAppLocale, fallback);
    return fallback;
  }

  static Future<void> saveAppLocale(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = localeCode.trim().toLowerCase();
    final normalized = supportedAppLocales.contains(value) ? value : 'en';
    await prefs.setString(_prefsKeyAppLocale, normalized);
  }

  static Future<bool> loadProUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyProUnlocked) ?? false;
  }

  static Future<void> saveProUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyProUnlocked, value);
  }

  static Future<String> loadUserTier() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKeyUserTier)?.trim().toLowerCase();
    if (stored == 'plus') {
      return 'plus';
    }
    if (stored == 'free') {
      return 'free';
    }
    final legacyPro = prefs.getBool(_prefsKeyProUnlocked) ?? false;
    final fallback = legacyPro ? 'plus' : 'free';
    await prefs.setString(_prefsKeyUserTier, fallback);
    return fallback;
  }

  static Future<void> saveUserTier(String tier) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = tier.trim().toLowerCase() == 'plus' ? 'plus' : 'free';
    await prefs.setString(_prefsKeyUserTier, normalized);
    await prefs.setBool(_prefsKeyProUnlocked, normalized == 'plus');
  }

  static Future<Set<String>> loadOwnedTcgs() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_prefsKeyOwnedTcgs) ?? const <String>[];
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static Future<void> saveOwnedTcgs(Set<String> ownedTcgs) async {
    final prefs = await SharedPreferences.getInstance();
    final values = ownedTcgs
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList()
      ..sort();
    await prefs.setStringList(_prefsKeyOwnedTcgs, values);
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
    await prefs.remove(_prefsKeyUserTier);
    await prefs.remove(_prefsKeyOwnedTcgs);
    await prefs.remove(_prefsKeySearchLanguages);
    await prefs.remove(_prefsKeySearchAllLanguages);
    await prefs.remove(_prefsKeyAvailableLanguages);
    await prefs.remove(_prefsKeyCollectionViewMode);
    await prefs.remove(_prefsKeyBulkType);
    await prefs.remove(_prefsKeyPriceCurrency);
    await prefs.remove(_prefsKeyShowPrices);
    await prefs.remove(_prefsKeyAppLocale);
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
