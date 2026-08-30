import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;

/// Full-screen camera view for capturing the front or back of an ID card.
///
/// Detection logic:
///   1. Text recognition — looks for Philippine National ID keywords AND
///      a minimum number of text blocks (dense text = ID-like document).
///   2. Tilt check — average rotation angle of detected text blocks must be
///      within [_maxTiltDegrees] of horizontal.
///   3. Face detection (front only) — a face must be visible inside the
///      guide box. Skipped for back captures.
///   4. QR / barcode detection (back only, when [requireQr] is true) — a
///      QR/PDF417 code must be visible inside the guide box.
///
/// When all required conditions are met for [_countdownSeconds] stable
/// frames, the screen auto-captures a photo, applies a perspective
/// crop/de-skew to the guide-box region, and returns the file path.
class IdCaptureScreen extends StatefulWidget {
  final String label;
  final bool requireQr;
  final bool isBack;

  const IdCaptureScreen({super.key, this.label = 'ID Front', bool? requireQr})
    : requireQr = requireQr ?? false,
      isBack = false;

  const IdCaptureScreen.back({
    super.key,
    this.label = 'ID Back',
    this.requireQr = true,
  }) : isBack = true;

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
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode, BarcodeFormat.pdf417],
  );

  bool _isProcessing = false;
  bool _isCapturing = false;

  // Frame throttling — avoid running ML Kit back-to-back with zero gap.
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _frameInterval = Duration(milliseconds: 150);

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

  // ─── Guide overlay and detection constants (single source of truth) ───
  static const double _cardCenterYFraction = 0.42;
  static const double _cardWidthFraction = 0.88;
  static const double _cardAspectRatio = 1.586;
  static const double _cardHeightFraction =
      _cardWidthFraction / _cardAspectRatio;
  static const double _guideLeft = 0.5 - _cardWidthFraction / 2;
  static const double _guideRight = 0.5 + _cardWidthFraction / 2;
  static const double _guideTop =
      _cardCenterYFraction - _cardHeightFraction / 2;
  static const double _guideBottom =
      _cardCenterYFraction + _cardHeightFraction / 2;

  // Max allowed average text-block tilt, in degrees, before we flag "straighten".
  static const double _maxTiltDegrees = 8.0;

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

    final now = DateTime.now();
    if (now.difference(_lastFrameTime) < _frameInterval) return;
    _lastFrameTime = now;

    _isProcessing = true;
    _processFrame(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    final inputImage = _convertCameraImage(image);
    if (inputImage == null) return;

    try {
      final futures = <Future<Object>>[
        _textRecognizer.processImage(inputImage),
        if (!widget.isBack) _faceDetector.processImage(inputImage),
        if (widget.isBack && widget.requireQr)
          _barcodeScanner.processImage(inputImage),
      ];

      final results = await Future.wait(futures);
      if (!mounted || _isCapturing) return;

      final recognizedText = results[0] as RecognizedText;

      List<Face> faces = const [];
      List<Barcode> barcodes = const [];
      int nextIndex = 1;
      if (!widget.isBack) {
        faces = results[nextIndex] as List<Face>;
        nextIndex++;
      }
      if (widget.isBack && widget.requireQr) {
        barcodes = results[nextIndex] as List<Barcode>;
      }

      _analyzeFrame(
        recognizedText,
        faces,
        barcodes,
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

  /// Returns true if the point (fractional coords) falls inside the guide box.
  bool _isInsideGuideBox(double xFrac, double yFrac) {
    return xFrac >= _guideLeft &&
        xFrac <= _guideRight &&
        yFrac >= _guideTop &&
        yFrac <= _guideBottom;
  }

  void _analyzeFrame(
    RecognizedText recognizedText,
    List<Face> faces,
    List<Barcode> barcodes,
    double frameW,
    double frameH,
    int sensorOrientation,
  ) {
    final double portraitW =
        (sensorOrientation == 90 || sensorOrientation == 270) ? frameH : frameW;
    final double portraitH =
        (sensorOrientation == 90 || sensorOrientation == 270) ? frameW : frameH;

    // ── Only process text inside the guide box, and track bounding envelope & tilt ──
    int blockCount = 0;
    int keywordHits = 0;
    bool isForbidden = false;
    double totalAngle = 0.0;
    int angleCount = 0;

    double minX = 1.0;
    double maxX = 0.0;
    double minY = 1.0;
    double maxY = 0.0;

    int upperBlockCount = 0;
    int lowerBlockCount = 0;

    for (final block in recognizedText.blocks) {
      final rect = block.boundingBox;
      final bLeft = (rect.left / portraitW).clamp(0.0, 1.0);
      final bRight = (rect.right / portraitW).clamp(0.0, 1.0);
      final bTop = (rect.top / portraitH).clamp(0.0, 1.0);
      final bBottom = (rect.bottom / portraitH).clamp(0.0, 1.0);

      final cx = (bLeft + bRight) / 2;
      final cy = (bTop + bBottom) / 2;

      if (!_isInsideGuideBox(cx, cy)) continue;

      blockCount++;
      minX = math.min(minX, bLeft);
      maxX = math.max(maxX, bRight);
      minY = math.min(minY, bTop);
      maxY = math.max(maxY, bBottom);

      if (cy < _cardCenterYFraction) {
        upperBlockCount++;
      } else {
        lowerBlockCount++;
      }

      final text = block.text.toUpperCase();
      keywordHits += _countKeywordMatches(text);
      if (_hasForbiddenKeyword(text)) {
        isForbidden = true;
      }

      // Estimate tilt from the block's corner points (top edge slope).
      final corners = block.cornerPoints;
      if (corners.length >= 4) {
        final sorted = List.of(corners)..sort((a, b) => a.y.compareTo(b.y));
        final dx = (sorted[1].x - sorted[0].x).toDouble();
        final dy = (sorted[1].y - sorted[0].y).toDouble();
        if (dx != 0 || dy != 0) {
          double angle = math.atan2(dy, dx) * (180.0 / math.pi);
          if (angle > 90) angle -= 180;
          if (angle < -90) angle += 180;
          totalAngle += angle;
          angleCount++;
        }
      }
    }

    // ── Face gate (front only) ──
    bool hasFaceInBox = true;
    if (!widget.isBack) {
      hasFaceInBox = false;
      for (final face in faces) {
        final rect = face.boundingBox;
        final fLeft = (rect.left / portraitW).clamp(0.0, 1.0);
        final fRight = (rect.right / portraitW).clamp(0.0, 1.0);
        final fTop = (rect.top / portraitH).clamp(0.0, 1.0);
        final fBottom = (rect.bottom / portraitH).clamp(0.0, 1.0);

        final cx = (fLeft + fRight) / 2;
        final cy = (fTop + fBottom) / 2;
        if (_isInsideGuideBox(cx, cy)) {
          hasFaceInBox = true;
          minX = math.min(minX, fLeft);
          maxX = math.max(maxX, fRight);
          minY = math.min(minY, fTop);
          maxY = math.max(maxY, fBottom);
        }
      }
    }

    // ── QR/barcode gate (back only) ──
    bool hasQrInBox = true;
    if (widget.isBack && widget.requireQr) {
      hasQrInBox = false;
      for (final barcode in barcodes) {
        final rect = barcode.boundingBox;
        final bLeft = (rect.left / portraitW).clamp(0.0, 1.0);
        final bRight = (rect.right / portraitW).clamp(0.0, 1.0);
        final bTop = (rect.top / portraitH).clamp(0.0, 1.0);
        final bBottom = (rect.bottom / portraitH).clamp(0.0, 1.0);

        final cx = (bLeft + bRight) / 2;
        final cy = (bTop + bBottom) / 2;
        if (_isInsideGuideBox(cx, cy)) {
          hasQrInBox = true;
          minX = math.min(minX, bLeft);
          maxX = math.max(maxX, bRight);
          minY = math.min(minY, bTop);
          maxY = math.max(maxY, bBottom);
        }
      }
    }

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

    // ── 1. Text Density & Coverage Gates ──
    final bool isRichEnough = widget.isBack
        ? (blockCount >= 2 || hasQrInBox)
        : (keywordHits >= 2 && blockCount >= 4);

    final double cardHeightSpan = (maxY > minY) ? (maxY - minY) : 0.0;
    final double cardWidthSpan = (maxX > minX) ? (maxX - minX) : 0.0;
    final double cardCenterY = (minY + maxY) / 2;

    // The card must span at least 38% of the guide box vertically and 50% horizontally
    final bool hasFullCardCoverage = cardHeightSpan >= (_cardHeightFraction * 0.38) &&
        cardWidthSpan >= (_cardWidthFraction * 0.50);

    // Front card must have text in both top and bottom halves (not half cut off)
    final bool hasTopAndBottomContent = widget.isBack ||
        (upperBlockCount >= 1 && lowerBlockCount >= 2);

    // Card must be vertically centered in the box (not stuck at the bottom or top edge)
    final bool isWellCentered = (cardCenterY - _cardCenterYFraction).abs() <= 0.09;

    // ── 2. Tilt Gate ──
    const int minAngleSamples = 3;
    final double avgAngle =
        angleCount > 0 ? (totalAngle / angleCount).abs() : 0.0;
    final bool isStraight =
        angleCount < minAngleSamples || avgAngle <= _maxTiltDegrees;

    // ── 3. PERFECT ALIGNMENT: Full Card Inside Box ──
    if (isRichEnough &&
        hasFullCardCoverage &&
        hasTopAndBottomContent &&
        isWellCentered &&
        isStraight &&
        hasFaceInBox &&
        hasQrInBox) {
      if (mounted) {
        setState(() {
          _isForbiddenCard = false;
          _isIdDetected = true;
          _progress = 1.0;
          _statusText = _countdownActive
              ? 'Capturing in $_countdownSeconds...'
              : 'ID Aligned! Hold steady...';
          _guidanceText = 'Hold still for photo';
        });
      }

      if (!_countdownActive) {
        _startCountdown();
      }
      return;
    }

    // ── 4. Not Aligned: Provide helpful dynamic feedback ──
    if (_countdownActive) _resetCountdown();

    if (keywordHits >= 1 || blockCount >= 2) {
      String statusMsg = 'Fit ID inside the box';
      String guideMsg = 'Center the full card inside the green lines';

      if (!isStraight) {
        statusMsg = 'Straighten the card';
        guideMsg = 'Hold the ID level with the frame';
      } else if (!hasFaceInBox && !widget.isBack) {
        statusMsg = 'Photo not visible';
        guideMsg = 'Make sure the ID photo is inside the frame';
      } else if (!hasQrInBox && widget.isBack && widget.requireQr) {
        statusMsg = 'QR code not visible';
        guideMsg = 'Make sure the QR code is inside the frame';
      } else if (!isWellCentered) {
        if (cardCenterY > _cardCenterYFraction + 0.06) {
          statusMsg = 'Move ID up';
          guideMsg = 'Center the ID inside the green frame';
        } else if (cardCenterY < _cardCenterYFraction - 0.06) {
          statusMsg = 'Move ID down';
          guideMsg = 'Center the ID inside the green frame';
        }
      } else if (!hasFullCardCoverage || !hasTopAndBottomContent) {
        statusMsg = 'Fit entire card in box';
        guideMsg = 'Show all top and bottom text inside the frame';
      }

      if (mounted) {
        setState(() {
          _isForbiddenCard = false;
          _isIdDetected = false;
          _progress = 0.0;
          _statusText = statusMsg;
          _guidanceText = guideMsg;
        });
      }
      return;
    }

    // ── 5. No ID detected ──
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
  // Countdown & Auto-capture (Snappy 1-Second Countdown)
  // ─────────────────────────────────────────────────

  void _startCountdown() {
    if (_countdownActive) return;
    _countdownActive = true;
    _countdownSeconds = 1;

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
    _countdownSeconds = 1;
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
      final croppedPath = await _applyGuideBoxCrop(xFile.path);

      if (mounted) {
        Navigator.of(context).pop(croppedPath);
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

  /// Crops the captured photo down to the guide-box region and corrects
  /// for EXIF orientation. Uses a straight crop (not homography) because
  /// the detection gate already enforces the card sits flat and centered
  /// inside the guide box before capture is allowed — this avoids the
  /// warping artifacts a `copyRectify` homography can introduce when
  /// estimated corners are imprecise.
  Future<String> _applyGuideBoxCrop(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return filePath;

      final upright = img.bakeOrientation(original);
      final int iw = upright.width;
      final int ih = upright.height;

      final left = (_guideLeft * iw).round().clamp(0, iw);
      final right = (_guideRight * iw).round().clamp(0, iw);
      final top = (_guideTop * ih).round().clamp(0, ih);
      final bottom = (_guideBottom * ih).round().clamp(0, ih);

      final cropW = (right - left).clamp(1, iw);
      final cropH = (bottom - top).clamp(1, ih);

      final cropped = img.copyCrop(
        upright,
        x: left,
        y: top,
        width: cropW,
        height: cropH,
      );

      final outJpg = img.encodeJpg(cropped, quality: 94);
      await File(filePath).writeAsBytes(outJpg);
      return filePath;
    } catch (e) {
      debugPrint('[IdCapture] Crop error: $e');
      return filePath;
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
    _barcodeScanner.close();
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
      Paint()..color = Colors.black.withValues(alpha: 0.95),
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
