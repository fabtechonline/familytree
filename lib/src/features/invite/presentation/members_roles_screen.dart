import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/supabase_providers.dart';
import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../data/invite_repository.dart';
import '../domain/invite_models.dart';

/// Admin screen to manage who belongs to the family and their roles.
class MembersRolesScreen extends ConsumerWidget {
  const MembersRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final roster = ref.watch(rosterProvider(family.id));
    final myId = ref.watch(currentSessionProvider)?.user.id;
    final iAmAdmin = family.myRole.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members & roles'),
        actions: [
          if (iAmAdmin)
            IconButton(
              tooltip: 'Invite',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => context.push('/invite'),
            ),
        ],
      ),
      body: roster.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load members: $e')),
        data: (members) => ListView.separated(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
              AppSpacing.md, AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
          itemCount: members.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) {
            final m = members[i];
            return _RosterTile(
              member: m,
              isSelf: m.userId == myId,
              canManage: iAmAdmin && m.userId != myId,
              onRoleChanged: (role) async {
                await ref
                    .read(inviteRepositoryProvider)
                    .setMemberRole(family.id, m.userId, role);
                ref.invalidate(rosterProvider(family.id));
              },
              onRemove: () => _confirmRemove(context, ref, family, m),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref,
      Family family, RosterMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${m.label}?'),
        content: const Text(
            'They will lose access to this family. They can re-join with a new invite.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(inviteRepositoryProvider).removeMember(family.id, m.userId);
    ref.invalidate(rosterProvider(family.id));
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({
    required this.member,
    required this.isSelf,
    required this.canManage,
    required this.onRoleChanged,
    required this.onRemove,
  });

  final RosterMember member;
  final bool isSelf;
  final bool canManage;
  final ValueChanged<FamilyRole> onRoleChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Text(member.initials,
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.label + (isSelf ? ' (you)' : ''),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  if ((member.email ?? '').isNotEmpty)
                    Text(member.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (canManage) ...[
              DropdownButton<FamilyRole>(
                value: member.role,
                underline: const SizedBox.shrink(),
                onChanged: (role) {
                  if (role != null) onRoleChanged(role);
                },
                items: FamilyRole.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_label(r)),
                        ))
                    .toList(),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.person_remove_rounded, size: 20),
                onPressed: onRemove,
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Chip(
                  label: Text(_label(member.role)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _label(FamilyRole r) =>
      r.name[0].toUpperCase() + r.name.substring(1);
}
