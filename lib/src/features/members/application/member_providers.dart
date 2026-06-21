import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/member_repository.dart';
import '../domain/member.dart';
import '../domain/relationship.dart';

/// All members of a family, keyed by family id. Invalidate after add/edit.
final membersProvider =
    FutureProvider.family<List<Member>, String>((ref, familyId) async {
  return ref.watch(memberRepositoryProvider).listMembers(familyId);
});

/// All relationship edges of a family, keyed by family id.
final relationshipsProvider =
    FutureProvider.family<List<Relationship>, String>((ref, familyId) async {
  return ref.watch(memberRepositoryProvider).listRelationships(familyId);
});

/// Convenience: refresh both members and relationships for a family after a
/// mutation so the dashboard and tree reflect changes.
void invalidateFamilyData(WidgetRef ref, String familyId) {
  ref.invalidate(membersProvider(familyId));
  ref.invalidate(relationshipsProvider(familyId));
}
