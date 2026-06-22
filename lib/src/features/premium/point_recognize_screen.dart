import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'paywall_screen.dart';

/// Premium "Point & Recognize" face lens. Gated behind Premium; the recognition
/// engine itself is set up in a follow-up (pending the on-device vs cloud
/// decision and biometric-consent sign-off).
class PointRecognizeScreen extends ConsumerWidget {
  const PointRecognizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    if (!isPremium) {
      return const PaywallScreen(
        feature: 'Point & Recognize',
        blurb:
            'Aim your camera at a relative and the app recognises them from your tree.',
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Point & Recognize')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.center_focus_strong_rounded,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text('Almost ready',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The face-recognition engine is being set up. It runs on-device, '
                'is strictly opt-in, and only ever matches within your own family.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
