import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/athlete.dart';
import '../models/pending_analysis.dart';
import '../models/performance_category.dart';
import '../models/run_result.dart';
import '../models/test_mode.dart';
import '../services/firebase/firestore_service.dart';

class TSmartState extends ChangeNotifier {
  TSmartState({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  // ── Local state ────────────────────────────────────────────────────────────
  final List<Athlete> _athletes = [];
  final List<RunResult> _history = [];

  int _totalAttempts = 0;
  RunResult? _lastRunResult;
  Athlete? _selectedAthlete;
  TestMode _testMode = TestMode.videoOnly;
  PendingAnalysis? pendingAnalysis;

  // ── Firestore sync state ───────────────────────────────────────────────────
  String? _uid;
  bool _loading = false;
  String? _error;

  StreamSubscription<List<Athlete>>? _athletesSub;
  StreamSubscription<List<RunResult>>? _resultsSub;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Athlete> get athletes => List.unmodifiable(_athletes);
  List<RunResult> get history => List.unmodifiable(_history);
  int get totalAttempts => _totalAttempts;
  RunResult? get lastRunResult => _lastRunResult;
  Athlete? get selectedAthlete => _selectedAthlete;
  TestMode get testMode => _testMode;
  bool get loading => _loading;
  String? get error => _error;
  bool get isFirestoreConnected => _uid != null;

  // ---------------------------------------------------------------------------
  // Firestore sync — dipanggil setelah login berhasil
  // ---------------------------------------------------------------------------

  /// Mulai mendengarkan perubahan Firestore untuk [uid].
  Future<void> connectFirestore(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    _loading = true;
    _error = null;
    notifyListeners();

    // Batalkan subscription lama jika ada
    await _athletesSub?.cancel();
    await _resultsSub?.cancel();

    _athletesSub = _firestoreService.watchAthletes(uid).listen(
      (athletes) {
        _athletes
          ..clear()
          ..addAll(athletes);
        _loading = false;
        // Pastikan selectedAthlete masih valid
        if (_selectedAthlete != null &&
            !_athletes.any((a) => a.id == _selectedAthlete!.id)) {
          _selectedAthlete = _athletes.isNotEmpty ? _athletes.first : null;
        }
        notifyListeners();
      },
      onError: (dynamic e) {
        _error = 'Gagal memuat data atlet: $e';
        _loading = false;
        notifyListeners();
      },
    );

    _resultsSub = _firestoreService.watchResults(uid).listen(
      (results) {
        _history
          ..clear()
          ..addAll(results);
        _totalAttempts = _history.length;
        if (_history.isNotEmpty && _lastRunResult == null) {
          _lastRunResult = _history.first;
        }
        notifyListeners();
      },
      onError: (dynamic e) {
        debugPrint('TSmartState results stream error: $e');
      },
    );
  }

  /// Putuskan koneksi Firestore saat logout.
  Future<void> disconnectFirestore() async {
    await _athletesSub?.cancel();
    await _resultsSub?.cancel();
    _athletesSub = null;
    _resultsSub = null;
    _uid = null;
    _athletes.clear();
    _history.clear();
    _totalAttempts = 0;
    _lastRunResult = null;
    _selectedAthlete = null;
    pendingAnalysis = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Athletes
  // ---------------------------------------------------------------------------

  void setSelectedAthlete(Athlete? athlete) {
    _selectedAthlete = athlete;
    notifyListeners();
  }

  Athlete? getAthleteById(String id) {
    try {
      return _athletes.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addAthlete(Athlete athlete) async {
    if (_uid != null) {
      final newId = await _firestoreService.addAthlete(_uid!, athlete);
      // Stream listener akan update _athletes otomatis, tapi simpan juga
      // ID baru agar bisa dipilih langsung
      final withId = athlete.copyWith(id: newId);
      _selectedAthlete ??= withId;
    } else {
      _athletes.add(athlete);
      notifyListeners();
    }
  }

  Future<void> updateAthlete(Athlete athlete) async {
    if (_uid != null) {
      await _firestoreService.updateAthlete(_uid!, athlete);
      // Stream akan update _athletes
    } else {
      final i = _athletes.indexWhere((a) => a.id == athlete.id);
      if (i >= 0) {
        _athletes[i] = athlete;
        notifyListeners();
      }
    }
  }

  Future<void> deleteAthlete(String id) async {
    if (_uid != null) {
      await _firestoreService.deleteAthlete(_uid!, id);
    } else {
      _athletes.removeWhere((a) => a.id == id);
    }
    if (_selectedAthlete?.id == id) {
      _selectedAthlete = _athletes.isNotEmpty ? _athletes.first : null;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Test mode & pending analysis
  // ---------------------------------------------------------------------------

  void setTestMode(TestMode mode) {
    _testMode = mode;
    notifyListeners();
  }

  void setPendingAnalysis(PendingAnalysis data) {
    pendingAnalysis = data;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Complete run
  // ---------------------------------------------------------------------------

  Future<void> completeRunWithFullResult({
    required String aiAnalysis,
    required double? bersediaScore,
    required double? berlariScore,
    required List<String> recommendations,
    required int bersediaFrameCount,
    required int berlariFrameCount,
  }) async {
    final athlete = _selectedAthlete;
    final pending = pendingAnalysis;
    if (athlete == null) return;

    final timeSeconds = pending?.timerSeconds.toDouble() ?? 0.0;
    final category = _categoryForScore(bersediaScore, berlariScore);

    final result = RunResult(
      athleteId: athlete.id,
      athleteName: athlete.name,
      timeSeconds: timeSeconds,
      category: category,
      startMarkSeconds: 0.0,
      finishMarkSeconds: timeSeconds,
      stepCount: berlariFrameCount,
      avgSpeedKmh: timeSeconds > 0 ? (60 / timeSeconds * 3.6) : 0,
      recordedAt: DateTime.now(),
      analysisNote: aiAnalysis,
      bersediaScore: bersediaScore,
      berlariScore: berlariScore,
      recommendations: recommendations,
      bersediaFrameCount: bersediaFrameCount,
      berlariFrameCount: berlariFrameCount,
    );

    _lastRunResult = result;
    pendingAnalysis = null;

    if (_uid != null) {
      await _firestoreService.addResult(_uid!, result);
      // Stream listener akan update _history dan _totalAttempts
    } else {
      _history.insert(0, result);
      _totalAttempts = _history.length;
    }

    notifyListeners();
  }

  static PerformanceCategory _categoryForScore(
      double? bersediaScore, double? berlariScore) {
    final avg = ((bersediaScore ?? 0) + (berlariScore ?? 0)) / 2;
    if (avg >= 75) return PerformanceCategory.baik;
    if (avg >= 50) return PerformanceCategory.cukup;
    return PerformanceCategory.kurang;
  }

  @override
  void dispose() {
    _athletesSub?.cancel();
    _resultsSub?.cancel();
    super.dispose();
  }
}
