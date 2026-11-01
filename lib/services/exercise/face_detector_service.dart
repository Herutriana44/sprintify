import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Size;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../services/camera/camera_manager.dart';

/// Service yang mendeteksi wajah via MLKit untuk menghitung repetisi Sit Up.
///
/// Logika Sit Up:
/// - Wajah **tidak terdeteksi** → posisi TIDUR (bawah)
/// - Wajah **terdeteksi**       → posisi DUDUK (atas)
/// - Transisi tidur→duduk = 1 repetisi
class FaceDetectorService {
  FaceDetectorService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: false,
        enableLandmarks: false,
        enableTracking: false,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  late final FaceDetector _detector;

  int _repCount = 0;
  bool _faceWasPresent = false;

  // Debounce
  int _presentStreak = 0;
  int _absentStreak = 0;
  static const int _debounceFrames = 4;

  int get repCount => _repCount;

  /// Reset untuk sesi baru.
  void reset() {
    _repCount = 0;
    _faceWasPresent = false;
    _presentStreak = 0;
    _absentStreak = 0;
  }

  /// Proses frame kamera dan update hitungan repetisi.
  ///
  /// Mengembalikan `true` jika wajah terdeteksi pada frame ini.
  Future<bool> processFrame({
    required CameraImage image,
    required int sensorOrientation,
    required CameraManager cameraManager,
  }) async {
    final inputImage = _buildInputImage(
      image: image,
      sensorOrientation: sensorOrientation,
      cameraManager: cameraManager,
    );

    if (inputImage == null) return false;

    try {
      final faces = await _detector.processImage(inputImage);
      final faceDetected = faces.isNotEmpty;

      if (faceDetected) {
        _presentStreak++;
        _absentStreak = 0;

        // Konfirmasi wajah hadir setelah debounce
        if (_presentStreak >= _debounceFrames && !_faceWasPresent) {
          _faceWasPresent = true;
          _repCount++;  // wajah muncul = 1 rep sit up selesai
          _presentStreak = 0;
        }
      } else {
        _absentStreak++;
        _presentStreak = 0;

        // Konfirmasi wajah absen setelah debounce
        if (_absentStreak >= _debounceFrames && _faceWasPresent) {
          _faceWasPresent = false;
          _absentStreak = 0;
        }
      }

      return faceDetected;
    } catch (e) {
      debugPrint('FaceDetectorService error: $e');
      return false;
    }
  }

  /// Bersihkan resource detektor.
  Future<void> dispose() async {
    await _detector.close();
  }

  InputImage? _buildInputImage({
    required CameraImage image,
    required int sensorOrientation,
    required CameraManager cameraManager,
  }) {
    try {
      final rotation = cameraManager.getRotation(sensorOrientation);
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('FaceDetectorService _buildInputImage error: $e');
      return null;
    }
  }
}
