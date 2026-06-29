import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/pending_analysis.dart';
import '../models/test_mode.dart';
import '../providers/t_smart_state.dart';
import '../services/pose/pose_manager.dart';
import '../services/pose/pose_classifier.dart';
import '../services/pose/frame_saving_isolate.dart';
import '../services/camera/camera_manager.dart';
import '../services/logger_service.dart';
import '../services/analysis/analysis_service.dart';
import '../services/analysis/batch_frame_processor.dart';
import 'assessment_waiting_screen.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AnalysisService _analysisService = AnalysisService();
  BatchFrameProcessor? _batchProcessor;
  FrameSavingIsolate? _frameSavingIsolate;

  // Per-frame score accumulators
  final List<double> _bersediaScores = [];
  final List<double> _berlariScores = [];

  // Track best frame for each pose (path + score)
  String? _bestBersediaFramePath;
  double _bestBersediaScore = -1;
  String? _bestBerlariFramePath;
  double _bestBerlariScore = -1;

  String? _videoPath;
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;

  final CameraManager _cameraManager = CameraManager();
  final PoseManager _poseManager = PoseManager();
  final ImagePicker _picker = ImagePicker();

  CameraController? get _cameraController => _cameraManager.controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _cameraInitializing = false;
  String? _cameraError;

  bool _isBusy = false;
  int _nullFrameCount = 0;   // debug counter: berapa frame yang return null
  Map<String, Map<String, double>>? _detectedLandmarks;
  Size? _imageSize;

  // Pose overlay state
  bool _processorReady = false;
  int _poseLostFrameCount = 0;
  static const int _poseKeepAliveFrames = 10; // persist skeleton ~0.5-1 s setelah pose hilang

  // ── Timer logika baru ──────────────────────────────────────────────────────
  // State mesin timer: idle → running → waiting (5 detik setelah start)
  bool _isPoseDetected = false;
  bool _timerRunning = false;            // apakah timer sedang berjalan
  bool _waitingForStopDetection = false; // sedang di window 5 detik untuk stop
  Timer? _stopWindowTimer;              // timer 5-detik setelah deteksi pertama
  int _poseDetectedStreak = 0;          // frame berturut-turut pose terdeteksi
  int _poseMissingStreak  = 0;          // frame berturut-turut pose tidak terdeteksi

  // Current frame label (for overlay display)
  PoseLabel _currentLabel = PoseLabel.unknown;

  final List<String> _logHistory = [];
  final ScrollController _logScrollController = ScrollController();
  final LoggerService _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    _initializeProcessors();
    if (_isMobile) {
      _initCamera();
    }
  }

  Future<void> _initializeProcessors() async {
    await _analysisService.loadReferencePoses();

    // Initialize batch processor untuk parallel pose detection & classification
    if (_analysisService.isLoaded) {
      final referencePoses = await _loadReferencePosesData();
      _batchProcessor = BatchFrameProcessor(
        referencePoses: referencePoses,
        poseDetectionPoolSize: 2, // 2 isolates untuk pose detection
      );
      await _batchProcessor!.initialize();
      if (mounted) setState(() => _processorReady = true);
      _addLog('Parallel processor initialized (2 worker isolates)', type: LogType.app);
    }

    // Initialize frame saving isolate untuk non-blocking I/O
    _frameSavingIsolate = FrameSavingIsolate();
    await _frameSavingIsolate!.start();
  }

  Future<Map<String, dynamic>> _loadReferencePosesData() async {
    final String response = await rootBundle.loadString('assets/data/reference_poses.json');
    return json.decode(response)['reference_poses'] as Map<String, dynamic>;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopWindowTimer?.cancel();
    _cameraManager.dispose();
    _poseManager.dispose();
    _analysisService.dispose();
    _batchProcessor?.dispose();
    _frameSavingIsolate?.dispose();
    super.dispose();
  }

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _cameraLive =>
      _isMobile &&
      _cameraController != null &&
      _cameraController!.value.isInitialized;

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------

  Future<void> _addLog(String message,
      {LogType type = LogType.app, bool isError = false}) async {
    if (!mounted) return;
    _logger.log(message, type: type, isError: isError);
    setState(() {
      _logHistory.add(
          '${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} '
          '${isError ? '[ERR]' : '[INF]'} $message');
      if (_logHistory.length > 50) _logHistory.removeAt(0);
    });
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Gallery pick
  // ---------------------------------------------------------------------------

  Future<void> _pickVideo() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.videos,
      Permission.photos,
    ].request();

    final bool isGranted =
        (statuses[Permission.videos] ?? PermissionStatus.denied).isGranted ||
            (statuses[Permission.photos] ?? PermissionStatus.denied).isGranted;

    if (isGranted) {
      final XFile? file =
          await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        setState(() => _videoPath = file.path);
        _addLog('Video dipilih: ${file.name}');
      }
    } else if ((statuses[Permission.videos] ?? PermissionStatus.denied)
            .isPermanentlyDenied ||
        (statuses[Permission.photos] ?? PermissionStatus.denied)
            .isPermanentlyDenied) {
      openAppSettings();
    } else {
      _addLog('Izin akses galeri/media ditolak.', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Camera init
  // ---------------------------------------------------------------------------

  Future<void> _initCamera({int? cameraIndex}) async {
    setState(() {
      _cameraInitializing = true;
      _cameraError = null;
    });
    // Reset _isBusy setiap kali kamera di-init ulang
    _isBusy = false;
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
      setState(() => _cameraInitializing = false);
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
    // Reset _isBusy agar stream baru bisa langsung memproses frame
    _isBusy = false;
    setState(() {});
    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCamera(cameraIndex: newIndex);
  }

  // ---------------------------------------------------------------------------
  // Timer logic: pose-triggered start/stop
  // ---------------------------------------------------------------------------

  // Mesin state timer:
  //   idle → (pose masuk box) → running → (5s berlalu, pose masih ada) → stopped
  //
  // Aturan:
  //   1. Pose masuk bounding box saat idle   → mulai timer + mulai countdown 5s
  //   2. Countdown 5s habis, pose masih ada  → timer berhenti
  //   3. Countdown 5s habis, pose hilang     → jadwalkan ulang countdown 5s
  //   4. Noise frame (flicker deteksi)       → DIABAIKAN, pakai debounce

  // Berapa frame berturut-turut pose harus terdeteksi sebelum dianggap "masuk"
  static const int _poseDebounceFrames = 3;

  /// Dipanggil dari _processCameraImage setiap frame dengan status pose terkini.
  void _handlePosePresence(bool poseInBox) {
    if (poseInBox) {
      _poseDetectedStreak++;
      _poseMissingStreak = 0;
    } else {
      _poseMissingStreak++;
      _poseDetectedStreak = 0;
    }

    // Auto-start rekaman saat pose terdeteksi stabil
    if (_poseDetectedStreak >= _poseDebounceFrames && !_isPoseDetected) {
      _isPoseDetected = true;
      if (!_recording) {
        _addLog('Pose terdeteksi: Mulai rekaman otomatis.', type: LogType.inference);
        _toggleVideoRecording();
      }
    }

    if (_poseMissingStreak >= _poseDebounceFrames && _isPoseDetected) {
      _isPoseDetected = false;
    }
  }

  /// Dipanggil saat pose pertama kali stabil terdeteksi di bounding box.
  void _onPoseEntered() {
    if (!_recording || _timerRunning) return;

    _timerRunning = true;
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
    _addLog('Pelari masuk → Timer mulai', type: LogType.inference);
    _scheduleStopWindow();
  }

  /// Mulai countdown 5 detik. Saat habis:
  ///   - pose masih ada → timer berhenti
  ///   - pose hilang    → tunggu pose masuk lagi (idle kembali ke cek per-frame)
  void _scheduleStopWindow() {
    _stopWindowTimer?.cancel();
    _waitingForStopDetection = true;
    if (mounted) setState(() {});

    _stopWindowTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _waitingForStopDetection = false;

      if (_isPoseDetected && _timerRunning) {
        // Pose masih ada setelah 5 detik → hentikan timer
        _addLog('Pose terdeteksi setelah 5s → Timer berhenti',
            type: LogType.inference);
        _stopTimer();
      } else {
        // Pose hilang saat countdown habis → jadwalkan countdown baru
        // supaya saat pose masuk lagi, timer langsung berhenti dalam 5s
        _addLog('Pose hilang, timer terus berjalan...', type: LogType.inference);
        _scheduleStopWindow();
      }
    });
  }

  /// Hentikan timer.
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _timerRunning = false;
    _waitingForStopDetection = false;
    _stopWindowTimer?.cancel();
    _stopWindowTimer = null;
    if (mounted) setState(() {});
  }

  /// Reset semua state timer (saat rekaman dimulai ulang).
  void _resetTimerState() {
    _timer?.cancel();
    _timer = null;
    _stopWindowTimer?.cancel();
    _stopWindowTimer = null;
    _timerRunning = false;
    _waitingForStopDetection = false;
    _seconds = 0;
    _isPoseDetected = false;
    _poseDetectedStreak = 0;
    _poseMissingStreak  = 0;
  }

  // ---------------------------------------------------------------------------
  // Live frame processing
  // ---------------------------------------------------------------------------

  Future<void> _processCameraImage(CameraImage image) async {
    if (_batchProcessor == null || !_batchProcessor!.isInitialized) {
      _isBusy = false;
      return;
    }

    _nullFrameCount = 0;
    try {
      final sensorOrientation =
          _cameraController?.description.sensorOrientation ?? 0;

      // Hitung ukuran image sesuai orientasi sensor
      final Size currentImageSize =
          (sensorOrientation == 90 || sensorOrientation == 270)
              ? Size(image.height.toDouble(), image.width.toDouble())
              : Size(image.width.toDouble(), image.height.toDouble());

      // Process frame dengan batch processor (parallel pose detection + classification)
      final result = await _batchProcessor!.processSingleFrame(
        image: image,
        metadata: CameraImageMetadata(
          rotation: _cameraManager.getRotation(sensorOrientation),
          sensorOrientation: sensorOrientation,
        ),
        frameIndex: 0,
        timestamp: Duration.zero,
      );

      // Bail out early jika widget sudah unmounted
      if (!mounted) {
        _isBusy = false;
        return;
      }

      final bool isPersonDetected = result.poseDetected;
      final bool poseInBox = isPersonDetected &&
          result.serializedLandmarks != null &&
          _isPoseInBoundingBoxFromLandmarks(result.serializedLandmarks!, currentImageSize);

      // Delegasikan ke mesin state dengan debounce
      _handlePosePresence(poseInBox);

      PoseLabel currentLabel = PoseLabel.unknown;

      if (result.classification != null) {
        currentLabel = result.classification!.label;

        if (_recording) {
          if (result.classification!.label == PoseLabel.bersedia) {
            _bersediaScores.add(result.classification!.score);
            if (result.classification!.score > _bestBersediaScore) {
              _bestBersediaScore = result.classification!.score;
              unawaited(_saveBestFrame(image, 'bersedia', result.classification!.score));
            }
          } else if (result.classification!.label == PoseLabel.berlari) {
            _berlariScores.add(result.classification!.score);
            if (result.classification!.score > _bestBerlariScore) {
              _bestBerlariScore = result.classification!.score;
              unawaited(_saveBestFrame(image, 'berlari', result.classification!.score));
            }
          }
        }
      }

      // Hitung keep-alive agar skeleton tidak langsung hilang saat 1 frame gagal
      if (result.serializedLandmarks != null) {
        _poseLostFrameCount = 0;
      } else {
        _poseLostFrameCount++;
      }

      if (mounted) {
        setState(() {
          _currentLabel = currentLabel;
          _imageSize = currentImageSize;
          if (result.serializedLandmarks != null) {
            // Pose terdeteksi: update landmarks
            _detectedLandmarks = result.serializedLandmarks;
          } else if (_poseLostFrameCount > _poseKeepAliveFrames) {
            // Pose benar-benar hilang: hapus skeleton
            _detectedLandmarks = null;
          }
          // else: pertahankan landmarks terakhir selama keep-alive aktif
        });
      }
    } catch (e, stack) {
      debugPrint('Error processing image: $e\n$stack');
      _addLog('Err: $e', isError: true);
    } finally {
      _isBusy = false;
    }
  }

  /// Cek apakah pose berada di dalam bounding box tengah layar (60% x 60%).
  bool _isPoseInBoundingBox(Pose pose, Size imageSize) {
    if (pose.landmarks.isEmpty) return false;

    // Bounding box area: 60% dari lebar & tinggi gambar, di tengah
    final boxLeft   = imageSize.width  * 0.20;
    final boxTop    = imageSize.height * 0.20;
    final boxRight  = imageSize.width  * 0.80;
    final boxBottom = imageSize.height * 0.80;

    // Hitung rata-rata koordinat landmark untuk menentukan posisi tubuh
    double sumX = 0, sumY = 0;
    int count = 0;
    for (final lm in pose.landmarks.values) {
      sumX += lm.x;
      sumY += lm.y;
      count++;
    }
    if (count == 0) return false;
    final centerX = sumX / count;
    final centerY = sumY / count;

    return centerX >= boxLeft &&
        centerX <= boxRight &&
        centerY >= boxTop &&
        centerY <= boxBottom;
  }

  /// Cek bounding box dari serialized landmarks (hasil dari isolate processing).
  bool _isPoseInBoundingBoxFromLandmarks(
    Map<String, Map<String, double>> landmarks,
    Size imageSize,
  ) {
    if (landmarks.isEmpty) return false;

    final boxLeft   = imageSize.width  * 0.20;
    final boxTop    = imageSize.height * 0.20;
    final boxRight  = imageSize.width  * 0.80;
    final boxBottom = imageSize.height * 0.80;

    double sumX = 0, sumY = 0;
    int count = 0;
    for (final lm in landmarks.values) {
      sumX += lm['x']!;
      sumY += lm['y']!;
      count++;
    }
    if (count == 0) return false;
    final centerX = sumX / count;
    final centerY = sumY / count;

    return centerX >= boxLeft &&
        centerX <= boxRight &&
        centerY >= boxTop &&
        centerY <= boxBottom;
  }

  /// Simpan frame terbaik dengan non-blocking I/O di background isolate.
  Future<void> _saveBestFrame(
      CameraImage image, String label, double score) async {
    if (_frameSavingIsolate == null) return;

    try {
      final result = await _frameSavingIsolate!.saveFrame(
        frameBytes: image.planes.first.bytes,
        label: label,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        outputDir: '/storage/emulated/0/Movies/T-Smart/frames',
      );

      if (result.success && result.path != null) {
        if (label == 'bersedia') {
          _bestBersediaFramePath = result.path;
        } else {
          _bestBerlariFramePath = result.path;
        }
      }
    } catch (e) {
      debugPrint('Gagal menyimpan best frame: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Recording toggle
  // ---------------------------------------------------------------------------

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
        _resetTimerState();
        _bersediaScores.clear();
        _berlariScores.clear();
        _bestBersediaScore = -1;
        _bestBerlariScore = -1;
        _bestBersediaFramePath = null;
        _bestBerlariFramePath = null;
      } else {
        _resetTimerState();
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
          _resetTimerState();
          _bersediaScores.clear();
          _berlariScores.clear();
          _bestBersediaScore = -1;
          _bestBerlariScore = -1;
          _bestBersediaFramePath = null;
          _bestBerlariFramePath = null;
        });
      } else {
        // Set _recording = false lebih dulu agar _processCameraImage
        // tidak lagi mengakumulasi skor atau mengubah state timer
        // sementara stopVideoRecording() masih berjalan
        setState(() => _recording = false);
        _timer?.cancel();
        _timer = null;
        _stopWindowTimer?.cancel();
        _stopWindowTimer = null;
        _timerRunning = false;
        _waitingForStopDetection = false;

        if (c.value.isRecordingVideo) {
          final XFile file = await c.stopVideoRecording();
          if (!mounted) return;
          final directory =
              Directory('/storage/emulated/0/Movies/T-Smart');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          final fileName =
              'run_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final targetPath = '${directory.path}/$fileName';
          final savedFile = await File(file.path).copy(targetPath);
          if (!mounted) return;
          setState(() => _videoPath = savedFile.path);
          _addLog('Video disimpan di: $_videoPath', type: LogType.app);
        }
      }
    } catch (e) {
      _addLog('Rekaman/Penyimpanan gagal: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Finish & submit
  // ---------------------------------------------------------------------------

  Future<void> _finish() async {
    if (_recording) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harap berhenti merekam terlebih dahulu.')));
      return;
    }
    if (_videoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada video yang tersedia.')));
      return;
    }
    _timer?.cancel();

    // Tampilkan loading dialog saat mempersiapkan data
    if (!mounted) return;
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

    // Rekapitulasi Penilaian
    final avgBersedia = _bersediaScores.isEmpty ? 0.0 : _bersediaScores.reduce((a, b) => a + b) / _bersediaScores.length;
    final avgBerlari = _berlariScores.isEmpty ? 0.0 : _berlariScores.reduce((a, b) => a + b) / _berlariScores.length;
    _addLog('Penilaian Selesai. Rata-rata Skor: Bersedia: ${avgBersedia.toStringAsFixed(2)}, Berlari: ${avgBerlari.toStringAsFixed(2)}', type: LogType.app);

    final pending = PendingAnalysis(
      videoPath: _videoPath!,
      timerSeconds: _seconds,
      bersediaScores: List.unmodifiable(_bersediaScores),
      berlariScores: List.unmodifiable(_berlariScores),
      bestBersediaFrame: _bestBersediaFramePath != null
          ? File(_bestBersediaFramePath!)
          : null,
      bestBerlariFrame: _bestBerlariFramePath != null
          ? File(_bestBerlariFramePath!)
          : null,
    );

    if (!mounted) return;
    context.read<TSmartState>().setPendingAnalysis(pending);

    // Tutup loading dialog lalu navigasi
    Navigator.of(context, rootNavigator: true).pop();
    context.push('/processing');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TSmartState>();
    final athlete = state.selectedAthlete;

    return Scaffold(
      appBar: AppBar(title: const Text('Rekaman')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                athlete?.name ?? '—',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'Mode: ${state.testMode.label}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            // Live score summary during recording
            if (_recording)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ScoreChip(
                      label: 'Bersedia',
                      count: _bersediaScores.length,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _ScoreChip(
                      label: 'Berlari',
                      count: _berlariScores.length,
                      color: Colors.green,
                    ),
                  ],
                ),
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
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'REC ${_fmt(_seconds)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Pose label overlay
                        if (_recording && _currentLabel != PoseLabel.unknown)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _currentLabel == PoseLabel.bersedia
                                    ? Colors.blue.withValues(alpha: 0.85)
                                    : Colors.green.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _currentLabel == PoseLabel.bersedia
                                    ? 'Bersedia'
                                    : 'Berlari',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
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
              child: Column(
                children: [
                  if (_videoPath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'File terpilih: ${File(_videoPath!).path.split('/').last}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Row(
                    children: [
                      if (_recording)
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _toggleVideoRecording,
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.errorContainer,
                              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            child: const Text('Stop Rekaman'),
                          ),
                        ),
                      if (!_recording)
                        IconButton(
                          onPressed: _pickVideo,
                          icon: const Icon(Icons.photo_library),
                          tooltip: 'Pilih dari galeri',
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _finish,
                          child: const Text('Selesai & analisis'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Log panel
            Padding(
              padding: const EdgeInsets.only(
                  left: 20, right: 20, bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('LOG INFERENSI',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(
                                  ClipboardData(
                                      text: _logHistory.join('\n')))
                              .then((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Log disalin ke clipboard')),
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: _logHistory.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        child: Text(
                          _logHistory[index],
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_cameraInitializing) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_cameraError != null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Text(_cameraError!)),
      );
    }

    final c = _cameraController;
    if (c != null && c.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(c),
          CustomPaint(painter: DetectionAreaPainter()),
          if (_recording && !_timerRunning)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'Menunggu pelari...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          if (_timerRunning && _waitingForStopDetection)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'Menunggu 5s...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          if (_timerRunning && !_waitingForStopDetection)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'Timer berjalan',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          if (!_timerRunning && !_recording && _seconds > 0)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Selesai: ${_fmt(_seconds)}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          if (_cameras.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: _switchCamera,
                icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black45),
              ),
            ),
          // Overlay inisialisasi detektor
          if (!_processorReady)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Menginisialisasi detektor pose...',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          // Skeleton overlay pose detection
          if (_detectedLandmarks != null && _imageSize != null)
            CustomPaint(
              painter: SerializedPosePainter(
                _detectedLandmarks!,
                _imageSize!,
                rotation: _cameras.isNotEmpty &&
                        _selectedCameraIndex < _cameras.length
                    ? _cameraManager.getRotation(
                        _cameras[_selectedCameraIndex].sensorOrientation)
                    : InputImageRotation.rotation90deg,
                isFrontCamera: _cameras.isNotEmpty &&
                    _selectedCameraIndex < _cameras.length &&
                    _cameras[_selectedCameraIndex].lensDirection ==
                        CameraLensDirection.front,
              ),
            ),
        ],
      );
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $count frame',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class SerializedPosePainter extends CustomPainter {
  final Map<String, Map<String, double>> landmarks;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  SerializedPosePainter(
    this.landmarks,
    this.imageSize, {
    this.rotation = InputImageRotation.rotation90deg,
    this.isFrontCamera = false,
  });

  // Koneksi antar landmark untuk membentuk skeleton
  static const Map<String, List<String>> _connections = {
    'nose': ['left_eye', 'right_eye', 'left_ear', 'right_ear'],
    'left_eye': ['left_ear'],
    'right_eye': ['right_ear'],
    'left_shoulder': ['right_shoulder', 'left_elbow', 'left_hip'],
    'right_shoulder': ['right_elbow', 'right_hip'],
    'left_elbow': ['left_wrist'],
    'right_elbow': ['right_wrist'],
    'left_hip': ['right_hip', 'left_knee'],
    'right_hip': ['right_knee'],
    'left_knee': ['left_ankle'],
    'right_knee': ['right_ankle'],
    'left_ankle': ['left_heel', 'left_foot_index'],
    'right_ankle': ['right_heel', 'right_foot_index'],
    'left_heel': ['left_foot_index'],
    'right_heel': ['right_foot_index'],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // Kamera depan menampilkan preview yang di-mirror secara horizontal.
    // Koordinat x dari ML Kit perlu di-flip agar skeleton selaras dengan tampilan.
    double toX(double x) =>
        isFrontCamera ? size.width - x * scaleX : x * scaleX;
    double toY(double y) => y * scaleY;

    // Gambar koneksi antar landmark (skeleton)
    final bonePaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.9)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (final entry in _connections.entries) {
      final startKey = entry.key;
      if (!landmarks.containsKey(startKey)) continue;

      final start = landmarks[startKey]!;
      final startX = toX(start['x']!);
      final startY = toY(start['y']!);

      for (final endKey in entry.value) {
        if (!landmarks.containsKey(endKey)) continue;
        final end = landmarks[endKey]!;

        canvas.drawLine(
          Offset(startX, startY),
          Offset(toX(end['x']!), toY(end['y']!)),
          bonePaint,
        );
      }
    }

    // Gambar landmark (titik)
    final pointPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;
    for (final landmark in landmarks.values) {
      canvas.drawCircle(
        Offset(toX(landmark['x']!), toY(landmark['y']!)),
        6.0,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(SerializedPosePainter oldDelegate) =>
      landmarks != oldDelegate.landmarks ||
      isFrontCamera != oldDelegate.isFrontCamera;
}

class DetectionAreaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.6,
      height: size.height * 0.6,
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
