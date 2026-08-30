import 'dart:async';
import 'dart:io';
import 'package:image/image.dart' as img;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Result returned from the IdBackCaptureScreen.
/// Contains the QR raw string data and the path to the captured photo.
class IdBackCaptureResult {
  final String qrData;
  final String imagePath;
  IdBackCaptureResult({required this.qrData, required this.imagePath});
}

/// Full-screen camera view for automatically scanning the BACK of a National ID.
/// It validates the PhilSys QR code and automatically captures as soon as the QR is recognized.
class IdBackCaptureScreen extends StatefulWidget {
  final String label;
  const IdBackCaptureScreen({super.key, this.label = 'PhilSys QR Auto-Scan'});

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

  CameraController? _controller;
  CameraDescription? _rearCamera;
  bool _isCameraReady = false;

  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  bool _qrDetected = false;
  final bool _isInvalidQr = false;
  bool _isCapturing = false;
  bool _countdownActive = false;
  int _countdown = 1;
  String? _detectedQrData;
  String _statusText = 'Point camera at PhilSys QR Code';
  String _guidanceText = 'Hold steady, camera will auto-capture';

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
        _statusText = 'Point camera at PhilSys QR Code';
        _guidanceText = 'Hold steady, camera will auto-capture';
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

    final barcodes = await _barcodeScanner.processImage(inputImage);

    if (!mounted || _isCapturing) return;

    _analyzeFrame(
      barcodes: barcodes,
      frameW: image.width.toDouble(),
      frameH: image.height.toDouble(),
      sensorOrientation: _rearCamera!.sensorOrientation,
    );
  } catch (e) {
    debugPrint('Error processing image: $e');
  } finally {
    _isProcessing = false;
  }
}

void _analyzeFrame({
  required List<Barcode> barcodes,
  required double frameW,
  required double frameH,
  required int sensorOrientation,
}) {
  Barcode? validBarcode;

  for (final barcode in barcodes) {
    final rawValue = barcode.rawValue ?? barcode.displayValue ?? '';
    if (rawValue.length >= 8) {
      validBarcode = barcode;
      break;
    }
  }

  if (validBarcode == null) {
    if (_countdownActive) _resetCountdown();

    setState(() {
      _qrDetected = false;
      _detectedQrData = null;
      _statusText = 'Position ID Back in frame';
      _guidanceText = 'Fit the entire card inside the box';
    });
    return;
  }

  final guideRect = _portraitGuideRect();
  final qrRect = _normalizeRectToPortraitFraction(
    validBarcode.boundingBox,
    frameW,
    frameH,
    sensorOrientation,
  );
  final cx = qrRect.center.dx;
  final cy = qrRect.center.dy;
  final bool isInsideBox = cx >= (guideRect.left - 0.02) &&
                cx <= (guideRect.right + 0.02) &&
                cy >= (guideRect.top - 0.02) &&
                cy <= (guideRect.bottom + 0.02);
  final bool isLargeEnough = qrRect.width >= 0.20 && qrRect.height >= 0.18;

  if (!isInsideBox || !isLargeEnough) {
    if (_countdownActive) _resetCountdown();
    setState(() {
      _qrDetected = false;
      _detectedQrData = null;
      if (!isInsideBox) {
        _statusText = 'Fit ID inside the box';
        _guidanceText = 'Align the ID card inside the guide frame';
      } else {
        _statusText = 'Move closer';
        _guidanceText = 'Position the ID closer to fill the box';
      }
    });
    return;
  }

  _detectedQrData = validBarcode.rawValue ?? validBarcode.displayValue;

  setState(() {
    _qrDetected = true;
    _statusText = 'ID Aligned! Capturing...';
    _guidanceText = 'Hold steady for photo';
  });

  if (!_countdownActive) {
    _startCaptureCountdown();
  }
}

Rect _portraitGuideRect() {
  final cardHeight = _cardWidthFraction / _cardAspectRatio;
  return Rect.fromCenter(
    center: const Offset(0.5, _cardCenterYFraction),
    width: _cardWidthFraction,
    height: cardHeight,
  ).inflate(0.06);
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

  void _startCaptureCountdown() {
    if (_countdownActive) return;

    _countdownActive = true;
    _countdown = 1;
    _countdownTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _captureAndReturn();
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownActive = false;
    _countdown = 1;
  }

  Future<void> _captureAndReturn() async {
    if (_isCapturing || _controller == null || _detectedQrData == null) return;

    setState(() => _isCapturing = true);

    try {
      await _controller!.stopImageStream();
      final photo = await _controller!.takePicture();
      final croppedPath = await _cropToGuideBox(photo.path);

      if (mounted) {
        Navigator.of(context).pop(
          IdBackCaptureResult(qrData: _detectedQrData!, imagePath: croppedPath),
        );
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _qrDetected = false;
          _detectedQrData = null;
          _statusText = 'Capture failed. Try again';
          _guidanceText = 'Center the full ID back and hold steady';
        });
        _resetCountdown();
        _controller!.startImageStream(_processCameraImage);
      }
    }
  }

  /// Crops the full photo to only the region inside the guide box.
  Future<String> _cropToGuideBox(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return imagePath;

      final upright = img.bakeOrientation(original);
      final iw = upright.width;
      final ih = upright.height;

      const cardWidthFraction = 0.88;
      const cardAspectRatio = 1.586;
      const cardCenterYFraction = 0.42;
      const cardHeightFraction = cardWidthFraction / cardAspectRatio;

      final left   = ((0.5 - cardWidthFraction / 2) * iw).round().clamp(0, iw);
      final right  = ((0.5 + cardWidthFraction / 2) * iw).round().clamp(0, iw);
      final top    = ((cardCenterYFraction - cardHeightFraction / 2) * ih).round().clamp(0, ih);
      final bottom = ((cardCenterYFraction + cardHeightFraction / 2) * ih).round().clamp(0, ih);

      final cropped = img.copyCrop(
        upright,
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
      );

      final croppedBytes = img.encodeJpg(cropped, quality: 92);
      await File(imagePath).writeAsBytes(croppedBytes);
      return imagePath;
    } catch (e) {
      debugPrint('[IdBack] Crop error: $e');
      return imagePath;
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
              progress: _qrDetected ? (1 - _countdown) / 1.0 : 0.0,
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
            bottom: 40,
            left: 20,
            right: 20,
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
                    Icons.flip_to_back_rounded,
                  ),
                const SizedBox(height: 12),
                Text(
                  _guidanceText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                if (_qrDetected && _countdown > 0)
                  Text(
                    'Capturing in $_countdown...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else
                  Text(
                    'Auto-captures when QR is aligned',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                const SizedBox(height: 32),
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
