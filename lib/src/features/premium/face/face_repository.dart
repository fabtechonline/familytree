import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_providers.dart';
import '../../members/domain/member.dart';
import 'face_recognizer.dart';

class FaceMatch {
  const FaceMatch({required this.memberId, required this.distance});
  final String memberId;
  final double distance;

  /// MobileFaceNet L2 distance threshold for a confident match.
  bool get isConfident => distance <= 0.9;
  bool get isMaybe => distance > 0.9 && distance <= 1.1;
}

class FaceRepository {
  FaceRepository(this._client, this._recognizer);

  final SupabaseClient _client;
  final FaceRecognizer _recognizer;

  String _vec(List<double> e) => '[${e.join(',')}]';

  Future<void> setConsent(String familyId, bool enabled) async {
    await _client.rpc('set_face_recognition',
        params: {'p_family': familyId, 'p_enabled': enabled});
  }

  /// Computes and stores embeddings for every member that has a photo.
  /// Returns how many were successfully indexed.
  Future<int> indexFamily(String familyId, List<Member> members) async {
    var count = 0;
    for (final m in members) {
      final url = m.photoUrl;
      if (url == null || url.isEmpty) continue;
      final bytes = await FaceRecognizer.downloadBytes(url);
      if (bytes == null) continue;
      final emb = await _recognizer.embedFromBytes(bytes);
      if (emb == null) continue;
      await _client.rpc('upsert_face_embedding', params: {
        'p_member': m.id,
        'p_family': familyId,
        'p_embedding': _vec(emb),
      });
      count++;
    }
    return count;
  }

  /// Embeds the face in [path] and returns the nearest member, or null.
  Future<FaceMatch?> matchFile(String familyId, String path) async {
    final emb = await _recognizer.embedFromFile(path);
    if (emb == null) return null;
    final res = await _client
        .rpc('match_face', params: {'p_family': familyId, 'p_embedding': _vec(emb)});
    final list = res as List;
    if (list.isEmpty) return null;
    final row = list.first as Map<String, dynamic>;
    return FaceMatch(
      memberId: row['member_id'] as String,
      distance: (row['distance'] as num).toDouble(),
    );
  }
}

final faceRecognizerProvider = Provider<FaceRecognizer>((ref) {
  final r = FaceRecognizer();
  ref.onDispose(r.dispose);
  return r;
});

final faceRepositoryProvider = Provider<FaceRepository>((ref) {
  return FaceRepository(
      ref.watch(supabaseClientProvider), ref.watch(faceRecognizerProvider));
});
