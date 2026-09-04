import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

/// Result from 1-to-1 Biometric Facial Comparison.
class BiometricFaceMatchResult {
  final bool isMatched;
  final double similarityScore; // 0.0 to 1.0
  final bool faceFoundOnId;
  final bool faceFoundOnSelfie;
  final String status;
  final Map<String, dynamic> details;

  const BiometricFaceMatchResult({
    required this.isMatched,
    required this.similarityScore,
    required this.faceFoundOnId,
    required this.faceFoundOnSelfie,
    required this.status,
    this.details = const {},
  });

  Map<String, dynamic> toJson() => {
        'is_matched': isMatched,
        'similarity_score': similarityScore,
        'face_found_on_id': faceFoundOnId,
        'face_found_on_selfie': faceFoundOnSelfie,
        'status': status,
        'details': details,
      };
}

/// On-Device Biometric Facial Matcher.
///
/// Compares the facial portrait extracted from an ID card with a live selfie
/// using Google ML Kit BlazeFace landmarks, structural triangle ratios,
/// and normalized facial geometry vectors.
class BiometricFaceMatchingService {
  /// Minimum facial similarity score required for identity confirmation.
  static const double matchThreshold = 0.65; // 65% match

  /// Compares an ID Front image and a Live Selfie image.
  static Future<BiometricFaceMatchResult> compareFaces({
    required String idFrontImagePath,
    required String selfieImagePath,
    Uint8List? idFrontBytes,
    Uint8List? selfieBytes,
  }) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1,
      ),
    );

    try {
      // 1. Process ID Card Image
      InputImage? idInputImage;
      if (!kIsWeb && File(idFrontImagePath).existsSync()) {
        idInputImage = InputImage.fromFilePath(idFrontImagePath);
      } else if (idFrontBytes != null) {
        idInputImage = InputImage.fromBytes(
          bytes: idFrontBytes,
          metadata: InputImageMetadata(
            size: const Size(640, 480),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: 640,
          ),
        );
      }

      // 2. Process Live Selfie Image
      InputImage? selfieInputImage;
      if (!kIsWeb && File(selfieImagePath).existsSync()) {
        selfieInputImage = InputImage.fromFilePath(selfieImagePath);
      } else if (selfieBytes != null) {
        selfieInputImage = InputImage.fromBytes(
          bytes: selfieBytes,
          metadata: InputImageMetadata(
            size: const Size(640, 480),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: 640,
          ),
        );
      }

      if (idInputImage == null || selfieInputImage == null) {
        return const BiometricFaceMatchResult(
          isMatched: false,
          similarityScore: 0.0,
          faceFoundOnId: false,
          faceFoundOnSelfie: false,
          status: 'Image files could not be loaded for facial analysis',
        );
      }

      final idFaces = await detector.processImage(idInputImage);
      final selfieFaces = await detector.processImage(selfieInputImage);

      final faceFoundOnId = idFaces.isNotEmpty;
      final faceFoundOnSelfie = selfieFaces.isNotEmpty;

      if (!faceFoundOnId || !faceFoundOnSelfie) {
        return BiometricFaceMatchResult(
          isMatched: false,
          similarityScore: 0.0,
          faceFoundOnId: faceFoundOnId,
          faceFoundOnSelfie: faceFoundOnSelfie,
          status: !faceFoundOnId
              ? 'No face found on ID card portrait'
              : 'No face found on live selfie',
        );
      }

      // Pick the primary (largest) face from each image
      idFaces.sort((a, b) =>
          (b.boundingBox.width * b.boundingBox.height)
              .compareTo(a.boundingBox.width * a.boundingBox.height));
      selfieFaces.sort((a, b) =>
          (b.boundingBox.width * b.boundingBox.height)
              .compareTo(a.boundingBox.width * a.boundingBox.height));

      final idFace = idFaces.first;
      final selfieFace = selfieFaces.first;

      // Extract geometry vectors
      final idVector = _extractFacialGeometryVector(idFace);
      final selfieVector = _extractFacialGeometryVector(selfieFace);

      double landmarkSimilarity = _computeCosineSimilarity(idVector, selfieVector);

      // Optional visual correlation if local files exist
      double visualSimilarity = landmarkSimilarity;
      if (!kIsWeb && File(idFrontImagePath).existsSync() && File(selfieImagePath).existsSync()) {
        try {
          final idCrop = await _cropFace(idFrontImagePath, idFace.boundingBox);
          final selfieCrop = await _cropFace(selfieImagePath, selfieFace.boundingBox);
          if (idCrop != null && selfieCrop != null) {
            visualSimilarity = _computeImageCorrelation(idCrop, selfieCrop);
          }
        } catch (_) {
          // Fallback to landmark similarity
        }
      }

      // Blend: 70% Geometric landmarks + 30% Visual structure
      final blendedScore = ((landmarkSimilarity * 0.7) + (visualSimilarity * 0.3)).clamp(0.0, 1.0);
      final isMatched = blendedScore >= matchThreshold;

      return BiometricFaceMatchResult(
        isMatched: isMatched,
        similarityScore: double.parse(blendedScore.toStringAsFixed(3)),
        faceFoundOnId: true,
        faceFoundOnSelfie: true,
        status: isMatched
            ? 'Biometric Match Confirmed (${(blendedScore * 100).toStringAsFixed(1)}%)'
            : 'Face Mismatch: Selfie does not match ID portrait (${(blendedScore * 100).toStringAsFixed(1)}%)',
        details: {
          'landmark_similarity': landmarkSimilarity,
          'visual_similarity': visualSimilarity,
          'id_head_euler_y': idFace.headEulerAngleY,
          'selfie_head_euler_y': selfieFace.headEulerAngleY,
        },
      );
    } catch (e) {
      return BiometricFaceMatchResult(
        isMatched: false,
        similarityScore: 0.0,
        faceFoundOnId: false,
        faceFoundOnSelfie: false,
        status: 'Face analysis error: $e',
      );
    } finally {
      detector.close();
    }
  }

  /// Extracts scale-invariant normalized facial feature vectors from landmarks and contours.
  static List<double> _extractFacialGeometryVector(Face face) {
    final vector = <double>[];

    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final noseBase = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;
    final leftEar = face.landmarks[FaceLandmarkType.leftEar]?.position;
    final rightEar = face.landmarks[FaceLandmarkType.rightEar]?.position;

    // Normalize scale by inter-pupillary distance (eye-to-eye distance)
    double eyeDist = 100.0;
    if (leftEye != null && rightEye != null) {
      final dx = (rightEye.x - leftEye.x).toDouble();
      final dy = (rightEye.y - leftEye.y).toDouble();
      eyeDist = sqrt(dx * dx + dy * dy);
      if (eyeDist < 1.0) eyeDist = 1.0;
    }

    final box = face.boundingBox;
    vector.add(box.width / (box.height > 0 ? box.height : 1.0)); // Aspect ratio

    if (leftEye != null && rightEye != null) {
      final midEyeX = (leftEye.x + rightEye.x) / 2.0;
      final midEyeY = (leftEye.y + rightEye.y) / 2.0;

      if (noseBase != null) {
        vector.add((noseBase.x - midEyeX) / eyeDist);
        vector.add((noseBase.y - midEyeY) / eyeDist);
      }
      if (bottomMouth != null) {
        vector.add((bottomMouth.x - midEyeX) / eyeDist);
        vector.add((bottomMouth.y - midEyeY) / eyeDist);
      }
      if (leftCheek != null && rightCheek != null) {
        final cheekDx = (rightCheek.x - leftCheek.x).toDouble();
        final cheekDy = (rightCheek.y - leftCheek.y).toDouble();
        vector.add(sqrt(cheekDx * cheekDx + cheekDy * cheekDy) / eyeDist);
      }
      if (leftEar != null && rightEar != null) {
        final earDx = (rightEar.x - leftEar.x).toDouble();
        final earDy = (rightEar.y - leftEar.y).toDouble();
        vector.add(sqrt(earDx * earDx + earDy * earDy) / eyeDist);
      }
    }

    // Add contour points if available
    final faceOval = face.contours[FaceContourType.face];
    if (faceOval != null && faceOval.points.isNotEmpty) {
      final step = max(1, faceOval.points.length ~/ 10);
      for (int i = 0; i < faceOval.points.length; i += step) {
        final pt = faceOval.points[i];
        vector.add((pt.x - box.left) / (box.width > 0 ? box.width : 1.0));
        vector.add((pt.y - box.top) / (box.height > 0 ? box.height : 1.0));
      }
    }

    return vector;
  }

  /// Calculates cosine similarity between two feature vectors.
  static double _computeCosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.isEmpty || v2.isEmpty) return 0.0;
    final minLen = min(v1.length, v2.length);

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < minLen; i++) {
      dotProduct += v1[i] * v2[i];
      norm1 += v1[i] * v1[i];
      norm2 += v2[i] * v2[i];
    }

    if (norm1 <= 0.0 || norm2 <= 0.0) return 0.0;
    final sim = dotProduct / (sqrt(norm1) * sqrt(norm2));
    return sim.clamp(0.0, 1.0);
  }

  /// Crops face bounding box from file image.
  static Future<img.Image?> _cropFace(String path, Rect rect) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final x = max(0, rect.left.toInt());
      final y = max(0, rect.top.toInt());
      final w = min(decoded.width - x, rect.width.toInt());
      final h = min(decoded.height - y, rect.height.toInt());

      if (w <= 10 || h <= 10) return null;
      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
      return img.copyResize(cropped, width: 64, height: 64);
    } catch (_) {
      return null;
    }
  }

  /// Computes pixel-level structural intensity correlation on 64x64 cropped faces.
  static double _computeImageCorrelation(img.Image img1, img.Image img2) {
    final gray1 = img.grayscale(img1);
    final gray2 = img.grayscale(img2);

    double sumDiff = 0.0;
    int totalPixels = 0;

    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        final p1 = gray1.getPixel(x, y).r;
        final p2 = gray2.getPixel(x, y).r;
        sumDiff += (p1 - p2).abs() / 255.0;
        totalPixels++;
      }
    }

    if (totalPixels == 0) return 0.0;
    final avgDiff = sumDiff / totalPixels;
    // Lower diff means higher similarity
    return (1.0 - avgDiff).clamp(0.0, 1.0);
  }
}
