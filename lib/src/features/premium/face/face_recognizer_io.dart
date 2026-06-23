import 'dart:io';

import 'package:flutter/foundation.dart';
// TEMP(sim): google_mlkit_face_detection disabled for iOS Simulator on Apple
// Silicon (no arm64 simulator slice). Face detection falls back to using the
// whole image. Re-enable the import + detector for device/release builds.
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device face embedding: detects the largest face with ML Kit, crops it,
/// and runs MobileFaceNet (TFLite) to produce a 192-d embedding. Nothing leaves
/// the device.
class FaceRecognizer {
  Interpreter? _interpreter;

  Future<void> _ensureModel() async {
    _interpreter ??=
        await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
  }

  /// 192-d embedding for the largest face in [path], or null if no face found.
  Future<List<double>?> embedFromFile(String path) async {
    await _ensureModel();

    var decoded = img.decodeImage(await File(path).readAsBytes());
    if (decoded == null) return null;
    decoded = img.bakeOrientation(decoded);

    // TEMP(sim): ML Kit face detection disabled on the iOS Simulator. Use the
    // whole image as the "face" region. Restore the FaceDetector-based crop
    // (largest bounding box) for device/release builds.
    final face = img.copyResize(decoded, width: 112, height: 112);
    return _embed(face);
  }

  /// Embed from raw image bytes (e.g. a downloaded member photo).
  Future<List<double>?> embedFromBytes(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(
        '${dir.path}/probe_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await f.writeAsBytes(bytes);
    try {
      return await embedFromFile(f.path);
    } finally {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  List<double> _embed(img.Image face) {
    final input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(112, (x) {
          final p = face.getPixel(x, y);
          return [
            (p.r - 128) / 128.0,
            (p.g - 128) / 128.0,
            (p.b - 128) / 128.0,
          ];
        }),
      ),
    );
    final output = List.generate(1, (_) => List.filled(192, 0.0));
    _interpreter!.run(input, output);
    return List<double>.from(output.first);
  }

  /// Downloads bytes from a public URL without extra packages.
  static Future<Uint8List?> downloadBytes(String url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      return await consolidateHttpClientResponseBytes(resp);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  void dispose() {
    _interpreter?.close();
    // TEMP(sim): _detector.close() removed while ML Kit is disabled.
  }
}
