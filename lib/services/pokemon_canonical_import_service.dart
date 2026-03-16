import '../db/canonical_catalog_store.dart';
import '../domain/domain_models.dart';
import '../providers/provider_contracts.dart';
import '../providers/tcgdex_pokemon_provider.dart';
import 'pokemon_dataset_manifest.dart';

class PokemonCanonicalImportReport {
  const PokemonCanonicalImportReport({
    required this.profile,
    required this.setsImported,
    required this.cardsImported,
    required this.printingsImported,
    required this.localizedCardsImported,
    required this.localizedSetsImported,
    required this.priceSnapshotsImported,
  });

  final String profile;
  final int setsImported;
  final int cardsImported;
  final int printingsImported;
  final int localizedCardsImported;
  final int localizedSetsImported;
  final int priceSnapshotsImported;
}

class PokemonCanonicalImportService {
  PokemonCanonicalImportService({
    TcgdexPokemonProvider? provider,
    CanonicalCatalogStore? store,
  }) : _provider = provider ?? TcgdexPokemonProvider(),
       _store = store;

  final TcgdexPokemonProvider _provider;
  final CanonicalCatalogStore? _store;

  Future<PokemonCanonicalImportReport> importProfile({
    required String profile,
    List<TcgCardLanguage> languages = TcgdexPokemonProvider.supportedLanguages,
    void Function(double progress)? onProgress,
    void Function(CanonicalCatalogImportBatch batch)? onBatchBuilt,
    void Function(String status)? onStatus,
  }) async {
    final setCodes = await _resolveSetCodes(profile, onStatus: onStatus);
    final cardsById = <String, CatalogCard>{};
    final setsById = <String, CatalogSet>{};
    final printingsById = <String, CardPrintingRef>{};
    final cardLocalizationsByKey = <String, LocalizedCardData>{};
    final setLocalizationsByKey = <String, LocalizedSetData>{};
    final providerMappings = <String, ProviderMappingRecord>{};
    final priceSnapshotsByKey = <String, PriceSnapshot>{};

    final totalSets = setCodes.length;
    for (var index = 0; index < totalSets; index += 1) {
      final setCode = setCodes[index];
      onStatus?.call(
        'Downloading set ${setCode.toUpperCase()} (${index + 1}/$totalSets)',
      );
      final localizedSets = <TcgCardLanguage, CatalogSet>{};
      for (final language in languages) {
        final localizedSet = await _provider.fetchSetByCodeLocalized(
          setCode,
          language: language,
        );
        if (localizedSet != null) {
          localizedSets[language] = localizedSet;
        }
      }
      final canonicalSet =
          localizedSets[TcgdexPokemonProvider.canonicalLanguage] ??
          (localizedSets.isEmpty ? null : localizedSets.values.first);
      if (canonicalSet != null) {
        setsById[canonicalSet.setId] = _mergeSet(
          setsById[canonicalSet.setId],
          canonicalSet,
        );
        for (final localized in canonicalSet.localizedData) {
          setLocalizationsByKey[_setLocalizationKey(localized)] = localized;
        }
        for (final localizedSet in localizedSets.values) {
          for (final localized in localizedSet.localizedData) {
            setLocalizationsByKey[_setLocalizationKey(localized)] = localized;
          }
        }
      }
      final setBaseProgress = index / totalSets;
      final setRange = 1 / totalSets;
      List<ProviderPrintingBundle> bundles;
      try {
        bundles = await _provider.fetchSetPrintings(
          setCode,
          languages: languages,
          onProgress: (completed, total) {
            final cardFraction = total <= 0 ? 1.0 : (completed / total);
            final progress = setBaseProgress + (cardFraction * setRange);
            onProgress?.call(progress.clamp(0.0, 1.0));
          },
        );
      } catch (error) {
        if (_isTcgdexNotFound(error)) {
          onStatus?.call(
            'Skipping set ${setCode.toUpperCase()} (missing resource on TCGdex)',
          );
          onProgress?.call((setBaseProgress + setRange).clamp(0.0, 1.0));
          continue;
        }
        rethrow;
      }
      for (final bundle in bundles) {
        cardsById[bundle.card.cardId] = bundle.card;
        setsById[bundle.set.setId] = _mergeSet(
          setsById[bundle.set.setId],
          bundle.set,
        );
        printingsById[bundle.printing.printingId] = bundle.printing;
        for (final localized in bundle.card.localizedData) {
          cardLocalizationsByKey[_cardLocalizationKey(localized)] = localized;
        }
        for (final localized in bundle.set.localizedData) {
          setLocalizationsByKey[_setLocalizationKey(localized)] = localized;
        }
        for (final mapping in bundle.printing.providerMappings) {
          providerMappings[_providerMappingKey(
            mapping,
            bundle,
          )] = ProviderMappingRecord(
            mapping: mapping,
            cardId: bundle.card.cardId,
            printingId: bundle.printing.printingId,
            setId: bundle.set.setId,
          );
        }
        final snapshots = _provider.extractPriceSnapshotsFromBundle(bundle);
        for (final snapshot in snapshots) {
          priceSnapshotsByKey[_priceSnapshotKey(snapshot)] = snapshot;
        }
      }
      final progress = (index + 1) / totalSets;
      onProgress?.call(progress.clamp(0.0, 1.0));
    }

    final batch = CanonicalCatalogImportBatch(
      cards: cardsById.values.toList(growable: false),
      sets: setsById.values.toList(growable: false),
      printings: printingsById.values.toList(growable: false),
      cardLocalizations: cardLocalizationsByKey.values.toList(growable: false),
      setLocalizations: setLocalizationsByKey.values.toList(growable: false),
      providerMappings: providerMappings.values.toList(growable: false),
      priceSnapshots: priceSnapshotsByKey.values.toList(growable: false),
    );
    onBatchBuilt?.call(batch);
    _store?.replacePokemonCatalog(batch);

    return PokemonCanonicalImportReport(
      profile: profile,
      setsImported: batch.sets.length,
      cardsImported: batch.cards.length,
      printingsImported: batch.printings.length,
      localizedCardsImported: batch.cardLocalizations.length,
      localizedSetsImported: batch.setLocalizations.length,
      priceSnapshotsImported: batch.priceSnapshots.length,
    );
  }

  Future<List<String>> _resolveSetCodes(
    String profile, {
    void Function(String status)? onStatus,
  }) async {
    final normalized = profile.trim().toLowerCase();
    if (normalized != 'full') {
      final setSpecs = PokemonDatasetManifest.setsForProfile(normalized);
      if (setSpecs.isEmpty) {
        throw ArgumentError.value(
          profile,
          'profile',
          'No manifest sets configured',
        );
      }
      return setSpecs
          .map((spec) => spec.setCode.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toList(growable: false);
    }

    onStatus?.call('Loading full set list from TCGdex');
    final sets = await _provider.fetchSets(limit: 2000);
    final codes =
        sets
            .map((set) => set.code.trim().toLowerCase())
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (codes.isEmpty) {
      throw ArgumentError.value(
        profile,
        'profile',
        'TCGdex returned no sets for full profile',
      );
    }
    return codes;
  }

  CatalogSet _mergeSet(CatalogSet? existing, CatalogSet next) {
    if (existing == null) {
      return next;
    }
    final mergedLocalizations = <String, LocalizedSetData>{};
    for (final localized in existing.localizedData) {
      mergedLocalizations[_setLocalizationKey(localized)] = localized;
    }
    for (final localized in next.localizedData) {
      mergedLocalizations[_setLocalizationKey(localized)] = localized;
    }
    return CatalogSet(
      setId: existing.setId,
      gameId: existing.gameId,
      code: existing.code,
      canonicalName: existing.canonicalName,
      seriesId: existing.seriesId ?? next.seriesId,
      releaseDate: existing.releaseDate ?? next.releaseDate,
      defaultLocalizedData:
          existing.defaultLocalizedData ?? next.defaultLocalizedData,
      localizedData: mergedLocalizations.values.toList(growable: false),
      metadata: <String, Object?>{...existing.metadata, ...next.metadata},
    );
  }

  String _cardLocalizationKey(LocalizedCardData localized) =>
      '${localized.cardId}:${localized.language.code}';

  String _setLocalizationKey(LocalizedSetData localized) =>
      '${localized.setId}:${localized.language.code}';

  String _providerMappingKey(
    ProviderMapping mapping,
    ProviderPrintingBundle bundle,
  ) =>
      '${mapping.providerId.value}:${mapping.objectType}:${mapping.providerObjectId}:${bundle.printing.printingId}';

  String _priceSnapshotKey(PriceSnapshot snapshot) =>
      '${snapshot.printingId}:${snapshot.sourceId.value}:${snapshot.currencyCode}:${snapshot.finishKey ?? 'default'}';

  bool _isTcgdexNotFound(Object error) {
    return error.toString().toLowerCase().contains('tcgdex_http_404');
  }
}
