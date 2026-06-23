import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';

/// Premium: call the `generate-avatar` edge function to analyze a member's photo
/// with Claude vision and return a matching DiceBear avatar config map. The
/// Anthropic key lives server-side; this only sends the user's JWT + memberId.
Future<Map<String, dynamic>> generateAvatarFromPhoto(
    SupabaseClient client, String memberId) async {
  final jwt = client.auth.currentSession?.accessToken;
  if (jwt == null) throw Exception('Not signed in');
  final url = '${AppConfig.supabaseUrl}/functions/v1/generate-avatar';

  final http = HttpClient();
  try {
    final req = await http.postUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $jwt');
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.add(utf8.encode(jsonEncode({'memberId': memberId})));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode != 200) {
      throw Exception('Generation failed: ${resp.statusCode} $body');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    http.close();
  }
}
