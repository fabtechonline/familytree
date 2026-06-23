/// Platform-dispatching facade for [FaceRecognizer].
///
/// On mobile/desktop (where `dart:io` and `dart:ffi` exist) this resolves to
/// the real TFLite + ML Kit implementation in `face_recognizer_io.dart`. On the
/// web — where `tflite_flutter` (dart:ffi) cannot compile — it resolves to the
/// no-op stub in `face_recognizer_web.dart`, so the rest of the app still builds
/// and on-device face recognition simply returns no match.
library;

export 'face_recognizer_web.dart'
    if (dart.library.io) 'face_recognizer_io.dart';
