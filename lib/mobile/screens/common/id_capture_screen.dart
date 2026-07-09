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
  int _stableFrames = 0;
  static const int _requiredStableFrames = 2;

  // ─── Countdown ───
  Timer? _countdownTimer;
  int _countdownSeconds = 3;
  bool _countdownActive = false;
  double _progress = 0.0;

  String _statusText = 'Initializing camera...';
  String _guidanceText = '';

  // ─── Guide overlay and detection constants ───
  static const double _cardCenterYFraction = 0.42;
  static const double _cardWidthFraction = 0.88;
  static const double _cardAspectRatio = 1.586;
  static const double _guideToleranceFraction = 0.05; // Was 0.025
  static const double _minFeatureWidthFraction = 0.42;
  static const double _minFeatureHeightFraction = 0.12;

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
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
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
    final bool isBack = widget.label.toLowerCase().contains('back');
    final bool hasFace = isBack ? true : faces.isNotEmpty;
    final bool isForbidden = _hasForbiddenKeyword(fullText);

    // ID-like: 1+ keyword AND (3+ keywords OR 5+ text blocks)
    // For back scan, just require at least 2 text blocks
    final bool hasKeywords = isBack
        ? (blockCount >= 2)
        : (keywordHits >= 1 && (keywordHits >= 3 || blockCount >= 5));

    // ── 1. Build a combined bounding box of ALL features ──
    Rect? combinedFeatureBox;
    for (final block in recognizedText.blocks) {
      final rect = _normalizeRectToPortraitFraction(
        block.boundingBox,
        frameW,
        frameH,
        sensorOrientation,
      );
      combinedFeatureBox = combinedFeatureBox == null
          ? rect
          : combinedFeatureBox.expandToInclude(rect);
    }
    bool hasFaceInsideGuide = false;
    for (final face in faces) {
      final rect = _normalizeRectToPortraitFraction(
        face.boundingBox,
        frameW,
        frameH,
        sensorOrientation,
      );
      combinedFeatureBox = combinedFeatureBox == null
          ? rect
          : combinedFeatureBox.expandToInclude(rect);
      hasFaceInsideGuide =
          hasFaceInsideGuide || _isRectInsideGuide(rect, _portraitGuideRect());
    }

    bool isInsideGuide = false;
    bool isLargeEnough = false;

    if (combinedFeatureBox != null) {
      final double left = combinedFeatureBox.left;
      final double right = combinedFeatureBox.right;
      final double top = combinedFeatureBox.top;
      final double bottom = combinedFeatureBox.bottom;

      final double cx = (left + right) / 2;
      final double cy = (top + bottom) / 2;
      final double cw = (right - left).abs();
      final double ch = (bottom - top).abs();

      final guideRect = _portraitGuideRect();
      isInsideGuide =
          hasFaceInsideGuide &&
          _isRectInsideGuide(combinedFeatureBox, guideRect);

      isLargeEnough =
          cw >= _minFeatureWidthFraction && ch >= _minFeatureHeightFraction;

      debugPrint(
        '[IdCapture] PortraitBox: L=${left.toStringAsFixed(2)} R=${right.toStringAsFixed(2)} T=${top.toStringAsFixed(2)} B=${bottom.toStringAsFixed(2)}',
      );
      debugPrint(
        '[IdCapture] Center: (${cx.toStringAsFixed(2)}, ${cy.toStringAsFixed(2)}) Size: ${cw.toStringAsFixed(2)}x${ch.toStringAsFixed(2)}',
      );
    }

    final String debug =
        'k=$keywordHits b=$blockCount f=${faces.length} '
        'in=$isInsideGuide big=$isLargeEnough '
        'rot=$sensorOrientation';
    debugPrint('[IdCapture] $debug');

    // ── Forbidden card ──
    if (isForbidden) {
      _stableFrames = 0;
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

    // ── All conditions met ──
    if (hasKeywords && hasFace && isInsideGuide && isLargeEnough) {
      _stableFrames++;
      if (mounted) {
        setState(() {
          _isForbiddenCard = false;
          _isIdDetected = true;
          _progress = (_stableFrames / _requiredStableFrames).clamp(0.0, 1.0);
        });
      }

      if (_stableFrames >= _requiredStableFrames && !_countdownActive) {
        _startCountdown();
      }

      if (mounted) {
        setState(() {
          _statusText = _countdownActive
              ? 'Hold still — $_countdownSeconds'
              : 'Validating ID...';
          _guidanceText = _countdownActive
              ? 'ID detected! Stay steady'
              : 'Keep the card steady';
        });
      }
      return;
    }

    // ── Keywords + face but not in the box ──
    if (hasKeywords && hasFace && !isInsideGuide) {
      _stableFrames = 0;
      if (_countdownActive) _resetCountdown();
      if (mounted) {
        setState(() {
          _isForbiddenCard = false;
          _isIdDetected = false;
          _progress = 0.0;
          _statusText = 'Fit ID inside the box';
          _guidanceText = 'Move the card so it fits inside the guide lines';
        });
      }
      return;
    }

    // ── Keywords + face but too small ──
    if (hasKeywords && hasFace && !isLargeEnough) {
      _stableFrames = 0;
      if (_countdownActive) _resetCountdown();
      if (mounted) {
        setState(() {
          _isForbiddenCard = false;
          _isIdDetected = false;
          _progress = 0.0;
          _statusText = 'Move closer';
          _guidanceText = 'The ID should fill the guide box';
        });
      }
      return;
    }

    // ── Keywords found but no face ──
    if (hasKeywords) {
      _stableFrames = 0;
      if (_countdownActive) _resetCountdown();
      if (mounted) {
        setState(() {
          _isForbiddenCard = false;
          _isIdDetected = false;
          _progress = 0.0;
          _statusText = 'Face not found';
          _guidanceText = 'Ensure the portrait photo is visible and well-lit';
        });
      }
      return;
    }

    // ── Face found but no text ──
    if (hasFace) {
      _stableFrames = 0;
      if (_countdownActive) _resetCountdown();
      if (mounted) {
        setState(() {
          _isForbiddenCard = false;
          _isIdDetected = false;
          _progress = 0.0;
          _statusText = 'Reading text...';
          _guidanceText = 'Hold still so the camera can focus';
        });
      }
      return;
    }

    // ── Nothing ──
    _resetDetection();
  }

  Rect _portraitGuideRect() {
    final cardHeight = _cardWidthFraction / _cardAspectRatio;
    return Rect.fromCenter(
      center: const Offset(0.5, _cardCenterYFraction),
      width: _cardWidthFraction,
      height: cardHeight,
    ).inflate(_guideToleranceFraction);
  }

  Rect _normalizeRectToPortraitFraction(
    Rect rect,
    double frameW,
    double frameH,
    int sensorOrientation,
  ) {
    final points = [
      _normalizePointToPortraitFraction(
        rect.left,
        rect.top,
        frameW,
        frameH,
        sensorOrientation,
      ),
      _normalizePointToPortraitFraction(
        rect.right,
        rect.top,
        frameW,
        frameH,
        sensorOrientation,
      ),
      _normalizePointToPortraitFraction(
        rect.right,
        rect.bottom,
        frameW,
        frameH,
        sensorOrientation,
      ),
      _normalizePointToPortraitFraction(
        rect.left,
        rect.bottom,
        frameW,
        frameH,
        sensorOrientation,
      ),
    ];

    final xs = points.map((point) => point.dx);
    final ys = points.map((point) => point.dy);

    return Rect.fromLTRB(
      xs.reduce((a, b) => a < b ? a : b).clamp(0.0, 1.0),
      ys.reduce((a, b) => a < b ? a : b).clamp(0.0, 1.0),
      xs.reduce((a, b) => a > b ? a : b).clamp(0.0, 1.0),
      ys.reduce((a, b) => a > b ? a : b).clamp(0.0, 1.0),
    );
  }

  Offset _normalizePointToPortraitFraction(
    double x,
    double y,
    double frameW,
    double frameH,
    int sensorOrientation,
  ) {
    switch (sensorOrientation) {
      case 90:
        return Offset(1.0 - (y / frameH), x / frameW);
      case 180:
        return Offset(1.0 - (x / frameW), 1.0 - (y / frameH));
      case 270:
        return Offset(y / frameH, 1.0 - (x / frameW));
      default:
        return Offset(x / frameW, y / frameH);
    }
  }

  bool _isRectInsideGuide(Rect rect, Rect guideRect) {
    return rect.left >= guideRect.left &&
        rect.top >= guideRect.top &&
        rect.right <= guideRect.right &&
        rect.bottom <= guideRect.bottom;
  }

  void _resetDetection() {
    _stableFrames = 0;
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
    _countdownSeconds = 3;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownSeconds--;
        _progress = (3 - _countdownSeconds) / 3.0;
        _statusText = _countdownSeconds > 0
            ? 'Capturing in $_countdownSeconds…'
            : 'Capturing…';
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

  Future<void> _autoCapture() async {
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      await _controller!.stopImageStream();
      final xFile = await _controller!.takePicture();
      if (mounted) Navigator.of(context).pop(xFile.path);
    } catch (e) {
      debugPrint('[IdCapture] Capture error: $e');
      _isCapturing = false;
      _stableFrames = 0;
      _resetCountdown();
      if (mounted) {
        setState(() {
          _isIdDetected = false;
          _statusText = 'Capture failed — try again';
          _guidanceText = 'Position your ID and hold steady';
        });
        _controller?.startImageStream(_onCameraFrame);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _controller?.dispose();
    _textRecognizer.close();
    _faceDetector.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──
          if (_isCameraReady && _controller != null)
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

          // ── Countdown number ──
          if (_countdownActive && _countdownSeconds > 0)
            Positioned(
              top:
                  MediaQuery.of(context).size.height * _cardCenterYFraction -
                  36,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_countdownSeconds),
                  tween: Tween(begin: 1.5, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primary.withValues(alpha: 0.2),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$_countdownSeconds',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

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
                    'Auto-captures when Philippine ID is detected',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _autoCapture,
                    child: Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
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
