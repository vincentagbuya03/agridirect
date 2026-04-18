import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Full-screen camera view for capturing the front or back of an ID card.
/// Uses ML Kit Text Recognition with Intelligent Keyword Filtering to 
/// differentiate valid IDs from credit/debit cards.
class IdCaptureScreen extends StatefulWidget {
  final String label;
  const IdCaptureScreen({super.key, this.label = 'ID Front'});

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
    ),
  );
  bool _isProcessing = false;

  // ─── Detection States ───
  bool _isValidIdDetected = false;
  bool _isForbiddenCardDetected = false;
  bool _isIdConfirmed = false; // stays true only while face+text are continuously visible
  int _stableFrames = 0;
  static const int _requiredStableFrames = 4; // Frames needed to confirm valid ID

  // ─── Countdown Timer ───
  Timer? _countdownTimer;
  int _countdownSeconds = 3;
  bool _countdownActive = false;
  bool _isCapturing = false;

  String _statusText = 'Initializing camera…';
  String _guidanceText = '';
  double _progress = 0.0;

  static const double _cardCenterYFraction = 0.42;
  static const double _cardWidthFraction = 0.88;
  static const double _cardAspectRatio = 1.586;

  // --- Keywords for Intelligent Detection ---
  
  // Valid ID Keywords (PhilSys / General National ID — Filipino + English)
  final List<String> _validKeywords = [
    // Filipino text on PhilID
    'REPUBLIKA NG PILIPINAS',
    'PAMBANSANG PAGKAKAKILANLAN',
    'PAGKAKAKILANLAN',
    // English text on PhilID
    'REPUBLIC OF THE PHILIPPINES',
    'PHILIPPINE IDENTIFICATION',
    'IDENTIFICATION CARD',
    'PHILID',
    'NATIONAL ID',
    // Common PhilID field labels
    'PCN',
    'DATE OF BIRTH',
    'LAST NAME',
    'FIRST NAME',
    'APELYIDO',
    'MGA PANGALAN',
    'PETSA NG KAPANGANAKAN',
    'TIRAHAN',
  ];

  // Forbidden Keywords (Bank Cards)
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
        _guidanceText = 'Waiting for National ID...';
      });

      // Begin streaming frames for text detection
      await _controller!.startImageStream(_onCameraFrame);
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Camera not available');
      }
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isProcessing || _isCapturing) return;
    _isProcessing = true;
    _processFrame(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    final inputImage = _convertCameraImage(image);
    if (inputImage == null) return;

    try {
      // Process both text and faces concurrently for speed
      final results = await Future.wait([
        _textRecognizer.processImage(inputImage),
        _faceDetector.processImage(inputImage),
      ]);

      if (!mounted || _isCapturing) return;

      final recognizedText = results[0] as RecognizedText;
      final faces = results[1] as List<Face>;

      _analyzeFrame(recognizedText, faces, image.height.toDouble());

    } catch (e) {
      debugPrint('Frame processing error: $e');
    }
  }

  void _analyzeFrame(RecognizedText recognizedText, List<Face> faces, double frameHeight) {
    if (recognizedText.blocks.isEmpty) {
      _resetDetectionState();
      return;
    }

    final String fullText = recognizedText.text.toUpperCase();

    // 1. Check for Valid ID Keywords FIRST
    bool isValidId = false;
    for (final keyword in _validKeywords) {
      if (fullText.contains(keyword)) {
        isValidId = true;
        break;
      }
    }

    // 2. Check for Forbidden Cards (only if not a valid ID)
    bool isForbidden = false;
    if (!isValidId) {
      for (final keyword in _forbiddenKeywords) {
        if (fullText.contains(keyword)) {
          isForbidden = true;
          break;
        }
      }
    }

    if (isForbidden) {
      _stableFrames = 0;
      if (_countdownActive) _resetCountdown();

      setState(() {
        _isForbiddenCardDetected = true;
        _isValidIdDetected = false;
        _progress = 0.0;
        _statusText = 'Invalid ID Detected!';
        _guidanceText = 'Please scan a valid National ID.';
      });
      return;
    }

    // 3. Intelligent Face Requirement
    // A valid National ID must have a face that is:
    // a) Large enough to be the portrait (not a tiny background face)
    bool hasValidFace = false;
    
    for (final face in faces) {
      final rect = face.boundingBox;
      
      // Face must be at least 15% of the frame height to be considered the ID portrait
      final double faceHeightRatio = rect.height / frameHeight;
      
      if (faceHeightRatio > 0.15) {
        hasValidFace = true;
        break;
      }
    }

    if (isValidId && hasValidFace) {
      _stableFrames++;
      _isIdConfirmed = true; // face + valid text are present right now

      setState(() {
        _isForbiddenCardDetected = false;
        _isValidIdDetected = true;
      });

      if (_stableFrames >= _requiredStableFrames && !_countdownActive) {
        _startCountdown();
      }

      if (_countdownActive) {
        setState(() {
          _statusText = 'Hold still — $_countdownSeconds';
          _guidanceText = 'National ID detected ✓ Stay steady!';
        });
      } else {
        setState(() {
          _statusText = 'Validating ID…';
          _guidanceText = 'Keep the card steady in the frame';
          _progress = (_stableFrames / _requiredStableFrames).clamp(0.0, 1.0);
        });
      }
    } else {
      // Face or valid keywords disappeared — clear confirmed state and reset
      _isIdConfirmed = false;
      _resetDetectionState();
    }
  }

  void _resetDetectionState() {
    _stableFrames = 0;
    if (_countdownActive) {
      _resetCountdown();
    }

    if (mounted && (_isValidIdDetected || _isForbiddenCardDetected)) {
      setState(() {
        _isValidIdDetected = false;
        _isForbiddenCardDetected = false;
        _progress = 0.0;
        _statusText = 'Position your ID in the frame';
        _guidanceText = 'Waiting for National ID...';
      });
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

  Future<void> _autoCapture() async {
    if (_isCapturing) return;
    
    // Final safety check — if the face was covered just as the timer fired,
    // abort the capture and restart detection instead.
    if (!_isIdConfirmed) {
      _stableFrames = 0;
      _resetCountdown();
      if (mounted) {
        setState(() {
          _isValidIdDetected = false;
          _statusText = 'ID face not visible!';
          _guidanceText = 'Make sure the portrait on your ID is uncovered';
        });
        _controller?.startImageStream(_onCameraFrame);
      }
      return;
    }

    _isCapturing = true;

    try {
      await _controller!.stopImageStream();
      final xFile = await _controller!.takePicture();
      if (mounted) Navigator.of(context).pop(xFile.path);
    } catch (e) {
      _isCapturing = false;
      _stableFrames = 0;
      _resetCountdown();
      if (mounted) {
        setState(() {
          _isValidIdDetected = false;
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
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            const Center(child: AppShimmerLoader(color: _primary)),

          // Dark overlay with card cutout
          CustomPaint(
            painter: _CardOverlayPainter(
              cardDetected: _isValidIdDetected,
              isForbidden: _isForbiddenCardDetected,
              progress: _progress,
              primaryColor: _primary,
              errorColor: _errorColor,
              cardWidthFraction: _cardWidthFraction,
              cardCenterYFraction: _cardCenterYFraction,
              cardAspectRatio: _cardAspectRatio,
            ),
            size: Size.infinite,
          ),

          // ─── Countdown number in the center ───
          if (_countdownActive && _countdownSeconds > 0)
            Positioned(
              top: MediaQuery.of(context).size.height * _cardCenterYFraction - 30,
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
                    width: 72,
                    height: 72,
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
                      color: _isForbiddenCardDetected 
                          ? _errorColor.withValues(alpha: 0.9)
                          : (_isValidIdDetected ? _primary.withValues(alpha: 0.9) : Colors.black54),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isForbiddenCardDetected
                              ? Icons.cancel_rounded
                              : (_isValidIdDetected ? Icons.check_circle : Icons.credit_card_rounded),
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
                          color: _isForbiddenCardDetected ? _errorColor : Colors.white70,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Info text
                  Text(
                    'Auto-captures when valid ID is detected for 3 seconds',
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

// ─── Overlay painter with rounded-rect card cutout & progress border ───
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

    // 1) Semi-transparent background with punched-out card
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(cardRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // 2) Card border — green if detected, red if forbidden, white if not
    Color borderColor = Colors.white.withValues(alpha: 0.7);
    if (isForbidden) {
      borderColor = errorColor;
    } else if (cardDetected) {
      borderColor = primaryColor;
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = borderColor;
    canvas.drawRRect(cardRect, borderPaint);

    // 3) Corner brackets
    _drawCornerBrackets(canvas, cardRect.outerRect, borderColor);

    // 4) Progress border (traces around the card as countdown proceeds)
    if (progress > 0 && cardDetected && !isForbidden) {
      final progressRect = RRect.fromRectAndRadius(
        cardRect.outerRect.inflate(6),
        const Radius.circular(20),
      );

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = primaryColor;

      final path = Path()..addRRect(progressRect);
      final pathMetrics = path.computeMetrics().first;
      final progressLength = pathMetrics.length * progress;
      final extractedPath = pathMetrics.extractPath(0, progressLength);

      canvas.drawPath(extractedPath, arcPaint);
    }

    // 5) Subtle inner guide when not detected
    if (!cardDetected && !isForbidden) {
      final innerGuide = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.2);

      final innerRect = RRect.fromRectAndRadius(
        cardRect.outerRect.deflate(12),
        const Radius.circular(10),
      );
      canvas.drawRRect(innerRect, innerGuide);
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;

    const bracketLength = 28.0;
    const offset = 4.0;

    // Top-left
    canvas.drawLine(
      Offset(rect.left - offset, rect.top - offset),
      Offset(rect.left - offset + bracketLength, rect.top - offset),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left - offset, rect.top - offset),
      Offset(rect.left - offset, rect.top - offset + bracketLength),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(rect.right + offset, rect.top - offset),
      Offset(rect.right + offset - bracketLength, rect.top - offset),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right + offset, rect.top - offset),
      Offset(rect.right + offset, rect.top - offset + bracketLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(rect.left - offset, rect.bottom + offset),
      Offset(rect.left - offset + bracketLength, rect.bottom + offset),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left - offset, rect.bottom + offset),
      Offset(rect.left - offset, rect.bottom + offset - bracketLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(rect.right + offset, rect.bottom + offset),
      Offset(rect.right + offset - bracketLength, rect.bottom + offset),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right + offset, rect.bottom + offset),
      Offset(rect.right + offset, rect.bottom + offset - bracketLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CardOverlayPainter old) =>
      old.cardDetected != cardDetected || 
      old.isForbidden != isForbidden ||
      old.progress != progress;
}
