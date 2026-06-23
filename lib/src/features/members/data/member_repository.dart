import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';
import '../domain/member.dart';
import '../domain/relationship.dart';
import 'photo_upload.dart';

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

  /// Set or clear (null) a member's illustrated avatar config.
  Future<void> setAvatarConfig(String memberId, Map<String, dynamic>? config) async {
    await _client.from('members').update({'avatar_config': config}).eq('id', memberId);
  }

  Future<void> deleteMember(String id) async {
    await _client.from('members').delete().eq('id', id);
  }

  /// Uploads a member photo to the `member-photos` bucket and returns its public
  /// URL. Path is `{familyId}/{memberId}/...` so storage RLS can authorize the
  /// write by family role. A timestamped filename avoids stale CDN caching.
  /// Uploads via the `upload-photo` Edge Function (server-side service-role
  /// write), since storage-api rejects end-user JWTs on this project. Returns
  /// the public URL.
  Future<String> uploadMemberPhoto({
    required String familyId,
    required String memberId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) {
    return uploadMemberImage(
      _client,
      familyId: familyId,
      memberId: memberId,
      folder: 'avatar',
      bytes: bytes,
      contentType: contentType,
    );
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

  /// Adds a relationship edge, skipping duplicates. A unique index prevents
  /// exact-direction duplicates; for spouse/partner unions we also skip the
  /// reverse direction (a↔b is the same union as b↔a).
  Future<void> addRelationship({
    required String familyId,
    required String fromMember,
    required String toMember,
    required RelType type,
    RelSubtype subtype = RelSubtype.biological,
  }) async {
    if (type == RelType.spouse || type == RelType.partner) {
      final existing = await _client
          .from('relationships')
          .select('id')
          .eq('family_id', familyId)
          .inFilter('type', ['spouse', 'partner']).or(
              'and(from_member.eq.$fromMember,to_member.eq.$toMember),'
              'and(from_member.eq.$toMember,to_member.eq.$fromMember)');
      if ((existing as List).isNotEmpty) return;
    }

    // ON CONFLICT DO NOTHING against the (family, from, to, type) unique index.
    await _client.from('relationships').upsert(
      {
        'family_id': familyId,
        'from_member': fromMember,
        'to_member': toMember,
        'type': type.name,
        'subtype': subtype.name,
      },
      onConflict: 'family_id,from_member,to_member,type',
      ignoreDuplicates: true,
    );
  }

  Future<void> deleteRelationship(String id) async {
    await _client.from('relationships').delete().eq('id', id);
  }

  /// Makes [newMemberId] a sibling of [siblingOfId] by giving the new member the
  /// same parents (siblings are derived from shared parents). If the sibling has
  /// no recorded parents yet, no edges are created.
  Future<void> linkSiblingByParents({
    required String familyId,
    required String newMemberId,
    required String siblingOfId,
  }) async {
    final rows = await _client
        .from('relationships')
        .select('from_member')
        .eq('family_id', familyId)
        .eq('type', 'parent')
        .eq('to_member', siblingOfId);

    for (final row in rows as List) {
      await addRelationship(
        familyId: familyId,
        fromMember: row['from_member'] as String,
        toMember: newMemberId,
        type: RelType.parent,
      );
    }
  }
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(supabaseClientProvider));
});
