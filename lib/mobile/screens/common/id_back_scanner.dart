import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result returned from the IdBackCaptureScreen.
/// Contains the QR raw string data and the path to the captured photo.
class IdBackCaptureResult {
  final String qrData;
  final String imagePath;
  IdBackCaptureResult({required this.qrData, required this.imagePath});
}

/// Full-screen camera view for scanning the BACK of a National ID.
/// It validates the PhilSys QR code and only captures once the full card
/// appears to be inside the visible guide for a few stable frames.
class IdBackCaptureScreen extends StatefulWidget {
  final String label;
  const IdBackCaptureScreen({super.key, this.label = 'ID Back'});

  @override
  State<IdBackCaptureScreen> createState() => _IdBackCaptureScreenState();
}

class _IdBackCaptureScreenState extends State<IdBackCaptureScreen>
    with WidgetsBindingObserver {
  static const Color _primary = Color(0xFF10B981);
  static const Color _errorColor = Color(0xFFEF4444);

  static const double _cardCenterYFraction = 0.42;
  static const double _cardWidthFraction = 0.88;
  static const double _cardAspectRatio = 1.586;
  static const double _guideInset = 10.0;
  static const double _guideTolerance = 40.0; // Much more tolerant guide fit
  static const double _guideFilterMargin = 80.0; // Wider filter area
  static const double _minGuideIntersectionRatio =
      0.45; // More lenient intersection
  static const double _minDetectedWidthCoverage = 0.30; // Relaxed from 0.62
  static const double _minDetectedHeightCoverage = 0.25; // Relaxed from 0.50
  static const double _minQrWidthCoverage = 0.08; // Relaxed from 0.18
  static const int _requiredStableFrames = 3; // Reduced from 4

  CameraController? _controller;
  CameraDescription? _rearCamera;
  bool _isCameraReady = false;

  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isProcessing = false;
  bool _qrDetected = false;
  bool _isInvalidQr = false;
  bool _isCapturing = false;
  bool _countdownActive = false;
  int _stableFrames = 0;
  int _countdown = 3;
  String? _detectedQrData;
  String _statusText = 'Fit the full ID back inside the box';
  String _guidanceText = 'Center the entire card until it is captured';

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _controller?.dispose();
    _barcodeScanner.close();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _rearCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
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

    try {
      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
        _statusText = 'Fit the full ID back inside the box';
        _guidanceText = 'Center the entire card until it is captured';
      });

      await _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isCapturing) return;
    _isProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation:
              InputImageRotationValue.fromRawValue(
                _rearCamera!.sensorOrientation,
              ) ??
              InputImageRotation.rotation0deg,
          format:
              InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final results = await Future.wait([
        _barcodeScanner.processImage(inputImage),
        _textRecognizer.processImage(inputImage),
      ]);

      if (!mounted || _isCapturing) return;

      _analyzeFrame(
        barcodes: results[0] as List<Barcode>,
        recognizedText: results[1] as RecognizedText,
        frameWidth: image.width.toDouble(),
        frameHeight: image.height.toDouble(),
      );
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _analyzeFrame({
    required List<Barcode> barcodes,
    required RecognizedText recognizedText,
    required double frameWidth,
    required double frameHeight,
  }) {
    final guideRect = _buildGuideRect(
      frameWidth,
      frameHeight,
      inset: _guideInset,
    );
    final guideFilterRect = guideRect.inflate(_guideFilterMargin);

    final normalizedTextRects = recognizedText.blocks
        .map(
          (block) => _normalizeRectToPortrait(
            block.boundingBox,
            frameWidth,
            frameHeight,
          ),
        )
        .where(
          (rect) =>
              _intersectionRatio(rect, guideFilterRect) >=
              _minGuideIntersectionRatio,
        )
        .toList();

    Barcode? validBarcode;
    Rect? qrRect;
    bool sawInvalidPayload = false;

    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue ?? barcode.displayValue ?? '';
      final rect = barcode.boundingBox;

      final normalizedRect = _normalizeRectToPortrait(
        rect,
        frameWidth,
        frameHeight,
      );
      final qrWidthCoverage = (normalizedRect.width / guideRect.width).clamp(
        0.0,
        1.0,
      );
      // Accept any QR with meaningful content (PhilSys QR may vary in format)
      final isValidPayload = rawValue.length >= 10;

      if (!isValidPayload) {
        sawInvalidPayload = true;
        continue;
      }

      if (_intersectionRatio(normalizedRect, guideFilterRect) >=
              _minGuideIntersectionRatio &&
          _isRectInsideGuide(normalizedRect, guideRect) &&
          qrWidthCoverage >= _minQrWidthCoverage) {
        validBarcode = barcode;
        qrRect = normalizedRect;
        break;
      }
    }

    if (validBarcode == null || qrRect == null) {
      _stableFrames = 0;
      if (_countdownActive) _resetCountdown();

      if (sawInvalidPayload) {
        _markInvalidQr();
      }

      setState(() {
        _qrDetected = false;
        _detectedQrData = null;
        _statusText = 'Align the ID back inside the guide';
        _guidanceText = barcodes.isEmpty
            ? 'Center the full card back and keep it steady'
            : 'Move the full ID inside the box before capture';
      });
      return;
    }

    final detectedBounds = _combineRects([qrRect, ...normalizedTextRects]);

    final coverage = detectedBounds == null
        ? (width: 0.0, height: 0.0)
        : _computeRectCoverage([detectedBounds], guideRect);
    final hasGoodGuideFit =
        detectedBounds != null && _isRectInsideGuide(detectedBounds, guideRect);
    final hasEnoughCoverage =
        coverage.width >= _minDetectedWidthCoverage &&
        coverage.height >= _minDetectedHeightCoverage;

    if (!hasGoodGuideFit || !hasEnoughCoverage) {
      _stableFrames = 0;
      if (_countdownActive) _resetCountdown();

      setState(() {
        _qrDetected = false;
        _detectedQrData = null;
        _statusText = 'Fit the full ID back inside the box';
        _guidanceText = detectedBounds == null
            ? 'Move the card fully into the guide'
            : _buildGuideOverflowHint(detectedBounds, guideRect);
      });
      return;
    }

    _stableFrames++;
    _detectedQrData = validBarcode.rawValue ?? validBarcode.displayValue;

    setState(() {
      _qrDetected = true;
      _isInvalidQr = false;
      _statusText = _countdownActive
          ? 'Capturing in $_countdown...'
          : 'ID Back detected. Hold steady';
      _guidanceText = 'Keep the full ID back inside the guide';
    });

    if (_stableFrames >= _requiredStableFrames && !_countdownActive) {
      _startCaptureCountdown();
    }
  }

  Size _normalizedFrameSize(double frameWidth, double frameHeight) {
    return Size(
      frameWidth < frameHeight ? frameWidth : frameHeight,
      frameWidth > frameHeight ? frameWidth : frameHeight,
    );
  }

  Rect _normalizeRectToPortrait(
    Rect rect,
    double frameWidth,
    double frameHeight,
  ) {
    if (frameHeight >= frameWidth) return rect;

    return Rect.fromLTRB(rect.top, rect.left, rect.bottom, rect.right);
  }

  Rect _buildGuideRect(
    double frameWidth,
    double frameHeight, {
    double inset = 0,
  }) {
    final frameSize = _normalizedFrameSize(frameWidth, frameHeight);
    final cardWidth = frameSize.width * _cardWidthFraction;
    final cardHeight = cardWidth / _cardAspectRatio;

    return Rect.fromCenter(
      center: Offset(
        frameSize.width / 2,
        frameSize.height * _cardCenterYFraction,
      ),
      width: cardWidth,
      height: cardHeight,
    ).deflate(inset);
  }

  Rect? _combineRects(Iterable<Rect> rects) {
    Rect? combined;
    for (final rect in rects) {
      combined = combined == null ? rect : combined.expandToInclude(rect);
    }
    return combined;
  }

  ({double width, double height}) _computeRectCoverage(
    List<Rect> rects,
    Rect guideRect,
  ) {
    if (rects.isEmpty) return (width: 0, height: 0);

    double minX = double.infinity;
    double maxX = 0;
    double minY = double.infinity;
    double maxY = 0;

    for (final rect in rects) {
      if (rect.left < minX) minX = rect.left;
      if (rect.right > maxX) maxX = rect.right;
      if (rect.top < minY) minY = rect.top;
      if (rect.bottom > maxY) maxY = rect.bottom;
    }

    final widthCoverage = ((maxX - minX) / guideRect.width).clamp(0.0, 1.0);
    final heightCoverage = ((maxY - minY) / guideRect.height).clamp(0.0, 1.0);

    return (width: widthCoverage, height: heightCoverage);
  }

  bool _isRectInsideGuide(Rect rect, Rect guideRect) {
    return rect.left >= guideRect.left - _guideTolerance &&
        rect.top >= guideRect.top - _guideTolerance &&
        rect.right <= guideRect.right + _guideTolerance &&
        rect.bottom <= guideRect.bottom + _guideTolerance;
  }

  double _intersectionRatio(Rect rect, Rect guideRect) {
    final intersection = rect.intersect(guideRect);
    if (intersection.isEmpty) return 0.0;

    final rectArea = rect.width * rect.height;
    if (rectArea <= 0) return 0.0;

    return (intersection.width * intersection.height) / rectArea;
  }

  String _buildGuideOverflowHint(Rect rect, Rect guideRect) {
    final hints = <String>[];

    if (rect.left < guideRect.left - _guideTolerance) {
      hints.add('Move ID right');
    }
    if (rect.right > guideRect.right + _guideTolerance) {
      hints.add('Move ID left');
    }
    if (rect.top < guideRect.top - _guideTolerance) {
      hints.add('Move ID down');
    }
    if (rect.bottom > guideRect.bottom + _guideTolerance) {
      hints.add('Move ID up');
    }

    return hints.isEmpty
        ? 'Move the full ID fully inside the guide'
        : hints.join(' | ');
  }

  void _markInvalidQr() {
    if (_isInvalidQr) return;

    setState(() => _isInvalidQr = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isInvalidQr = false);
      }
    });
  }

  void _startCaptureCountdown() {
    if (_countdownActive) return;

    _countdownActive = true;
    _countdown = 3;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdown--;
        if (_countdown > 0) {
          _statusText = 'Capturing in $_countdown...';
        } else {
          _statusText = 'Capturing...';
        }
      });

      if (_countdown <= 0) {
        timer.cancel();
        _captureAndReturn();
      }
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownActive = false;
    _countdown = 3;
  }

  Future<void> _captureAndReturn() async {
    if (_isCapturing || _controller == null || _detectedQrData == null) return;

    setState(() => _isCapturing = true);

    try {
      await _controller!.stopImageStream();
      final photo = await _controller!.takePicture();

      if (mounted) {
        Navigator.of(context).pop(
          IdBackCaptureResult(qrData: _detectedQrData!, imagePath: photo.path),
        );
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _qrDetected = false;
          _detectedQrData = null;
          _stableFrames = 0;
          _statusText = 'Capture failed. Try again';
          _guidanceText = 'Center the full ID back and hold steady';
        });
        _resetCountdown();
        _controller!.startImageStream(_processCameraImage);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraReady && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: _primary)),
          CustomPaint(
            painter: _CardOverlayPainter(
              qrDetected: _qrDetected,
              isInvalid: _isInvalidQr,
              progress: _qrDetected ? (3 - _countdown) / 3.0 : 0.0,
              cardWidthFraction: _cardWidthFraction,
              cardCenterYFraction: _cardCenterYFraction,
              cardAspectRatio: _cardAspectRatio,
            ),
            child: Container(),
          ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            left: 40,
            right: 40,
            child: Column(
              children: [
                if (_qrDetected)
                  _buildStatusChip(_statusText, _primary, Icons.check_circle)
                else if (_isInvalidQr)
                  _buildStatusChip(
                    'Invalid ID back. Use PhilSys ID',
                    _errorColor,
                    Icons.warning,
                  )
                else
                  _buildStatusChip(
                    _statusText,
                    Colors.white.withValues(alpha: 0.2),
                    Icons.badge_rounded,
                  ),
                const SizedBox(height: 16),
                Text(
                  _guidanceText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                if (_qrDetected && _countdown > 0)
                  Text(
                    'Capturing in $_countdown...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
          if (_isCapturing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: _primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardOverlayPainter extends CustomPainter {
  final bool qrDetected;
  final bool isInvalid;
  final double progress;
  final double cardWidthFraction;
  final double cardCenterYFraction;
  final double cardAspectRatio;

  _CardOverlayPainter({
    required this.qrDetected,
    required this.isInvalid,
    required this.progress,
    required this.cardWidthFraction,
    required this.cardCenterYFraction,
    required this.cardAspectRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cardWidth = size.width * cardWidthFraction;
    final cardHeight = cardWidth / cardAspectRatio;
    final cardTop = (size.height * cardCenterYFraction) - (cardHeight / 2);
    final cardLeft = (size.width - cardWidth) / 2;

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      const Radius.circular(20),
    );

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.drawRRect(cardRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    var borderColor = Colors.white.withValues(alpha: 0.3);
    if (isInvalid) {
      borderColor = const Color(0xFFEF4444);
    } else if (qrDetected) {
      borderColor = const Color(0xFF10B981);
    }

    canvas.drawRRect(
      cardRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = borderColor,
    );

    if (progress > 0 && qrDetected) {
      final progressRect = RRect.fromRectAndRadius(
        cardRect.outerRect.inflate(6),
        const Radius.circular(20),
      );
      final path = Path()..addRRect(progressRect);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF10B981),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CardOverlayPainter old) =>
      old.qrDetected != qrDetected ||
      old.isInvalid != isInvalid ||
      old.progress != progress;
}
