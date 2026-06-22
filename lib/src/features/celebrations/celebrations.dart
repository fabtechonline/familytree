import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../members/application/member_providers.dart';
import '../members/domain/member.dart';
import '../members/domain/relationship.dart';

enum CelebrationKind { birthday, anniversary }

/// An upcoming birthday or wedding anniversary.
class Celebration {
  const Celebration({
    required this.kind,
    required this.title,
    required this.date,
    required this.daysUntil,
    required this.years,
    this.memberId,
    this.photoUrl,
  });

  final CelebrationKind kind;
  final String title;
  final DateTime date; // next occurrence
  final int daysUntil;
  final int years; // age turning, or years married (0 if unknown)
  final String? memberId; // person to greet (birthdays)
  final String? photoUrl;

  bool get isToday => daysUntil == 0;
}

/// Next occurrence of [date]'s month/day on or after [from] (date-only).
DateTime _nextOccurrence(DateTime date, DateTime from) {
  final today = DateTime(from.year, from.month, from.day);
  var next = DateTime(today.year, date.month, date.day);
  if (next.isBefore(today)) {
    next = DateTime(today.year + 1, date.month, date.day);
  }
  return next;
}

/// Upcoming celebrations within the next [withinDays] days, soonest first.
final upcomingCelebrationsProvider =
    FutureProvider.family<List<Celebration>, String>((ref, familyId) async {
  final members = await ref.watch(membersProvider(familyId).future);
  final relationships =
      await ref.watch(relationshipsProvider(familyId).future);
  return computeCelebrations(members, relationships);
});

/// Pure function (testable) that derives celebrations from members + edges.
List<Celebration> computeCelebrations(
  List<Member> members,
  List<Relationship> relationships, {
  int withinDays = 60,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final byId = {for (final m in members) m.id: m};
  final result = <Celebration>[];

  // Birthdays — living members with a known birth date.
  for (final m in members) {
    if (!m.isLiving || m.birthDate == null) continue;
    final next = _nextOccurrence(m.birthDate!, today);
    final days = next.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days <= withinDays) {
      result.add(Celebration(
        kind: CelebrationKind.birthday,
        title: m.fullName,
        date: next,
        daysUntil: days,
        years: next.year - m.birthDate!.year,
        memberId: m.id,
        photoUrl: m.photoUrl,
      ));
    }
  }

  // Anniversaries — spouse/partner unions with a known start date.
  final seen = <String>{};
  for (final r in relationships) {
    if (!r.isUnion || r.startDate == null) continue;
    final a = byId[r.fromMember];
    final b = byId[r.toMember];
    if (a == null || b == null) continue;
    final key = a.id.compareTo(b.id) < 0 ? '${a.id}|${b.id}' : '${b.id}|${a.id}';
    if (!seen.add(key)) continue;
    final next = _nextOccurrence(r.startDate!, today);
    final days = next.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days <= withinDays) {
      result.add(Celebration(
        kind: CelebrationKind.anniversary,
        title: '${a.firstName} & ${b.firstName}',
        date: next,
        daysUntil: days,
        years: next.year - r.startDate!.year,
      ));
    }
  }

  result.sort((x, y) => x.daysUntil.compareTo(y.daysUntil));
  return result;
}
