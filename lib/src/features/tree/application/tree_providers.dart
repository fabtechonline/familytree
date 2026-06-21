import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../members/application/member_providers.dart';
import '../domain/family_graph.dart';

/// Builds the [FamilyGraph] for a family by combining its members and
/// relationship edges. Shared by the dashboard stats and the tree view.
final familyGraphProvider =
    FutureProvider.family<FamilyGraph, String>((ref, familyId) async {
  final members = await ref.watch(membersProvider(familyId).future);
  final relationships =
      await ref.watch(relationshipsProvider(familyId).future);
  return FamilyGraph.build(members, relationships);
});

/// Aggregate counts shown on the dashboard.
class FamilyStats {
  const FamilyStats({
    required this.totalMembers,
    required this.living,
    required this.ancestors,
    required this.generations,
    required this.surnames,
  });

  final int totalMembers;
  final int living;
  final int ancestors;
  final int generations;
  final int surnames;

  factory FamilyStats.fromGraph(FamilyGraph graph) {
    final living = graph.members.where((m) => m.isLiving).length;
    final surnames = graph.members
        .map((m) => (m.lastName ?? '').trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .length;
    return FamilyStats(
      totalMembers: graph.members.length,
      living: living,
      ancestors: graph.members.length - living,
      generations: graph.generationCount,
      surnames: surnames,
    );
  }
}

final familyStatsProvider =
    FutureProvider.family<FamilyStats, String>((ref, familyId) async {
  final graph = await ref.watch(familyGraphProvider(familyId).future);
  return FamilyStats.fromGraph(graph);
});
