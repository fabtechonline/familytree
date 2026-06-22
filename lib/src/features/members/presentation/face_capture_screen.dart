import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

/// Full-screen camera with an oval face guide (bank-style). Returns the captured
/// photo bytes (centred-square, ~800px) via `Navigator.pop<Uint8List>`.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _camIndex = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initController();
    }
  }

  Future<void> _setup() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _error = 'Camera permission is needed to take a photo.');
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera found on this device.');
        return;
      }
      _camIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front);
      if (_camIndex < 0) _camIndex = 0;
      await _initController();
    } catch (e) {
      setState(() => _error = 'Could not open the camera: $e');
    }
  }

  Future<void> _initController() async {
    final controller = CameraController(
      _cameras[_camIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    await _controller?.dispose();
    setState(() {
      _controller = null;
      _camIndex = (_camIndex + 1) % _cameras.length;
    });
    await _initController();
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await c.takePicture();
      final raw = await shot.readAsBytes();
      final processed = _process(
          raw, _cameras[_camIndex].lensDirection == CameraLensDirection.front);
      if (!mounted) return;
      Navigator.pop<Uint8List>(context, processed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not capture: $e')));
    }
  }

  /// Bake orientation, un-mirror front shots, centre-crop to a square and
  /// downscale — a tidy headshot regardless of sensor size.
  Uint8List _process(Uint8List bytes, bool front) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    var im = img.bakeOrientation(decoded);
    if (front) im = img.flipHorizontal(im);
    final side = math.min(im.width, im.height);
    im = img.copyCrop(im,
        x: (im.width - side) ~/ 2, y: (im.height - side) ~/ 2,
        width: side, height: side);
    im = img.copyResize(im, width: 800, height: 800);
    return Uint8List.fromList(img.encodeJpg(im, quality: 88));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final preview = controller.value.previewSize!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed preview.
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: preview.height,
              height: preview.width,
              child: CameraPreview(controller),
            ),
          ),
          // Oval guide.
          const Positioned.fill(child: CustomPaint(painter: _OvalGuidePainter())),
          // Top controls.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (_cameras.length > 1)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.cameraswitch_rounded),
                      onPressed: _flip,
                    ),
                ],
              ),
            ),
          ),
          // Hint + capture button.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Fit the face inside the oval',
                          style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _busy ? null : _capture,
                      child: Container(
                        height: 76,
                        width: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white70, width: 4),
                        ),
                        child: _busy
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(strokeWidth: 3))
                            : const Icon(Icons.camera_alt_rounded,
                                color: Colors.black87, size: 32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OvalGuidePainter extends CustomPainter {
  const _OvalGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.72,
      height: size.height * 0.46,
    );
    // Dim everything outside the oval.
    final scrim = Path()..addRect(Offset.zero & size);
    final hole = Path()..addOval(oval);
    canvas.drawPath(
      Path.combine(PathOperation.difference, scrim, hole),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    // Oval outline.
    canvas.drawOval(
      oval,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
