import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../core/blink_detection/blink_detector.dart';

class CameraFeed extends StatefulWidget {
  final BlinkDetector blinkDetector;

  const CameraFeed({super.key, required this.blinkDetector});

  @override
  State<CameraFeed> createState() => _CameraFeedState();
}

class _CameraFeedState extends State<CameraFeed> {
  CameraController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    // TODO: wire mediapipe_face_mesh to _controller image stream and call
    // widget.blinkDetector.processFrame(leftEye: ..., rightEye: ...)
    // on each frame where a face is detected.

    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CameraPreview(_controller!),
    );
  }
}
