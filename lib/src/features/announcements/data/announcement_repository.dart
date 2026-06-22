import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';
import '../domain/announcement.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._client);

  final SupabaseClient _client;

  Future<List<Announcement>> list(String familyId) async {
    final rows = await _client
        .from('announcements')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((r) => Announcement.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> post({
    required String familyId,
    required String type,
    required String title,
    String? body,
  }) async {
    await _client.from('announcements').insert({
      'family_id': familyId,
      'author_id': _client.auth.currentUser?.id,
      'type': type,
      'title': title,
      'body': body,
    });
  }

  Future<void> delete(String id) async {
    await _client.from('announcements').delete().eq('id', id);
  }
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(ref.watch(supabaseClientProvider));
});

final announcementsProvider =
    FutureProvider.family<List<Announcement>, String>((ref, familyId) async {
  return ref.watch(announcementRepositoryProvider).list(familyId);
});
