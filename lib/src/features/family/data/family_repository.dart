import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';
import '../domain/family.dart';

class FamilyRepository {
  FamilyRepository(this._client);

  final SupabaseClient _client;

  /// Families the current user belongs to, with their role in each. Ordered by
  /// most-recently joined.
  Future<List<Family>> myFamilies() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await _client
        .from('family_members')
        .select('role, joined_at, families(*)')
        .eq('user_id', uid)
        .order('joined_at', ascending: false);

    return (rows as List)
        .where((row) => row['families'] != null)
        .map((row) => Family.fromMap(
              row['families'] as Map<String, dynamic>,
              role: FamilyRole.fromName(row['role'] as String?),
            ))
        .toList();
  }

  /// Creates a family and the creator's admin membership atomically via the
  /// `create_family` SECURITY DEFINER RPC.
  Future<Family> createFamily(String name) async {
    final result = await _client.rpc('create_family', params: {'p_name': name});
    final map = (result is List ? result.first : result) as Map<String, dynamic>;
    return Family.fromMap(map, role: FamilyRole.admin);
  }
}

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(ref.watch(supabaseClientProvider));
});
