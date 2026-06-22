import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tree/application/tree_providers.dart';
import '../tree/domain/family_graph.dart';

/// Fun aggregate "family DNA" facts derived from the tree.
class FamilyInsights {
  const FamilyInsights({
    required this.totalPeople,
    required this.generations,
    required this.averageLifespan,
    required this.oldestLivingName,
    required this.oldestLivingAge,
    required this.commonSurname,
    required this.commonFirstName,
    required this.largestGeneration,
    required this.birthplaceCount,
    required this.averageChildren,
  });

  final int totalPeople;
  final int generations;
  final int? averageLifespan;
  final String? oldestLivingName;
  final int? oldestLivingAge;
  final String? commonSurname;
  final String? commonFirstName;
  final int largestGeneration;
  final int birthplaceCount;
  final double? averageChildren;

  factory FamilyInsights.fromGraph(FamilyGraph g) {
    final now = DateTime.now();

    // Average lifespan from members with both birth and death dates.
    final lifespans = <int>[];
    for (final m in g.members) {
      if (m.birthDate != null && m.deathDate != null) {
        lifespans.add(m.deathDate!.year - m.birthDate!.year);
      }
    }
    final avgLife = lifespans.isEmpty
        ? null
        : (lifespans.reduce((a, b) => a + b) / lifespans.length).round();

    // Oldest living member.
    String? oldestName;
    int? oldestAge;
    DateTime? oldestBirth;
    for (final m in g.members) {
      if (m.isLiving && m.birthDate != null) {
        if (oldestBirth == null || m.birthDate!.isBefore(oldestBirth)) {
          oldestBirth = m.birthDate;
          oldestName = m.fullName;
          oldestAge = now.year - m.birthDate!.year;
        }
      }
    }

    String? mode(Iterable<String> values) {
      final counts = <String, int>{};
      for (final v in values) {
        final key = v.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      if (counts.isEmpty) return null;
      return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    final commonSurname = mode(g.members.map((m) => m.lastName ?? ''));
    final commonFirst = mode(g.members.map((m) => m.firstName));

    // Largest generation.
    final perGen = <int, int>{};
    for (final d in g.depthOf.values) {
      perGen[d] = (perGen[d] ?? 0) + 1;
    }
    final largestGen =
        perGen.values.isEmpty ? 0 : perGen.values.reduce((a, b) => a > b ? a : b);

    final birthplaces = g.members
        .map((m) => (m.birthPlace ?? '').trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet()
        .length;

    final childCounts = g.childrenOf.values.map((c) => c.length).toList();
    final avgChildren = childCounts.isEmpty
        ? null
        : childCounts.reduce((a, b) => a + b) / childCounts.length;

    return FamilyInsights(
      totalPeople: g.members.length,
      generations: g.generationCount,
      averageLifespan: avgLife,
      oldestLivingName: oldestName,
      oldestLivingAge: oldestAge,
      commonSurname: commonSurname,
      commonFirstName: commonFirst,
      largestGeneration: largestGen,
      birthplaceCount: birthplaces,
      averageChildren: avgChildren,
    );
  }
}

final familyInsightsProvider =
    FutureProvider.family<FamilyInsights, String>((ref, familyId) async {
  final graph = await ref.watch(familyGraphProvider(familyId).future);
  return FamilyInsights.fromGraph(graph);
});
