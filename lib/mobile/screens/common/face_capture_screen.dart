import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Full-screen camera view that automatically detects & captures the user's face.
/// Returns the captured image file path via `Navigator.pop(context, path)`.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  // ─── Colors ───
  static const Color _primary = Color(0xFF10B981);

  // ─── Camera ───
  CameraController? _controller;
  CameraDescription? _frontCamera;
  bool _isCameraReady = false;

  // ─── Face Detection ───
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool _isProcessing = false;
  bool _faceDetected = false;
  int _stableFrames = 0;
  static const int _requiredStableFrames = 12; // ~2 sec at ~6-7 fps

  // ─── Capture ───
  bool _isCapturing = false;
  String _statusText = 'Initializing camera…';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ────────────────────────────────────────────────────────────
  // Camera initialisation
  // ────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _frontCamera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
        _statusText = 'Position your face in the circle';
      });

      // Begin streaming frames for face detection
      await _controller!.startImageStream(_onCameraFrame);
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Camera not available');
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  // Frame processing
  // ────────────────────────────────────────────────────────────
  void _onCameraFrame(CameraImage image) {
    if (_isProcessing || _isCapturing) return;
    _isProcessing = true;
    _detectFace(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _detectFace(CameraImage image) async {
    final inputImage = _convertCameraImage(image);
    if (inputImage == null) return;

    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted || _isCapturing) return;

      if (faces.length == 1) {
        _stableFrames++;
        final progress = (_stableFrames / _requiredStableFrames).clamp(
          0.0,
          1.0,
        );

        setState(() {
          _faceDetected = true;
          _progress = progress;
          _statusText = _stableFrames < _requiredStableFrames
              ? 'Face detected — hold still…'
              : 'Capturing…';
        });

        if (_stableFrames >= _requiredStableFrames) {
          _autoCapture();
        }
      } else {
        _stableFrames = 0;
        if (mounted) {
          setState(() {
            _faceDetected = false;
            _progress = 0.0;
            _statusText = faces.isEmpty
                ? 'Position your face in the circle'
                : 'Only one face should be visible';
          });
        }
      }
    } catch (_) {
      // Skip unprocessable frames
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (_frontCamera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      _frontCamera!.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // Fallback for Android NV21
    final imageFormat =
        format ?? (Platform.isAndroid ? InputImageFormat.nv21 : null);
    if (imageFormat == null) return null;

    final bytesBuilder = BytesBuilder();
    for (final plane in image.planes) {
      bytesBuilder.add(plane.bytes);
    }

    return InputImage.fromBytes(
      bytes: Uint8List.fromList(bytesBuilder.toBytes()),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: imageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Capture
  // ────────────────────────────────────────────────────────────
  Future<void> _autoCapture() async {
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      await _controller!.stopImageStream();
      final xFile = await _controller!.takePicture();
      if (mounted) Navigator.of(context).pop(xFile.path);
    } catch (e) {
      _isCapturing = false;
      _stableFrames = 0;
      if (mounted) {
        setState(() => _statusText = 'Capture failed — try again');
        _controller?.startImageStream(_onCameraFrame);
      }
    }
  }

  Future<void> _manualCapture() async {
    if (_isCapturing || _controller == null) return;
    _isCapturing = true;
    setState(() => _statusText = 'Capturing…');

    try {
      await _controller!.stopImageStream();
      final xFile = await _controller!.takePicture();
      if (mounted) Navigator.of(context).pop(xFile.path);
    } catch (e) {
      _isCapturing = false;
      if (mounted) {
        setState(() => _statusText = 'Capture failed — try again');
        _controller?.startImageStream(_onCameraFrame);
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  // Dispose
  // ────────────────────────────────────────────────────────────
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isCameraReady && _controller != null)
            Center(
              child: Transform.scale(
                scaleX: -1, // mirror front camera
                child: AspectRatio(
                  aspectRatio: 1 / _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: _primary)),

          // Dark overlay with oval cutout
          CustomPaint(
            painter: _FaceOverlayPainter(
              faceDetected: _faceDetected,
              progress: _progress,
              primaryColor: _primary,
            ),
            size: Size.infinite,
          ),

          // ─── Top bar ───
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      'Face Verification',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // ─── Bottom status & capture button ───
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _faceDetected
                          ? _primary.withValues(alpha: 0.9)
                          : Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _faceDetected ? Icons.check_circle : Icons.face,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Manual shutter button
                  GestureDetector(
                    onTap: _isCameraReady && !_isCapturing
                        ? _manualCapture
                        : null,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCameraReady ? Colors.white : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Auto-captures when face is detected',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overlay painter with oval cutout & progress ring ───
class _FaceOverlayPainter extends CustomPainter {
  final bool faceDetected;
  final double progress;
  final Color primaryColor;

  _FaceOverlayPainter({
    required this.faceDetected,
    required this.progress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final rx = size.width * 0.32;
    final ry = rx * 1.25;

    final ovalRect = Rect.fromCenter(
      center: center,
      width: rx * 2,
      height: ry * 2,
    );

    // 1) Semi-transparent background with punched-out oval
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawOval(ovalRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // 2) Oval border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = faceDetected
          ? primaryColor
          : Colors.white.withValues(alpha: 0.6);
    canvas.drawOval(ovalRect, borderPaint);

    // 3) Progress arc (fills as face stays stable)
    if (progress > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = primaryColor;

      canvas.drawArc(
        ovalRect.inflate(4),
        -1.5708, // -π/2 → start from top
        progress * 6.2832, // 2π
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter old) =>
      old.faceDetected != faceDetected || old.progress != progress;
}
