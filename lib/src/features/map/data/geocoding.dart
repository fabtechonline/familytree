import 'dart:convert';
import 'dart:io';

/// A geocoded coordinate.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Geocode a free-text place (address or birthplace) to coordinates via the free
/// OpenStreetMap Nominatim service. Best-effort: returns null on any failure so
/// callers never block a save. A descriptive User-Agent satisfies Nominatim's
/// usage policy.
Future<GeoPoint?> geocode(String query) async {
  final q = query.trim();
  if (q.isEmpty) return null;
  final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&limit=1'
      '&email=info@riza.co.za&q=${Uri.encodeQueryComponent(q)}');
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, 'RizaFamilyApp/1.0 (info@riza.co.za)');
    final resp = await req.close();
    if (resp.statusCode != 200) return null;
    final body = await resp.transform(utf8.decoder).join();
    final data = jsonDecode(body) as List;
    if (data.isEmpty) return null;
    final r = data.first as Map<String, dynamic>;
    final lat = double.tryParse(r['lat'] as String? ?? '');
    final lng = double.tryParse(r['lon'] as String? ?? '');
    if (lat == null || lng == null) return null;
    return GeoPoint(lat, lng);
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}
