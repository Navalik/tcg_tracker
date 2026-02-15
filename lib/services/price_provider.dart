import 'dart:convert';

import 'scryfall_api_client.dart';

class CardPrices {
  const CardPrices({
    this.usd,
    this.usdFoil,
    this.usdEtched,
    this.eur,
    this.eurFoil,
    this.tix,
  });

  final String? usd;
  final String? usdFoil;
  final String? usdEtched;
  final String? eur;
  final String? eurFoil;
  final String? tix;

  bool get hasAnyValue =>
      (usd?.isNotEmpty ?? false) ||
      (usdFoil?.isNotEmpty ?? false) ||
      (usdEtched?.isNotEmpty ?? false) ||
      (eur?.isNotEmpty ?? false) ||
      (eurFoil?.isNotEmpty ?? false) ||
      (tix?.isNotEmpty ?? false);
}

abstract class PriceProvider {
  Future<CardPrices?> fetchPrices(String scryfallId);
}

class ScryfallPriceProvider implements PriceProvider {
  @override
  Future<CardPrices?> fetchPrices(String scryfallId) async {
    final id = scryfallId.trim();
    if (id.isEmpty) {
      return null;
    }
    final uri = Uri.parse('https://api.scryfall.com/cards/$id');
    final response = await ScryfallApiClient.instance.get(
      uri,
      timeout: const Duration(seconds: 6),
      maxRetries: 2,
    );
    if (response.statusCode != 200) {
      return null;
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    final prices = payload['prices'];
    if (prices is! Map<String, dynamic>) {
      return null;
    }
    return CardPrices(
      usd: _asPriceString(prices['usd']),
      usdFoil: _asPriceString(prices['usd_foil']),
      usdEtched: _asPriceString(prices['usd_etched']),
      eur: _asPriceString(prices['eur']),
      eurFoil: _asPriceString(prices['eur_foil']),
      tix: _asPriceString(prices['tix']),
    );
  }

  String? _asPriceString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class MtgJsonPriceProvider implements PriceProvider {
  @override
  Future<CardPrices?> fetchPrices(String scryfallId) async {
    // Stub provider for future MTGJSON integration.
    return null;
  }
}
