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
    List<String> languages = TcgdexPokemonProvider.supportedLanguages,
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
      final localizedSets = <String, CatalogSet>{};
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
        for (final localized in bundle.card.localizedData) {
          cardLocalizationsByKey[_cardLocalizationKey(localized)] = localized;
        }
        for (final localized in bundle.set.localizedData) {
          setLocalizationsByKey[_setLocalizationKey(localized)] = localized;
        }
        final expandedPrintings = _expandLocalizedPrintings(bundle);
        final baseSnapshots = _provider.extractPriceSnapshotsFromBundle(bundle);
        for (final printing in expandedPrintings) {
          printingsById[printing.printingId] = printing;
          for (final mapping in printing.providerMappings) {
            providerMappings[_providerMappingKey(
              mapping,
              printing.printingId,
            )] = ProviderMappingRecord(
              mapping: mapping,
              cardId: bundle.card.cardId,
              printingId: printing.printingId,
              setId: bundle.set.setId,
            );
          }
          for (final snapshot in _remapPriceSnapshots(
            baseSnapshots,
            printingId: printing.printingId,
          )) {
            priceSnapshotsByKey[_priceSnapshotKey(snapshot)] = snapshot;
          }
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
      '${localized.cardId}:${localized.languageCode}';

  String _setLocalizationKey(LocalizedSetData localized) =>
      '${localized.setId}:${localized.languageCode}';

  String _providerMappingKey(
    ProviderMapping mapping,
    String printingId,
  ) =>
      '${mapping.providerId.value}:${mapping.objectType}:${mapping.providerObjectId}:$printingId';

  String _priceSnapshotKey(PriceSnapshot snapshot) =>
      '${snapshot.printingId}:${snapshot.sourceId.value}:${snapshot.currencyCode}:${snapshot.finishKey ?? 'default'}';

  bool _isTcgdexNotFound(Object error) {
    return error.toString().toLowerCase().contains('tcgdex_http_404');
  }

  List<CardPrintingRef> _expandLocalizedPrintings(ProviderPrintingBundle bundle) {
    final languages = <String>{
      for (final localized in bundle.card.localizedData)
        localized.languageCode.trim().toLowerCase(),
      bundle.printing.languageCode.trim().toLowerCase(),
    }.where((value) => value.isNotEmpty).toList(growable: false);
    if (languages.isEmpty) {
      return <CardPrintingRef>[bundle.printing];
    }
    return languages.map((language) {
      final localizedPrintingId = _localizedPrintingId(
        bundle.printing.printingId,
        language,
      );
      return CardPrintingRef(
        printingId: localizedPrintingId,
        cardId: bundle.printing.cardId,
        setId: bundle.printing.setId,
        gameId: bundle.printing.gameId,
        collectorNumber: bundle.printing.collectorNumber,
        languageCode: language,
        providerMappings: _localizedProviderMappings(
          bundle.printing.providerMappings,
          language: language,
          canonicalLanguage: bundle.printing.languageCode.trim().toLowerCase(),
        ),
        rarity: bundle.printing.rarity,
        releaseDate: bundle.printing.releaseDate,
        imageUris: bundle.printing.imageUris,
        finishKeys: bundle.printing.finishKeys,
        metadata: <String, Object?>{
          ...bundle.printing.metadata,
          'base_printing_id': bundle.printing.printingId,
        },
      );
    }).toList(growable: false);
  }

  List<ProviderMapping> _localizedProviderMappings(
    List<ProviderMapping> mappings, {
    required String language,
    required String canonicalLanguage,
  }) {
    final normalizedLanguage = language.trim().toLowerCase();
    final normalizedCanonical = canonicalLanguage.trim().toLowerCase();
    final result = <ProviderMapping>[];
    for (final mapping in mappings) {
      if (mapping.objectType == 'legacy_printing') {
        if (normalizedLanguage == normalizedCanonical) {
          result.add(mapping);
        }
        result.add(
          ProviderMapping(
            providerId: mapping.providerId,
            objectType: 'legacy_printing',
            providerObjectId: _localizedProviderObjectId(
              mapping.providerObjectId,
              normalizedLanguage,
            ),
            providerObjectVersion: mapping.providerObjectVersion,
            mappingConfidence: mapping.mappingConfidence,
          ),
        );
        continue;
      }
      if (mapping.objectType == 'printing' &&
          normalizedLanguage != normalizedCanonical) {
        result.add(
          ProviderMapping(
            providerId: mapping.providerId,
            objectType: 'printing_localized',
            providerObjectId: _localizedProviderObjectId(
              mapping.providerObjectId,
              normalizedLanguage,
            ),
            providerObjectVersion: mapping.providerObjectVersion,
            mappingConfidence: mapping.mappingConfidence,
          ),
        );
        continue;
      }
      result.add(mapping);
    }
    return result;
  }

  List<PriceSnapshot> _remapPriceSnapshots(
    List<PriceSnapshot> snapshots, {
    required String printingId,
  }) {
    return snapshots
        .map(
          (snapshot) => PriceSnapshot(
            printingId: printingId,
            sourceId: snapshot.sourceId,
            currencyCode: snapshot.currencyCode,
            amount: snapshot.amount,
            capturedAt: snapshot.capturedAt,
            finishKey: snapshot.finishKey,
          ),
        )
        .toList(growable: false);
  }

  String _localizedPrintingId(String basePrintingId, String languageCode) {
    final normalizedLanguage = languageCode.trim().toLowerCase();
    if (normalizedLanguage.isEmpty) {
      return basePrintingId;
    }
    return '$basePrintingId:$normalizedLanguage';
  }

  String _localizedProviderObjectId(String rawId, String languageCode) {
    final normalizedId = rawId.trim();
    final normalizedLanguage = languageCode.trim().toLowerCase();
    if (normalizedId.isEmpty || normalizedLanguage.isEmpty) {
      return normalizedId;
    }
    return '$normalizedId:$normalizedLanguage';
  }
}
