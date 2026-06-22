import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_providers.dart';

class Capsule {
  const Capsule({
    required this.id,
    required this.title,
    this.body,
    required this.unlockAt,
    required this.authorId,
    required this.locked,
  });

  final String id;
  final String title;
  final String? body;
  final DateTime unlockAt;
  final String authorId;
  final bool locked;

  factory Capsule.fromMap(Map<String, dynamic> m) => Capsule(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        unlockAt: DateTime.parse(m['unlock_at'] as String),
        authorId: m['author_id'] as String,
        locked: m['locked'] as bool? ?? true,
      );
}

class CapsuleRepository {
  CapsuleRepository(this._client);
  final SupabaseClient _client;

  Future<List<Capsule>> list(String familyId) async {
    final rows = await _client.rpc('list_capsules', params: {'p_family': familyId});
    return (rows as List)
        .map((r) => Capsule.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required String familyId,
    required String title,
    String? body,
    required DateTime unlockAt,
  }) async {
    await _client.from('legacy_capsules').insert({
      'family_id': familyId,
      'author_id': _client.auth.currentUser?.id,
      'title': title,
      'body': body,
      'unlock_at': unlockAt.toIso8601String(),
    });
  }

  Future<void> delete(String id) async {
    await _client.from('legacy_capsules').delete().eq('id', id);
  }
}

final capsuleRepositoryProvider = Provider<CapsuleRepository>((ref) {
  return CapsuleRepository(ref.watch(supabaseClientProvider));
});

final capsulesProvider =
    FutureProvider.family<List<Capsule>, String>((ref, familyId) async {
  return ref.watch(capsuleRepositoryProvider).list(familyId);
});
