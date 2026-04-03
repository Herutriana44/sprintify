import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/athlete.dart';
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
  bool _sensorConnected = true;

  List<Athlete> get athletes => List.unmodifiable(_athletes);
  List<RunResult> get history => List.unmodifiable(_history);
  int get totalAttempts => _totalAttempts;
  RunResult? get lastRunResult => _lastRunResult;
  Athlete? get selectedAthlete => _selectedAthlete;
  TestMode get testMode => _testMode;
  bool get sensorConnected => _sensorConnected;

  void setSelectedAthlete(Athlete? athlete) {
    _selectedAthlete = athlete;
    notifyListeners();
  }

  void setTestMode(TestMode mode) {
    _testMode = mode;
    notifyListeners();
  }

  void setSensorConnected(bool value) {
    _sensorConnected = value;
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

  /// Simulasi hasil analisis setelah "processing".
  void completeRunWithSimulatedResult() {
    final athlete = _selectedAthlete;
    if (athlete == null) return;

    final rnd = Random();
    final base = 7.5 + rnd.nextDouble() * 3.5;
    final time = double.parse(base.toStringAsFixed(1));
    final category = _categoryForTime(time);

    final result = RunResult(
      athleteId: athlete.id,
      athleteName: athlete.name,
      timeSeconds: time,
      category: category,
      startMarkSeconds: 0.0,
      finishMarkSeconds: time,
      stepCount: 42 + rnd.nextInt(20),
      avgSpeedKmh: 60 / time * 3.6,
      recordedAt: DateTime.now(),
    );

    _lastRunResult = result;
    _history.insert(0, result);
    _totalAttempts += 1;
    notifyListeners();
  }

  PerformanceCategory _categoryForTime(double seconds) {
    if (seconds <= 8.5) return PerformanceCategory.baik;
    if (seconds <= 10.5) return PerformanceCategory.cukup;
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
