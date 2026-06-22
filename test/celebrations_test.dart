import 'package:riza/src/features/celebrations/celebrations.dart';
import 'package:riza/src/features/members/domain/member.dart';
import 'package:riza/src/features/members/domain/relationship.dart';
import 'package:flutter_test/flutter_test.dart';

Member _m(String id, String name,
        {DateTime? birth, bool living = true, DateTime? death}) =>
    Member(
      id: id,
      familyId: 'fam',
      firstName: name,
      birthDate: birth,
      isLiving: living,
      deathDate: death,
    );

void main() {
  final now = DateTime(2026, 6, 22);

  test('birthday within window appears with correct days and age', () {
    final members = [_m('a', 'Ann', birth: DateTime(1990, 6, 27))];
    final list = computeCelebrations(members, const [], now: now);
    expect(list, hasLength(1));
    expect(list.first.kind, CelebrationKind.birthday);
    expect(list.first.daysUntil, 5);
    expect(list.first.years, 36); // turning 36 in 2026
  });

  test('excludes deceased members and those without a birth date', () {
    final members = [
      _m('a', 'NoDate'),
      _m('b', 'Gone',
          birth: DateTime(1900, 6, 25), living: false, death: DateTime(1980)),
    ];
    expect(computeCelebrations(members, const [], now: now), isEmpty);
  });

  test('birthday outside the window is excluded', () {
    final members = [_m('a', 'Far', birth: DateTime(1990, 12, 1))];
    expect(
        computeCelebrations(members, const [], now: now, withinDays: 60), isEmpty);
  });

  test('anniversary derived from a union start date', () {
    final members = [
      _m('h', 'Husband', birth: DateTime(1980, 1, 1)),
      _m('w', 'Wife', birth: DateTime(1982, 1, 1)),
    ];
    final rels = [
      Relationship(
        id: 'r1',
        familyId: 'fam',
        fromMember: 'h',
        toMember: 'w',
        type: RelType.spouse,
        startDate: DateTime(2010, 7, 1),
      ),
    ];
    final list = computeCelebrations(members, rels, now: now);
    final anniv = list.where((c) => c.kind == CelebrationKind.anniversary);
    expect(anniv, hasLength(1));
    expect(anniv.first.years, 16); // 2010 -> 2026
    expect(anniv.first.daysUntil, 9); // Jun 22 -> Jul 1
  });
}
