import 'package:flutter/foundation.dart';

import '../models/athlete.dart';
import '../models/pending_analysis.dart';
import '../models/performance_category.dart';
import '../models/run_result.dart';
import '../models/test_mode.dart';

class TSmartState extends ChangeNotifier {
  // ── Local state ────────────────────────────────────────────────────────────
  final List<Athlete> _athletes = [];
  final List<RunResult> _history = [];

  int _totalAttempts = 0;
  RunResult? _lastRunResult;
  Athlete? _selectedAthlete;
  TestMode _testMode = TestMode.videoOnly;
  PendingAnalysis? pendingAnalysis;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Athlete> get athletes => List.unmodifiable(_athletes);
  List<RunResult> get history => List.unmodifiable(_history);
  int get totalAttempts => _totalAttempts;
  RunResult? get lastRunResult => _lastRunResult;
  Athlete? get selectedAthlete => _selectedAthlete;
  TestMode get testMode => _testMode;
  bool get loading => false;
  String? get error => null;

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
    _athletes.add(athlete);
    _selectedAthlete ??= athlete;
    notifyListeners();
  }

  Future<void> updateAthlete(Athlete athlete) async {
    final i = _athletes.indexWhere((a) => a.id == athlete.id);
    if (i >= 0) {
      _athletes[i] = athlete;
      notifyListeners();
    }
  }

  Future<void> deleteAthlete(String id) async {
    _athletes.removeWhere((a) => a.id == id);
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

    _history.insert(0, result);
    _totalAttempts = _history.length;

    notifyListeners();
  }

  static PerformanceCategory _categoryForScore(
      double? bersediaScore, double? berlariScore) {
    final avg = ((bersediaScore ?? 0) + (berlariScore ?? 0)) / 2;
    if (avg >= 75) return PerformanceCategory.baik;
    if (avg >= 50) return PerformanceCategory.cukup;
    return PerformanceCategory.kurang;
  }
}
