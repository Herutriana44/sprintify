import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraManager {
  CameraController? controller;

  /// Callback frame yang dipakai baik saat preview (startImageStream) maupun
  /// saat rekaman (startVideoRecording onAvailable). Disimpan agar bisa
  /// dipasang ulang setiap kali sumber frame berpindah.
  void Function(CameraImage)? _onImage;

  Future<void> initialize(
      CameraDescription description,
      void Function(CameraImage) onImage,
      ) async {
    _onImage = onImage;
    controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await controller!.initialize();
    await controller!.startImageStream(onImage);
  }

  bool get isRecording => controller?.value.isRecordingVideo ?? false;

  /// Mulai merekam video TANPA menghentikan aliran frame untuk pose detection.
  ///
  /// Plugin camera tidak boleh menjalankan startImageStream dan
  /// startVideoRecording sekaligus, jadi stream preview dihentikan dulu lalu
  /// frame dialirkan lewat parameter `onAvailable` milik startVideoRecording.
  /// Dengan begitu deteksi pose, klasifikasi, dan skeleton tetap hidup selama
  /// perekaman berlangsung (tidak membeku).
  Future<void> startRecording() async {
    final c = controller;
    if (c == null || !c.value.isInitialized || c.value.isRecordingVideo) {
      return;
    }
    if (c.value.isStreamingImages) {
      await c.stopImageStream();
    }
    await c.startVideoRecording(onAvailable: _onImage);
  }

  /// Hentikan rekaman lalu kembalikan aliran frame preview agar deteksi pose
  /// terus berjalan. Mengembalikan file video hasil rekaman (bila ada).
  Future<XFile?> stopRecording() async {
    final c = controller;
    if (c == null) return null;
    XFile? file;
    if (c.value.isRecordingVideo) {
      // stopVideoRecording juga menutup stream onAvailable secara internal.
      file = await c.stopVideoRecording();
    }
    await ensurePreviewStream();
    return file;
  }

  /// Pastikan stream preview aktif (dipakai untuk resume setelah rekaman atau
  /// pemulihan bila memulai rekaman gagal), sehingga frame tetap mengalir ke
  /// pose detection.
  Future<void> ensurePreviewStream() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isRecordingVideo) return; // frame datang via onAvailable
    if (c.value.isStreamingImages) return; // sudah streaming
    final cb = _onImage;
    if (cb != null) {
      await c.startImageStream(cb);
    }
  }

  InputImageRotation getRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  InputImage? inputImageFromCameraImage(CameraImage image) {
    final camera = controller?.description;
    if (camera == null) return null;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) return null;

    // Validasi format per platform
    if (Platform.isAndroid && inputImageFormat != InputImageFormat.nv21) {
      return null;
    }
    if (Platform.isIOS && inputImageFormat != InputImageFormat.bgra8888) {
      return null;
    }

    final rotation = getRotation(camera.sensorOrientation);

    if (Platform.isAndroid) {
      // NV21: Android bisa mengirim 1 atau 2 planes tergantung driver/kamera.
      // Bila 2 planes, gabungkan Y-plane dan UV-plane menjadi satu buffer NV21.
      // Bila 1 plane, gunakan langsung.
      final Uint8List bytes;
      if (image.planes.length == 1) {
        bytes = image.planes[0].bytes;
      } else if (image.planes.length >= 2) {
        // Gabungkan Y + UV menjadi buffer NV21 yang valid
        final yPlane = image.planes[0].bytes;
        final uvPlane = image.planes[1].bytes;
        final combined = Uint8List(yPlane.length + uvPlane.length);
        combined.setAll(0, yPlane);
        combined.setAll(yPlane.length, uvPlane);
        bytes = combined;
      } else {
        return null;
      }

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else {
      // iOS: BGRA8888 selalu 1 plane
      if (image.planes.length != 1) return null;
      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }
  }

  Future<void> dispose() async {
    await controller?.dispose();
    controller = null;
    _onImage = null;
  }
}
