import 'package:flutter/foundation.dart';

/// Web stub for [FaceRecognizer].
///
/// On-device face recognition relies on `tflite_flutter` (dart:ffi) and ML Kit,
/// neither of which is available on the web. This stub keeps the public API
/// identical so [FaceRepository] and its screens compile and run on web; every
/// embedding call simply returns `null` (treated everywhere as "no face found"),
/// which gracefully disables the point-and-recognise feature in the browser.
class FaceRecognizer {
  /// No embedding on web — always returns null ("no face found").
  Future<List<double>?> embedFromFile(String path) async => null;

  /// No embedding on web — always returns null ("no face found").
  Future<List<double>?> embedFromBytes(Uint8List bytes) async => null;

  /// Not used on web (indexing runs on-device); returns null.
  static Future<Uint8List?> downloadBytes(String url) async => null;

  void dispose() {}
}
