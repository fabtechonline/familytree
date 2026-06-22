import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../members/application/member_providers.dart';
import '../../members/domain/member.dart';
import '../../members/presentation/widgets/member_avatar.dart';
import '../../celebrations/celebrations.dart';
import '../../celebrations/presentation/celebrations_screen.dart';
import '../../suggestions/data/suggestion_repository.dart';
import '../../tree/application/tree_providers.dart';
import '../application/family_providers.dart';
import '../application/realtime_provider.dart';
import '../domain/family.dart';

/// The signed-in landing screen for a family: stats, members, and entry to the
/// visual tree. Replaces the Phase 0 placeholder home.
class FamilyDashboardScreen extends ConsumerWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    // Keep a live Realtime subscription open while the dashboard is visible so
    // changes from other relatives appear without a manual refresh.
    ref.watch(familyRealtimeProvider(family.id));
    final membersAsync = ref.watch(membersProvider(family.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(family.name),
        actions: [
          if (family.subscriptionTier == SubscriptionTier.premium)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.workspace_premium_rounded),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'signout':
                  ref.read(authRepositoryProvider).signOut();
                case 'new-family':
                  context.push('/create-family');
                case 'join-family':
                  context.push('/join');
                case 'invite':
                  context.push('/invite');
                case 'members-roles':
                  context.push('/members-roles');
                case 'suggestions':
                  context.push('/suggestions');
              }
            },
            itemBuilder: (context) => [
              if (family.myRole.isAdmin) ...[
                const PopupMenuItem(
                    value: 'invite', child: Text('Invite family')),
                const PopupMenuItem(
                    value: 'members-roles', child: Text('Members & roles')),
                const PopupMenuItem(
                    value: 'suggestions', child: Text('Suggestions')),
              ],
              const PopupMenuItem(
                  value: 'join-family', child: Text('Join a family')),
              const PopupMenuItem(value: 'new-family', child: Text('New family')),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      floatingActionButton: (family.myRole.canEdit ||
              family.myRole == FamilyRole.contributor)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/member/new'),
              icon: Icon(family.myRole.canEdit
                  ? Icons.person_add_alt_1_rounded
                  : Icons.edit_note_rounded),
              label: Text(
                  family.myRole.canEdit ? 'Add member' : 'Suggest member'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => invalidateFamilyData(ref, family.id),
        child: ListView(
          // Bottom padding leaves room for the FAB and the device nav bar so
          // the last member isn't hidden behind them.
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
              AppSpacing.md, 96 + MediaQuery.paddingOf(context).bottom),
          children: [
            if (family.myRole.isAdmin) _SuggestionsBanner(familyId: family.id),
            _StatsSection(familyId: family.id),
            const SizedBox(height: AppSpacing.md),
            _ViewTreeCard(onTap: () => context.push('/tree')),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _QuickLinkCard(
                    icon: Icons.cake_rounded,
                    label: 'Celebrations',
                    onTap: () => context.push('/celebrations'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _QuickLinkCard(
                    icon: Icons.campaign_rounded,
                    label: 'Family feed',
                    onTap: () => context.push('/feed'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _UpcomingCelebrations(familyId: family.id),
            const SizedBox(height: AppSpacing.lg),
            Text('Members',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load members: $e'),
              ),
              data: (members) => members.isEmpty
                  ? _EmptyMembers(canEdit: family.myRole.canEdit)
                  : _MembersList(members: members),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(familyStatsProvider(familyId));
    return stats.when(
      loading: () => const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.4,
        children: [
          _StatCard(
              icon: Icons.groups_rounded,
              label: 'Members',
              value: '${s.totalMembers}'),
          _StatCard(
              icon: Icons.layers_rounded,
              label: 'Generations',
              value: '${s.generations}'),
          _StatCard(
              icon: Icons.favorite_rounded,
              label: 'Living',
              value: '${s.living}'),
          _StatCard(
              icon: Icons.history_edu_rounded,
              label: 'Ancestors',
              value: '${s.ancestors}'),
        ],
      ),
    );
  }
}

class _SuggestionsBanner extends ConsumerWidget {
  const _SuggestionsBanner({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSuggestionsProvider(familyId)).value ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        child: ListTile(
          onTap: () => context.push('/suggestions'),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: Text('${pending.length}',
                style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800)),
          ),
          title: Text(
              '${pending.length} suggestion${pending.length == 1 ? '' : 's'} to review',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Tap to approve or reject'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(label,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewTreeCard extends StatelessWidget {
  const _ViewTreeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.account_tree_rounded,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('View family tree',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text('See everyone connected, visually',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  const _QuickLinkCard(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCelebrations extends ConsumerWidget {
  const _UpcomingCelebrations({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(upcomingCelebrationsProvider(familyId)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final top = items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Upcoming celebrations',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            if (items.length > 3)
              TextButton(
                  onPressed: () => context.push('/celebrations'),
                  child: const Text('See all')),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final c in top) CelebrationTile(celebration: c),
      ],
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.members});
  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final m in members)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              onTap: () => context.push('/profile/${m.id}'),
              leading: MemberAvatar(member: m),
              title: Text(m.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_subtitle(m)),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
      ],
    );
  }

  String _subtitle(Member m) {
    final parts = <String>[];
    if (m.birthYear != null) {
      parts.add(m.isLiving ? 'b. ${m.birthYear}' : '${m.birthYear}');
    }
    if (!m.isLiving && m.deathDate != null) {
      parts.add('d. ${m.deathDate!.year}');
    }
    if (!m.isLiving && parts.isEmpty) parts.add('Deceased');
    return parts.join(' · ');
  }
}

class _EmptyMembers extends StatelessWidget {
  const _EmptyMembers({required this.canEdit});
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(Icons.person_search_rounded,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text('No members yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              canEdit
                  ? 'Tap “Add member” to add the first person to your tree.'
                  : 'Members will appear here once an editor adds them.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
