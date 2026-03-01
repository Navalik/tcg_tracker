import 'package:shared_preferences/shared_preferences.dart';

enum CollectionViewMode { list, gallery }

enum AppTcgGame { mtg, pokemon }

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
  static const _prefsKeyVisualTheme = 'visual_theme';
  static const _prefsKeyProUnlocked = 'pro_unlocked';
  static const _prefsKeyFreeScanDate = 'free_scan_date';
  static const _prefsKeyFreeScanCount = 'free_scan_count';
  static const _prefsKeyFreeScanLastSeenEpochMs =
      'free_scan_last_seen_epoch_ms';
  static const _prefsKeyFreeScanClockTampered = 'free_scan_clock_tampered';
  static const _prefsKeyLastSeenReleaseNotesId = 'last_seen_release_notes_id';
  static const _prefsKeySelectedTcg = 'selected_tcg';
  static const _prefsKeyPrimaryTcg = 'primary_tcg';
  static const _prefsKeyPokemonUnlocked = 'pokemon_unlocked';
  static const _prefsKeyExtraTcgSlots = 'extra_tcg_slots';
  static const _prefsKeyPokemonDatasetProfile = 'pokemon_dataset_profile';
  static const _prefsKeyCollectionCoherenceCheckVersionPrefix =
      'collection_coherence_check_version';
  static String _prefsKeyBulkTypeForGame(AppTcgGame game) =>
      'scryfall_bulk_type_${game == AppTcgGame.pokemon ? 'pokemon' : 'mtg'}';
  static String _prefsKeyCollectionCoherenceCheckVersionForGame(
    AppTcgGame game,
  ) =>
      '${_prefsKeyCollectionCoherenceCheckVersionPrefix}_${game == AppTcgGame.pokemon ? 'pokemon' : 'mtg'}';

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

  static const List<String> defaultLanguages = ['en'];
  static const List<String> supportedAppLocales = ['en', 'it'];

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
    return loadBulkTypeForGame(AppTcgGame.mtg);
  }

  static Future<String?> loadBulkTypeForGame(AppTcgGame game) async {
    final prefs = await SharedPreferences.getInstance();
    final gameKey = _prefsKeyBulkTypeForGame(game);
    final stored = prefs.getString(gameKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    const fallback = 'oracle_cards';
    if (game == AppTcgGame.mtg) {
      final legacy = prefs.getString(_prefsKeyBulkType);
      if (legacy != null && legacy.isNotEmpty) {
        await prefs.setString(gameKey, legacy);
        return legacy;
      }
    }
    await prefs.setString(gameKey, fallback);
    return fallback;
  }

  static Future<void> saveBulkType(String value) async {
    return saveBulkTypeForGame(AppTcgGame.mtg, value);
  }

  static Future<void> saveBulkTypeForGame(AppTcgGame game, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyBulkTypeForGame(game), value);
  }

  static Future<String> loadPriceCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs
        .getString(_prefsKeyPriceCurrency)
        ?.trim()
        .toLowerCase();
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

  static Future<String> loadVisualTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyVisualTheme)?.trim().toLowerCase();
    if (value == 'magic' || value == 'vault') {
      return value!;
    }
    const fallback = 'magic';
    await prefs.setString(_prefsKeyVisualTheme, fallback);
    return fallback;
  }

  static Future<void> saveVisualTheme(String themeCode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = themeCode.trim().toLowerCase();
    final normalized = (value == 'magic' || value == 'vault')
        ? value
        : 'magic';
    await prefs.setString(_prefsKeyVisualTheme, normalized);
  }

  static Future<bool> loadProUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyProUnlocked) ?? false;
  }

  static Future<void> saveProUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyProUnlocked, value);
  }

  static Future<String?> loadLastSeenReleaseNotesId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyLastSeenReleaseNotesId)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static Future<void> saveLastSeenReleaseNotesId(String releaseId) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = releaseId.trim();
    if (normalized.isEmpty) {
      await prefs.remove(_prefsKeyLastSeenReleaseNotesId);
      return;
    }
    await prefs.setString(_prefsKeyLastSeenReleaseNotesId, normalized);
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
    const fallback = 'free';
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
    final values =
        ownedTcgs
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList()
          ..sort();
    await prefs.setStringList(_prefsKeyOwnedTcgs, values);
  }

  static Future<bool> loadPokemonUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyPokemonUnlocked) ?? false;
  }

  static Future<void> savePokemonUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyPokemonUnlocked, value);
  }

  static String _todayKey([DateTime? now]) {
    final local = (now ?? DateTime.now()).toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static Future<bool> _detectClockRollback(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final currentMs = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final lastSeenMs = prefs.getInt(_prefsKeyFreeScanLastSeenEpochMs);
    final alreadyTampered =
        prefs.getBool(_prefsKeyFreeScanClockTampered) ?? false;

    // Small tolerance to avoid false positives due to skew.
    const rollbackToleranceMs = 5 * 60 * 1000;
    final rollbackDetected =
        lastSeenMs != null && currentMs + rollbackToleranceMs < lastSeenMs;
    final tampered = alreadyTampered || rollbackDetected;

    if (tampered != alreadyTampered) {
      await prefs.setBool(_prefsKeyFreeScanClockTampered, tampered);
    }
    if (lastSeenMs == null || currentMs > lastSeenMs) {
      await prefs.setInt(_prefsKeyFreeScanLastSeenEpochMs, currentMs);
    }
    return tampered;
  }

  static Future<int> loadTodayFreeScans({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    if (await _detectClockRollback(prefs, now: now)) {
      return 999999;
    }
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
    if (await _detectClockRollback(prefs, now: now)) {
      return false;
    }
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
    await prefs.remove(_prefsKeyBulkTypeForGame(AppTcgGame.mtg));
    await prefs.remove(_prefsKeyBulkTypeForGame(AppTcgGame.pokemon));
    await prefs.remove(_prefsKeyPriceCurrency);
    await prefs.remove(_prefsKeyShowPrices);
    await prefs.remove(_prefsKeyAppLocale);
    await prefs.remove(_prefsKeyVisualTheme);
    await prefs.remove(_prefsKeySelectedTcg);
    await prefs.remove(_prefsKeyPrimaryTcg);
    await prefs.remove(_prefsKeyPokemonUnlocked);
    await prefs.remove(_prefsKeyExtraTcgSlots);
    await prefs.remove(_prefsKeyPokemonDatasetProfile);
    await prefs.remove(
      _prefsKeyCollectionCoherenceCheckVersionForGame(AppTcgGame.mtg),
    );
    await prefs.remove(
      _prefsKeyCollectionCoherenceCheckVersionForGame(AppTcgGame.pokemon),
    );
    await prefs.remove(_prefsKeyProUnlocked);
    await prefs.remove(_prefsKeyFreeScanDate);
    await prefs.remove(_prefsKeyFreeScanCount);
    await prefs.remove(_prefsKeyFreeScanLastSeenEpochMs);
    await prefs.remove(_prefsKeyFreeScanClockTampered);
  }

  static Future<CollectionViewMode> loadCollectionViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyCollectionViewMode);
    if (value == 'gallery') {
      return CollectionViewMode.gallery;
    }
    return CollectionViewMode.list;
  }

  static Future<void> saveCollectionViewMode(CollectionViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKeyCollectionViewMode,
      mode == CollectionViewMode.gallery ? 'gallery' : 'list',
    );
  }

  static Future<AppTcgGame> loadSelectedTcgGame() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeySelectedTcg)?.trim().toLowerCase();
    if (value == 'pokemon') {
      return AppTcgGame.pokemon;
    }
    if (value == 'mtg') {
      return AppTcgGame.mtg;
    }
    await prefs.setString(_prefsKeySelectedTcg, 'mtg');
    return AppTcgGame.mtg;
  }

  static Future<void> saveSelectedTcgGame(AppTcgGame game) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKeySelectedTcg,
      game == AppTcgGame.pokemon ? 'pokemon' : 'mtg',
    );
  }

  static Future<bool> hasPrimaryGameSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyPrimaryTcg)?.trim().toLowerCase();
    return value == 'mtg' || value == 'pokemon';
  }

  static Future<AppTcgGame?> loadPrimaryTcgGameOrNull() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyPrimaryTcg)?.trim().toLowerCase();
    if (value == 'pokemon') {
      return AppTcgGame.pokemon;
    }
    if (value == 'mtg') {
      return AppTcgGame.mtg;
    }
    return null;
  }

  static Future<void> savePrimaryTcgGame(AppTcgGame game) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKeyPrimaryTcg,
      game == AppTcgGame.pokemon ? 'pokemon' : 'mtg',
    );
  }

  static Future<void> ensurePrimaryTcgGame(AppTcgGame fallback) async {
    final existing = await loadPrimaryTcgGameOrNull();
    if (existing != null) {
      return;
    }
    await savePrimaryTcgGame(fallback);
  }

  static Future<String> loadPokemonDatasetProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs
        .getString(_prefsKeyPokemonDatasetProfile)
        ?.trim()
        .toLowerCase();
    if (value == 'starter' ||
        value == 'standard' ||
        value == 'expanded' ||
        value == 'full') {
      return value!;
    }
    const fallback = 'starter';
    await prefs.setString(_prefsKeyPokemonDatasetProfile, fallback);
    return fallback;
  }

  static Future<void> savePokemonDatasetProfile(String profile) async {
    final prefs = await SharedPreferences.getInstance();
    final value = profile.trim().toLowerCase();
    final normalized =
        (value == 'starter' ||
            value == 'standard' ||
            value == 'expanded' ||
            value == 'full')
        ? value
        : 'starter';
    await prefs.setString(_prefsKeyPokemonDatasetProfile, normalized);
  }

  static Future<void> resetPrimaryGameSelectionFlow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeySelectedTcg);
    await prefs.remove(_prefsKeyPrimaryTcg);
    await prefs.remove(_prefsKeyOwnedTcgs);
    await prefs.remove(_prefsKeyPokemonUnlocked);
    await prefs.remove(_prefsKeyExtraTcgSlots);
  }

  static Future<int> loadExtraTcgSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_prefsKeyExtraTcgSlots) ?? 0;
    return value < 0 ? 0 : value;
  }

  static Future<void> saveExtraTcgSlots(int slots) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = slots < 0 ? 0 : slots;
    await prefs.setInt(_prefsKeyExtraTcgSlots, normalized);
  }

  static Future<String?> loadCollectionCoherenceCheckVersionForGame(
    AppTcgGame game,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs
        .getString(_prefsKeyCollectionCoherenceCheckVersionForGame(game))
        ?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static Future<void> saveCollectionCoherenceCheckVersionForGame(
    AppTcgGame game,
    String version,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = version.trim();
    if (normalized.isEmpty) {
      await prefs.remove(_prefsKeyCollectionCoherenceCheckVersionForGame(game));
      return;
    }
    await prefs.setString(
      _prefsKeyCollectionCoherenceCheckVersionForGame(game),
      normalized,
    );
  }
}
