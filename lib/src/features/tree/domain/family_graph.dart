import '../../members/domain/member.dart';
import '../../members/domain/relationship.dart';

/// An in-memory graph view over a family's members and relationship edges.
///
/// Builds parent/child/spouse adjacency and assigns each member a generation
/// depth (0 = oldest ancestors). Shared by the stats dashboard and the visual
/// tree layout so both agree on structure.
class FamilyGraph {
  FamilyGraph._({
    required this.members,
    required this.byId,
    required this.childrenOf,
    required this.parentsOf,
    required this.spousesOf,
    required this.depthOf,
  });

  final List<Member> members;
  final Map<String, Member> byId;

  /// parentId -> child ids.
  final Map<String, List<String>> childrenOf;

  /// childId -> parent ids.
  final Map<String, List<String>> parentsOf;

  /// memberId -> spouse/partner ids.
  final Map<String, List<String>> spousesOf;

  /// memberId -> generation depth (0 = topmost ancestors).
  final Map<String, int> depthOf;

  int get generationCount =>
      depthOf.isEmpty ? 0 : (depthOf.values.reduce((a, b) => a > b ? a : b) + 1);

  factory FamilyGraph.build(
    List<Member> members,
    List<Relationship> relationships,
  ) {
    final byId = {for (final m in members) m.id: m};
    final childrenOf = <String, List<String>>{};
    final parentsOf = <String, List<String>>{};
    final spousesOf = <String, List<String>>{};

    for (final r in relationships) {
      // Skip edges that reference members not in this family snapshot.
      if (!byId.containsKey(r.fromMember) || !byId.containsKey(r.toMember)) {
        continue;
      }
      if (r.isParentChild) {
        childrenOf.putIfAbsent(r.fromMember, () => []).add(r.toMember);
        parentsOf.putIfAbsent(r.toMember, () => []).add(r.fromMember);
      } else if (r.isUnion) {
        spousesOf.putIfAbsent(r.fromMember, () => []).add(r.toMember);
        spousesOf.putIfAbsent(r.toMember, () => []).add(r.fromMember);
      }
    }

    final depthOf = _computeDepths(members, childrenOf, parentsOf);

    return FamilyGraph._(
      members: members,
      byId: byId,
      childrenOf: childrenOf,
      parentsOf: parentsOf,
      spousesOf: spousesOf,
      depthOf: depthOf,
    );
  }

  /// Longest-path depth from roots (members with no parents). Guards against
  /// accidental cycles with a visited set so it always terminates.
  static Map<String, int> _computeDepths(
    List<Member> members,
    Map<String, List<String>> childrenOf,
    Map<String, List<String>> parentsOf,
  ) {
    final depth = {for (final m in members) m.id: 0};

    final roots = members
        .where((m) => (parentsOf[m.id] ?? const []).isEmpty)
        .map((m) => m.id)
        .toList();

    final queue = <String>[...roots];
    final visits = <String, int>{};
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      // Cap re-processing per node to avoid infinite loops on bad data.
      final count = (visits[id] ?? 0) + 1;
      visits[id] = count;
      if (count > members.length + 1) continue;

      for (final child in childrenOf[id] ?? const <String>[]) {
        final candidate = depth[id]! + 1;
        if (candidate > (depth[child] ?? 0)) {
          depth[child] = candidate;
          queue.add(child);
        }
      }
    }
    return depth;
  }
}
