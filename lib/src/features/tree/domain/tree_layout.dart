import 'dart:ui';

import '../../members/domain/member.dart';
import 'family_graph.dart';

/// A positioned node in the laid-out tree.
class TreeNode {
  const TreeNode({required this.member, required this.center});
  final Member member;
  final Offset center;
}

/// A spouse/partner link drawn as a bar between two adjacent nodes.
class UnionLink {
  const UnionLink({required this.a, required this.b});
  final String a;
  final String b;
}

/// A parent→child descent. When [parentB] is set, the child descends from the
/// midpoint between the couple rather than from a single parent.
class DescentLink {
  const DescentLink({required this.parentA, this.parentB, required this.child});
  final String parentA;
  final String? parentB;
  final String child;
}

/// The laid-out tree: node centers, spouse links, parent→child descents and the
/// total canvas size.
class TreeLayout {
  const TreeLayout({
    required this.nodes,
    required this.unions,
    required this.descents,
    required this.size,
    required this.nodeSize,
  });

  final List<TreeNode> nodes;
  final List<UnionLink> unions;
  final List<DescentLink> descents;
  final Size size;
  final Size nodeSize;

  bool get isEmpty => nodes.isEmpty;
}

/// One generation row containing one person or a married couple. Couples are
/// laid out as a unit so spouses always sit side by side.
class _Unit {
  _Unit(this.members);
  final List<String> members; // 1 or 2 ids
  double centerCol = 0;
  bool get isCouple => members.length == 2;
}

/// Lays out a family as a top-down, couple-aware generational tree.
///
/// Spouses are grouped into a unit and placed adjacently; their children
/// descend from the couple's midpoint. Y is driven by generation depth.
class TreeLayoutEngine {
  static const double nodeWidth = 132;
  static const double nodeHeight = 150;
  static const double hGap = 28;
  static const double vGap = 80;
  static const double margin = 48;

  static TreeLayout build(FamilyGraph graph) {
    if (graph.members.isEmpty) {
      return const TreeLayout(
        nodes: [],
        unions: [],
        descents: [],
        size: Size.zero,
        nodeSize: Size(nodeWidth, nodeHeight),
      );
    }

    int birthKey(String id) => graph.byId[id]?.birthYear ?? 9999;

    // --- 1. Group members into units (singles or couples). -------------------
    final unitOf = <String, _Unit>{};
    final units = <_Unit>[];
    for (final m in graph.members) {
      if (unitOf.containsKey(m.id)) continue;
      final spouses = graph.spousesOf[m.id] ?? const [];
      String? partner;
      for (final s in spouses) {
        if (graph.byId.containsKey(s) && !unitOf.containsKey(s)) {
          partner = s;
          break;
        }
      }
      final unit = _Unit(partner == null ? [m.id] : [m.id, partner]);
      units.add(unit);
      for (final id in unit.members) {
        unitOf[id] = unit;
      }
    }

    // --- 2. Row (depth) per member: a married-in spouse shares its partner's
    //        row even if it has no ancestors of its own. ----------------------
    final rowOf = <String, int>{};
    for (final unit in units) {
      var row = 0;
      for (final id in unit.members) {
        final hasParents = (graph.parentsOf[id] ?? const []).isNotEmpty;
        if (hasParents) {
          final d = graph.depthOf[id] ?? 0;
          if (d > row) row = d;
        }
      }
      for (final id in unit.members) {
        rowOf[id] = row;
      }
    }

    // --- 3. Child units of a unit (distinct children of either spouse). ------
    List<_Unit> childUnitsOf(_Unit unit) {
      final childIds = <String>{};
      for (final id in unit.members) {
        for (final c in graph.childrenOf[id] ?? const <String>[]) {
          childIds.add(c);
        }
      }
      final seen = <_Unit>{};
      final result = <_Unit>[];
      final sorted = childIds.toList()
        ..sort((a, b) => birthKey(a).compareTo(birthKey(b)));
      for (final c in sorted) {
        final u = unitOf[c];
        if (u != null && seen.add(u)) result.add(u);
      }
      return result;
    }

    // --- 4. Assign columns: leaves take sequential slots, parents center over
    //        their children. ---------------------------------------------------
    final placed = <_Unit>{};
    double nextCol = 0;

    double assign(_Unit unit) {
      if (placed.contains(unit)) return unit.centerCol;
      placed.add(unit);
      final children = childUnitsOf(unit).where((u) => !placed.contains(u)).toList();
      if (children.isEmpty) {
        final width = unit.isCouple ? 2.0 : 1.0;
        unit.centerCol = nextCol + (width - 1) / 2;
        nextCol += width;
      } else {
        final centers = children.map(assign).toList();
        unit.centerCol = (centers.first + centers.last) / 2;
      }
      return unit.centerCol;
    }

    final roots = units.where((u) {
      return u.members
          .every((id) => (graph.parentsOf[id] ?? const []).isEmpty);
    }).toList()
      ..sort((a, b) => birthKey(a.members.first).compareTo(birthKey(b.members.first)));
    for (final r in roots) {
      assign(r);
    }
    for (final u in units) {
      assign(u);
    }

    // --- 5. Pixel positions. -------------------------------------------------
    const colWidth = nodeWidth + hGap;
    const rowHeight = nodeHeight + vGap;

    double colOfMember(_Unit unit, String id) {
      if (!unit.isCouple) return unit.centerCol;
      return unit.members.first == id
          ? unit.centerCol - 0.5
          : unit.centerCol + 0.5;
    }

    final nodes = <TreeNode>[];
    for (final m in graph.members) {
      final unit = unitOf[m.id]!;
      final col = colOfMember(unit, m.id);
      final row = rowOf[m.id] ?? 0;
      nodes.add(TreeNode(
        member: m,
        center: Offset(
          margin + col * colWidth + nodeWidth / 2,
          margin + row * rowHeight + nodeHeight / 2,
        ),
      ));
    }

    // --- 6. Edges. -----------------------------------------------------------
    final unions = <UnionLink>[];
    final seenUnions = <String>{};
    graph.spousesOf.forEach((a, partners) {
      for (final b in partners) {
        if (!graph.byId.containsKey(b)) continue;
        final key = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
        if (seenUnions.add(key)) unions.add(UnionLink(a: a, b: b));
      }
    });

    final descents = <DescentLink>[];
    for (final unit in units) {
      final childIds = <String>{};
      for (final id in unit.members) {
        for (final c in graph.childrenOf[id] ?? const <String>[]) {
          childIds.add(c);
        }
      }
      for (final child in childIds) {
        descents.add(DescentLink(
          parentA: unit.members.first,
          parentB: unit.isCouple ? unit.members[1] : null,
          child: child,
        ));
      }
    }

    double maxX = 0, maxY = 0;
    for (final n in nodes) {
      if (n.center.dx > maxX) maxX = n.center.dx;
      if (n.center.dy > maxY) maxY = n.center.dy;
    }

    return TreeLayout(
      nodes: nodes,
      unions: unions,
      descents: descents,
      size: Size(maxX + nodeWidth / 2 + margin, maxY + nodeHeight / 2 + margin),
      nodeSize: const Size(nodeWidth, nodeHeight),
    );
  }
}
