import 'package:flutter/foundation.dart';

import '../models/athlete.dart';
import '../models/pending_analysis.dart';
import '../models/performance_category.dart';
import '../models/run_result.dart';
import '../models/test_mode.dart';

class SprintifyState extends ChangeNotifier {
  SprintifyState() {
    _athletes.addAll(_seedAthletes);
  }

  final List<Athlete> _athletes = [];
  final List<RunResult> _history = [];

  int _totalAttempts = 3;
  RunResult? _lastRunResult;
  Athlete? _selectedAthlete;
  TestMode _testMode = TestMode.videoOnly;

  /// Data analisis yang dikumpulkan dari layar rekaman,
  /// menunggu diproses di [ProcessingScreen].
  PendingAnalysis? pendingAnalysis;

  List<Athlete> get athletes => List.unmodifiable(_athletes);
  List<RunResult> get history => List.unmodifiable(_history);
  int get totalAttempts => _totalAttempts;
  RunResult? get lastRunResult => _lastRunResult;
  Athlete? get selectedAthlete => _selectedAthlete;
  TestMode get testMode => _testMode;

  void setSelectedAthlete(Athlete? athlete) {
    _selectedAthlete = athlete;
    notifyListeners();
  }

  void setTestMode(TestMode mode) {
    _testMode = mode;
    notifyListeners();
  }

  /// Simpan data pending dari layar rekaman sebelum pindah ke processing.
  void setPendingAnalysis(PendingAnalysis data) {
    pendingAnalysis = data;
    notifyListeners();
  }

  Athlete? getAthleteById(String id) {
    try {
      return _athletes.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  void addAthlete(Athlete athlete) {
    _athletes.add(athlete);
    notifyListeners();
  }

  void updateAthlete(Athlete athlete) {
    final i = _athletes.indexWhere((a) => a.id == athlete.id);
    if (i >= 0) {
      _athletes[i] = athlete;
      notifyListeners();
    }
  }

  void deleteAthlete(String id) {
    _athletes.removeWhere((a) => a.id == id);
    if (_selectedAthlete?.id == id) {
      _selectedAthlete = null;
    }
    notifyListeners();
  }

  /// Selesaikan analisis dengan hasil lengkap dari pipeline penilaian.
  void completeRunWithFullResult({
    required String aiAnalysis,
    required double? bersediaScore,
    required double? berlariScore,
    required List<String> recommendations,
    required int bersediaFrameCount,
    required int berlariFrameCount,
  }) {
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
    _history.insert(0, result);
    _totalAttempts += 1;
    pendingAnalysis = null;
    notifyListeners();
  }

  PerformanceCategory _categoryForScore(
      double? bersediaScore, double? berlariScore) {
    final avg = ((bersediaScore ?? 0) + (berlariScore ?? 0)) / 2;
    if (avg >= 75) return PerformanceCategory.baik;
    if (avg >= 50) return PerformanceCategory.cukup;
    return PerformanceCategory.kurang;
  }
}

final _seedAthletes = [
  Athlete(
    id: 'a1',
    name: 'Budi Santoso',
    age: 16,
    gender: 'Laki-laki',
    className: 'X IPA 1',
  ),
  Athlete(
    id: 'a2',
    name: 'Siti Aminah',
    age: 15,
    gender: 'Perempuan',
    className: 'X IPA 2',
  ),
];
