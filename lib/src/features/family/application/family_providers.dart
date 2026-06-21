import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family_repository.dart';
import '../domain/family.dart';

/// All families the signed-in user belongs to. Re-fetched on invalidate (e.g.
/// after creating a family).
final myFamiliesProvider = FutureProvider<List<Family>>((ref) async {
  return ref.watch(familyRepositoryProvider).myFamilies();
});

/// The explicitly-selected family id, or null to fall back to the first family.
/// Lets users with multiple families switch the active one.
class SelectedFamilyId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? familyId) => state = familyId;
}

final selectedFamilyIdProvider =
    NotifierProvider<SelectedFamilyId, String?>(SelectedFamilyId.new);

/// The currently active family: the explicit selection if still valid,
/// otherwise the first family. Null while loading or when the user has none.
final currentFamilyProvider = Provider<Family?>((ref) {
  final families = ref.watch(myFamiliesProvider).value;
  if (families == null || families.isEmpty) return null;

  final selectedId = ref.watch(selectedFamilyIdProvider);
  if (selectedId != null) {
    for (final f in families) {
      if (f.id == selectedId) return f;
    }
  }
  return families.first;
});
