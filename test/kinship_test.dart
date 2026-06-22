import 'package:familytree/src/features/members/domain/member.dart';
import 'package:familytree/src/features/members/domain/relationship.dart';
import 'package:familytree/src/features/relate/kinship.dart';
import 'package:familytree/src/features/tree/domain/family_graph.dart';
import 'package:flutter_test/flutter_test.dart';

Member _m(String id, String gender) =>
    Member(id: id, familyId: 'fam', firstName: id, gender: gender);

Relationship _p(String parent, String child) => Relationship(
    id: '$parent>$child',
    familyId: 'fam',
    fromMember: parent,
    toMember: child,
    type: RelType.parent);

Relationship _s(String a, String b) => Relationship(
    id: '$a=$b', familyId: 'fam', fromMember: a, toMember: b, type: RelType.spouse);

void main() {
  // gp1 (m) = gp2 (f); their children p1 (m) and p2 (f).
  // p1 = p1spouse (f); their children me (m) and sib (f).
  // p2's child: cousin (m).
  final graph = FamilyGraph.build(
    [
      _m('gp1', 'male'), _m('gp2', 'female'),
      _m('p1', 'male'), _m('p2', 'female'), _m('p1spouse', 'female'),
      _m('me', 'male'), _m('sib', 'female'), _m('cousin', 'male'),
    ],
    [
      _s('gp1', 'gp2'),
      _p('gp1', 'p1'), _p('gp2', 'p1'),
      _p('gp1', 'p2'), _p('gp2', 'p2'),
      _s('p1', 'p1spouse'),
      _p('p1', 'me'), _p('p1', 'sib'),
      _p('p2', 'cousin'),
    ],
  );

  String rel(String a, String b) => computeKinship(graph, a, b).label;

  test('parent and child', () {
    expect(rel('me', 'p1'), 'father');
    expect(rel('p1', 'me'), 'son');
  });

  test('grandparents', () {
    expect(rel('me', 'gp1'), 'grandfather');
    expect(rel('me', 'gp2'), 'grandmother');
  });

  test('siblings', () {
    expect(rel('me', 'sib'), 'sister');
  });

  test('aunt and niece', () {
    expect(rel('me', 'p2'), 'aunt');
    expect(rel('p2', 'me'), 'nephew');
  });

  test('first cousins', () {
    expect(rel('me', 'cousin'), 'first cousin');
  });

  test('spouse', () {
    expect(rel('gp1', 'gp2'), 'wife');
    expect(rel('gp2', 'gp1'), 'husband');
  });

  test('step-parent', () {
    // p1spouse is married to me's parent (p1) but isn't my blood parent.
    expect(rel('me', 'p1spouse'), 'stepmother');
  });

  test('parent-in-law and child-in-law', () {
    // gp1 is the father of p1spouse's spouse (p1) -> father-in-law.
    expect(rel('p1spouse', 'gp1'), 'father-in-law');
    // p1spouse is the spouse of gp1's child (p1) -> daughter-in-law.
    expect(rel('gp1', 'p1spouse'), 'daughter-in-law');
  });

  test('sibling-in-law', () {
    // p2 is the sister of p1spouse's spouse (p1) -> sister-in-law.
    expect(rel('p1spouse', 'p2'), 'sister-in-law');
    expect(rel('p2', 'p1spouse'), 'sister-in-law');
  });

  test('great-grandparent', () {
    final g2 = FamilyGraph.build(
      [_m('a', 'male'), _m('b', 'male'), _m('c', 'male'), _m('d', 'male')],
      [_p('a', 'b'), _p('b', 'c'), _p('c', 'd')],
    );
    expect(computeKinship(g2, 'd', 'a').label, 'great-grandfather');
  });
}
