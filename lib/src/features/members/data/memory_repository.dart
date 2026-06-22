import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';
import '../domain/memory.dart';

class MemoryRepository {
  MemoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<Memory>> list(String memberId) async {
    final rows = await _client
        .from('member_media')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Memory.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Uploads a photo to the member-photos bucket (under a `memories` subfolder)
  /// and records it. The first path segment stays the family id so storage RLS
  /// authorizes by family role.
  Future<void> add({
    required String familyId,
    required String memberId,
    required Uint8List bytes,
    String? caption,
  }) async {
    final path =
        '$familyId/$memberId/memories/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('member-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    final url = _client.storage.from('member-photos').getPublicUrl(path);
    await _client.from('member_media').insert({
      'family_id': familyId,
      'member_id': memberId,
      'uploaded_by': _client.auth.currentUser?.id,
      'media_url': url,
      'caption': caption,
    });
  }

  Future<void> delete(String id) async {
    await _client.from('member_media').delete().eq('id', id);
  }
}

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(ref.watch(supabaseClientProvider));
});

final memoriesProvider =
    FutureProvider.family<List<Memory>, String>((ref, memberId) async {
  return ref.watch(memoryRepositoryProvider).list(memberId);
});
