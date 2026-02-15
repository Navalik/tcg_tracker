import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import 'app_settings.dart';

enum UserTier { free, plus }

enum PlusPlanPeriod { monthly, yearly }

class PlusPlanOption {
  const PlusPlanOption({
    required this.period,
    required this.formattedPrice,
    required this.productDetails,
    required this.billingPeriod,
    this.offerToken,
  });

  final PlusPlanPeriod period;
  final String formattedPrice;
  final ProductDetails productDetails;
  final String billingPeriod;
  final String? offerToken;
}

class PurchaseManager extends ChangeNotifier {
  PurchaseManager._();

  static final PurchaseManager instance = PurchaseManager._();

  // Google Play subscription product id configured in Play Console.
  static const String plusProductId = 'bindervault_plus';
  static const String _billingMonthlyPeriod = 'P1M';
  static const String _billingYearlyPeriod = 'P1Y';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  UserTier _userTier = UserTier.free;
  Set<String> _ownedTcgs = const <String>{};
  bool _storeAvailable = false;
  bool _initialized = false;
  bool _loadingPlans = false;
  bool _purchasePending = false;
  bool _restoringPurchases = false;
  String? _lastError;
  PlusPlanOption? _monthlyPlan;
  PlusPlanOption? _yearlyPlan;

  UserTier get userTier => _userTier;
  bool get isPro => _userTier == UserTier.plus;
  Set<String> get ownedTcgs => _ownedTcgs;
  bool get storeAvailable => _storeAvailable;
  bool get isInitialized => _initialized;
  bool get loadingPlans => _loadingPlans;
  bool get purchasePending => _purchasePending;
  bool get restoringPurchases => _restoringPurchases;
  String? get lastError => _lastError;
  PlusPlanOption? get monthlyPlan => _monthlyPlan;
  PlusPlanOption? get yearlyPlan => _yearlyPlan;
  bool get hasPlans => _monthlyPlan != null && _yearlyPlan != null;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _userTier = _tierFromStored(await AppSettings.loadUserTier());
    _ownedTcgs = await AppSettings.loadOwnedTcgs();

    if (_supportsStore()) {
      _storeAvailable = await _inAppPurchase.isAvailable();
      _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          _purchaseSubscription = null;
        },
        onError: (_) {},
      );

      if (_storeAvailable) {
        await refreshCatalog();
        await refreshEntitlementFromStore();
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> refreshCatalog() async {
    if (!_supportsStore()) {
      return;
    }
    _loadingPlans = true;
    _lastError = null;
    notifyListeners();
    try {
      _storeAvailable = await _inAppPurchase.isAvailable();
      if (!_storeAvailable) {
        _monthlyPlan = null;
        _yearlyPlan = null;
        _lastError = 'store_unavailable';
        return;
      }
      final response = await _inAppPurchase.queryProductDetails({plusProductId});
      if (response.error != null) {
        _lastError = response.error!.message;
        _monthlyPlan = null;
        _yearlyPlan = null;
      } else {
        _resolvePlansFromResponse(response);
        if (!hasPlans) {
          _lastError = 'plans_unavailable';
        }
      }
    } catch (error) {
      _lastError = error.toString();
      _monthlyPlan = null;
      _yearlyPlan = null;
    } finally {
      _loadingPlans = false;
      notifyListeners();
    }
  }

  Future<void> purchasePlus(PlusPlanPeriod period) async {
    final selected = period == PlusPlanPeriod.monthly ? _monthlyPlan : _yearlyPlan;
    if (!_supportsStore() || !_storeAvailable || selected == null) {
      return;
    }
    _lastError = null;
    _purchasePending = true;
    notifyListeners();
    try {
      final PurchaseParam param;
      if (Platform.isAndroid) {
        final offerToken = selected.offerToken;
        if (offerToken == null || offerToken.isEmpty) {
          _lastError = 'missing_offer_token';
          _purchasePending = false;
          notifyListeners();
          return;
        }
        // Android subscriptions require the selected offer token.
        param = GooglePlayPurchaseParam(
          productDetails: selected.productDetails,
          offerToken: offerToken,
        );
      } else {
        param = PurchaseParam(productDetails: selected.productDetails);
      }
      await _inAppPurchase.buyNonConsumable(purchaseParam: param);
    } catch (error) {
      _lastError = error.toString();
      _purchasePending = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (!_supportsStore() || !_storeAvailable) {
      return;
    }
    _restoringPurchases = true;
    _lastError = null;
    notifyListeners();
    try {
      await _inAppPurchase.restorePurchases();
      await refreshEntitlementFromStore();
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _restoringPurchases = false;
      notifyListeners();
    }
  }

  Future<void> refreshEntitlementFromStore() async {
    if (!_supportsStore() || !_storeAvailable || !Platform.isAndroid) {
      return;
    }
    try {
      final addition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      var plusActive = false;
      for (final purchase in response.pastPurchases) {
        if (purchase.productID == plusProductId &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored)) {
          plusActive = true;
          break;
        }
      }
      await _setTier(plusActive ? UserTier.plus : UserTier.free);
    } catch (_) {
      // Keep local entitlement when store-side query is unavailable.
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != plusProductId) {
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) {
        _purchasePending = true;
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _lastError = purchase.error?.message ?? purchase.error?.code;
        _purchasePending = false;
        notifyListeners();
      }

      if (purchase.status == PurchaseStatus.canceled) {
        _purchasePending = false;
        notifyListeners();
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _setTier(UserTier.plus);
        _purchasePending = false;
        notifyListeners();
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  void _resolvePlansFromResponse(ProductDetailsResponse response) {
    final products = response.productDetails
        .where((details) => details.id == plusProductId)
        .toList(growable: false);

    _monthlyPlan = null;
    _yearlyPlan = null;

    if (products.isEmpty) {
      return;
    }
    final product = products.first;

    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      final monthlyOffer = _selectOffer(offers, _billingMonthlyPeriod);
      final yearlyOffer = _selectOffer(offers, _billingYearlyPeriod);

      if (monthlyOffer != null) {
        _monthlyPlan = PlusPlanOption(
          period: PlusPlanPeriod.monthly,
          formattedPrice: monthlyOffer.$2.formattedPrice,
          productDetails: product,
          billingPeriod: monthlyOffer.$2.billingPeriod,
          offerToken: monthlyOffer.$1.offerIdToken,
        );
      }
      if (yearlyOffer != null) {
        _yearlyPlan = PlusPlanOption(
          period: PlusPlanPeriod.yearly,
          formattedPrice: yearlyOffer.$2.formattedPrice,
          productDetails: product,
          billingPeriod: yearlyOffer.$2.billingPeriod,
          offerToken: yearlyOffer.$1.offerIdToken,
        );
      }
      return;
    }

    // Non-Android fallback: keep app functional without Android-only offer details.
    _monthlyPlan = PlusPlanOption(
      period: PlusPlanPeriod.monthly,
      formattedPrice: product.price,
      productDetails: product,
      billingPeriod: _billingMonthlyPeriod,
    );
    _yearlyPlan = PlusPlanOption(
      period: PlusPlanPeriod.yearly,
      formattedPrice: product.price,
      productDetails: product,
      billingPeriod: _billingYearlyPeriod,
    );
  }

  (
    SubscriptionOfferDetailsWrapper,
    PricingPhaseWrapper
  )? _selectOffer(
    List<SubscriptionOfferDetailsWrapper>? offers,
    String targetBillingPeriod,
  ) {
    if (offers == null || offers.isEmpty) {
      return null;
    }

    SubscriptionOfferDetailsWrapper? bestOffer;
    PricingPhaseWrapper? bestPhase;
    var bestScore = -1;

    for (final offer in offers) {
      PricingPhaseWrapper? matchingPhase;
      for (final phase in offer.pricingPhases) {
        if (phase.billingPeriod == targetBillingPeriod) {
          matchingPhase = phase;
          break;
        }
      }
      if (matchingPhase == null) {
        continue;
      }

      var score = 0;
      // Prefer base plans (offerId null/empty) over promo offers.
      if ((offer.offerId ?? '').trim().isEmpty) {
        score += 100;
      }
      // Prefer simple non-trial/non-discount offers.
      if (offer.pricingPhases.length == 1) {
        score += 20;
      }
      if (matchingPhase.priceAmountMicros > 0) {
        score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        bestOffer = offer;
        bestPhase = matchingPhase;
      }
    }

    if (bestOffer == null || bestPhase == null) {
      return null;
    }
    return (bestOffer, bestPhase);
  }

  Future<void> _setTier(UserTier tier) async {
    if (_userTier == tier) {
      await AppSettings.saveUserTier(_tierToStorage(tier));
      return;
    }
    _userTier = tier;
    await AppSettings.saveUserTier(_tierToStorage(tier));
    notifyListeners();
  }

  Future<void> setOwnedTcgs(Set<String> values) async {
    _ownedTcgs = values;
    await AppSettings.saveOwnedTcgs(values);
    notifyListeners();
  }

  String _tierToStorage(UserTier tier) {
    return tier == UserTier.plus ? 'plus' : 'free';
  }

  UserTier _tierFromStored(String value) {
    return value.trim().toLowerCase() == 'plus' ? UserTier.plus : UserTier.free;
  }

  bool _supportsStore() => Platform.isAndroid || Platform.isIOS;
}
