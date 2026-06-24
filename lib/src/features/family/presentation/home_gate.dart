import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/data/admin_repository.dart';
import '../../../admin/presentation/admin_home_screen.dart';
import '../../settings/app_settings_provider.dart';
import '../../auth/application/account_status_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../application/family_providers.dart';
import 'create_family_screen.dart';
import 'family_dashboard_screen.dart';

/// Entry screen for signed-in users. Decides between onboarding (no families
/// yet) and the family dashboard, reacting to the loaded family list.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Blocked/suspended accounts can't use the app.
    final status = ref.watch(accountStatusProvider).value;
    if (status == 'blocked' || status == 'suspended') {
      return _BlockedScreen(status: status!);
    }

    // Maintenance mode blocks the app for everyone except super-admins.
    final settings = ref.watch(publicSettingsProvider).value;
    final isSuper = ref.watch(isSuperAdminProvider).value ?? false;
    if (settings != null && settings.maintenanceEnabled && !isSuper) {
      return _MaintenanceScreen(message: settings.maintenanceMessage);
    }

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
      data: (families) {
        if (families.isNotEmpty) return const FamilyDashboardScreen();
        // No families yet: super-admins go straight to the platform console;
        // everyone else is onboarded to create their first family.
        return ref.watch(isSuperAdminProvider).when(
              loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator())),
              error: (_, _) => const CreateFamilyScreen(isFirstFamily: true),
              data: (isSuper) => isSuper
                  ? const AdminHomeScreen()
                  : const CreateFamilyScreen(isFirstFamily: true),
            );
      },
    );
  }
}

/// Shown when the platform is in maintenance mode.
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_rounded, size: 56),
              const SizedBox(height: 16),
              Text('We’ll be right back',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  message.isEmpty
                      ? 'Riza is undergoing maintenance. Please check back shortly.'
                      : message,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when an account has been blocked or suspended by the platform admin.
class _BlockedScreen extends ConsumerWidget {
  const _BlockedScreen({required this.status});
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_person_rounded,
                  size: 56, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                status == 'suspended'
                    ? 'Your account is suspended'
                    : 'Your account has been blocked',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('Please contact support if you believe this is a mistake.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
