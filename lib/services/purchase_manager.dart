import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_settings.dart';

class PurchaseManager extends ChangeNotifier {
  PurchaseManager._();

  static final PurchaseManager instance = PurchaseManager._();
  static const String _proProductId = 'bindervault_pro';

  bool _isPro = false;
  bool _storeAvailable = false;
  bool _testMode = true;
  bool _initialized = false;
  ProductDetails? _proProduct;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool get isPro => _isPro;
  bool get storeAvailable => _storeAvailable;
  bool get testMode => _testMode;
  bool get isInitialized => _initialized;
  String get priceLabel => _proProduct?.price ?? 'TBD';

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _isPro = await AppSettings.loadProUnlocked();
    if (_supportsStore()) {
      _storeAvailable = await InAppPurchase.instance.isAvailable();
      _subscription ??= InAppPurchase.instance.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          _subscription = null;
        },
      );
      if (_storeAvailable) {
        final response = await InAppPurchase.instance.queryProductDetails(
          {_proProductId},
        );
        if (response.error == null && response.productDetails.isNotEmpty) {
          _proProduct = response.productDetails.first;
        }
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setTestMode(bool value) async {
    _testMode = value;
    notifyListeners();
  }

  Future<void> purchasePro() async {
    if (_testMode || !_supportsStore()) {
      await _setPro(!_isPro);
      return;
    }
    if (!_storeAvailable || _proProduct == null) {
      return;
    }
    final purchaseParam = PurchaseParam(productDetails: _proProduct!);
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> restorePurchases() async {
    if (!_supportsStore()) {
      return;
    }
    await InAppPurchase.instance.restorePurchases();
  }

  bool _supportsStore() => Platform.isAndroid || Platform.isIOS;

  Future<void> _setPro(bool value) async {
    _isPro = value;
    await AppSettings.saveProUnlocked(value);
    notifyListeners();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _setPro(true);
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }
}
