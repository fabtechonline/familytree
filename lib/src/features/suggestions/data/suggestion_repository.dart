import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';
import '../domain/edit_suggestion.dart';

class SuggestionRepository {
  SuggestionRepository(this._client);

  final SupabaseClient _client;

  Future<void> suggestMemberAdd({
    required String familyId,
    required Map<String, dynamic> payload,
    String? note,
  }) async {
    await _client.from('edit_suggestions').insert({
      'family_id': familyId,
      'suggested_by': _client.auth.currentUser?.id,
      'kind': 'add_member',
      'payload': payload,
      'note': note,
    });
  }

  Future<void> suggestMemberEdit({
    required String familyId,
    required String targetMemberId,
    required Map<String, dynamic> payload,
    String? note,
  }) async {
    await _client.from('edit_suggestions').insert({
      'family_id': familyId,
      'suggested_by': _client.auth.currentUser?.id,
      'kind': 'edit_member',
      'target_member_id': targetMemberId,
      'payload': payload,
      'note': note,
    });
  }

  Future<List<EditSuggestion>> listPending(String familyId) async {
    final rows = await _client
        .from('edit_suggestions')
        .select()
        .eq('family_id', familyId)
        .eq('status', 'pending')
        .order('created_at');
    return (rows as List)
        .map((r) => EditSuggestion.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Admin: approve a suggestion (applies the change via RPC).
  Future<void> approve(String id) async {
    await _client.rpc('apply_suggestion', params: {'p_id': id});
  }

  /// Admin: reject a suggestion.
  Future<void> reject(String id) async {
    await _client.from('edit_suggestions').update({
      'status': 'rejected',
      'reviewed_by': _client.auth.currentUser?.id,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}

final suggestionRepositoryProvider = Provider<SuggestionRepository>((ref) {
  return SuggestionRepository(ref.watch(supabaseClientProvider));
});

/// Pending suggestions for a family (admins see all; others see their own).
final pendingSuggestionsProvider =
    FutureProvider.family<List<EditSuggestion>, String>((ref, familyId) async {
  return ref.watch(suggestionRepositoryProvider).listPending(familyId);
});
