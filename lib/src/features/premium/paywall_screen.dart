import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../family/application/family_providers.dart';
import '../family/domain/family.dart';

/// Whether the active family has Premium. Gateway-agnostic: it reads the
/// `subscription_tier` flag, which today the super-admin console can toggle and
/// later a payment provider will set on successful purchase.
final isPremiumProvider = Provider<bool>((ref) {
  final family = ref.watch(currentFamilyProvider);
  return family?.subscriptionTier == SubscriptionTier.premium;
});

/// Shown when a free family taps a premium feature.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.feature, required this.blurb});

  final String feature;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 88,
                  width: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentSun.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      size: 48, color: AppColors.accentSun),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('$feature is a Premium feature',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                Text(blurb,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.lg),
                const _Benefit('🤳', 'Point & Recognize face lens'),
                const _Benefit('🌳', 'Unlimited members & generations'),
                const _Benefit('🖼️', 'More photo storage & memories'),
                const _Benefit('✨', 'Advanced views & exports'),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => context.push('/plans-billing'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: const Text('See plans'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.emoji, this.text);
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
          const Icon(Icons.check_circle_rounded, color: AppColors.seed, size: 20),
        ],
      ),
    );
  }
}
