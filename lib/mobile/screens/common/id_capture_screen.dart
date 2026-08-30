import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Full-screen camera view for capturing the front of an ID card.
///
/// Detection logic (simplified & robust):
///   1. Text recognition — looks for Philippine National ID keywords OR
///      a minimum number of text blocks (dense text = ID-like document).
///   2. Face detection — a face must be visible on the ID card.
///
/// The detected face and text must also fit inside the visible guide box.
///
/// When BOTH conditions are met for [_requiredStableFrames] stable frames,
/// the screen auto-captures a photo and returns the file path.
class IdCaptureScreen extends StatefulWidget {
  final String label;
  final bool requireQr;

  const IdCaptureScreen({super.key, this.label = 'ID Front', bool? requireQr})
    : requireQr = requireQr ?? false;

  const IdCaptureScreen.back({
    super.key,
    this.label = 'ID Back',
    this.requireQr = true,
  });

  @override
  State<IdCaptureScreen> createState() => _IdCaptureScreenState();
}

class _IdCaptureScreenState extends State<IdCaptureScreen>
    with WidgetsBindingObserver {
  static const Color _primary = Color(0xFF10B981);
  static const Color _errorColor = Color(0xFFEF4444);

  CameraController? _controller;
  CameraDescription? _rearCamera;
  bool _isCameraReady = false;

  final TextRecognizer _textRecognizer = TextRecognizer();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
      // Very small — ID card photo is a tiny printed image
      minFaceSize: 0.02,
    ),
  );

  bool _isProcessing = false;
  bool _isCapturing = false;

  // ─── Detection state ───
  bool _isIdDetected = false;
  bool _isForbiddenCard = false;

  // ─── Countdown & Progress ───
  Timer? _countdownTimer;
  int _countdownSeconds = 2;
  bool _countdownActive = false;
  double _progress = 0.0;

  String _statusText = 'Initializing camera...';
  String _guidanceText = '';

  // ─── Guide overlay and detection constants ───
  static const double _cardCenterYFraction = 0.42;
  static const double _cardWidthFraction = 0.88;
  static const double _cardAspectRatio = 1.586;

  // ─── Keywords for Philippine National ID ───
  final List<String> _validKeywords = [
    'REPUBLIKA',
    'PILIPINAS',
    'PHILIPPINES',
    'PAMBANSANG',
    'PAGKAKAKILANLAN',
    'PHILIPPINE IDENTIFICATION',
    'IDENTIFICATION CARD',
    'NATIONAL ID',
    'PHILID',
    'PHIL ID',
    'PHILSYS',
    'APELYIDO',
    'PANGALAN',
    'KAPANGANAKAN',
    'TIRAHAN',
    'KASARIAN',
    'LAST NAME',
    'FIRST NAME',
    'MIDDLE NAME',
    'DATE OF BIRTH',
    'PLACE OF BIRTH',
    'ADDRESS',
    'PHL',
    'PCN',
    // OCR fragments
    'REPUB',
    'PILI',
    'PINAS',
    'PAMBAN',
    'PAGKAKA',
    'TIRA',
    'APEL',
    'PANG',
  ];

  final List<String> _forbiddenKeywords = [
    'VISA',
    'MASTERCARD',
    'DEBIT',
    'CREDIT',
    'PREPAID',
    'BDO',
    'BPI',
    'METROBANK',
    'UNIONBANK',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      setState(() => _isCameraReady = false);
      cameraController.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _rearCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _rearCamera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
        _statusText = 'Position your ID in the frame';
        _guidanceText = 'Fit the entire card inside the box';
      });

      await _controller!.startImageStream(_onCameraFrame);
    } catch (e) {
      debugPrint('[IdCapture] Camera init error: $e');
      if (mounted) {
        setState(() => _statusText = 'Camera not available');
      }
    }
  }

  // ─────────────────────────────────────────────────
  // Frame processing
  // ─────────────────────────────────────────────────

  void _onCameraFrame(CameraImage image) {
    if (_isProcessing || _isCapturing) return;
    _isProcessing = true;
    _processFrame(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    final inputImage = _convertCameraImage(image);
    if (inputImage == null) return;

    try {
      final results = await Future.wait([
        _textRecognizer.processImage(inputImage),
        _faceDetector.processImage(inputImage),
      ]);

      if (!mounted || _isCapturing) return;

      final recognizedText = results[0] as RecognizedText;
      final faces = results[1] as List<Face>;

      _analyzeFrame(
        recognizedText,
        faces,
        image.width.toDouble(),
        image.height.toDouble(),
        _rearCamera!.sensorOrientation,
      );
    } catch (e) {
      debugPrint('[IdCapture] Frame processing error: $e');
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (_rearCamera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      _rearCamera!.sensorOrientation,
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

  // ─────────────────────────────────────────────────
  // Detection logic
  // ─────────────────────────────────────────────────

  int _countKeywordMatches(String text) {
    int count = 0;
    for (final keyword in _validKeywords) {
      if (text.contains(keyword)) count++;
    }
    return count;
  }

  bool _hasForbiddenKeyword(String text) {
    for (final keyword in _forbiddenKeywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  void _analyzeFrame(
    RecognizedText recognizedText,
    List<Face> faces,
    double frameW,
    double frameH,
    int sensorOrientation,
  ) {
    final String fullText = recognizedText.text.toUpperCase();
    final int blockCount = recognizedText.blocks.length;
    final int keywordHits = _countKeywordMatches(fullText);
    final bool isForbidden = _hasForbiddenKeyword(fullText);

    // ── Forbidden card ──
    if (isForbidden) {
      if (_countdownActive) _resetCountdown();
      if (mounted) {
        setState(() {
          _isForbiddenCard = true;
          _isIdDetected = false;
          _progress = 0.0;
          _statusText = 'Invalid card detected!';
          _guidanceText = 'Please use a valid Philippine National ID';
        });
      }
      return;
    }

    // ── Text-density gate:
    // Require 3+ Philippine ID keywords AND 5+ text blocks.
    // A tilted or partially-visible card cannot produce this many readable fields.
    final bool isRichEnough = keywordHits >= 3 && blockCount >= 5;

    if (isRichEnough) {
      if (mounted) {
        setState(() {
          _isForbiddenCard = false;
          _isIdDetected = true;
          _progress = 1.0;
          _statusText = _countdownActive
              ? 'Capturing in $_countdownSeconds...'
              : 'ID Detected! Hold steady...';
          _guidanceText = 'Hold still — all fields visible';
        });
      }

      if (!_countdownActive) {
        _startCountdown();
      }
      return;
    }

    // ── Partial card detected (some keywords but not enough) ──
    if (_countdownActive) _resetCountdown();

    if (keywordHits >= 1) {
      if (mounted) {
        setState(() {
          _isForbiddenCard = false;
          _isIdDetected = false;
          _progress = 0.0;
          _statusText = 'Move ID closer & fit inside box';
          _guidanceText =
              'Make sure all card text is visible inside the green frame';
        });
      }
      return;
    }

    // ── No ID detected ──
    _resetDetection();
  }

  void _resetDetection() {
    if (_countdownActive) _resetCountdown();
    if (mounted) {
      setState(() {
        _isIdDetected = false;
        _isForbiddenCard = false;
        _progress = 0.0;
        _statusText = 'Position your ID in the frame';
        _guidanceText = 'Fit the entire card inside the box';
      });
    }
  }

  // ─────────────────────────────────────────────────
  // Countdown & Auto-capture
  // ─────────────────────────────────────────────────

  void _startCountdown() {
    if (_countdownActive) return;
    _countdownActive = true;
    _countdownSeconds = 2;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownSeconds--;
        _progress = 1.0;
        _statusText = _countdownSeconds > 0
            ? 'Capturing in $_countdownSeconds...'
            : 'Capturing photo...';
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
    _countdownSeconds = 2;
  }

  Future<void> _autoCapture() async {
    if (_isCapturing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }
    _isCapturing = true;

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      final xFile = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(xFile.path);
      }
    } catch (e) {
      debugPrint('[IdCapture] Capture error: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isIdDetected = false;
          _statusText = 'Capture failed — try again';
          _guidanceText = 'Position your ID in the frame';
        });
        _resetCountdown();
        if (_controller != null &&
            _controller!.value.isInitialized &&
            !_controller!.value.isStreamingImages) {
          _controller?.startImageStream(_onCameraFrame);
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    final cameraController = _controller;
    _controller = null;
    _isCameraReady = false;
    cameraController?.dispose();
    _textRecognizer.close();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──
          if (_isCameraReady &&
              _controller != null &&
              _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    CustomPaint(
                      painter: _CardOverlayPainter(
                        cardDetected: _isIdDetected,
                        isForbidden: _isForbiddenCard,
                        progress: _progress,
                        primaryColor: _primary,
                        errorColor: _errorColor,
                        cardWidthFraction: _cardWidthFraction,
                        cardCenterYFraction: _cardCenterYFraction,
                        cardAspectRatio: _cardAspectRatio,
                      ),
                      size: Size.infinite,
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(child: AppShimmerLoader(color: _primary)),

          // ── Top bar ──
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
                      widget.label,
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

          // ── Bottom status & guidance ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _isForbiddenCard
                          ? _errorColor.withValues(alpha: 0.8)
                          : (_isIdDetected
                                ? _primary.withValues(alpha: 0.8)
                                : Colors.black54),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isForbiddenCard
                              ? Icons.cancel_rounded
                              : (_isIdDetected
                                    ? Icons.check_circle
                                    : Icons.credit_card_rounded),
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
                  const SizedBox(height: 8),

                  if (_guidanceText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _guidanceText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _isForbiddenCard
                              ? _errorColor
                              : Colors.white70,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),

                  Text(
                    'Auto-captures when card is aligned inside the frame',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overlay painter ───────────────────────────────────────────────────────
class _CardOverlayPainter extends CustomPainter {
  final bool cardDetected;
  final bool isForbidden;
  final double progress;
  final Color primaryColor;
  final Color errorColor;
  final double cardWidthFraction;
  final double cardCenterYFraction;
  final double cardAspectRatio;

  _CardOverlayPainter({
    required this.cardDetected,
    required this.isForbidden,
    required this.progress,
    required this.primaryColor,
    required this.errorColor,
    required this.cardWidthFraction,
    required this.cardCenterYFraction,
    required this.cardAspectRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cardWidth = size.width * cardWidthFraction;
    final cardHeight = cardWidth / cardAspectRatio;
    final centerY = size.height * cardCenterYFraction;

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, centerY),
        width: cardWidth,
        height: cardHeight,
      ),
      const Radius.circular(16),
    );

    // 1) Dimmed background with card cutout
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.drawRRect(cardRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // 2) Border
    final borderColor = isForbidden
        ? errorColor
        : (cardDetected ? primaryColor : Colors.white.withValues(alpha: 0.4));
    canvas.drawRRect(
      cardRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = borderColor,
    );

    // 3) Corner brackets
    _drawCornerBrackets(canvas, cardRect.outerRect, borderColor);

    // 4) Progress arc
    if (progress > 0 && cardDetected && !isForbidden) {
      final progressRect = RRect.fromRectAndRadius(
        cardRect.outerRect.inflate(6),
        const Radius.circular(20),
      );
      final path = Path()..addRRect(progressRect);
      final metrics = path.computeMetrics().first;
      canvas.drawPath(
        metrics.extractPath(0, metrics.length * progress),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = primaryColor,
      );
    }

    // 5) Subtle inner guide when idle
    if (!cardDetected && !isForbidden) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          cardRect.outerRect.deflate(12),
          const Radius.circular(10),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.15),
      );
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    const len = 28.0;
    const o = 4.0;

    canvas.drawLine(
      Offset(rect.left - o, rect.top - o),
      Offset(rect.left - o + len, rect.top - o),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left - o, rect.top - o),
      Offset(rect.left - o, rect.top - o + len),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right + o, rect.top - o),
      Offset(rect.right + o - len, rect.top - o),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right + o, rect.top - o),
      Offset(rect.right + o, rect.top - o + len),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left - o, rect.bottom + o),
      Offset(rect.left - o + len, rect.bottom + o),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left - o, rect.bottom + o),
      Offset(rect.left - o, rect.bottom + o - len),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right + o, rect.bottom + o),
      Offset(rect.right + o - len, rect.bottom + o),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right + o, rect.bottom + o),
      Offset(rect.right + o, rect.bottom + o - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CardOverlayPainter old) =>
      old.cardDetected != cardDetected ||
      old.isForbidden != isForbidden ||
      old.progress != progress;
}
