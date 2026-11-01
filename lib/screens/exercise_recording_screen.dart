import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/exercise_type.dart';
import '../models/pending_exercise.dart';
import '../providers/t_smart_state.dart';
import '../services/camera/camera_manager.dart';
import '../services/exercise/face_detector_service.dart';
import '../services/exercise/rep_counter_service.dart';
import '../services/pose/frame_saving_isolate.dart';

// ── Fase sesi ──────────────────────────────────────────────────────────────
enum _SessionPhase {
  /// Inisialisasi kamera & service berlangsung.
  initializing,

  /// Kamera siap, menunggu user tekan Mulai.
  ready,

  /// Hitung mundur aktif (countdown).
  countdown,

  /// Rekaman & penghitungan rep aktif.
  recording,

  /// Selesai (sedang navigasi ke layar processing).
  done,
}

class ExerciseRecordingScreen extends StatefulWidget {
  const ExerciseRecordingScreen({
    super.key,
    required this.countdownSeconds,
  });

  /// Durasi hitung mundur dalam detik (3, 5, atau 10).
  final int countdownSeconds;

  @override
  State<ExerciseRecordingScreen> createState() =>
      _ExerciseRecordingScreenState();
}

class _ExerciseRecordingScreenState extends State<ExerciseRecordingScreen> {
  // ── Core services ──────────────────────────────────────────────────────────
  final CameraManager _cameraManager = CameraManager();
  late RepCounterService _repCounter;
  FaceDetectorService? _faceDetector;
  FrameSavingIsolate? _frameSavingIsolate;
  PoseDetector? _poseDetector;

  // ── Camera ─────────────────────────────────────────────────────────────────
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  String? _cameraError;

  // ── Session state ──────────────────────────────────────────────────────────
  _SessionPhase _phase = _SessionPhase.initializing;
  int _countdownValue = 0;
  int _elapsedSeconds = 0;
  Timer? _countdownTimer;
  Timer? _elapsedTimer;

  // ── Rep counting ───────────────────────────────────────────────────────────
  int _repCount = 0;
  bool _faceDetected = false; // untuk sit up UI feedback

  // ── Pose overlay ──────────────────────────────────────────────────────────
  Map<String, Map<String, double>>? _detectedLandmarks;
  Size? _imageSize;
  bool _isBusy = false;
  int _poseLostFrameCount = 0;
  static const int _poseKeepAliveFrames = 8;

  // ── Sample frames ─────────────────────────────────────────────────────────
  final List<String> _sampleFramePaths = [];
  int _sampleFrameCounter = 0;
  static const int _maxSampleFrames = 15;
  static const int _sampleFrameInterval = 8;

  // ── Exercise info ─────────────────────────────────────────────────────────
  late ExerciseType _exerciseType;

  CameraController? get _cameraController => _cameraManager.controller;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _cameraLive =>
      _isMobile &&
      _cameraController != null &&
      _cameraController!.value.isInitialized;

  @override
  void initState() {
    super.initState();
    _exerciseType = context.read<TSmartState>().selectedExerciseType;
    _repCounter = RepCounterService(exerciseType: _exerciseType);
    if (_exerciseType == ExerciseType.sitUp) {
      _faceDetector = FaceDetectorService();
    } else {
      _poseDetector = PoseDetector(options: PoseDetectorOptions());
    }
    _initAll();
  }

  Future<void> _initAll() async {
    await _initFrameSaver();
    if (_isMobile) {
      await _initCamera();
    } else {
      // Platform non-mobile: langsung ke ready
      if (mounted) setState(() => _phase = _SessionPhase.ready);
    }
  }

  Future<void> _initFrameSaver() async {
    try {
      _frameSavingIsolate = FrameSavingIsolate();
      await _frameSavingIsolate!.start();
    } catch (e) {
      debugPrint('FrameSavingIsolate init error: $e');
    }
  }

  Future<void> _initCamera({int? cameraIndex}) async {
    if (mounted) setState(() => _cameraError = null);

    var cameraGranted = (await Permission.camera.status).isGranted;
    if (!cameraGranted) {
      final status = await Permission.camera.request();
      cameraGranted = status.isGranted;
    }

    if (!cameraGranted) {
      if (mounted) {
        setState(() {
          _cameraError = 'Izin kamera belum diberikan.';
          _phase = _SessionPhase.ready;
        });
      }
      return;
    }

    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraError = 'Tidak ada kamera yang tersedia.';
            _phase = _SessionPhase.ready;
          });
        }
        return;
      }
      _selectedCameraIndex = cameraIndex ?? 0;
      await _cameraManager.initialize(
        _cameras[_selectedCameraIndex],
        (image) {
          if (!_isBusy) {
            _isBusy = true;
            _processCameraFrame(image);
          }
        },
      );
      if (mounted) setState(() => _phase = _SessionPhase.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = e.toString();
          _phase = _SessionPhase.ready;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    await _cameraManager.dispose();
    _isBusy = false;
    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCamera(cameraIndex: newIndex);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    _cameraManager.dispose();
    _faceDetector?.dispose();
    _poseDetector?.close();
    _frameSavingIsolate?.dispose();
    super.dispose();
  }

  // ── Countdown ──────────────────────────────────────────────────────────────

  void _startCountdown() {
    setState(() {
      _phase = _SessionPhase.countdown;
      _countdownValue = widget.countdownSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownValue <= 1) {
        timer.cancel();
        _startRecording();
      } else {
        setState(() => _countdownValue--);
      }
    });
  }

  void _startRecording() {
    _repCounter.reset();
    _sampleFramePaths.clear();
    _sampleFrameCounter = 0;
    _repCount = 0;

    setState(() {
      _phase = _SessionPhase.recording;
      _elapsedSeconds = 0;
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _stopRecording() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    setState(() => _phase = _SessionPhase.done);
    _finish();
  }

  // ── Frame processing ───────────────────────────────────────────────────────

  Future<void> _processCameraFrame(CameraImage image) async {
    if (!mounted) {
      _isBusy = false;
      return;
    }

    final sensorOrientation =
        _cameraController?.description.sensorOrientation ?? 0;
    final currentImageSize =
        (sensorOrientation == 90 || sensorOrientation == 270)
            ? Size(image.height.toDouble(), image.width.toDouble())
            : Size(image.width.toDouble(), image.height.toDouble());

    try {
      if (_exerciseType == ExerciseType.sitUp) {
        // Sit up: gunakan face detection
        if (_phase == _SessionPhase.recording) {
          final facePresent = await _faceDetector!.processFrame(
            image: image,
            sensorOrientation: sensorOrientation,
            cameraManager: _cameraManager,
          );
          if (mounted) {
            setState(() {
              _faceDetected = facePresent;
              _repCount = _faceDetector!.repCount;
            });
          }

          // Simpan sample frame
          await _maybeSaveSampleFrame(image);
        }
      } else {
        // Push up / pull up / squat jump: gunakan pose detection
        await _processPoseFrame(image, sensorOrientation, currentImageSize);
      }
    } catch (e) {
      debugPrint('ExerciseRecordingScreen frame error: $e');
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _processPoseFrame(
    CameraImage image,
    int sensorOrientation,
    Size currentImageSize,
  ) async {
    final inputImage = _cameraManager.inputImageFromCameraImage(image);
    if (inputImage == null) return;

    if (_poseDetector == null) return;
    final poses = await _poseDetector!.processImage(inputImage);

    if (poses.isEmpty) {
      _poseLostFrameCount++;
      if (mounted && _poseLostFrameCount > _poseKeepAliveFrames) {
        setState(() => _detectedLandmarks = null);
      }
      return;
    }

    _poseLostFrameCount = 0;
    final pose = poses.first;
    final landmarks = _serializeLandmarks(pose, currentImageSize);

    if (_phase == _SessionPhase.recording) {
      final normalized = RepCounterService.normalizeLandmarks(landmarks);
      final count = _repCounter.processFrame(normalized);
      if (mounted) setState(() => _repCount = count);

      // Simpan sample frame
      await _maybeSaveSampleFrame(image);
    }

    if (mounted) {
      setState(() {
        _imageSize = currentImageSize;
        _detectedLandmarks = landmarks;
      });
    }
  }

  /// Serialize pose landmarks ke format yang bisa dipakai overlay dan
  /// rep counter.
  Map<String, Map<String, double>> _serializeLandmarks(
    Pose pose,
    Size imageSize,
  ) {
    final result = <String, Map<String, double>>{};
    for (final entry in pose.landmarks.entries) {
      final name = entry.key.name.toLowerCase().replaceAll('_', ' ');
      final lm = entry.value;
      result[name] = {
        'x': lm.x,
        'y': lm.y,
        'z': lm.z,
        'likelihood': lm.likelihood,
      };
    }
    return result;
  }

  /// Simpan sample frame secara berkala selama recording berlangsung.
  Future<void> _maybeSaveSampleFrame(CameraImage image) async {
    if (_frameSavingIsolate == null) return;
    if (_sampleFramePaths.length >= _maxSampleFrames) return;

    _sampleFrameCounter++;
    if (_sampleFrameCounter % _sampleFrameInterval != 0) return;

    try {
      final result = await _frameSavingIsolate!.saveFrame(
        frameBytes: image.planes.first.bytes,
        label: 'sample_${_exerciseType.name}',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        outputDir: '/storage/emulated/0/Movies/T-Smart/frames',
      );
      if (result.success && result.path != null) {
        _sampleFramePaths.add(result.path!);
      }
    } catch (e) {
      debugPrint('Sample frame save error: $e');
    }
  }

  // ── Finish & navigate ──────────────────────────────────────────────────────

  Future<void> _finish() async {
    // Hentikan video recording jika sedang berjalan
    if (_cameraManager.isRecording) {
      await _cameraManager.stopRecording();
    }

    final pending = PendingExercise(
      exerciseType: _exerciseType,
      repCount: _repCount,
      durationSeconds: _elapsedSeconds,
      sampleFramePaths: List.unmodifiable(_sampleFramePaths),
    );

    if (!mounted) return;
    context.read<TSmartState>().setPendingExercise(pending);

    // Dialog transisi singkat
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Mempersiapkan analisis…'),
            ],
          ),
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    context.go('/exercise-processing');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Kamera preview
          _buildCameraPreview(),

          // Area bounding box (bukan sit up)
          if (_exerciseType != ExerciseType.sitUp)
            _DetectionAreaPainterWidget(exerciseType: _exerciseType),

          // Pose skeleton overlay (bukan sit up)
          if (_exerciseType != ExerciseType.sitUp &&
              _detectedLandmarks != null &&
              _imageSize != null)
            CustomPaint(
              painter: _PoseSkeletonPainter(
                landmarks: _detectedLandmarks!,
                imageSize: _imageSize!,
              ),
            ),

          // Sit up: indikator wajah terdeteksi
          if (_exerciseType == ExerciseType.sitUp)
            _SitUpFaceIndicator(faceDetected: _faceDetected),

          // Overlay sesuai fase
          _buildPhaseOverlay(),

          // AppBar custom (transparan)
          _buildTopBar(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraError != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            _cameraError!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_cameraLive) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return CameraPreview(_cameraController!);
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Tombol kembali
            CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _phase == _SessionPhase.recording
                    ? null // jangan izinkan kembali saat recording
                    : () => context.pop(),
              ),
            ),
            const SizedBox(width: 8),

            // Label exercise
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _exerciseType.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),

            const Spacer(),

            // Switch kamera
            if (_cameras.length > 1)
              CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  onPressed: _switchCamera,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseOverlay() {
    switch (_phase) {
      case _SessionPhase.initializing:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );

      case _SessionPhase.ready:
        return _buildReadyOverlay();

      case _SessionPhase.countdown:
        return _buildCountdownOverlay();

      case _SessionPhase.recording:
        return _buildRecordingOverlay();

      case _SessionPhase.done:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
    }
  }

  // ── Ready overlay ──────────────────────────────────────────────────────────

  Widget _buildReadyOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      _exerciseType.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _exerciseType.cameraInstruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hitung mundur: ${widget.countdownSeconds} detik',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startCountdown,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Mulai'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Countdown overlay ──────────────────────────────────────────────────────

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bersiap...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              key: ValueKey(_countdownValue),
              tween: Tween(begin: 1.3, end: 0.9),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Text(
                '$_countdownValue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'detik',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recording overlay ──────────────────────────────────────────────────────

  Widget _buildRecordingOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Spacer untuk menghindari top bar
          const SizedBox(height: 64),

          // Rep counter chip
          Center(
            child: _RepCounterChip(
              repCount: _repCount,
              exerciseType: _exerciseType,
            ),
          ),

          const Spacer(),

          // Bottom controls
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Timer
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(_elapsedSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tombol stop
                GestureDetector(
                  onTap: _stopRecording,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.shade600,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.stop,
                        color: Colors.white, size: 30),
                  ),
                ),

                // Jumlah frame tersimpan
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${_sampleFramePaths.length}/${_maxSampleFrames}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── Rep Counter Chip ────────────────────────────────────────────────────────

class _RepCounterChip extends StatelessWidget {
  const _RepCounterChip({
    required this.repCount,
    required this.exerciseType,
  });

  final int repCount;
  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$repCount',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 72,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            exerciseType.unit,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sit Up Face Indicator ───────────────────────────────────────────────────

class _SitUpFaceIndicator extends StatelessWidget {
  const _SitUpFaceIndicator({required this.faceDetected});
  final bool faceDetected;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: faceDetected
                ? Colors.green.withValues(alpha: 0.8)
                : Colors.red.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                faceDetected ? Icons.face : Icons.face_retouching_off,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                faceDetected ? 'Wajah terdeteksi' : 'Wajah tidak terdeteksi',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detection Area Painter Widget ──────────────────────────────────────────

class _DetectionAreaPainterWidget extends StatelessWidget {
  const _DetectionAreaPainterWidget({required this.exerciseType});
  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DetectionAreaPainter(exerciseType: exerciseType),
    );
  }
}

class _DetectionAreaPainter extends CustomPainter {
  const _DetectionAreaPainter({required this.exerciseType});
  final ExerciseType exerciseType;

  @override
  void paint(Canvas canvas, Size size) {
    // Dua area deteksi: kiri dan kanan
    final leftArea = Rect.fromLTRB(
      size.width * 0.02,
      size.height * 0.10,
      size.width * 0.45,
      size.height * 0.90,
    );
    final rightArea = Rect.fromLTRB(
      size.width * 0.55,
      size.height * 0.10,
      size.width * 0.98,
      size.height * 0.90,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.greenAccent.withValues(alpha: 0.7)
      ..strokeWidth = 2;

    const radius = Radius.circular(12);
    canvas.drawRRect(RRect.fromRectAndRadius(leftArea, radius), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(rightArea, radius), paint);

    // Label area
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'AREA 1',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(leftArea.left + 8, leftArea.top + 8),
    );

    final textPainter2 = TextPainter(
      text: const TextSpan(
        text: 'AREA 2',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter2.paint(
      canvas,
      Offset(rightArea.left + 8, rightArea.top + 8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Pose Skeleton Painter ──────────────────────────────────────────────────

class _PoseSkeletonPainter extends CustomPainter {
  const _PoseSkeletonPainter({
    required this.landmarks,
    required this.imageSize,
  });

  final Map<String, Map<String, double>> landmarks;
  final Size imageSize;

  static const List<List<String>> _connections = [
    ['left shoulder', 'right shoulder'],
    ['left shoulder', 'left elbow'],
    ['left elbow', 'left wrist'],
    ['right shoulder', 'right elbow'],
    ['right elbow', 'right wrist'],
    ['left shoulder', 'left hip'],
    ['right shoulder', 'right hip'],
    ['left hip', 'right hip'],
    ['left hip', 'left knee'],
    ['left knee', 'left ankle'],
    ['right hip', 'right knee'],
    ['right knee', 'right ankle'],
    ['nose', 'left shoulder'],
    ['nose', 'right shoulder'],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    Offset? _landmarkOffset(String name) {
      final lm = landmarks[name];
      if (lm == null) return null;
      final x = lm['x'];
      final y = lm['y'];
      if (x == null || y == null) return null;
      // Koordinat landmark dari MLKit sudah dalam piksel gambar
      return Offset(
        x / imageSize.width * size.width,
        y / imageSize.height * size.height,
      );
    }

    // Gambar koneksi
    for (final conn in _connections) {
      final a = _landmarkOffset(conn[0]);
      final b = _landmarkOffset(conn[1]);
      if (a != null && b != null) {
        canvas.drawLine(a, b, linePaint);
      }
    }

    // Gambar titik landmark
    for (final lm in landmarks.values) {
      final x = lm['x'];
      final y = lm['y'];
      if (x == null || y == null) continue;
      canvas.drawCircle(
        Offset(
          x / imageSize.width * size.width,
          y / imageSize.height * size.height,
        ),
        4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PoseSkeletonPainter old) =>
      old.landmarks != landmarks;
}
