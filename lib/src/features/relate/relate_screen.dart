import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../family/application/family_providers.dart';
import '../members/domain/member.dart';
import '../members/presentation/widgets/member_avatar.dart';
import '../tree/application/tree_providers.dart';
import '../tree/domain/family_graph.dart';
import 'kinship.dart';

/// "How am I related?" — pick two people and see their relationship.
class RelateScreen extends ConsumerStatefulWidget {
  const RelateScreen({super.key});

  @override
  ConsumerState<RelateScreen> createState() => _RelateScreenState();
}

class _RelateScreenState extends ConsumerState<RelateScreen> {
  String? _aId;
  String? _bId;

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final graphAsync = ref.watch(familyGraphProvider(family.id));

    return Scaffold(
      appBar: AppBar(title: const Text('How am I related?')),
      body: graphAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (graph) {
          final members = [...graph.members]
            ..sort((a, b) => a.fullName.compareTo(b.fullName));
          if (members.length < 2) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Add at least two related people to compare.',
                  textAlign: TextAlign.center),
            ));
          }
          _aId ??= members.first.id;
          _bId ??= members.length > 1 ? members[1].id : members.first.id;

          return ListView(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                AppSpacing.lg, AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
            children: [
              _PersonPicker(
                label: 'Person',
                members: members,
                selectedId: _aId,
                onChanged: (id) => setState(() => _aId = id),
              ),
              const SizedBox(height: AppSpacing.md),
              _PersonPicker(
                label: 'is the … of',
                members: members,
                selectedId: _bId,
                onChanged: (id) => setState(() => _bId = id),
              ),
              const SizedBox(height: AppSpacing.xl),
              _ResultCard(graph: graph, aId: _aId!, bId: _bId!),
            ],
          );
        },
      ),
    );
  }
}

class _PersonPicker extends StatelessWidget {
  const _PersonPicker({
    required this.label,
    required this.members,
    required this.selectedId,
    required this.onChanged,
  });
  final String label;
  final List<Member> members;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: members
          .map((m) => DropdownMenuItem(
                value: m.id,
                child: Text(m.fullName, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(
      {required this.graph, required this.aId, required this.bId});
  final FamilyGraph graph;
  final String aId;
  final String bId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = graph.byId[aId];
    final b = graph.byId[bId];
    if (a == null || b == null) return const SizedBox.shrink();
    final k = computeKinship(graph, aId, bId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Face(member: b),
                Icon(Icons.swap_horiz_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
                _Face(member: a),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey('$aId-$bId-${k.label}'),
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${b.firstName} is '),
                      TextSpan(
                        text: k.related ? k.label : k.label,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: k.related
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant),
                      ),
                      if (k.related && k.label != 'the same person')
                        TextSpan(text: ' of ${a.firstName}.'),
                    ]),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          MemberAvatar(member: member, radius: 34),
          const SizedBox(height: 6),
          Text(member.firstName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
