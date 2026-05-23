import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sprintify/services/logger_service.dart';
import 'package:sprintify/services/analysis/analysis_service.dart';

import '../models/test_mode.dart';
import '../providers/sprintify_state.dart';
import '../services/pose/pose_manager.dart';
import '../services/camera/camera_manager.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AnalysisService _analysisService = AnalysisService();
  final List<double> _bersediaScores = [];
  final List<double> _lariScores = [];

  String? _videoPath;
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;

  final CameraManager _cameraManager = CameraManager();
  final PoseManager _poseManager = PoseManager();

  CameraController? get _cameraController => _cameraManager.controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _cameraInitializing = false;
  String? _cameraError;
  
  bool _isBusy = false;
  Pose? _detectedPose; // Hasil dari deteksi pose
  Size? _imageSize; // Ukuran gambar untuk scaling
  int _detectionTimerSeconds = 0;
  Timer? _detectionTimer;
  bool _isPoseDetected = false;
  int _poseFoundTime = 0;

  final LoggerService _logger = LoggerService();

  Future<void> _addLog(String message, {LogType type = LogType.app, bool isError = false}) async {
    if (!mounted) return;
    
    // Log to file is temporarily disabled
    // _logger.log(message, type: type, isError: isError);
  }

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _cameraLive =>
      _isMobile && _cameraController != null && _cameraController!.value.isInitialized;

  @override
  void initState() {
    super.initState();
    _analysisService.loadReferencePoses();
    if (_isMobile) {
      _initCamera();
    }
  }

  Future<void> _initCamera({int? cameraIndex}) async {
    setState(() {
      _cameraInitializing = true;
      _cameraError = null;
    });
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    if (!cam.isGranted || !mic.isGranted) {
      if (mounted) {
        setState(() {
          _cameraInitializing = false;
          _cameraError = 'Izin kamera atau mikrofon belum diberikan.';
        });
      }
      return;
    }
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraInitializing = false;
            _cameraError = 'Tidak ada kamera.';
          });
        }
        return;
      }
      
      _selectedCameraIndex = cameraIndex ?? 0;
      await _cameraManager.initialize(_cameras[_selectedCameraIndex], (image) {
        if (!_isBusy) {
          _isBusy = true;
          _processCameraImage(image);
        }
      });
      
      if (!mounted) return;
      setState(() {
        _cameraInitializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraInitializing = false;
          _cameraError = e.toString();
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    await _cameraManager.dispose();
    setState(() {});
    
    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCamera(cameraIndex: newIndex);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _detectionTimer?.cancel();
    _cameraManager.dispose();
    _poseManager.dispose();
    super.dispose();
  }

  void _startDetectionTimer() {
    _detectionTimerSeconds = 0;
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_recording) {
        timer.cancel();
        return;
      }
      setState(() {
        _detectionTimerSeconds++;
      });
      if (_detectionTimerSeconds % 5 == 0) {
        _addLog('Mencari pose... (${_detectionTimerSeconds}s)', type: LogType.inference);
      }
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final inputImage = _cameraManager.inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }
    try {
      final List<Pose> poses = await _poseManager.processImage(inputImage);
      if (mounted) {
        final sensorOrientation = _cameraController?.description.sensorOrientation ?? 0;
        final bool isPersonDetected = poses.isNotEmpty;

        if (isPersonDetected != _isPoseDetected) {
          _isPoseDetected = isPersonDetected;
          if (_isPoseDetected) {
            _detectionTimer?.cancel();
            _poseFoundTime = _detectionTimerSeconds;
            _addLog('OK: Pose ditemukan! (Berhenti di ${_poseFoundTime}s)', type: LogType.inference);
          } else if (_recording) {
            _startDetectionTimer();
          }
        }

        if (isPersonDetected) {
          final bersediaScore = _analysisService.calculatePoseScore(poses.first, 'bersedia');
          final lariScore = _analysisService.calculatePoseScore(poses.first, 'berlari');
          
          if (_recording) {
            _bersediaScores.add(bersediaScore);
            _lariScores.add(lariScore);
          }
        }

        setState(() {
          _detectedPose = isPersonDetected ? poses.first : null;
          
          if (sensorOrientation == 90 || sensorOrientation == 270) {
            _imageSize = Size(image.height.toDouble(), image.width.toDouble());
          } else {
            _imageSize = Size(image.width.toDouble(), image.height.toDouble());
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      _addLog('Err: $e', isError: true);
    }
    _isBusy = false;
  }

  Future<void> _toggle() async {
    if (_cameraLive) {
      await _toggleVideoRecording();
    } else {
      _toggleMockRecording();
    }
  }

  void _toggleMockRecording() {
    setState(() {
      _recording = !_recording;
      if (_recording) {
        _seconds = 0;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _seconds++);
        });
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  Future<void> _toggleVideoRecording() async {
    final c = _cameraController;
    if (c == null || !c.value.isInitialized) return;
    try {
      if (!_recording) {
        await c.startVideoRecording();
        if (!mounted) return;
        setState(() {
          _recording = true;
          _seconds = 0;
          _startDetectionTimer();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (!mounted) return;
            setState(() => _seconds++);
          });
        });
      } else {
        if (c.value.isRecordingVideo) {
          final XFile file = await c.stopVideoRecording();
          _videoPath = file.path;
          
          // Simpan ke direktori aplikasi
          final appDocDir = await getApplicationDocumentsDirectory();
          final fileName = 'run_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final savedFile = await File(file.path).copy('${appDocDir.path}/$fileName');
          _videoPath = savedFile.path;
          
          debugPrint('Video saved to: ${_videoPath}');
        }
        _timer?.cancel();
        _timer = null;
        if (!mounted) return;
        setState(() => _recording = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rekaman gagal: $e')),
        );
      }
    }
  }

  Future<void> _finish() async {
    if (_recording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap berhenti merekam terlebih dahulu.')),
      );
      return;
    }

    // Simulasi pengecekan hasil rekaman (perlu disesuaikan jika sudah ada path file)
    // Jika tidak ada data video (misal _recording belum pernah true atau path kosong), hentikan
    // Disini diasumsikan jika _recording sempat true, kita lanjut.
    
    _timer?.cancel();
    if (!mounted) return;
    context.push('/processing');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SprintifyState>();
    final athlete = state.selectedAthlete;

    return Scaffold(
      appBar: AppBar(title: const Text('Rekaman')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(athlete?.name ?? '—', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Mode: ${state.testMode.label}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPreview(context),
                        if (_recording)
                          Positioned(
                            top: 12, left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text('REC ${_fmt(_seconds)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(child: FilledButton.tonal(onPressed: _cameraInitializing ? null : _toggle, child: Text(_recording ? 'Berhenti' : 'Mulai rekaman'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: _finish, child: const Text('Selesai & analisis'))),
                ],
              ),
            ),
// Hapus bagian tampilan log dari antarmuka pengguna
            /*
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('LOG INFERENSI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.copy, size: 16), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log disalin')))),
                    ],
                  ),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: _logHistory.length,
                      itemBuilder: (context, index) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: Text(_logHistory[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 10))),
                    ),
                  ),
                ],
              ),
            ),
            */
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_cameraInitializing) return ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Center(child: CircularProgressIndicator()));
    if (_cameraError != null) return ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: Center(child: Text(_cameraError!)));
    
    final c = _cameraController;
    if (c != null && c.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(c),
          CustomPaint(painter: DetectionAreaPainter()),
          if (_recording && _detectionTimer != null)
             Positioned(bottom: 20, right: 20, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text('Mencari: ${_detectionTimerSeconds}s', style: const TextStyle(color: Colors.white, fontSize: 14)))),
          if (_isPoseDetected)
             Positioned(bottom: 20, right: 20, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)), child: Text('Ditemukan: ${_poseFoundTime}s', style: const TextStyle(color: Colors.white, fontSize: 14)))),
          if (_cameras.length > 1)
             Positioned(top: 12, right: 12, child: IconButton(onPressed: _switchCamera, icon: const Icon(Icons.flip_camera_ios, color: Colors.white), style: IconButton.styleFrom(backgroundColor: Colors.black45))),
          if (_detectedPose != null && _imageSize != null)
             CustomPaint(painter: PosePainter(_detectedPose!, _imageSize!)),
        ],
      );
    }
    return ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Center(child: CircularProgressIndicator()));
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  PosePainter(this.pose, this.imageSize);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.green..strokeWidth = 4.0;
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    for (final landmark in pose.landmarks.values) {
      canvas.drawCircle(Offset(landmark.x * scaleX, landmark.y * scaleY), 5.0, paint);
    }
  }
  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
}

class DetectionAreaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 3.0;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width * 0.6, height: size.height * 0.6);
    canvas.drawRect(rect, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
