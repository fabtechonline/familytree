import 'package:familytree/src/features/members/domain/member.dart';
import 'package:familytree/src/features/members/domain/relationship.dart';
import 'package:familytree/src/features/tree/domain/family_graph.dart';
import 'package:familytree/src/features/tree/domain/lineage.dart';
import 'package:flutter_test/flutter_test.dart';

Member _m(String id, String gender) =>
    Member(id: id, familyId: 'fam', firstName: id, gender: gender);
Relationship _p(String a, String b) => Relationship(
    id: '$a>$b', familyId: 'fam', fromMember: a, toMember: b, type: RelType.parent);
Relationship _s(String a, String b) => Relationship(
    id: '$a=$b', familyId: 'fam', fromMember: a, toMember: b, type: RelType.spouse);

void main() {
  // gp1(m)=gp2(f) -> p1(m), p2(f); p1=w(f) -> me(m), sib(f).
  final g = FamilyGraph.build(
    [
      _m('gp1', 'male'), _m('gp2', 'female'),
      _m('p1', 'male'), _m('p2', 'female'), _m('w', 'female'),
      _m('me', 'male'), _m('sib', 'female'),
    ],
    [
      _s('gp1', 'gp2'),
      _p('gp1', 'p1'), _p('gp2', 'p1'),
      _p('gp1', 'p2'), _p('gp2', 'p2'),
      _s('p1', 'w'),
      _p('p1', 'me'), _p('p1', 'sib'),
    ],
  );

  test('immediate lineage of a child: parent + sibling', () {
    final l = computeLineage(g, 'me');
    expect(l.members, containsAll(['me', 'p1', 'sib']));
    expect(l.labels['p1'], 'Father');
    expect(l.labels['sib'], 'Sister');
    expect(l.descentChildIds, containsAll(['me', 'sib']));
    expect(l.descentParentIds, {'me'});
  });

  test('immediate lineage of a parent: spouse, children, own parents', () {
    final l = computeLineage(g, 'p1');
    expect(l.labels['w'], 'Wife');
    expect(l.labels['me'], 'Son');
    expect(l.labels['sib'], 'Daughter');
    expect(l.labels['gp1'], 'Father');
    expect(l.unionMembers, containsAll(['p1', 'w']));
    expect(l.descentParentIds, contains('p1')); // p1's children highlight
  });

  test('full lineage extends to ancestors', () {
    final l = computeLineage(g, 'me', full: true);
    expect(l.members, containsAll(['p1', 'gp1', 'gp2', 'sib']));
    expect(l.labels['gp1'], 'Grandfather');
    expect(l.labels['gp2'], 'Grandmother');
    expect(l.descentChildIds, containsAll(['me', 'p1', 'gp1', 'gp2']));
  });
}
