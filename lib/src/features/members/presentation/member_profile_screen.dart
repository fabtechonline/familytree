import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../tree/application/tree_providers.dart';
import '../../tree/domain/family_graph.dart';
import '../domain/member.dart';
import 'widgets/member_avatar.dart';

/// Read-only profile of a member: photo, life details, bio and relationships.
class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final graphAsync = ref.watch(familyGraphProvider(family.id));
    final canChange = family.myRole != FamilyRole.viewer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (canChange)
            TextButton.icon(
              onPressed: () => context.push('/member/$memberId'),
              icon: Icon(family.myRole.canEdit
                  ? Icons.edit_rounded
                  : Icons.edit_note_rounded),
              label: Text(family.myRole.canEdit ? 'Edit' : 'Suggest'),
            ),
        ],
      ),
      body: graphAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (graph) {
          final member = graph.byId[memberId];
          if (member == null) {
            return const Center(child: Text('Member not found.'));
          }
          return _ProfileBody(graph: graph, member: member);
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.graph, required this.member});
  final FamilyGraph graph;
  final Member member;

  List<Member> _members(Iterable<String> ids) =>
      ids.map((id) => graph.byId[id]).whereType<Member>().toList();

  List<Member> get _parents => _members(graph.parentsOf[member.id] ?? const []);
  List<Member> get _children =>
      _members(graph.childrenOf[member.id] ?? const []);
  List<Member> get _spouses => _members(graph.spousesOf[member.id] ?? const []);

  List<Member> get _siblings {
    final sibIds = <String>{};
    for (final parent in graph.parentsOf[member.id] ?? const []) {
      for (final child in graph.childrenOf[parent] ?? const []) {
        if (child != member.id) sibIds.add(child);
      }
    }
    return _members(sibIds);
  }

  String get _lifeLine {
    final b = member.birthYear;
    if (!member.isLiving || member.deathDate != null) {
      final d = member.deathDate?.year;
      return '${b ?? '?'} – ${d ?? '?'}';
    }
    return b == null ? 'Living' : 'Born $b';
  }

  int? get _age {
    if (member.birthDate == null) return null;
    final end = (!member.isLiving && member.deathDate != null)
        ? member.deathDate!
        : DateTime.now();
    var age = end.year - member.birthDate!.year;
    final hadBirthday = (end.month > member.birthDate!.month) ||
        (end.month == member.birthDate!.month &&
            end.day >= member.birthDate!.day);
    if (!hadBirthday) age--;
    return age < 0 ? null : age;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = _age;

    return ListView(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: Column(
            children: [
              MemberAvatar(member: member, radius: 56),
              const SizedBox(height: AppSpacing.md),
              Text(member.fullName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              if ((member.maidenName ?? '').isNotEmpty)
                Text('née ${member.maidenName}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(
                age == null ? _lifeLine : '$_lifeLine  ·  $age yrs',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (!member.isLiving)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Chip(
                    label: const Text('In memoriam'),
                    visualDensity: VisualDensity.compact,
                    avatar: const Text('🕊️'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if ((member.birthPlace ?? '').isNotEmpty)
          _InfoRow(
              icon: Icons.place_outlined, label: 'Born in', value: member.birthPlace!),
        if ((member.bio ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('About',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(member.bio!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.lg),
        _RelationGroup(title: 'Parents', members: _parents),
        _RelationGroup(title: 'Spouse / partner', members: _spouses),
        _RelationGroup(title: 'Children', members: _children),
        _RelationGroup(title: 'Siblings', members: _siblings),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Text('$label ', style: theme.textTheme.bodyMedium),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _RelationGroup extends StatelessWidget {
  const _RelationGroup({required this.title, required this.members});
  final String title;
  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) {
                final m = members[i];
                return InkWell(
                  onTap: () => context.push('/profile/${m.id}'),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        MemberAvatar(member: m, radius: 28),
                        const SizedBox(height: 6),
                        Text(m.firstName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
