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
    (icon: Icons.sell_rounded, label: 'Plans'),
    (icon: Icons.settings_rounded, label: 'Settings'),
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
                _PlansSection(),
                _SettingsSection(),
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
            return Card(
              child: ListTile(
                title: Row(
                  children: [
                    Flexible(
                        child: Text(f.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (f.isSuspended) ...[
                      const SizedBox(width: 8),
                      const Chip(
                          label: Text('Suspended'),
                          visualDensity: VisualDensity.compact),
                    ],
                  ],
                ),
                subtitle: Text(
                    '${f.personCount} people  ·  ${f.userCount} users  ·  '
                    '${f.planKey.replaceAll('_', ' ')}${f.isComp ? ' (comp)' : ''}'),
                trailing: FilledButton.tonalIcon(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Manage'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _FamilyManageSheet(family: f),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FamilyManageSheet extends ConsumerStatefulWidget {
  const _FamilyManageSheet({required this.family});
  final AdminFamily family;

  @override
  ConsumerState<_FamilyManageSheet> createState() => _FamilyManageSheetState();
}

class _FamilyManageSheetState extends ConsumerState<_FamilyManageSheet> {
  late String _plan = widget.family.planKey;
  late bool _comp = widget.family.isComp;
  final _limit = TextEditingController();
  bool _busy = false;

  static const _plans = ['free', 'premium_monthly', 'premium_yearly', 'lifetime'];

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _run(
      Future<void> Function(AdminRepository) action, String ok) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await action(ref.read(adminRepositoryProvider));
      ref.invalidate(adminFamiliesProvider);
      ref.invalidate(adminStatsProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(ok)));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.family;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(f.name,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const Text('Plan', style: TextStyle(fontWeight: FontWeight.w600)),
          DropdownButton<String>(
            isExpanded: true,
            value: _plan,
            items: [
              for (final p in _plans)
                DropdownMenuItem(value: p, child: Text(p.replaceAll('_', ' '))),
            ],
            onChanged: _busy ? null : (v) => setState(() => _plan = v ?? _plan),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Free / comp (grant at no charge)'),
            value: _comp,
            onChanged: _busy ? null : (v) => setState(() => _comp = v ?? false),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run((r) => r.setFamilyPlan(f.id, _plan, comp: _comp),
                    'Plan updated'),
            child: const Text('Apply plan'),
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Expanded(
                  child: Text('Free-tier member limit (blank = default)')),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(
                    (r) => r.setMemberLimit(
                        f.id,
                        _limit.text.trim().isEmpty
                            ? null
                            : int.tryParse(_limit.text.trim())),
                    'Member limit saved'),
            child: const Text('Save limit'),
          ),
          const Divider(height: 32),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                foregroundColor:
                    f.isSuspended ? null : theme.colorScheme.error),
            onPressed: _busy
                ? null
                : () => _run((r) => r.suspendFamily(f.id, !f.isSuspended),
                    f.isSuspended ? 'Family unsuspended' : 'Family suspended'),
            child: Text(f.isSuspended ? 'Unsuspend access' : 'Suspend access'),
          ),
        ],
      ),
    );
  }
}

// ---- Plans ------------------------------------------------------------------

class _PlansSection extends ConsumerWidget {
  const _PlansSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(adminPlansProvider);
    return _SectionScaffold(
      title: 'Plans & pricing',
      child: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _PlanCard(plan: list[i]),
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard({required this.plan});
  final AdminPlan plan;

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  late final _label = TextEditingController(text: widget.plan.label);
  late final _price =
      TextEditingController(text: (widget.plan.priceCents / 100).toString());
  late final _paystack =
      TextEditingController(text: widget.plan.paystackPlanCode ?? '');
  late final _sku =
      TextEditingController(text: widget.plan.storeProductId ?? '');
  late bool _active = widget.plan.isActive;
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    _price.dispose();
    _paystack.dispose();
    _sku.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cents =
          ((double.tryParse(_price.text.trim()) ?? widget.plan.priceCents / 100) *
                  100)
              .round();
      await ref.read(adminRepositoryProvider).updatePlan(
            widget.plan.key,
            label: _label.text.trim(),
            priceCents: cents,
            interval: widget.plan.interval,
            isActive: _active,
            paystackPlanCode:
                _paystack.text.trim().isEmpty ? null : _paystack.text.trim(),
            storeProductId: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
          );
      ref.invalidate(adminPlansProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Plan saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      '${widget.plan.key.replaceAll('_', ' ')}  ·  ${widget.plan.tier} · ${widget.plan.interval}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Switch(
                    value: _active,
                    onChanged: _busy ? null : (v) => setState(() => _active = v)),
                const Text('Active'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                    width: 220,
                    child: TextField(
                        controller: _label,
                        decoration: const InputDecoration(
                            labelText: 'Label', border: OutlineInputBorder()))),
                SizedBox(
                    width: 140,
                    child: TextField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Price (R)',
                            border: OutlineInputBorder()))),
                SizedBox(
                    width: 220,
                    child: TextField(
                        controller: _paystack,
                        decoration: const InputDecoration(
                            labelText: 'Paystack plan code',
                            border: OutlineInputBorder()))),
                SizedBox(
                    width: 220,
                    child: TextField(
                        controller: _sku,
                        decoration: const InputDecoration(
                            labelText: 'Store product ID',
                            border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                  onPressed: _busy ? null : _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Settings ---------------------------------------------------------------

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminSettingsProvider);
    return _SectionScaffold(
      title: 'App settings',
      child: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          final byKey = {for (final s in list) s.key: s.value};
          Map<String, dynamic> m(String k) {
            final v = byKey[k];
            return (v is Map) ? Map<String, dynamic>.from(v) : <String, dynamic>{};
          }

          final lim = byKey['free_member_limit'];
          return ListView(
            children: [
              _MaintenanceCard(initial: m('maintenance')),
              const SizedBox(height: 12),
              _FeaturesCard(initial: m('features')),
              const SizedBox(height: 12),
              _MapCard(
                  title: 'Paystack',
                  settingKey: 'paystack',
                  initial: m('paystack'),
                  fields: const [
                    ('public_key', 'Public key'),
                    ('mode', 'Mode (test / live)'),
                  ],
                  note: 'The secret key stays a server-side function secret.'),
              const SizedBox(height: 12),
              _MapCard(
                  title: 'Support & announcements',
                  settingKey: 'support',
                  initial: m('support'),
                  fields: const [
                    ('email', 'Support email'),
                    ('announcement', 'Announcement (blank = hidden)'),
                  ]),
              const SizedBox(height: 12),
              _LimitCard(initial: (lim is num) ? lim.toInt() : 50),
            ],
          );
        },
      ),
    );
  }
}

class _SettingShell extends StatelessWidget {
  const _SettingShell({required this.title, required this.children, this.note});
  final String title;
  final List<Widget> children;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(note!,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaveBtn extends StatelessWidget {
  const _SaveBtn({required this.busy, required this.onSave});
  final bool busy;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: FilledButton(
              onPressed: busy ? null : onSave, child: const Text('Save')),
        ),
      );
}

Future<void> _saveSetting(
    WidgetRef ref, BuildContext context, String key, dynamic value) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(adminRepositoryProvider).setSetting(key, value);
    ref.invalidate(adminSettingsProvider);
    messenger.showSnackBar(const SnackBar(content: Text('Saved')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
  }
}

class _MaintenanceCard extends ConsumerStatefulWidget {
  const _MaintenanceCard({required this.initial});
  final Map<String, dynamic> initial;
  @override
  ConsumerState<_MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends ConsumerState<_MaintenanceCard> {
  late bool _enabled = widget.initial['enabled'] == true;
  late final _msg =
      TextEditingController(text: widget.initial['message'] as String? ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingShell(title: 'Maintenance mode', children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enabled'),
        value: _enabled,
        onChanged: _busy ? null : (v) => setState(() => _enabled = v),
      ),
      TextField(
          controller: _msg,
          decoration: const InputDecoration(
              labelText: 'Message', border: OutlineInputBorder())),
      _SaveBtn(
          busy: _busy,
          onSave: () async {
            setState(() => _busy = true);
            await _saveSetting(ref, context, 'maintenance',
                {'enabled': _enabled, 'message': _msg.text.trim()});
            if (mounted) setState(() => _busy = false);
          }),
    ]);
  }
}

class _FeaturesCard extends ConsumerStatefulWidget {
  const _FeaturesCard({required this.initial});
  final Map<String, dynamic> initial;
  @override
  ConsumerState<_FeaturesCard> createState() => _FeaturesCardState();
}

class _FeaturesCardState extends ConsumerState<_FeaturesCard> {
  static const _keys = ['face_recognition', 'ai_avatar', 'data_export'];
  late final Map<String, bool> _vals = {
    for (final k in _keys) k: widget.initial[k] != false
  };
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return _SettingShell(title: 'Premium feature flags', children: [
      for (final k in _keys)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(k.replaceAll('_', ' ')),
          value: _vals[k],
          onChanged:
              _busy ? null : (v) => setState(() => _vals[k] = v ?? false),
        ),
      _SaveBtn(
          busy: _busy,
          onSave: () async {
            setState(() => _busy = true);
            await _saveSetting(ref, context, 'features', _vals);
            if (mounted) setState(() => _busy = false);
          }),
    ]);
  }
}

class _MapCard extends ConsumerStatefulWidget {
  const _MapCard(
      {required this.title,
      required this.settingKey,
      required this.initial,
      required this.fields,
      this.note});
  final String title;
  final String settingKey;
  final Map<String, dynamic> initial;
  final List<(String, String)> fields;
  final String? note;
  @override
  ConsumerState<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends ConsumerState<_MapCard> {
  late final Map<String, TextEditingController> _ctl = {
    for (final f in widget.fields)
      f.$1: TextEditingController(text: widget.initial[f.$1]?.toString() ?? '')
  };
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingShell(title: widget.title, note: widget.note, children: [
      for (final f in widget.fields)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
              controller: _ctl[f.$1],
              decoration: InputDecoration(
                  labelText: f.$2, border: const OutlineInputBorder())),
        ),
      _SaveBtn(
          busy: _busy,
          onSave: () async {
            setState(() => _busy = true);
            final value = {
              for (final e in _ctl.entries) e.key: e.value.text.trim()
            };
            await _saveSetting(ref, context, widget.settingKey, value);
            if (mounted) setState(() => _busy = false);
          }),
    ]);
  }
}

class _LimitCard extends ConsumerStatefulWidget {
  const _LimitCard({required this.initial});
  final int initial;
  @override
  ConsumerState<_LimitCard> createState() => _LimitCardState();
}

class _LimitCardState extends ConsumerState<_LimitCard> {
  late final _ctl = TextEditingController(text: widget.initial.toString());
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingShell(title: 'Default free-tier member limit', children: [
      SizedBox(
        width: 160,
        child: TextField(
            controller: _ctl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder())),
      ),
      _SaveBtn(
          busy: _busy,
          onSave: () async {
            setState(() => _busy = true);
            await _saveSetting(ref, context, 'free_member_limit',
                int.tryParse(_ctl.text.trim()) ?? 50);
            if (mounted) setState(() => _busy = false);
          }),
    ]);
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
