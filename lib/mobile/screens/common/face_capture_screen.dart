import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Full-screen camera view that automatically detects & captures the user's face.
/// The face must be properly centered within the oval guide for 3 seconds before capture.
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
  static const Color _warningColor = Color(0xFFEF4444);

  // ─── Camera ───
  CameraController? _controller;
  CameraDescription? _frontCamera;
  bool _isCameraReady = false;

  // ─── Face Detection ───
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool _isProcessing = false;
  bool _faceDetected = false;
  bool _faceCentered = false;

  // ─── Countdown Timer ───
  Timer? _countdownTimer;
  int _countdownSeconds = 3;
  bool _countdownActive = false;

  // ─── Capture ───
  bool _isCapturing = false;
  String _statusText = 'Initializing camera…';
  String _guidanceText = '';
  double _progress = 0.0;

  // ─── Oval Guide dimensions (fraction of screen) ───
  // These match the painter
  static const double _ovalCenterYFraction = 0.38;
  static const double _ovalRadiusXFraction = 0.32;
  static const double _ovalRadiusYMultiplier = 1.25;

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
        _guidanceText = 'Center your face within the oval guide';
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
        final face = faces.first;
        final isCentered = _isFaceCenteredInOval(
          face,
          imageWidth: image.width.toDouble(),
          imageHeight: image.height.toDouble(),
        );

        setState(() {
          _faceDetected = true;
          _faceCentered = isCentered;
        });

        if (isCentered) {
          if (!_countdownActive) {
            _startCountdown();
          }
          setState(() {
            _statusText = 'Hold still — $_countdownSeconds';
            _guidanceText = 'Face centered ✓ Stay steady!';
            _progress = (3 - _countdownSeconds) / 3.0;
          });
        } else {
          // Face detected but not centered — reset countdown
          _resetCountdown();
          setState(() {
            _statusText = 'Center your face';
            _guidanceText = _getCenteringGuidance(face, image.width.toDouble(), image.height.toDouble());
            _progress = 0.0;
          });
        }
      } else {
        // No face or multiple faces
        _resetCountdown();
        if (mounted) {
          setState(() {
            _faceDetected = false;
            _faceCentered = false;
            _progress = 0.0;
            _statusText = faces.isEmpty
                ? 'Position your face in the circle'
                : 'Only one face should be visible';
            _guidanceText = faces.isEmpty
                ? 'Move closer and center your face'
                : 'Make sure only your face is visible';
          });
        }
      }
    } catch (_) {
      // Skip unprocessable frames
    }
  }

  // ────────────────────────────────────────────────────────────
  // Face centering check
  // ────────────────────────────────────────────────────────────
  bool _isFaceCenteredInOval(
    Face face, {
    required double imageWidth,
    required double imageHeight,
  }) {
    // Get the face bounding box center (in image coordinates)
    final faceRect = face.boundingBox;
    final faceCenterX = faceRect.center.dx / imageWidth;
    final faceCenterY = faceRect.center.dy / imageHeight;

    // The oval center in normalized coords
    // Note: front camera is mirrored, so X is flipped
    const ovalCenterX = 0.5;
    const ovalCenterY = _ovalCenterYFraction;

    // Allowable tolerance (percentage of screen)
    const toleranceX = 0.18;
    const toleranceY = 0.15;

    final dx = (faceCenterX - ovalCenterX).abs();
    final dy = (faceCenterY - ovalCenterY).abs();

    // Also check face size — too small means too far away
    final faceWidthRatio = faceRect.width / imageWidth;

    // Face should fill at least ~25% of the oval width
    final minFaceWidth = _ovalRadiusXFraction * 0.6;
    // Face shouldn't be too big (too close)
    final maxFaceWidth = _ovalRadiusXFraction * 2.2;

    if (faceWidthRatio < minFaceWidth || faceWidthRatio > maxFaceWidth) {
      return false;
    }

    return dx < toleranceX && dy < toleranceY;
  }

  String _getCenteringGuidance(Face face, double imageWidth, double imageHeight) {
    final faceRect = face.boundingBox;
    final faceCenterX = faceRect.center.dx / imageWidth;
    final faceCenterY = faceRect.center.dy / imageHeight;
    final faceWidthRatio = faceRect.width / imageWidth;

    final minFaceWidth = _ovalRadiusXFraction * 0.6;
    final maxFaceWidth = _ovalRadiusXFraction * 2.2;

    if (faceWidthRatio < minFaceWidth) {
      return 'Move closer to the camera';
    }
    if (faceWidthRatio > maxFaceWidth) {
      return 'Move further from the camera';
    }

    const ovalCenterX = 0.5;
    const ovalCenterY = _ovalCenterYFraction;

    final dx = faceCenterX - ovalCenterX;
    final dy = faceCenterY - ovalCenterY;

    // Front camera is mirrored, so directions are flipped for X
    if (dx.abs() > dy.abs()) {
      return dx > 0 ? 'Move your face left' : 'Move your face right';
    } else {
      return dy > 0 ? 'Move your face up' : 'Move your face down';
    }
  }

  // ────────────────────────────────────────────────────────────
  // Countdown Timer
  // ────────────────────────────────────────────────────────────
  void _startCountdown() {
    if (_countdownActive) return;
    _countdownActive = true;
    _countdownSeconds = 3;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownSeconds--;
        _progress = (3 - _countdownSeconds) / 3.0;
        if (_countdownSeconds > 0) {
          _statusText = 'Capturing in $_countdownSeconds…';
        } else {
          _statusText = 'Capturing…';
        }
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _autoCapture();
      }
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownActive = false;
    _countdownSeconds = 3;
  }

  // ────────────────────────────────────────────────────────────
  // Image conversion
  // ────────────────────────────────────────────────────────────
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
      _resetCountdown();
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
    _countdownTimer?.cancel();
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
            const Center(child: AppShimmerLoader(color: _primary)),

          // Dark overlay with oval cutout
          CustomPaint(
            painter: _FaceOverlayPainter(
              faceDetected: _faceDetected,
              faceCentered: _faceCentered,
              progress: _progress,
              primaryColor: _primary,
              warningColor: _warningColor,
            ),
            size: Size.infinite,
          ),

          // ─── Countdown number in the center ───
          if (_countdownActive && _countdownSeconds > 0)
            Positioned(
              top: MediaQuery.of(context).size.height * _ovalCenterYFraction - 40,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_countdownSeconds),
                  tween: Tween(begin: 1.5, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primary.withValues(alpha: 0.85),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$_countdownSeconds',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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

          // ─── Bottom status & guidance ───
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
                      color: _faceCentered
                          ? _primary.withValues(alpha: 0.9)
                          : (_faceDetected
                              ? _warningColor.withValues(alpha: 0.85)
                              : Colors.black54),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _faceCentered
                              ? Icons.check_circle
                              : (_faceDetected ? Icons.warning_rounded : Icons.face),
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
                  const SizedBox(height: 12),

                  // Guidance text
                  if (_guidanceText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _guidanceText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Info text
                  Text(
                    'Auto-captures when face is centered for 3 seconds',
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
  final bool faceCentered;
  final double progress;
  final Color primaryColor;
  final Color warningColor;

  _FaceOverlayPainter({
    required this.faceDetected,
    required this.faceCentered,
    required this.progress,
    required this.primaryColor,
    required this.warningColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height * _FaceCaptureScreenState._ovalCenterYFraction,
    );
    final rx = size.width * _FaceCaptureScreenState._ovalRadiusXFraction;
    final ry = rx * _FaceCaptureScreenState._ovalRadiusYMultiplier;

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

    // 2) Oval border — green if centered, orange/red if detected but not centered, white if no face
    final Color borderColor;
    if (faceCentered) {
      borderColor = primaryColor;
    } else if (faceDetected) {
      borderColor = warningColor;
    } else {
      borderColor = Colors.white.withValues(alpha: 0.6);
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = borderColor;
    canvas.drawOval(ovalRect, borderPaint);

    // 3) Corner brackets for centering guide
    _drawCornerBrackets(canvas, ovalRect, borderColor);

    // 4) Progress arc (fills as countdown proceeds)
    if (progress > 0 && faceCentered) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = primaryColor;

      canvas.drawArc(
        ovalRect.inflate(6),
        -1.5708, // -π/2 → start from top
        progress * 6.2832, // 2π
        false,
        arcPaint,
      );
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect ovalRect, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color;

    const bracketLength = 24.0;
    const offset = 8.0;

    // Top-left
    canvas.drawLine(
      Offset(ovalRect.left + offset, ovalRect.top - offset),
      Offset(ovalRect.left + offset + bracketLength, ovalRect.top - offset),
      paint,
    );
    canvas.drawLine(
      Offset(ovalRect.left + offset, ovalRect.top - offset),
      Offset(ovalRect.left + offset, ovalRect.top - offset + bracketLength),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(ovalRect.right - offset, ovalRect.top - offset),
      Offset(ovalRect.right - offset - bracketLength, ovalRect.top - offset),
      paint,
    );
    canvas.drawLine(
      Offset(ovalRect.right - offset, ovalRect.top - offset),
      Offset(ovalRect.right - offset, ovalRect.top - offset + bracketLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(ovalRect.left + offset, ovalRect.bottom + offset),
      Offset(ovalRect.left + offset + bracketLength, ovalRect.bottom + offset),
      paint,
    );
    canvas.drawLine(
      Offset(ovalRect.left + offset, ovalRect.bottom + offset),
      Offset(ovalRect.left + offset, ovalRect.bottom + offset - bracketLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(ovalRect.right - offset, ovalRect.bottom + offset),
      Offset(ovalRect.right - offset - bracketLength, ovalRect.bottom + offset),
      paint,
    );
    canvas.drawLine(
      Offset(ovalRect.right - offset, ovalRect.bottom + offset),
      Offset(ovalRect.right - offset, ovalRect.bottom + offset - bracketLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter old) =>
      old.faceDetected != faceDetected ||
      old.faceCentered != faceCentered ||
      old.progress != progress;
}
