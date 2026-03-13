import '../domain/domain_models.dart';

class ProviderPrintingBundle {
  const ProviderPrintingBundle({
    required this.card,
    required this.set,
    required this.printing,
  });

  final CatalogCard card;
  final CatalogSet set;
  final CardPrintingRef printing;
}

class CatalogSyncStatus {
  const CatalogSyncStatus({
    required this.providerId,
    required this.gameId,
    required this.datasetKey,
    required this.remoteAvailable,
    this.downloadUri,
    this.updatedAt,
    this.sizeBytes,
  });

  final CatalogProviderId providerId;
  final TcgGameId gameId;
  final String datasetKey;
  final bool remoteAvailable;
  final Uri? downloadUri;
  final DateTime? updatedAt;
  final int? sizeBytes;
}

abstract class CatalogProvider {
  CatalogProviderId get providerId;

  TcgGameId get gameId;

  Future<ProviderPrintingBundle?> fetchPrintingByProviderId(
    String providerObjectId,
  );
}

abstract class CatalogSyncService {
  CatalogProviderId get providerId;

  TcgGameId get gameId;

  Future<CatalogSyncStatus> fetchLatestCatalogStatus({
    required String datasetKey,
  });
}

abstract class SearchProvider {
  CatalogProviderId get providerId;

  TcgGameId get gameId;

  Future<List<ProviderPrintingBundle>> searchPrintingsByName(
    String query, {
    List<String> languages = const [],
    int limit = 40,
  });
}

abstract class SetProvider {
  CatalogProviderId get providerId;

  TcgGameId get gameId;

  Future<List<CatalogSet>> fetchSets({int limit = 500});

  Future<CatalogSet?> fetchSetByCode(String setCode);
}

abstract class DeckRulesProvider {
  CatalogProviderId get providerId;

  TcgGameId get gameId;

  bool supportsFormat(String format);

  Future<bool> isPrintingLegal(
    String providerObjectId, {
    required String format,
  });
}

abstract class PriceProvider {
  PriceSourceId get sourceId;

  TcgGameId get gameId;

  PriceRefreshPolicy get refreshPolicy;

  Future<List<PriceSnapshot>> fetchLatestPrices(PriceQuoteRequest request);
}

class PriceQuoteRequest {
  const PriceQuoteRequest({
    required this.gameId,
    required this.printingId,
    this.catalogProviderId,
    this.providerObjectId,
    this.preferredCurrencies = const <String>{},
    this.preferredFinishKeys = const <String>{},
  });

  final TcgGameId gameId;
  final String printingId;
  final CatalogProviderId? catalogProviderId;
  final String? providerObjectId;
  final Set<String> preferredCurrencies;
  final Set<String> preferredFinishKeys;
}

class PriceRefreshPolicy {
  const PriceRefreshPolicy({
    required this.ttl,
    this.maxConcurrentRequests = 2,
    this.allowsStaleReads = true,
  });

  final Duration ttl;
  final int maxConcurrentRequests;
  final bool allowsStaleReads;
}
