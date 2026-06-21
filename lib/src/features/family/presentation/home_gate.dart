import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/family_providers.dart';
import 'create_family_screen.dart';
import 'family_dashboard_screen.dart';

/// Entry screen for signed-in users. Decides between onboarding (no families
/// yet) and the family dashboard, reacting to the loaded family list.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final families = ref.watch(myFamiliesProvider);

    return families.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: 12),
                Text('Could not load your families.\n$e',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(myFamiliesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (families) => families.isEmpty
          ? const CreateFamilyScreen(isFirstFamily: true)
          : const FamilyDashboardScreen(),
    );
  }
}
