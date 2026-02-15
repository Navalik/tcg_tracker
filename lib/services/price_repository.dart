import 'dart:async';

import '../db/app_database.dart';
import 'price_provider.dart';

enum PriceProviderType {
  scryfall,
  mtgJson,
}

class PriceRepository {
  PriceRepository._();

  static final PriceRepository instance = PriceRepository._();

  static const Duration _ttl = Duration(hours: 24);
  static const int _maxConcurrentRequests = 2;

  final Map<String, Future<void>> _inFlight = <String, Future<void>>{};
  final List<Completer<void>> _waiters = <Completer<void>>[];

  int _activeRequests = 0;
  PriceProviderType _activeProviderType = PriceProviderType.scryfall;

  PriceProvider get _activeProvider {
    switch (_activeProviderType) {
      case PriceProviderType.mtgJson:
        return MtgJsonPriceProvider();
      case PriceProviderType.scryfall:
        return ScryfallPriceProvider();
    }
  }

  void setActiveProvider(PriceProviderType providerType) {
    _activeProviderType = providerType;
  }

  Future<void> ensurePricesFresh(String cardId) {
    final normalizedId = cardId.trim();
    if (normalizedId.isEmpty) {
      return Future<void>.value();
    }
    final existing = _inFlight[normalizedId];
    if (existing != null) {
      return existing;
    }
    final future = _ensureFreshInternal(normalizedId);
    _inFlight[normalizedId] = future;
    future.whenComplete(() {
      final current = _inFlight[normalizedId];
      if (identical(current, future)) {
        _inFlight.remove(normalizedId);
      }
    });
    return future;
  }

  Future<void> _ensureFreshInternal(String cardId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snapshot = await ScryfallDatabase.instance.fetchCardPriceSnapshot(cardId);
    if (snapshot == null) {
      return;
    }
    final updatedAt = snapshot.pricesUpdatedAt;
    final ageMs = updatedAt == null ? null : (now - updatedAt);
    if (ageMs != null && ageMs >= 0 && ageMs < _ttl.inMilliseconds) {
      return;
    }

    await _acquireSlot();
    try {
      final latest = await _activeProvider.fetchPrices(cardId);
      if (latest == null) {
        return;
      }
      await ScryfallDatabase.instance.updateCardPrices(
        cardId,
        latest,
        updatedAt: now,
      );
    } finally {
      _releaseSlot();
    }
  }

  Future<void> _acquireSlot() {
    if (_activeRequests < _maxConcurrentRequests) {
      _activeRequests += 1;
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future.then((_) {
      _activeRequests += 1;
    });
  }

  void _releaseSlot() {
    if (_activeRequests > 0) {
      _activeRequests -= 1;
    }
    if (_waiters.isEmpty) {
      return;
    }
    final completer = _waiters.removeAt(0);
    if (!completer.isCompleted) {
      completer.complete();
    }
  }
}
