import 'package:familytree/src/features/members/domain/member.dart';
import 'package:familytree/src/features/members/domain/relationship.dart';
import 'package:familytree/src/features/tree/domain/family_graph.dart';
import 'package:familytree/src/features/tree/domain/tree_layout.dart';
import 'package:flutter_test/flutter_test.dart';

Member _m(String id, String name, {int? birthYear}) => Member(
      id: id,
      familyId: 'fam',
      firstName: name,
      birthDate: birthYear == null ? null : DateTime(birthYear),
    );

Relationship _parent(String parent, String child) => Relationship(
      id: '$parent-$child',
      familyId: 'fam',
      fromMember: parent,
      toMember: child,
      type: RelType.parent,
    );

Relationship _spouse(String a, String b) => Relationship(
      id: '$a-$b',
      familyId: 'fam',
      fromMember: a,
      toMember: b,
      type: RelType.spouse,
    );

void main() {
  group('FamilyGraph', () {
    test('computes generation depth across three generations', () {
      final members = [
        _m('g', 'Grandparent', birthYear: 1940),
        _m('p', 'Parent', birthYear: 1970),
        _m('c', 'Child', birthYear: 2000),
      ];
      final graph = FamilyGraph.build(members, [_parent('g', 'p'), _parent('p', 'c')]);

      expect(graph.depthOf['g'], 0);
      expect(graph.depthOf['p'], 1);
      expect(graph.depthOf['c'], 2);
      expect(graph.generationCount, 3);
    });

    test('records spouse links symmetrically', () {
      final members = [_m('a', 'A'), _m('b', 'B')];
      final graph = FamilyGraph.build(members, [_spouse('a', 'b')]);

      expect(graph.spousesOf['a'], contains('b'));
      expect(graph.spousesOf['b'], contains('a'));
      expect(graph.generationCount, 1);
    });

    test('ignores edges referencing unknown members', () {
      final graph = FamilyGraph.build([_m('a', 'A')], [_parent('a', 'ghost')]);
      expect(graph.childrenOf['a'] ?? const [], isEmpty);
    });
  });

  group('TreeLayoutEngine', () {
    test('positions later generations below earlier ones', () {
      final members = [
        _m('g', 'Grandparent', birthYear: 1940),
        _m('p', 'Parent', birthYear: 1970),
        _m('c', 'Child', birthYear: 2000),
      ];
      final graph =
          FamilyGraph.build(members, [_parent('g', 'p'), _parent('p', 'c')]);
      final layout = TreeLayoutEngine.build(graph);

      double y(String id) =>
          layout.nodes.firstWhere((n) => n.member.id == id).center.dy;

      expect(y('g'), lessThan(y('p')));
      expect(y('p'), lessThan(y('c')));
      expect(layout.isEmpty, isFalse);
    });

    test('a parent is horizontally centered over two children', () {
      final members = [
        _m('p', 'Parent', birthYear: 1970),
        _m('c1', 'Child1', birthYear: 1995),
        _m('c2', 'Child2', birthYear: 2000),
      ];
      final graph = FamilyGraph.build(
          members, [_parent('p', 'c1'), _parent('p', 'c2')]);
      final layout = TreeLayoutEngine.build(graph);

      Offset center(String id) =>
          layout.nodes.firstWhere((n) => n.member.id == id).center;

      final px = center('p').dx;
      final mid = (center('c1').dx + center('c2').dx) / 2;
      expect((px - mid).abs(), lessThan(0.5));
    });

    test('empty graph yields empty layout', () {
      final layout = TreeLayoutEngine.build(FamilyGraph.build([], []));
      expect(layout.isEmpty, isTrue);
    });

    test('spouses sit on the same row, adjacent, with child descending from couple',
        () {
      final members = [
        _m('h', 'Husband', birthYear: 1970),
        _m('w', 'Wife', birthYear: 1972),
        _m('c', 'Child', birthYear: 2000),
      ];
      // Child is linked to only one parent in data, but should still descend
      // from the couple.
      final graph = FamilyGraph.build(
          members, [_spouse('h', 'w'), _parent('h', 'c')]);
      final layout = TreeLayoutEngine.build(graph);

      Offset center(String id) =>
          layout.nodes.firstWhere((n) => n.member.id == id).center;

      // Same row (married-in spouse shares the row).
      expect(center('h').dy, center('w').dy);
      // Adjacent horizontally (one column apart).
      expect((center('h').dx - center('w').dx).abs(),
          closeTo(TreeLayoutEngine.nodeWidth + TreeLayoutEngine.hGap, 0.5));
      // Child below the couple.
      expect(center('c').dy, greaterThan(center('h').dy));
      // The descent for the child records both parents (couple anchor).
      final descent = layout.descents.firstWhere((d) => d.child == 'c');
      expect({descent.parentA, descent.parentB}, containsAll(['h', 'w']));
    });
  });
}
