import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';

/// First screen for visitors who aren't signed in: a warm welcome with what the
/// app does and a single "Get started" call to action (sign-in/registration use
/// the same 6-digit OTP flow). Returning users with a saved session skip this.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.seed.withValues(alpha: 0.12),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 110,
                      width: 110,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.seed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.park_rounded,
                          size: 64, color: AppColors.seed),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('FamilyTree',
                        style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.seed)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Grow your family’s story together — beautifully.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _Highlight(
                      icon: Icons.account_tree_rounded,
                      title: 'Build a living tree',
                      subtitle: 'Add relatives with photos and watch it grow.',
                    ),
                    const _Highlight(
                      icon: Icons.group_add_rounded,
                      title: 'Invite the whole family',
                      subtitle: 'Everyone helps keep it up to date, together.',
                    ),
                    const _Highlight(
                      icon: Icons.cake_rounded,
                      title: 'Never miss a moment',
                      subtitle: 'Birthday & anniversary reminders, family feed.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: () => context.push('/register'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54)),
                      child: const Text('Create an account'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => context.push('/sign-in'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54)),
                      child: const Text('I already have an account'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Sign in with your password, or get a 6-digit email code.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
