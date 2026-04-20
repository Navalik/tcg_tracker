import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import 'app_settings.dart';
import 'entitlement_sync_service.dart';

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
  static const String additionalTcgProductId = 'unlock_additional_tcg';
  static const String magicOwnershipKey = 'magic';
  static const String pokemonOwnershipKey = 'pokemon';
  static const String androidPackageName = 'com.navalik.bindervault';
  static const String _billingMonthlyPeriod = 'P1M';
  static const String _billingYearlyPeriod = 'P1Y';
  static const bool _requireServerEntitlementVerification =
      bool.fromEnvironment(
        'REQUIRE_SERVER_ENTITLEMENT_VERIFICATION',
        defaultValue: true,
      );
  static const bool _serverEntitlementVerificationAvailable = true;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _purchaseWatchdog;

  UserTier _userTier = UserTier.free;
  Set<String> _ownedTcgs = const <String>{};
  bool _pokemonUnlocked = false;
  AppTcgGame _primaryGame = AppTcgGame.mtg;
  int _extraTcgSlots = 0;
  bool _storeAvailable = false;
  bool _initialized = false;
  bool _loadingPlans = false;
  bool _purchasePending = false;
  bool _restoringPurchases = false;
  String? _lastError;
  PlusPlanOption? _monthlyPlan;
  PlusPlanOption? _yearlyPlan;
  ProductDetails? _additionalTcgProduct;

  UserTier get userTier => _userTier;
  bool get isPro => _userTier == UserTier.plus;
  Set<String> get ownedTcgs => _ownedTcgs;
  ProductDetails? get additionalTcgProduct => _additionalTcgProduct;
  String? get additionalTcgPriceLabel => _additionalTcgProduct?.price;
  int get extraTcgSlots => _extraTcgSlots;
  bool get hasExtraTcgSlots => _extraTcgSlots > 0;
  bool canAccessGame(AppTcgGame game) {
    if (game == _primaryGame) {
      return true;
    }
    if (_ownedTcgs.contains(_ownershipKeyForGame(game))) {
      return true;
    }
    final secondaryGames = _knownGames
        .where((candidate) => candidate != _primaryGame)
        .toList(growable: false);
    final index = secondaryGames.indexOf(game);
    return index >= 0 && index < _extraTcgSlots;
  }

  bool canAccessPokemon() => canAccessGame(AppTcgGame.pokemon);
  bool get storeAvailable => _storeAvailable;
  bool get isInitialized => _initialized;
  bool get loadingPlans => _loadingPlans;
  bool get purchasePending => _purchasePending;
  bool get restoringPurchases => _restoringPurchases;
  String? get lastError => _lastError;
  PlusPlanOption? get monthlyPlan => _monthlyPlan;
  PlusPlanOption? get yearlyPlan => _yearlyPlan;
  bool get hasPlans => _monthlyPlan != null && _yearlyPlan != null;

  Future<void> _logBillingEvent(
    String event, {
    Map<String, Object?> details = const <String, Object?>{},
  }) async {
    try {
      final payload = <String>[
        'event=$event',
        'platform=${Platform.operatingSystem}',
        'store_available=$_storeAvailable',
        'purchase_pending=$_purchasePending',
        'restoring=$_restoringPurchases',
        'tier=${_tierToStorage(_userTier)}',
        'extra_slots=$_extraTcgSlots',
        if (_lastError != null && _lastError!.trim().isNotEmpty)
          'last_error=${_lastError!.trim()}',
        ...details.entries.map(
          (entry) => '${entry.key}=${_sanitizeDiagnosticValue(entry.value)}',
        ),
      ];
      FirebaseCrashlytics.instance.log('billing ${payload.join(' ')}');
    } catch (_) {}
  }

  String _sanitizeDiagnosticValue(Object? value) {
    final text = (value ?? '').toString().replaceAll(RegExp(r'[\r\n]+'), ' ');
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.length <= 120 ? trimmed : '${trimmed.substring(0, 120)}...';
  }

  Future<AndroidEntitlementProof?> _findPlusProof(
    List<PurchaseDetails> purchases,
  ) async {
    if (!Platform.isAndroid) {
      return null;
    }
    for (final purchase in purchases) {
      final activePurchase =
          purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;
      if (!activePurchase || purchase.productID != plusProductId) {
        continue;
      }
      final purchaseToken = purchase.verificationData.serverVerificationData
          .trim();
      if (purchaseToken.isEmpty) {
        continue;
      }
      return AndroidEntitlementProof(
        packageName: androidPackageName,
        productId: plusProductId,
        purchaseToken: purchaseToken,
      );
    }
    return null;
  }

  Future<void> _syncFirebaseEntitlementClaim({
    AndroidEntitlementProof? androidProof,
  }) async {
    try {
      final result = await EntitlementSyncService.instance.syncCurrentUserTier(
        localPlusActive: _userTier == UserTier.plus,
        androidProof: androidProof,
      );
      await _logBillingEvent(
        'firebase_claim_sync_complete',
        details: {
          'claim_tier': result.claimTier,
          'synced': result.synced,
          'source': result.source ?? '',
          'verification_state': result.verificationState ?? '',
        },
      );
    } catch (error) {
      await _logBillingEvent(
        'firebase_claim_sync_error',
        details: {'error': error},
      );
    }
  }

  Future<void> init() async {
    if (_initialized) {
      if (_supportsStore()) {
        _ensurePurchaseStreamListener();
      }
      return;
    }
    await _logBillingEvent('init_start');
    // Keep last known entitlement as fallback, then reconcile with store.
    _userTier = _tierFromStored(await AppSettings.loadUserTier());
    _ownedTcgs = await AppSettings.loadOwnedTcgs();
    _pokemonUnlocked = await AppSettings.loadPokemonUnlocked();
    _primaryGame =
        await AppSettings.loadPrimaryTcgGameOrNull() ?? AppTcgGame.mtg;
    _extraTcgSlots = await AppSettings.loadExtraTcgSlots();
    if (_pokemonUnlocked && !_ownedTcgs.contains(pokemonOwnershipKey)) {
      _ownedTcgs = {..._ownedTcgs, pokemonOwnershipKey};
      await AppSettings.saveOwnedTcgs(_ownedTcgs);
    }

    if (_supportsStore()) {
      _storeAvailable = await _inAppPurchase.isAvailable();
      _ensurePurchaseStreamListener();

      if (_storeAvailable) {
        unawaited(_warmStoreState());
      }
    }

    _initialized = true;
    await _logBillingEvent(
      'init_complete',
      details: {
        'owned_tcgs': _ownedTcgs.join(','),
        'has_plans': hasPlans,
        'has_additional_product': _additionalTcgProduct != null,
      },
    );
    notifyListeners();
  }

  Future<void> _warmStoreState() async {
    try {
      await refreshCatalog();
      await refreshEntitlementFromStore();
    } catch (error) {
      await _logBillingEvent(
        'store_warmup_exception',
        details: {'error': error},
      );
    }
  }

  Future<void> refreshCatalog() async {
    if (!_supportsStore()) {
      return;
    }
    _loadingPlans = true;
    _lastError = null;
    notifyListeners();
    try {
      await _logBillingEvent('catalog_refresh_start');
      _storeAvailable = await _inAppPurchase.isAvailable();
      if (!_storeAvailable) {
        _monthlyPlan = null;
        _yearlyPlan = null;
        _lastError = 'store_unavailable';
        await _logBillingEvent('catalog_refresh_store_unavailable');
        return;
      }
      final response = await _inAppPurchase.queryProductDetails({
        plusProductId,
        additionalTcgProductId,
      });
      if (response.error != null) {
        _lastError = 'plans_unavailable';
        _monthlyPlan = null;
        _yearlyPlan = null;
        _additionalTcgProduct = null;
        await _logBillingEvent(
          'catalog_refresh_error',
          details: {'response_error': response.error},
        );
      } else {
        _resolvePlansFromResponse(response);
        _additionalTcgProduct = null;
        for (final details in response.productDetails) {
          if (details.id == additionalTcgProductId) {
            _additionalTcgProduct = details;
            break;
          }
        }
        if (!hasPlans && _additionalTcgProduct == null) {
          _lastError = 'plans_unavailable';
        }
        await _logBillingEvent(
          'catalog_refresh_complete',
          details: {
            'product_count': response.productDetails.length,
            'has_monthly': _monthlyPlan != null,
            'has_yearly': _yearlyPlan != null,
            'has_additional_product': _additionalTcgProduct != null,
          },
        );
      }
    } catch (error) {
      _lastError = 'catalog_load_failed';
      _monthlyPlan = null;
      _yearlyPlan = null;
      _additionalTcgProduct = null;
      await _logBillingEvent(
        'catalog_refresh_exception',
        details: {'error': error},
      );
    } finally {
      _loadingPlans = false;
      notifyListeners();
    }
  }

  Future<void> purchaseAdditionalTcgUnlock() async {
    final product = _additionalTcgProduct;
    if (!_supportsStore() || !_storeAvailable || product == null) {
      await _logBillingEvent(
        'purchase_additional_skipped',
        details: {'product_missing': product == null},
      );
      return;
    }
    _ensurePurchaseStreamListener();
    _lastError = null;
    _purchasePending = true;
    _startPurchaseWatchdog();
    notifyListeners();
    try {
      final param = PurchaseParam(productDetails: product);
      await _logBillingEvent(
        'purchase_additional_start',
        details: {'product_id': product.id, 'price': product.price},
      );
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: param,
      );
      if (!started) {
        _lastError = 'purchase_start_failed';
        _purchasePending = false;
        _purchaseWatchdog?.cancel();
        await _logBillingEvent(
          'purchase_additional_not_started',
          details: {'product_id': product.id},
        );
        notifyListeners();
      }
    } catch (error) {
      if (_isAlreadyOwnedError(error)) {
        _lastError = 'already_owned';
        _purchasePending = false;
        _purchaseWatchdog?.cancel();
        await refreshEntitlementFromStore();
        if (_extraTcgSlots > 0 || _ownedTcgs.isNotEmpty) {
          _lastError = null;
        }
        await _logBillingEvent(
          'purchase_additional_already_owned',
          details: {'product_id': product.id, 'error': error},
        );
        notifyListeners();
        return;
      }
      _lastError = 'purchase_start_failed';
      _purchasePending = false;
      _purchaseWatchdog?.cancel();
      await _logBillingEvent(
        'purchase_additional_exception',
        details: {'product_id': product.id, 'error': error},
      );
      notifyListeners();
    }
  }

  Future<void> purchasePlus(PlusPlanPeriod period) async {
    final selected = period == PlusPlanPeriod.monthly
        ? _monthlyPlan
        : _yearlyPlan;
    if (!_supportsStore() || !_storeAvailable || selected == null) {
      await _logBillingEvent(
        'purchase_plus_skipped',
        details: {'period': period.name, 'plan_missing': selected == null},
      );
      return;
    }
    _ensurePurchaseStreamListener();
    _lastError = null;
    _purchasePending = true;
    _startPurchaseWatchdog();
    notifyListeners();
    try {
      final PurchaseParam param;
      if (Platform.isAndroid) {
        final offerToken = selected.offerToken;
        if (offerToken == null || offerToken.isEmpty) {
          _lastError = 'missing_offer_token';
          _purchasePending = false;
          await _logBillingEvent(
            'purchase_plus_missing_offer_token',
            details: {
              'period': period.name,
              'product_id': selected.productDetails.id,
            },
          );
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
      await _logBillingEvent(
        'purchase_plus_start',
        details: {
          'period': period.name,
          'product_id': selected.productDetails.id,
          'billing_period': selected.billingPeriod,
          'offer_token_present': (selected.offerToken ?? '').isNotEmpty,
          'price': selected.formattedPrice,
        },
      );
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: param,
      );
      if (!started) {
        _lastError = 'purchase_start_failed';
        _purchasePending = false;
        _purchaseWatchdog?.cancel();
        await _logBillingEvent(
          'purchase_plus_not_started',
          details: {
            'period': period.name,
            'product_id': selected.productDetails.id,
          },
        );
        notifyListeners();
      }
    } catch (error) {
      _lastError = 'purchase_start_failed';
      _purchasePending = false;
      _purchaseWatchdog?.cancel();
      await _logBillingEvent(
        'purchase_plus_exception',
        details: {
          'period': period.name,
          'product_id': selected.productDetails.id,
          'error': error,
        },
      );
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (!_supportsStore()) {
      return;
    }
    await _logBillingEvent('restore_start');
    try {
      _storeAvailable = await _inAppPurchase.isAvailable();
    } catch (_) {
      _storeAvailable = false;
    }
    if (!_storeAvailable) {
      _lastError = 'store_unavailable';
      notifyListeners();
      return;
    }
    _ensurePurchaseStreamListener();
    _restoringPurchases = true;
    _lastError = null;
    notifyListeners();
    try {
      await _inAppPurchase.restorePurchases();
      await refreshEntitlementFromStore();
      await _logBillingEvent('restore_complete');
    } catch (error) {
      _lastError = 'restore_failed';
      await _logBillingEvent('restore_exception', details: {'error': error});
    } finally {
      _restoringPurchases = false;
      notifyListeners();
    }
  }

  Future<void> refreshEntitlementFromStore() async {
    if (!_supportsStore() || !Platform.isAndroid) {
      return;
    }
    try {
      await _logBillingEvent('entitlement_refresh_start');
      _storeAvailable = await _inAppPurchase.isAvailable();
      if (!_storeAvailable) {
        _lastError = 'store_unavailable';
        await _logBillingEvent('entitlement_refresh_store_unavailable');
        notifyListeners();
        return;
      }
      final addition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      var plusActive = false;
      var additionalTcgUnlocked = false;
      for (final purchase in response.pastPurchases) {
        final activePurchase =
            purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored;
        if (!activePurchase) {
          continue;
        }
        if (purchase.productID == plusProductId) {
          plusActive = true;
          continue;
        }
        if (purchase.productID == additionalTcgProductId) {
          additionalTcgUnlocked = true;
        }
      }
      if (plusActive && _requireServerEntitlementVerification) {
        if (_serverEntitlementVerificationAvailable) {
          plusActive = await _verifyReceiptWithServer(response.pastPurchases);
          if (!plusActive) {
            _lastError = 'server_entitlement_unverified';
          }
        } else {
          await _logBillingEvent('server_entitlement_verification_unavailable');
        }
      }
      await _setTier(plusActive ? UserTier.plus : UserTier.free);
      _extraTcgSlots = additionalTcgUnlocked ? 1 : 0;
      await AppSettings.saveExtraTcgSlots(_extraTcgSlots);
      final secondary = _knownGames.firstWhere(
        (candidate) => candidate != _primaryGame,
        orElse: () => AppTcgGame.pokemon,
      );
      final key = _ownershipKeyForGame(secondary);
      final nextOwnedTcgs = additionalTcgUnlocked
          ? {..._ownedTcgs, key}
          : ({..._ownedTcgs}..remove(key));
      if (!setEquals(nextOwnedTcgs, _ownedTcgs)) {
        _ownedTcgs = nextOwnedTcgs;
        await AppSettings.saveOwnedTcgs(_ownedTcgs);
      }
      _pokemonUnlocked = _ownedTcgs.contains(pokemonOwnershipKey);
      await AppSettings.savePokemonUnlocked(_pokemonUnlocked);
      await _logBillingEvent(
        'entitlement_refresh_complete',
        details: {
          'plus_active': plusActive,
          'additional_tcg_unlocked': additionalTcgUnlocked,
          'past_purchase_count': response.pastPurchases.length,
          'owned_tcgs': _ownedTcgs.join(','),
        },
      );
      final plusProof = plusActive
          ? await _findPlusProof(response.pastPurchases)
          : null;
      await _syncFirebaseEntitlementClaim(androidProof: plusProof);
      notifyListeners();
    } catch (error) {
      _lastError = 'entitlement_refresh_failed';
      // Do not downgrade entitlements on transient store/network failures.
      await _logBillingEvent(
        'entitlement_refresh_exception',
        details: {'error': error},
      );
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    await _logBillingEvent(
      'purchase_updates_received',
      details: {'count': purchases.length},
    );
    for (final purchase in purchases) {
      await _logBillingEvent(
        'purchase_update_item',
        details: {
          'product_id': purchase.productID,
          'status': purchase.status.name,
          'pending_complete': purchase.pendingCompletePurchase,
          'error': purchase.error,
        },
      );
      final isKnownProduct =
          purchase.productID == plusProductId ||
          purchase.productID == additionalTcgProductId;
      if (!isKnownProduct) {
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) {
        _purchasePending = true;
        _startPurchaseWatchdog();
        notifyListeners();
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        if (_isAlreadyOwnedIapError(purchase.error)) {
          _lastError = 'already_owned';
          await refreshEntitlementFromStore();
          if (_extraTcgSlots > 0 || _ownedTcgs.isNotEmpty) {
            _lastError = null;
          }
        } else {
          _lastError = 'purchase_failed';
        }
        _purchasePending = false;
        _purchaseWatchdog?.cancel();
        notifyListeners();
      }

      if (purchase.status == PurchaseStatus.canceled) {
        _purchasePending = false;
        _purchaseWatchdog?.cancel();
        notifyListeners();
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Optimistic unlock on successful purchase callback, then reconcile.
        if (purchase.productID == plusProductId) {
          await _setTier(UserTier.plus);
          _lastError = null;
        }
        if (purchase.productID == additionalTcgProductId) {
          if (_extraTcgSlots < 1) {
            _extraTcgSlots = 1;
            await AppSettings.saveExtraTcgSlots(_extraTcgSlots);
          }
          _lastError = null;
        }
        await refreshEntitlementFromStore();
        if (purchase.productID == plusProductId && _userTier != UserTier.plus) {
          _lastError = 'entitlement_verification_failed';
        }
        if (purchase.productID == additionalTcgProductId &&
            _extraTcgSlots <= 0) {
          _lastError = 'entitlement_verification_failed';
        }
        _purchasePending = false;
        _purchaseWatchdog?.cancel();
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

  (SubscriptionOfferDetailsWrapper, PricingPhaseWrapper)? _selectOffer(
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

  Future<bool> _verifyReceiptWithServer(List<PurchaseDetails> purchases) async {
    final proof = await _findPlusProof(purchases);
    if (proof == null) {
      return false;
    }
    final result = await EntitlementSyncService.instance.syncCurrentUserTier(
      localPlusActive: true,
      androidProof: proof,
    );
    return result.claimTier == 'plus';
  }

  Future<void> setOwnedTcgs(Set<String> values) async {
    _ownedTcgs = values;
    await AppSettings.saveOwnedTcgs(values);
    _pokemonUnlocked = values.contains(pokemonOwnershipKey);
    await AppSettings.savePokemonUnlocked(_pokemonUnlocked);
    notifyListeners();
  }

  Future<void> syncPrimaryGameFromSettings() async {
    _primaryGame =
        await AppSettings.loadPrimaryTcgGameOrNull() ?? AppTcgGame.mtg;
    notifyListeners();
  }

  String _ownershipKeyForGame(AppTcgGame game) {
    return game == AppTcgGame.pokemon ? pokemonOwnershipKey : magicOwnershipKey;
  }

  static const List<AppTcgGame> _knownGames = [
    AppTcgGame.mtg,
    AppTcgGame.pokemon,
  ];

  String _tierToStorage(UserTier tier) {
    return tier == UserTier.plus ? 'plus' : 'free';
  }

  UserTier _tierFromStored(String value) {
    return value.trim().toLowerCase() == 'plus' ? UserTier.plus : UserTier.free;
  }

  void _startPurchaseWatchdog() {
    _purchaseWatchdog?.cancel();
    _purchaseWatchdog = Timer(const Duration(seconds: 90), () {
      if (!_purchasePending) {
        return;
      }
      _lastError = 'purchase_failed';
      _purchasePending = false;
      unawaited(_logBillingEvent('purchase_watchdog_timeout'));
      notifyListeners();
    });
  }

  bool _supportsStore() => Platform.isAndroid || Platform.isIOS;

  void _ensurePurchaseStreamListener() {
    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () {
        _purchasePending = false;
        _restoringPurchases = false;
        _purchaseWatchdog?.cancel();
        _purchaseSubscription = null;
        unawaited(_logBillingEvent('purchase_stream_done'));
        notifyListeners();
      },
      onError: (error) {
        _lastError = 'purchase_failed';
        _purchasePending = false;
        _restoringPurchases = false;
        _purchaseWatchdog?.cancel();
        _purchaseSubscription = null;
        unawaited(
          _logBillingEvent('purchase_stream_error', details: {'error': error}),
        );
        notifyListeners();
      },
    );
  }

  bool _isAlreadyOwnedIapError(IAPError? error) {
    if (error == null) {
      return false;
    }
    return _isAlreadyOwnedError(
      '${error.code} ${error.message} ${error.details}',
    );
  }

  bool _isAlreadyOwnedError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('already owned') ||
        raw.contains('already_owned') ||
        raw.contains('item_already_owned') ||
        raw.contains('itemalreadyowned') ||
        raw.contains('billingresponse.item_already_owned') ||
        raw.contains('you already own this item') ||
        raw.contains('possiedi gia') ||
        raw.contains('possiedi già');
  }
}
