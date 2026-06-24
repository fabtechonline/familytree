import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Store product IDs — must match the products configured in Google Play Console
/// and App Store Connect.
const kIapProductIds = {'premium_monthly', 'premium_yearly', 'lifetime'};

/// Wraps `in_app_purchase` for both Google Play and Apple: queries products,
/// starts purchases, and verifies completed purchases server-side via the
/// `iap-verify` edge function (which updates the family's billing + tier).
class IapService {
  IapService(this._client);
  final SupabaseClient _client;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  String? _pendingFamilyId;

  bool available = false;
  List<ProductDetails> products = [];

  /// Invoked after each finished purchase: (ok, message).
  void Function(bool ok, String message)? onResult;

  Future<void> init() async {
    available = await _iap.isAvailable();
    if (!available) return;
    _sub = _iap.purchaseStream.listen(_onPurchases,
        onError: (Object e) => onResult?.call(false, '$e'));
    final resp = await _iap.queryProductDetails(kIapProductIds);
    products = resp.productDetails;
  }

  ProductDetails? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> buy(ProductDetails product, String familyId) async {
    _pendingFamilyId = familyId;
    // Subscriptions and the non-consumable lifetime both go through
    // buyNonConsumable on this plugin.
    await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> restore(String familyId) async {
    _pendingFamilyId = familyId;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.pending) continue;
      if (p.status == PurchaseStatus.error ||
          p.status == PurchaseStatus.canceled) {
        onResult?.call(false, p.error?.message ?? 'Purchase cancelled');
      } else if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        final ok = await _verify(p);
        onResult?.call(
            ok, ok ? 'Premium activated' : 'Could not verify the purchase');
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  Future<bool> _verify(PurchaseDetails p) async {
    try {
      final res = await _client.functions.invoke('iap-verify', body: {
        'familyId': _pendingFamilyId,
        'productId': p.productID,
        'platform': Platform.isIOS ? 'apple' : 'android',
        'token': p.verificationData.serverVerificationData,
      });
      final data = res.data;
      return data is Map && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _sub?.cancel();
}
