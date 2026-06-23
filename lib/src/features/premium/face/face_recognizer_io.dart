import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device face embedding: detects the largest face with ML Kit, crops it,
/// and runs MobileFaceNet (TFLite) to produce a 192-d embedding. Nothing leaves
/// the device.
class FaceRecognizer {
  Interpreter? _interpreter;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  Future<void> _ensureModel() async {
    _interpreter ??=
        await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
  }

  /// 192-d embedding for the largest face in [path], or null if no face found.
  Future<List<double>?> embedFromFile(String path) async {
    await _ensureModel();
    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) return null;

    var decoded = img.decodeImage(await File(path).readAsBytes());
    if (decoded == null) return null;
    decoded = img.bakeOrientation(decoded);

    faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
        .compareTo(a.boundingBox.width * a.boundingBox.height));
    final box = faces.first.boundingBox;
    final x = box.left.clamp(0, decoded.width - 1).toInt();
    final y = box.top.clamp(0, decoded.height - 1).toInt();
    final w = box.width.clamp(1, decoded.width - x).toInt();
    final h = box.height.clamp(1, decoded.height - y).toInt();

    final crop = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    final face = img.copyResize(crop, width: 112, height: 112);
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
    _detector.close();
  }
}
