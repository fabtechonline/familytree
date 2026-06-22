import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';

/// Uploads a member image by (1) asking the `upload-photo` Edge Function for a
/// signed upload URL (which authorizes the caller's family role server-side),
/// then (2) PUTting the bytes directly to storage. This avoids the storage-api
/// rejecting end-user JWTs and avoids sending the photo through the function.
///
/// [folder] is 'avatar' or 'memories'. Returns the public URL.
Future<String> uploadMemberImage(
  SupabaseClient client, {
  required String familyId,
  required String memberId,
  required String folder,
  required Uint8List bytes,
  String contentType = 'image/jpeg',
}) async {
  final res = await client.functions.invoke('upload-photo', body: {
    'familyId': familyId,
    'memberId': memberId,
    'folder': folder,
  });
  if (res.status != 200) {
    final msg = res.data is Map ? res.data['error'] : null;
    throw Exception(msg ?? 'Could not prepare upload (${res.status})');
  }
  final data = res.data as Map;
  final signedUrl = data['signedUrl'] as String;
  final publicUrl = data['publicUrl'] as String;

  final httpClient = HttpClient();
  try {
    final req = await httpClient.putUrl(Uri.parse(signedUrl));
    req.headers.set('apikey', AppConfig.supabasePublishableKey);
    req.headers.set('x-upsert', 'true');
    req.headers.set(HttpHeaders.contentTypeHeader, contentType);
    req.add(bytes);
    final resp = await req.close();
    await resp.drain<void>();
    if (resp.statusCode != 200) {
      throw Exception('Upload failed (${resp.statusCode})');
    }
  } finally {
    httpClient.close();
  }
  return publicUrl;
}
