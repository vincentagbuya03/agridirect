import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Full-screen camera view that automatically detects & captures the user's face.
/// Supports both smooth 1.5s auto-capture when aligned and an instant manual shutter button.
/// Returns the captured image file path via `Navigator.pop(context, path)`.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ─── Colors ───
  static const Color _primary = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);

  // ─── Camera ───
  CameraController? _controller;
  CameraDescription? _frontCamera;
  bool _isCameraReady = false;
  bool _fillLightEnabled = false;

  // ─── Face Detection ───
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );
  bool _isProcessing = false;
  bool _faceDetected = false;
  bool _faceCentered = false;

  // Stability tracker to prevent noisy frame resets
  int _stableFrameCount = 0;
  DateTime? _lastUnstableTime;

  // ─── Countdown & Animation ───
  Timer? _countdownTimer;
  double _countdownProgress = 0.0; // 0.0 to 1.0
  bool _countdownActive = false;
  static const int _totalCountdownMs = 1500;
  static const int _tickIntervalMs = 50;

  // ─── Capture State ───
  bool _isCapturing = false;
  String _statusText = 'Position your face in the oval';
  String _guidanceText = 'Align your face inside the guide';

  // ─── Oval Guide dimensions (fraction of screen) ───
  static const double _ovalCenterYFraction = 0.36;
  static const double _ovalRadiusXFraction = 0.33;
  static const double _ovalRadiusYMultiplier = 1.30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      setState(() => _isCameraReady = false);
      cameraController.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ────────────────────────────────────────────────────────────
  // Camera Initialization
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
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
        _statusText = 'Position your face in the oval';
        _guidanceText = 'Center your face within the guide';
      });

      // Begin streaming frames for face detection
      await _controller!.startImageStream(_onCameraFrame);
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Camera unavailable');
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
        final isClear = _hasClearFace(face);

        final isFullyReady = isCentered && isClear;

        if (isFullyReady) {
          _stableFrameCount++;
          _lastUnstableTime = null;
        } else {
          // Allow a brief 250ms grace period for micro-jitters
          final now = DateTime.now();
          if (_lastUnstableTime == null) {
            _lastUnstableTime = now;
          } else if (now.difference(_lastUnstableTime!).inMilliseconds > 250) {
            _stableFrameCount = 0;
          }
        }

        final isStable = _stableFrameCount >= 2;

        setState(() {
          _faceDetected = true;
          _faceCentered = isFullyReady;
        });

        if (isFullyReady && isStable) {
          if (!_countdownActive) {
            _startSmoothCountdown();
          }
          setState(() {
            _statusText = 'Hold steady...';
            _guidanceText = 'Perfect! Capturing automatically';
          });
        } else if (!isFullyReady) {
          if (_lastUnstableTime != null &&
              DateTime.now().difference(_lastUnstableTime!).inMilliseconds > 250) {
            _resetCountdown();
          }
          setState(() {
            if (!isCentered) {
              _statusText = 'Center your face';
              _guidanceText = _getCenteringGuidance(
                face,
                image.width.toDouble(),
                image.height.toDouble(),
              );
            } else {
              _statusText = 'Adjust position';
              _guidanceText = _getClearFaceGuidance(face);
            }
          });
        }
      } else {
        // No face or multiple faces
        _stableFrameCount = 0;
        _resetCountdown();
        if (mounted) {
          setState(() {
            _faceDetected = false;
            _faceCentered = false;
            _statusText = faces.isEmpty
                ? 'Position your face in the oval'
                : 'Only one person in frame';
            _guidanceText = faces.isEmpty
                ? 'Look directly into the camera'
                : 'Ensure only your face is visible';
          });
        }
      }
    } catch (_) {
      // Ignore transient frame errors
    }
  }

  // ────────────────────────────────────────────────────────────
  // Face Centering & Size Evaluation
  // ────────────────────────────────────────────────────────────
  bool _isFaceCenteredInOval(
    Face face, {
    required double imageWidth,
    required double imageHeight,
  }) {
    final faceRect = face.boundingBox;
    final faceCenterX = faceRect.center.dx / imageWidth;
    final faceCenterY = faceRect.center.dy / imageHeight;

    const ovalCenterX = 0.5;
    const ovalCenterY = _ovalCenterYFraction;

    // Generous tolerances to make capturing smooth
    const toleranceX = 0.22;
    const toleranceY = 0.20;

    final dx = (faceCenterX - ovalCenterX).abs();
    final dy = (faceCenterY - ovalCenterY).abs();

    final faceWidthRatio = faceRect.width / imageWidth;
    final minFaceWidth = _ovalRadiusXFraction * 0.45;
    final maxFaceWidth = _ovalRadiusXFraction * 2.6;

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

    final minFaceWidth = _ovalRadiusXFraction * 0.45;
    final maxFaceWidth = _ovalRadiusXFraction * 2.6;

    if (faceWidthRatio < minFaceWidth) {
      return 'Move slightly closer to the camera';
    }
    if (faceWidthRatio > maxFaceWidth) {
      return 'Move slightly further back';
    }

    const ovalCenterX = 0.5;
    const ovalCenterY = _ovalCenterYFraction;

    final dx = faceCenterX - ovalCenterX;
    final dy = faceCenterY - ovalCenterY;

    if (dx.abs() > dy.abs()) {
      return dx > 0 ? 'Move face slightly right' : 'Move face slightly left';
    } else {
      return dy > 0 ? 'Move face slightly up' : 'Move face slightly down';
    }
  }

  // ────────────────────────────────────────────────────────────
  // Face Clarity & Head Angle
  // ────────────────────────────────────────────────────────────
  bool _hasClearFace(Face face) {
    // Relaxed eye openness threshold (0.40) so outdoor sun or glasses reflection won't block users
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    if (leftEye != null && leftEye < 0.40) return false;
    if (rightEye != null && rightEye < 0.40) return false;

    // Generous head tilt angles
    final eulerX = (face.headEulerAngleX ?? 0).abs(); // Pitch (up/down)
    final eulerY = (face.headEulerAngleY ?? 0).abs(); // Yaw (left/right)
    final eulerZ = (face.headEulerAngleZ ?? 0).abs(); // Roll (tilt)

    if (eulerX > 22 || eulerY > 25 || eulerZ > 22) {
      return false;
    }

    return true;
  }

  String _getClearFaceGuidance(Face face) {
    final eulerX = (face.headEulerAngleX ?? 0).abs();
    final eulerY = (face.headEulerAngleY ?? 0).abs();
    final eulerZ = (face.headEulerAngleZ ?? 0).abs();

    if (eulerX > 22 || eulerY > 25 || eulerZ > 22) {
      return 'Look straight at the camera';
    }

    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    if ((leftEye != null && leftEye < 0.40) ||
        (rightEye != null && rightEye < 0.40)) {
      return 'Keep your eyes open';
    }

    return 'Please remove masks or face coverings';
  }

  // ────────────────────────────────────────────────────────────
  // Smooth Countdown Timer (1.5 seconds)
  // ────────────────────────────────────────────────────────────
  void _startSmoothCountdown() {
    if (_countdownActive) return;
    _countdownActive = true;
    _countdownProgress = 0.0;
    HapticFeedback.lightImpact();

    int elapsedMs = 0;
    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: _tickIntervalMs),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        elapsedMs += _tickIntervalMs;
        final progress = (elapsedMs / _totalCountdownMs).clamp(0.0, 1.0);

        setState(() {
          _countdownProgress = progress;
        });

        if (progress >= 1.0) {
          timer.cancel();
          _performCapture();
        }
      },
    );
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownActive = false;
    _countdownProgress = 0.0;
  }

  // ────────────────────────────────────────────────────────────
  // Image Conversion for ML Kit
  // ────────────────────────────────────────────────────────────
  InputImage? _convertCameraImage(CameraImage image) {
    if (_frontCamera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      _frontCamera!.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
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
  // Capture Execution (Auto or Manual)
  // ────────────────────────────────────────────────────────────
  Future<void> _performCapture() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) {
      return;
    }
    _isCapturing = true;
    _resetCountdown();
    HapticFeedback.mediumImpact();

    try {
      await _controller!.stopImageStream();
      final xFile = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(xFile.path);
      }
    } catch (e) {
      _isCapturing = false;
      _resetCountdown();
      if (mounted) {
        setState(() => _statusText = 'Capture failed — tap shutter to retry');
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
    final cameraController = _controller;
    _controller = null;
    _isCameraReady = false;
    cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // UI Builder
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_isCameraReady &&
              _controller != null &&
              _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            const Center(child: AppShimmerLoader(color: _primary)),

          // 2. Screen Fill Light Overlay (Soft white illumination for dark environments)
          if (_fillLightEnabled)
            Container(
              color: Colors.white.withValues(alpha: 0.35),
            ),

          // 3. Dark Overlay with Oval Cutout & Dynamic Progress Ring
          CustomPaint(
            painter: _FaceOverlayPainter(
              faceDetected: _faceDetected,
              faceCentered: _faceCentered,
              progress: _countdownProgress,
              primaryColor: _primary,
              warningColor: _warningColor,
            ),
            size: Size.infinite,
          ),

          // 4. Top Action Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),

                    // Header Title & Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            color: _faceCentered ? _primary : Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Face Verification',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Screen Fill Light Toggle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _fillLightEnabled = !_fillLightEnabled;
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _fillLightEnabled
                              ? Colors.amber.withValues(alpha: 0.85)
                              : Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _fillLightEnabled
                                ? Colors.amber
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          _fillLightEnabled
                              ? Icons.lightbulb_rounded
                              : Icons.lightbulb_outline_rounded,
                          color: _fillLightEnabled ? Colors.black : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Center Guidance Status Pill
          Positioned(
            top: size.height * _ovalCenterYFraction +
                (size.width * _ovalRadiusXFraction * _ovalRadiusYMultiplier) +
                20,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary Status Badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _faceCentered
                        ? _primary.withValues(alpha: 0.9)
                        : (_faceDetected
                            ? _warningColor.withValues(alpha: 0.9)
                            : Colors.black.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: _faceCentered
                            ? _primary.withValues(alpha: 0.4)
                            : Colors.black38,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _faceCentered
                            ? Icons.check_circle_rounded
                            : (_faceDetected
                                ? Icons.info_outline_rounded
                                : Icons.face_rounded),
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _statusText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Helpful Direction Prompt
                Text(
                  _guidanceText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),

          // 6. Bottom Controls: Manual Shutter & Quick Hint
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Manual Capture Button
                    GestureDetector(
                      onTap: _faceDetected || _faceCentered
                          ? _performCapture
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _faceCentered
                                ? _primary
                                : (_faceDetected
                                    ? Colors.white
                                    : Colors.white38),
                            width: 4,
                          ),
                          color: _faceCentered
                              ? _primary.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _faceCentered
                                  ? _primary
                                  : (_faceDetected
                                      ? Colors.white
                                      : Colors.white54),
                              boxShadow: [
                                if (_faceCentered)
                                  BoxShadow(
                                    color: _primary.withValues(alpha: 0.5),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: _faceCentered ? Colors.white : Colors.black87,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick User Hint
                    Text(
                      _countdownActive
                          ? 'Auto-capturing in a moment...'
                          : (_faceDetected
                              ? 'Tap button anytime to snap photo'
                              : 'Align face in oval to auto-capture'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white60,
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

// ─── Custom Painter with Smooth Progress Ring & Centering Brackets ───
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

    // 1. Semi-transparent dark mask with smooth oval cutout
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
    canvas.drawOval(ovalRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // 2. Oval Guide Outline
    final Color borderColor;
    if (faceCentered) {
      borderColor = primaryColor;
    } else if (faceDetected) {
      borderColor = warningColor;
    } else {
      borderColor = Colors.white.withValues(alpha: 0.45);
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = borderColor;
    canvas.drawOval(ovalRect, borderPaint);

    // 3. Precision Corner Brackets
    _drawCornerBrackets(canvas, ovalRect, borderColor);

    // 4. Smooth Circular Progress Ring around Oval
    if (progress > 0 && faceCentered) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..color = primaryColor;

      canvas.drawArc(
        ovalRect.inflate(8),
        -1.5708, // Start at 12 o'clock (-π/2)
        progress * 6.2832, // Sweep angle (2π)
        false,
        arcPaint,
      );
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect ovalRect, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..color = color;

    const bracketLength = 26.0;
    const offset = 10.0;

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
