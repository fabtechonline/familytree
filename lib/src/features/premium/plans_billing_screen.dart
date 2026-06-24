import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/supabase_providers.dart';
import '../../theme/app_theme.dart';
import '../family/application/family_providers.dart';
import '../family/domain/family.dart';
import '../members/application/member_providers.dart';
import 'data/iap_service.dart';

/// In-app plans screen: buys via Google Play / Apple IAP, verifies server-side,
/// restores purchases, and deep-links to the store for cancellation.
class PlansBillingScreen extends ConsumerStatefulWidget {
  const PlansBillingScreen({super.key});

  @override
  ConsumerState<PlansBillingScreen> createState() => _PlansBillingScreenState();
}

class _PlansBillingScreenState extends ConsumerState<PlansBillingScreen> {
  late final IapService _iap;
  bool _loading = true;
  bool _busy = false;

  static const _order = ['premium_monthly', 'premium_yearly', 'lifetime'];

  @override
  void initState() {
    super.initState();
    _iap = IapService(ref.read(supabaseClientProvider));
    _iap.onResult = (ok, msg) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      if (ok) {
        final fam = ref.read(currentFamilyProvider);
        if (fam != null) invalidateFamilyData(ref, fam.id);
        ref.invalidate(myFamiliesProvider);
      }
    };
    _init();
  }

  Future<void> _init() async {
    await _iap.init();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _iap.dispose();
    super.dispose();
  }

  Future<void> _buy(String productId, String familyId) async {
    final p = _iap.product(productId);
    if (p == null) return;
    setState(() => _busy = true);
    await _iap.buy(p, familyId);
  }

  Future<void> _manage() async {
    final url = Platform.isIOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    final isPremium = family?.subscriptionTier == SubscriptionTier.premium;
    final isAdmin = family?.myRole.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Plans & billing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
              children: [
                Text(isPremium ? 'You’re on Premium 🎉' : 'You’re on the Free plan',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    isPremium
                        ? 'Thanks for supporting Riza.'
                        : 'Upgrade for unlimited members, Point & Recognize and AI avatars.',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: AppSpacing.lg),

                if (!isAdmin)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('Only the family admin can change the plan.'),
                    ),
                  )
                else if (!_iap.available || _iap.products.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.store_mall_directory_outlined),
                      title: Text('Plans aren’t available yet'),
                      subtitle: Text(
                          'In-app purchases aren’t set up on this device/store yet.'),
                    ),
                  )
                else
                  for (final id in _order)
                    if (_iap.product(id) != null)
                      _PlanCard(
                        product: _iap.product(id)!,
                        busy: _busy,
                        onBuy: family == null ? null : () => _buy(id, family.id),
                      ),

                const SizedBox(height: AppSpacing.md),
                if (isAdmin && _iap.available)
                  OutlinedButton.icon(
                    onPressed: _busy || family == null
                        ? null
                        : () => _iap.restore(family.id),
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore purchases'),
                  ),
                if (isPremium)
                  TextButton.icon(
                    onPressed: _manage,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Manage / cancel subscription'),
                  ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => launchUrl(
                      Uri.parse('https://www.riza.co.za/cancellation'),
                      mode: LaunchMode.externalApplication),
                  child: const Text('Cancellation policy'),
                ),
              ],
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.product, required this.busy, this.onBuy});
  final ProductDetails product;
  final bool busy;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title.replaceAll(RegExp(r'\(.*\)'), '').trim(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(product.price,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            FilledButton(
              onPressed: busy ? null : onBuy,
              child: const Text('Choose'),
            ),
          ],
        ),
      ),
    );
  }
}
