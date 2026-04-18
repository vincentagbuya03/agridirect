import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
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

/// Full-screen camera view for scanning the BACK of a National ID.
/// Uses ML Kit Barcode Scanning to detect the PhilSys QR code.
/// Once detected, it auto-captures the high-res photo.
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

  CameraController? _controller;
  CameraDescription? _rearCamera;
  bool _isCameraReady = false;

  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );
  bool _isProcessing = false;

  // ─── Detection States ───
  bool _qrDetected = false;
  bool _isInvalidQr = false;
  String? _detectedQrData;
  bool _isCapturing = false;

  // ─── Countdown ───
  Timer? _countdownTimer;
  int _countdownSeconds = 3;
  bool _countdownActive = false;
  double _progress = 0.0;

  String _statusText = 'Initializing camera…';
  String _guidanceText = 'Position the QR code within the frame';

  static const double _cardCenterYFraction = 0.42;
  static const double _cardWidthFraction = 0.88;
  static const double _cardAspectRatio = 1.586;

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
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
        _statusText = 'Position the back of your ID';
        _guidanceText = 'Align the QR code within the frame';
      });

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
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (!mounted || _isCapturing) return;

      _analyzeBarcodes(barcodes);
    } catch (e) {
      debugPrint('Barcode processing error: $e');
    }
  }

  void _analyzeBarcodes(List<Barcode> barcodes) {
    if (barcodes.isEmpty) {
      if (!_countdownActive) {
        setState(() {
          _qrDetected = false;
          _isInvalidQr = false;
          _statusText = 'Position the back of your ID';
        });
      }
      return;
    }

    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      // Validate PhilSys QR
      final upper = raw.toUpperCase();
      if (raw.contains('subject') || raw.contains('fName') || 
          raw.contains('PCN') || upper.contains('PHILSYS') || raw.startsWith('{')) {
        
        if (!_countdownActive) {
          setState(() {
            _qrDetected = true;
            _isInvalidQr = false;
            _detectedQrData = raw;
            _statusText = 'QR Code Detected!';
            _guidanceText = 'Hold still — auto-capturing…';
          });
          _startCountdown();
        }
        return;
      } else {
        setState(() {
          _isInvalidQr = true;
          _qrDetected = false;
          _statusText = 'Invalid QR Code!';
          _guidanceText = 'Please scan the PhilSys QR on your National ID.';
        });
      }
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (_rearCamera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      _rearCamera!.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final imageFormat = format ?? (Platform.isAndroid ? InputImageFormat.nv21 : null);
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
          _statusText = 'Done!';
        }
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _autoCapture();
      }
    });
  }

  Future<void> _autoCapture() async {
    if (_isCapturing || _detectedQrData == null) return;
    _isCapturing = true;

    try {
      await _controller!.stopImageStream();
      final xFile = await _controller!.takePicture();
      
      if (mounted) {
        Navigator.of(context).pop(
          IdBackCaptureResult(
            qrData: _detectedQrData!,
            imagePath: xFile.path,
          ),
        );
      }
    } catch (e) {
      _isCapturing = false;
      _countdownActive = false;
      _qrDetected = false;
      _initCamera();
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
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

          // Card overlay
          CustomPaint(
            painter: _CardOverlayPainter(
              cardDetected: _qrDetected,
              isForbidden: _isInvalidQr,
              progress: _progress,
              primaryColor: _primary,
              errorColor: _errorColor,
              cardWidthFraction: _cardWidthFraction,
              cardCenterYFraction: _cardCenterYFraction,
              cardAspectRatio: _cardAspectRatio,
            ),
            size: Size.infinite,
          ),

          // Countdown badge
          if (_countdownActive && _countdownSeconds > 0)
            Positioned(
              top: MediaQuery.of(context).size.height * _cardCenterYFraction - 30,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withValues(alpha: 0.85),
                  ),
                  child: Center(
                    child: Text('$_countdownSeconds',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 32, fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
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
                    Text(widget.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w700,
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

          // Bottom status
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isInvalidQr
                          ? _errorColor.withValues(alpha: 0.9)
                          : (_qrDetected ? _primary.withValues(alpha: 0.9) : Colors.black54),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isInvalidQr
                              ? Icons.cancel_rounded
                              : (_qrDetected ? Icons.check_circle : Icons.qr_code_scanner_rounded),
                          color: Colors.white, size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(_statusText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_guidanceText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(_guidanceText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: _isInvalidQr ? _errorColor : Colors.white70,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Auto-captures when PhilSys QR is detected',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white60),
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
    required this.cardDetected, required this.isForbidden,
    required this.progress, required this.primaryColor,
    required this.errorColor, required this.cardWidthFraction,
    required this.cardCenterYFraction, required this.cardAspectRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cardWidth = size.width * cardWidthFraction;
    final cardHeight = cardWidth / cardAspectRatio;
    final centerY = size.height * cardCenterYFraction;
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width / 2, centerY), width: cardWidth, height: cardHeight),
      const Radius.circular(16),
    );

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(cardRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    Color borderColor = Colors.white.withValues(alpha: 0.7);
    if (isForbidden) {
      borderColor = errorColor;
    } else if (cardDetected) {
      borderColor = primaryColor;
    }

    canvas.drawRRect(cardRect, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = borderColor);
    
    if (progress > 0 && cardDetected && !isForbidden) {
      final progressRect = RRect.fromRectAndRadius(cardRect.outerRect.inflate(6), const Radius.circular(20));
      final path = Path()..addRRect(progressRect);
      final pm = path.computeMetrics().first;
      canvas.drawPath(pm.extractPath(0, pm.length * progress),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round..color = primaryColor);
    }
  }

  @override
  bool shouldRepaint(covariant _CardOverlayPainter old) => true;
}
