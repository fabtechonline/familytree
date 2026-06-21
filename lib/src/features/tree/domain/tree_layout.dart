import 'dart:ui';

import '../../members/domain/member.dart';
import 'family_graph.dart';

/// A positioned node in the laid-out tree.
class TreeNode {
  const TreeNode({required this.member, required this.center});
  final Member member;
  final Offset center;
}

/// A connector between two nodes.
class TreeEdge {
  const TreeEdge({required this.from, required this.to, required this.isUnion});
  final String from;
  final String to;

  /// True for spouse/partner links (drawn as a horizontal bar), false for
  /// parent→child links (drawn as elbow connectors).
  final bool isUnion;
}

/// The result of laying out a [FamilyGraph]: node centers, edges and the total
/// canvas size needed to contain everything.
class TreeLayout {
  const TreeLayout({
    required this.nodes,
    required this.edges,
    required this.size,
    required this.nodeSize,
  });

  final List<TreeNode> nodes;
  final List<TreeEdge> edges;
  final Size size;
  final Size nodeSize;

  bool get isEmpty => nodes.isEmpty;
}

/// Lays out a family as a top-down generational tree.
///
/// Y is driven by generation depth (oldest ancestors on top). X uses a
/// Reingold–Tilford-style pass: leaves take sequential slots and parents center
/// over their children. Spouse links are drawn between nodes wherever they land.
/// (A couple-tidy and radial/fan layout come in a later phase.)
class TreeLayoutEngine {
  static const double nodeWidth = 132;
  static const double nodeHeight = 150;
  static const double hGap = 28;
  static const double vGap = 76;
  static const double margin = 48;

  static TreeLayout build(FamilyGraph graph) {
    if (graph.members.isEmpty) {
      return const TreeLayout(
        nodes: [],
        edges: [],
        size: Size.zero,
        nodeSize: Size(nodeWidth, nodeHeight),
      );
    }

    int birthKey(Member m) => m.birthYear ?? 9999;
    List<String> sortedChildren(String id) {
      final kids = [...?graph.childrenOf[id]];
      kids.sort((a, b) {
        final byBirth =
            birthKey(graph.byId[a]!).compareTo(birthKey(graph.byId[b]!));
        return byBirth != 0
            ? byBirth
            : graph.byId[a]!.fullName.compareTo(graph.byId[b]!.fullName);
      });
      return kids;
    }

    final xSlot = <String, double>{};
    final placed = <String>{};
    double nextSlot = 0;

    double assign(String id) {
      if (placed.contains(id)) return xSlot[id]!;
      placed.add(id);
      final kids = sortedChildren(id).where((c) => !placed.contains(c)).toList();
      double x;
      if (kids.isEmpty) {
        x = nextSlot;
        nextSlot += 1;
      } else {
        final xs = kids.map(assign).toList();
        x = (xs.first + xs.last) / 2;
      }
      xSlot[id] = x;
      return x;
    }

    // Roots first (members with no parents), oldest first, then anything left
    // over (disconnected members or cycles).
    final roots = graph.members
        .where((m) => (graph.parentsOf[m.id] ?? const []).isEmpty)
        .toList()
      ..sort((a, b) => birthKey(a).compareTo(birthKey(b)));
    for (final r in roots) {
      assign(r.id);
    }
    for (final m in graph.members) {
      assign(m.id);
    }

    const colWidth = nodeWidth + hGap;
    const rowHeight = nodeHeight + vGap;

    final nodes = <TreeNode>[];
    for (final m in graph.members) {
      final depth = graph.depthOf[m.id] ?? 0;
      final center = Offset(
        margin + xSlot[m.id]! * colWidth + nodeWidth / 2,
        margin + depth * rowHeight + nodeHeight / 2,
      );
      nodes.add(TreeNode(member: m, center: center));
    }

    final edges = <TreeEdge>[];
    // Parent→child edges.
    graph.childrenOf.forEach((parent, children) {
      for (final child in children) {
        edges.add(TreeEdge(from: parent, to: child, isUnion: false));
      }
    });
    // Union edges (dedupe the symmetric pairs).
    final seenUnions = <String>{};
    graph.spousesOf.forEach((a, partners) {
      for (final b in partners) {
        final key = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
        if (seenUnions.add(key)) {
          edges.add(TreeEdge(from: a, to: b, isUnion: true));
        }
      }
    });

    double maxX = 0;
    double maxY = 0;
    for (final n in nodes) {
      if (n.center.dx > maxX) maxX = n.center.dx;
      if (n.center.dy > maxY) maxY = n.center.dy;
    }

    return TreeLayout(
      nodes: nodes,
      edges: edges,
      size: Size(maxX + nodeWidth / 2 + margin, maxY + nodeHeight / 2 + margin),
      nodeSize: const Size(nodeWidth, nodeHeight),
    );
  }
}
