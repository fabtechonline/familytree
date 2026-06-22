import '../../relate/kinship.dart';
import 'family_graph.dart';

/// The highlight sets for "View lineage" of one person.
///
/// [immediate] highlights parents, siblings, spouse(s) and children. With
/// [full] it extends to all ancestors and all descendants. The edge sets are
/// expressed as member ids so the painter can decide which connectors to
/// highlight without knowing the graph.
class Lineage {
  const Lineage({
    required this.selectedId,
    required this.members,
    required this.labels,
    required this.unionMembers,
    required this.descentChildIds,
    required this.descentParentIds,
  });

  final String selectedId;

  /// Selected person + every highlighted relative (for ring/badge).
  final Set<String> members;

  /// relativeId -> capitalized relationship label ("Father", "Son", …).
  final Map<String, String> labels;

  /// A spouse bar highlights if either end is in this set.
  final Set<String> unionMembers;

  /// A child's up-link (to its parents) highlights if the child is in this set.
  final Set<String> descentChildIds;

  /// A parent's down-links (to its children) highlight if the parent is here.
  final Set<String> descentParentIds;

  String? labelFor(String id) => labels[id];
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// All ancestors of [id] (excluding self), via parent edges.
Set<String> _ancestors(FamilyGraph g, String id) {
  final out = <String>{};
  final queue = <String>[id];
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    for (final p in g.parentsOf[cur] ?? const <String>[]) {
      if (out.add(p)) queue.add(p);
    }
  }
  return out;
}

/// All descendants of [id] (excluding self), via child edges.
Set<String> _descendants(FamilyGraph g, String id) {
  final out = <String>{};
  final queue = <String>[id];
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    for (final c in g.childrenOf[cur] ?? const <String>[]) {
      if (out.add(c)) queue.add(c);
    }
  }
  return out;
}

Lineage computeLineage(FamilyGraph g, String selectedId, {bool full = false}) {
  final parents = {...?g.parentsOf[selectedId]};
  final spouses = {...?g.spousesOf[selectedId]};
  final children = {...?g.childrenOf[selectedId]};

  // Siblings = other children of the selected person's parents.
  final siblings = <String>{};
  for (final p in parents) {
    for (final c in g.childrenOf[p] ?? const <String>[]) {
      if (c != selectedId) siblings.add(c);
    }
  }

  final Set<String> descentChildIds;
  final Set<String> descentParentIds;
  final Set<String> related;

  if (full) {
    final ancestors = _ancestors(g, selectedId);
    final descendants = _descendants(g, selectedId);
    // Each ancestor's up-link + the selected person's own up-link.
    descentChildIds = {selectedId, ...ancestors, ...siblings};
    // The selected person + every descendant as a parent of their children.
    descentParentIds = {selectedId, ...descendants};
    related = {...parents, ...siblings, ...spouses, ...children,
      ...ancestors, ...descendants};
  } else {
    descentChildIds = {selectedId, ...siblings};
    descentParentIds = {selectedId};
    related = {...parents, ...siblings, ...spouses, ...children};
  }

  final members = {selectedId, ...related};
  final unionMembers = full ? members : {selectedId, ...spouses};

  final labels = <String, String>{};
  for (final id in related) {
    final k = computeKinship(g, selectedId, id);
    if (k.isTerm) labels[id] = _cap(k.label);
  }

  return Lineage(
    selectedId: selectedId,
    members: members,
    labels: labels,
    unionMembers: unionMembers,
    descentChildIds: descentChildIds,
    descentParentIds: descentParentIds,
  );
}
