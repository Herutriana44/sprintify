import 'dart:math';

import '../../models/exercise_type.dart';

/// Status fase gerakan untuk satu siklus repetisi.
enum _RepPhase {
  /// Posisi awal / atas (belum turun).
  up,

  /// Posisi bawah (sudah turun cukup jauh).
  down,
}

/// Service yang menghitung repetisi berdasarkan pose landmark dari MLKit.
///
/// Mendukung Push Up, Pull Up, dan Squat Jump menggunakan algoritma
/// state-machine sederhana: transisi [up → down → up] = 1 repetisi.
///
/// Sit Up ditangani secara terpisah oleh [FaceDetectorService].
class RepCounterService {
  RepCounterService({required this.exerciseType});

  final ExerciseType exerciseType;

  int _repCount = 0;
  _RepPhase _phase = _RepPhase.up;

  // Debounce: jumlah frame berturut-turut sebelum transisi fase dikonfirmasi.
  int _downStreak = 0;
  int _upStreak = 0;
  static const int _debounceFrames = 3;

  int get repCount => _repCount;

  /// Reset hitungan untuk sesi baru.
  void reset() {
    _repCount = 0;
    _phase = _RepPhase.up;
    _downStreak = 0;
    _upStreak = 0;
  }

  /// Proses satu frame dengan [landmarks].
  ///
  /// [landmarks] adalah map dari nama landmark ke koordinat {x, y, z} dalam
  /// koordinat gambar yang sudah dinormalisasi (0.0–1.0).
  ///
  /// Mengembalikan [repCount] terkini.
  int processFrame(Map<String, Map<String, double>> landmarks) {
    switch (exerciseType) {
      case ExerciseType.pushUp:
        _processPushUp(landmarks);
      case ExerciseType.pullUp:
        _processPullUp(landmarks);
      case ExerciseType.squatJump:
        _processSquatJump(landmarks);
      case ExerciseType.sitUp:
        // Sit up ditangani oleh FaceDetectorService
        break;
    }
    return _repCount;
  }

  // ── Push Up ────────────────────────────────────────────────────────────────
  //
  // Logika: monitor posisi vertikal bahu (left/right shoulder) relatif terhadap
  // pinggul (left/right hip).
  //
  //   ratio = shoulder_y / hip_y  (koordinat Y bertambah ke bawah)
  //
  // - ratio > 0.85 → bahu dekat pinggul → posisi BAWAH
  // - ratio < 0.70 → bahu jauh dari pinggul → posisi ATAS
  //
  // Transisi up→down→up = 1 repetisi.

  static const double _pushUpDownThreshold = 0.82;
  static const double _pushUpUpThreshold   = 0.68;

  void _processPushUp(Map<String, Map<String, double>> landmarks) {
    final leftShoulderY  = landmarks['left shoulder']?['y'];
    final rightShoulderY = landmarks['right shoulder']?['y'];
    final leftHipY       = landmarks['left hip']?['y'];
    final rightHipY      = landmarks['right hip']?['y'];

    if (leftShoulderY == null && rightShoulderY == null) return;
    if (leftHipY == null && rightHipY == null) return;

    final shoulderY = _average([leftShoulderY, rightShoulderY]);
    final hipY      = _average([leftHipY, rightHipY]);

    if (hipY == null || hipY == 0) return;

    final ratio = shoulderY! / hipY;
    _updatePhase(ratio, _pushUpDownThreshold, _pushUpUpThreshold);
  }

  // ── Pull Up ────────────────────────────────────────────────────────────────
  //
  // Logika: monitor posisi vertikal hidung/dagu relatif terhadap pergelangan
  // tangan (wrist).
  //
  //   ratio = nose_y / wrist_y  (Y bertambah ke bawah)
  //
  // - ratio < 0.85 → dagu di atas/setinggi bar → posisi ATAS (naik)
  // - ratio > 0.95 → dagu jauh di bawah bar   → posisi BAWAH (turun)
  //
  // Transisi down→up→down = 1 repetisi.

  static const double _pullUpUpThreshold   = 0.85;
  static const double _pullUpDownThreshold = 0.95;

  void _processPullUp(Map<String, Map<String, double>> landmarks) {
    final noseY       = landmarks['nose']?['y'];
    final leftWristY  = landmarks['left wrist']?['y'];
    final rightWristY = landmarks['right wrist']?['y'];

    if (noseY == null) return;
    if (leftWristY == null && rightWristY == null) return;

    final wristY = _average([leftWristY, rightWristY]);
    if (wristY == null || wristY == 0) return;

    final ratio = noseY / wristY;

    // Untuk pull up, "down" = dagu jauh di bawah bar (ratio besar),
    // "up" = dagu naik melewati bar (ratio kecil).
    // State machine berlawanan: kita track dengan nilai terbalik.
    _updatePhase(
      1 - ratio,         // invert agar logika _updatePhase tetap sama
      1 - _pullUpUpThreshold,
      1 - _pullUpDownThreshold,
    );
  }

  // ── Squat Jump ────────────────────────────────────────────────────────────
  //
  // Logika: monitor posisi vertikal pinggul relatif terhadap tinggi badan
  // keseluruhan (nose y − ankle y).
  //
  //   ratio = (hip_y - nose_y) / (ankle_y - nose_y)
  //
  // - ratio > 0.58 → pinggul mendekati lutut → JONGKOK / posisi BAWAH
  // - ratio < 0.48 → pinggul naik / lompat   → BERDIRI / posisi ATAS
  //
  // Transisi up→down→up = 1 repetisi.

  static const double _squatJumpDownThreshold = 0.58;
  static const double _squatJumpUpThreshold   = 0.48;

  void _processSquatJump(Map<String, Map<String, double>> landmarks) {
    final noseY      = landmarks['nose']?['y'];
    final leftHipY   = landmarks['left hip']?['y'];
    final rightHipY  = landmarks['right hip']?['y'];
    final leftAnkleY  = landmarks['left ankle']?['y'];
    final rightAnkleY = landmarks['right ankle']?['y'];

    if (noseY == null) return;
    if (leftHipY == null && rightHipY == null) return;
    if (leftAnkleY == null && rightAnkleY == null) return;

    final hipY   = _average([leftHipY, rightHipY])!;
    final ankleY = _average([leftAnkleY, rightAnkleY])!;

    final totalHeight = ankleY - noseY;
    if (totalHeight <= 0) return;

    final ratio = (hipY - noseY) / totalHeight;
    _updatePhase(ratio, _squatJumpDownThreshold, _squatJumpUpThreshold);
  }

  // ── State machine helper ──────────────────────────────────────────────────

  /// Update state machine berdasarkan [value].
  ///
  /// - [downThreshold]: jika value >= ini → kandidat posisi BAWAH
  /// - [upThreshold]:   jika value <= ini → kandidat posisi ATAS
  ///
  /// Rep dihitung setiap kali transisi [up → down → up] terkonfirmasi.
  void _updatePhase(double value, double downThreshold, double upThreshold) {
    if (value >= downThreshold) {
      _downStreak++;
      _upStreak = 0;
      if (_downStreak >= _debounceFrames && _phase == _RepPhase.up) {
        _phase = _RepPhase.down;
        _downStreak = 0;
      }
    } else if (value <= upThreshold) {
      _upStreak++;
      _downStreak = 0;
      if (_upStreak >= _debounceFrames && _phase == _RepPhase.down) {
        _phase = _RepPhase.up;
        _upStreak = 0;
        _repCount++;
      }
    } else {
      // Zona netral — biarkan streak tetap
    }
  }

  // ── Utils ─────────────────────────────────────────────────────────────────

  /// Hitung rata-rata dari list nilai nullable; return null jika semua null.
  static double? _average(List<double?> values) {
    final valid = values.where((v) => v != null).cast<double>().toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  // ── Konversi nama landmark MLKit ──────────────────────────────────────────

  /// Normalisasi nama landmark dari MLKit ke format lowercase dengan spasi.
  ///
  /// MLKit mengembalikan nama seperti 'LEFT_SHOULDER', 'rightHip', dsb.
  /// Fungsi ini membuat keduanya bekerja.
  static Map<String, Map<String, double>> normalizeLandmarks(
    Map<String, Map<String, double>> raw,
  ) {
    final normalized = <String, Map<String, double>>{};
    for (final entry in raw.entries) {
      final key = _normalizeLandmarkName(entry.key);
      normalized[key] = entry.value;
    }
    return normalized;
  }

  static String _normalizeLandmarkName(String name) {
    // Ubah UPPER_SNAKE_CASE ke lowercase dengan spasi
    return name
        .replaceAll('_', ' ')
        .toLowerCase()
        // Ubah camelCase ke lowercase dengan spasi
        .replaceAllMapped(
          RegExp(r'(?<=[a-z])([A-Z])'),
          (m) => ' ${m.group(1)!.toLowerCase()}',
        );
  }

  /// Helper: hitung bounding box semua landmark yang ada.
  static ({double minX, double maxX, double minY, double maxY})? getBoundingBox(
    Map<String, Map<String, double>> landmarks,
  ) {
    if (landmarks.isEmpty) return null;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final lm in landmarks.values) {
      final x = lm['x'];
      final y = lm['y'];
      if (x == null || y == null) continue;
      minX = min(minX, x);
      maxX = max(maxX, x);
      minY = min(minY, y);
      maxY = max(maxY, y);
    }

    if (minX.isInfinite) return null;
    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }
}
