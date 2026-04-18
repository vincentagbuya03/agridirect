import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  static const Color _primary = Color(0xFF10B981);
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isProcessing = true);
        _scannerController.stop();
        Navigator.of(context).pop(barcode.rawValue);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Scan PhilSys QR',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          
          // Scanning Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QROverlayShape(
                borderColor: _primary,
                borderRadius: 24,
                borderLength: 40,
                borderWidth: 8,
                cutOutSize: 300,
              ),
            ),
          ),

          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  'Align the QR code within the frame',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Data will be extracted automatically',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QROverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double overlayOpacity;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QROverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 8.0,
    this.overlayOpacity = 0.6,
    this.borderRadius = 24.0,
    this.borderLength = 40.0,
    this.cutOutSize = 300.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(
        rect.right,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.top,
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: overlayOpacity)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final cutOutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      );

    canvas.drawPath(
      Path.combine(PathOperation.difference, getOuterPath(rect), cutOutPath),
      backgroundPaint,
    );

    final path = Path()
      // top left
      ..moveTo(cutOutRect.left, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(cutOutRect.left, cutOutRect.top,
          cutOutRect.left + borderRadius, cutOutRect.top)
      ..lineTo(cutOutRect.left + borderRadius + borderLength, cutOutRect.top)
      ..moveTo(cutOutRect.left, cutOutRect.top + borderRadius)
      ..lineTo(cutOutRect.left, cutOutRect.top + borderRadius + borderLength)

      // top right
      ..moveTo(cutOutRect.right, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(cutOutRect.right, cutOutRect.top,
          cutOutRect.right - borderRadius, cutOutRect.top)
      ..lineTo(cutOutRect.right - borderRadius - borderLength, cutOutRect.top)
      ..moveTo(cutOutRect.right, cutOutRect.top + borderRadius)
      ..lineTo(cutOutRect.right, cutOutRect.top + borderRadius + borderLength)

      // bottom left
      ..moveTo(cutOutRect.left, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(cutOutRect.left, cutOutRect.bottom,
          cutOutRect.left + borderRadius, cutOutRect.bottom)
      ..lineTo(
          cutOutRect.left + borderRadius + borderLength, cutOutRect.bottom)
      ..moveTo(cutOutRect.left, cutOutRect.bottom - borderRadius)
      ..lineTo(cutOutRect.left, cutOutRect.bottom - borderRadius - borderLength)

      // bottom right
      ..moveTo(cutOutRect.right, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(cutOutRect.right, cutOutRect.bottom,
          cutOutRect.right - borderRadius, cutOutRect.bottom)
      ..lineTo(
          cutOutRect.right - borderRadius - borderLength, cutOutRect.bottom)
      ..moveTo(cutOutRect.right, cutOutRect.bottom - borderRadius)
      ..lineTo(
          cutOutRect.right, cutOutRect.bottom - borderRadius - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QROverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayOpacity: overlayOpacity,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
