import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';
import '../../family/domain/family.dart';
import '../domain/invite_models.dart';

class InviteRepository {
  InviteRepository(this._client);

  final SupabaseClient _client;

  /// Admin-only: mints a new invite code for [familyId] with [role]. For a
  /// "relative" invite, [targetMemberId] is the profile they will claim/manage.
  Future<Invitation> createInvitation(
    String familyId,
    FamilyRole role, {
    String? targetMemberId,
  }) async {
    final result = await _client.rpc('create_invitation', params: {
      'p_family': familyId,
      'p_role': role.name,
      'p_target_member': targetMemberId,
    });
    final map = (result is List ? result.first : result) as Map<String, dynamic>;
    return Invitation.fromMap(map);
  }

  /// Looks up an invite by [code] without joining. Returns null if not found.
  Future<InvitePreview?> previewInvite(String code) async {
    final result =
        await _client.rpc('invite_preview', params: {'p_code': code});
    final list = result as List;
    if (list.isEmpty) return null;
    return InvitePreview.fromMap(list.first as Map<String, dynamic>);
  }

  /// Joins the family the [code] belongs to and returns it.
  Future<Family> joinWithCode(String code) async {
    final result =
        await _client.rpc('join_family_with_code', params: {'p_code': code});
    final map = (result is List ? result.first : result) as Map<String, dynamic>;
    return Family.fromMap(map);
  }

  /// Members-only: roster with display info.
  Future<List<RosterMember>> roster(String familyId) async {
    final result =
        await _client.rpc('family_roster', params: {'p_family': familyId});
    return (result as List)
        .map((r) => RosterMember.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Admin-only (enforced by RLS): change a member's role.
  Future<void> setMemberRole(
      String familyId, String userId, FamilyRole role) async {
    await _client
        .from('family_members')
        .update({'role': role.name})
        .eq('family_id', familyId)
        .eq('user_id', userId);
  }

  /// Admin-only (enforced by RLS): remove a member from the family.
  Future<void> removeMember(String familyId, String userId) async {
    await _client
        .from('family_members')
        .delete()
        .eq('family_id', familyId)
        .eq('user_id', userId);
  }
}

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepository(ref.watch(supabaseClientProvider));
});

/// Roster for a family, keyed by family id.
final rosterProvider =
    FutureProvider.family<List<RosterMember>, String>((ref, familyId) async {
  return ref.watch(inviteRepositoryProvider).roster(familyId);
});
