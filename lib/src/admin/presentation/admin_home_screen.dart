import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_repository.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.dashboard_rounded, label: 'Overview'),
    (icon: Icons.people_alt_rounded, label: 'Accounts'),
    (icon: Icons.diversity_3_rounded, label: 'Families'),
    (icon: Icons.receipt_long_rounded, label: 'Audit log'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width > 900,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.shield_moon_rounded,
                  color: theme.colorScheme.primary),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: () =>
                        ref.read(adminRepositoryProvider).signOut(),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                    icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                _OverviewSection(),
                _AccountsSection(),
                _FamiliesSection(),
                _AuditSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
          child: Text(title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: child,
          ),
        ),
      ],
    );
  }
}

// ---- Overview ---------------------------------------------------------------

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    return _SectionScaffold(
      title: 'Overview',
      child: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (s) => Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
                label: 'Total users',
                value: '${s.totalUsers}',
                icon: Icons.people_alt_rounded),
            _StatCard(
                label: 'Families',
                value: '${s.totalFamilies}',
                icon: Icons.diversity_3_rounded),
            _StatCard(
                label: 'Premium families',
                value: '${s.premiumFamilies}',
                icon: Icons.workspace_premium_rounded),
            _StatCard(
                label: 'Blocked users',
                value: '${s.blockedUsers}',
                icon: Icons.block_rounded),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(value,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Accounts ---------------------------------------------------------------

class _AccountsSection extends ConsumerStatefulWidget {
  const _AccountsSection();

  @override
  ConsumerState<_AccountsSection> createState() => _AccountsSectionState();
}

class _AccountsSectionState extends ConsumerState<_AccountsSection> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _action(Account a, String action) async {
    final repo = ref.read(adminRepositoryProvider);
    try {
      switch (action) {
        case 'active':
        case 'suspended':
        case 'blocked':
          await repo.setStatus(a.id, action);
          ref.invalidate(adminAccountsProvider(_search));
          ref.invalidate(adminStatsProvider);
        case 'reset':
          if (a.email != null) await repo.sendPasswordReset(a.email!);
          _snack('Password reset email sent to ${a.email}');
      }
    } catch (e) {
      _snack('Action failed: $e');
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(adminAccountsProvider(_search));
    return _SectionScaffold(
      title: 'Accounts',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by email or name',
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        }),
              ),
              onSubmitted: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: accounts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => ListView.separated(
                itemCount: list.length,
                itemBuilder: (context, i) =>
                    _AccountTile(account: list[i], onAction: _action),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.onAction});
  final Account account;
  final Future<void> Function(Account, String) onAction;

  Color _statusColor(BuildContext context) {
    switch (account.status) {
      case 'blocked':
        return Theme.of(context).colorScheme.error;
      case 'suspended':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          child: Text(
            account.label.isNotEmpty ? account.label[0].toUpperCase() : '?',
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800),
          ),
        ),
        title: Row(
          children: [
            Flexible(
                child: Text(account.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            if (account.isSuperAdmin) ...[
              const SizedBox(width: 8),
              const Chip(
                  label: Text('Admin'), visualDensity: VisualDensity.compact),
            ],
          ],
        ),
        subtitle: Text(account.email ?? account.id),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(account.status,
                  style: TextStyle(
                      color: _statusColor(context),
                      fontWeight: FontWeight.w600)),
            ),
            PopupMenuButton<String>(
              enabled: !account.isSuperAdmin,
              onSelected: (v) => onAction(account, v),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'active', child: Text('Activate')),
                PopupMenuItem(value: 'suspended', child: Text('Suspend')),
                PopupMenuItem(value: 'blocked', child: Text('Block')),
                PopupMenuDivider(),
                PopupMenuItem(
                    value: 'reset', child: Text('Send password reset')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Families ---------------------------------------------------------------

class _FamiliesSection extends ConsumerWidget {
  const _FamiliesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final families = ref.watch(adminFamiliesProvider);
    return _SectionScaffold(
      title: 'Families & subscriptions',
      child: families.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final f = list[i];
            final isPremium = f.tier == 'premium';
            return Card(
              child: ListTile(
                title: Text(f.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${f.personCount} ${f.personCount == 1 ? 'person' : 'people'} in tree  ·  '
                    '${f.userCount} ${f.userCount == 1 ? 'user' : 'users'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isPremium ? 'Premium' : 'Free'),
                    Switch(
                      value: isPremium,
                      onChanged: (v) async {
                        await ref.read(adminRepositoryProvider).setSubscription(
                            f.id, v ? 'premium' : 'free');
                        ref.invalidate(adminFamiliesProvider);
                        ref.invalidate(adminStatsProvider);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---- Audit ------------------------------------------------------------------

class _AuditSection extends ConsumerWidget {
  const _AuditSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(adminAuditProvider);
    return _SectionScaffold(
      title: 'Audit log',
      child: audit.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No audit entries yet.'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = list[i];
                  return ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(e.action),
                    subtitle: Text(
                        '${e.metadata}  ·  ${e.createdAt.toLocal()}'),
                  );
                },
              ),
      ),
    );
  }
}
