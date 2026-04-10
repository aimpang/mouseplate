import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const String kPremiumProductId = 'mouseplate_premium';

/// Thin wrapper around the Flutter in_app_purchase plugin.
///
/// Usage:
///   final iap = IapService();
///   await iap.init();
///   iap.onPremiumUnlocked = () { controller.setPremiumUnlocked(true); };
///   await iap.buyPremium();
class IapService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  ProductDetails? _product;
  bool _available = false;
  bool _loading = false;
  String? _errorMessage;

  bool get available => _available;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  /// Called when a purchase or restore succeeds.
  VoidCallback? onPremiumUnlocked;

  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        _errorMessage = e.toString();
        notifyListeners();
      },
    );

    final response = await _iap.queryProductDetails({kPremiumProductId});
    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.first;
    }
    notifyListeners();
  }

  Future<void> buyPremium() async {
    if (_product == null || _loading) return;
    _setLoading(true);
    final param = PurchaseParam(productDetails: _product!);
    await _iap.buyNonConsumable(purchaseParam: param);
    // Loading is cleared in _onPurchaseUpdate.
  }

  Future<void> restorePurchases() async {
    if (_loading) return;
    _setLoading(true);
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != kPremiumProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          onPremiumUnlocked?.call();
          _setLoading(false);
        case PurchaseStatus.error:
          _errorMessage = purchase.error?.message;
          _setLoading(false);
        case PurchaseStatus.canceled:
          _setLoading(false);
        case PurchaseStatus.pending:
          // Still processing — keep loading state.
          break;
      }
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
