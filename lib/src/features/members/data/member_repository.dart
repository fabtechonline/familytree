import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';
import '../domain/member.dart';
import '../domain/relationship.dart';

class MemberRepository {
  MemberRepository(this._client);

  final SupabaseClient _client;

  // ---- Members -------------------------------------------------------------

  Future<List<Member>> listMembers(String familyId) async {
    final rows = await _client
        .from('members')
        .select()
        .eq('family_id', familyId)
        .order('created_at');
    return (rows as List)
        .map((r) => Member.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Member> addMember(Member member) async {
    final payload = member.toInsert()
      ..['created_by'] = _client.auth.currentUser?.id;
    final row =
        await _client.from('members').insert(payload).select().single();
    return Member.fromMap(row);
  }

  Future<Member> updateMember(Member member) async {
    final row = await _client
        .from('members')
        .update(member.toInsert())
        .eq('id', member.id)
        .select()
        .single();
    return Member.fromMap(row);
  }

  Future<void> deleteMember(String id) async {
    await _client.from('members').delete().eq('id', id);
  }

  /// Uploads a member photo to the `member-photos` bucket and returns its public
  /// URL. Path is `{familyId}/{memberId}/...` so storage RLS can authorize the
  /// write by family role. A timestamped filename avoids stale CDN caching.
  Future<String> uploadMemberPhoto({
    required String familyId,
    required String memberId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final path =
        '$familyId/$memberId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('member-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from('member-photos').getPublicUrl(path);
  }

  // ---- Relationships -------------------------------------------------------

  Future<List<Relationship>> listRelationships(String familyId) async {
    final rows = await _client
        .from('relationships')
        .select()
        .eq('family_id', familyId);
    return (rows as List)
        .map((r) => Relationship.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> addRelationship({
    required String familyId,
    required String fromMember,
    required String toMember,
    required RelType type,
    RelSubtype subtype = RelSubtype.biological,
  }) async {
    await _client.from('relationships').insert({
      'family_id': familyId,
      'from_member': fromMember,
      'to_member': toMember,
      'type': type.name,
      'subtype': subtype.name,
    });
  }

  Future<void> deleteRelationship(String id) async {
    await _client.from('relationships').delete().eq('id', id);
  }
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(supabaseClientProvider));
});
