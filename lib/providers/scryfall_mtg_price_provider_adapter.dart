import '../domain/domain_models.dart';
import '../services/price_provider.dart' as legacy_prices;
import 'provider_contracts.dart';

class ScryfallMtgPriceProviderAdapter implements PriceProvider {
  const ScryfallMtgPriceProviderAdapter({
    legacy_prices.PriceProvider? legacyProvider,
  }) : _legacyProvider = legacyProvider;

  final legacy_prices.PriceProvider? _legacyProvider;

  legacy_prices.PriceProvider get _provider =>
      _legacyProvider ?? legacy_prices.ScryfallPriceProvider();

  @override
  PriceSourceId get sourceId => PriceSourceId.scryfall;

  @override
  TcgGameId get gameId => TcgGameId.mtg;

  @override
  PriceRefreshPolicy get refreshPolicy => const PriceRefreshPolicy(
    ttl: Duration(hours: 24),
    maxConcurrentRequests: 2,
    allowsStaleReads: true,
  );

  @override
  Future<List<PriceSnapshot>> fetchLatestPrices(
    PriceQuoteRequest request,
  ) async {
    final providerObjectId = request.providerObjectId?.trim() ?? '';
    final printingId = request.printingId.trim();
    if (providerObjectId.isEmpty || printingId.isEmpty) {
      return const <PriceSnapshot>[];
    }
    final prices = await _provider.fetchPrices(providerObjectId);
    if (prices == null) {
      return const <PriceSnapshot>[];
    }
    final capturedAt = DateTime.now().toUtc();
    final preferredCurrencies = request.preferredCurrencies
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final preferredFinishKeys = request.preferredFinishKeys
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final snapshots = <PriceSnapshot>[];

    bool allowsCurrency(String currencyCode) {
      return preferredCurrencies.isEmpty ||
          preferredCurrencies.contains(currencyCode);
    }

    bool allowsFinish(String? finishKey) {
      final normalized = finishKey?.trim().toLowerCase();
      if (preferredFinishKeys.isEmpty) {
        return true;
      }
      return preferredFinishKeys.contains(normalized ?? 'default');
    }

    void addPrice(String? raw, String currencyCode, {String? finishKey}) {
      final parsed = double.tryParse((raw ?? '').trim());
      if (parsed == null ||
          !allowsCurrency(currencyCode) ||
          !allowsFinish(finishKey)) {
        return;
      }
      snapshots.add(
        PriceSnapshot(
          printingId: printingId,
          sourceId: sourceId,
          currencyCode: currencyCode,
          amount: parsed,
          capturedAt: capturedAt,
          finishKey: finishKey,
        ),
      );
    }

    addPrice(prices.usd, 'usd');
    addPrice(prices.usdFoil, 'usd', finishKey: 'foil');
    addPrice(prices.usdEtched, 'usd', finishKey: 'etched');
    addPrice(prices.eur, 'eur');
    addPrice(prices.eurFoil, 'eur', finishKey: 'foil');
    addPrice(prices.tix, 'tix');
    return snapshots;
  }
}
