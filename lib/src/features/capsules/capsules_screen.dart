import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../family/application/family_providers.dart';
import '../family/domain/family.dart';
import 'capsule_repository.dart';

/// Legacy capsules: messages to the future, sealed until their unlock date.
class CapsulesScreen extends ConsumerWidget {
  const CapsulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final capsules = ref.watch(capsulesProvider(family.id));
    final canCreate = family.myRole != FamilyRole.viewer;

    return Scaffold(
      appBar: AppBar(title: const Text('Legacy capsules')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _compose(context, ref, family.id),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Seal a capsule'),
            )
          : null,
      body: capsules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (items) {
          if (items.isEmpty) return const _Empty();
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
                AppSpacing.md, 96 + MediaQuery.paddingOf(context).bottom),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => _CapsuleCard(capsule: items[i]),
          );
        },
      ),
    );
  }

  Future<void> _compose(
      BuildContext context, WidgetRef ref, String familyId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ComposeCapsule(familyId: familyId),
    );
  }
}

class _ComposeCapsule extends ConsumerStatefulWidget {
  const _ComposeCapsule({required this.familyId});
  final String familyId;

  @override
  ConsumerState<_ComposeCapsule> createState() => _ComposeCapsuleState();
}

class _ComposeCapsuleState extends ConsumerState<_ComposeCapsule> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime _unlock = DateTime.now().add(const Duration(days: 365));
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _unlock,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 100),
    );
    if (picked != null) setState(() => _unlock = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(capsuleRepositoryProvider).create(
            familyId: widget.familyId,
            title: _title.text.trim(),
            body: _body.text.trim().isEmpty ? null : _body.text.trim(),
            unlockAt: _unlock,
          );
      ref.invalidate(capsulesProvider(widget.familyId));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not seal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _body,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Your message to the future',
                alignLabelWithHint: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_clock_rounded),
            title: const Text('Unlocks on'),
            subtitle: Text(
                '${_unlock.year}-${_unlock.month.toString().padLeft(2, '0')}-${_unlock.day.toString().padLeft(2, '0')}'),
            trailing: TextButton(onPressed: _pickDate, child: const Text('Change')),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Seal capsule'),
          ),
        ],
      ),
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard({required this.capsule});
  final Capsule capsule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        '${capsule.unlockAt.year}-${capsule.unlockAt.month.toString().padLeft(2, '0')}-${capsule.unlockAt.day.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(capsule.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: capsule.locked
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(capsule.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  if (capsule.locked)
                    Text('Sealed until $dateStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant))
                  else ...[
                    if ((capsule.body ?? '').isNotEmpty)
                      Text(capsule.body!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Opened $dateStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_clock_rounded,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text('No capsules yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Seal a message to be opened by the family in the future.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
