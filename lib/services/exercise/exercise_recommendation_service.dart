import '../../models/exercise_type.dart';
import '../../models/performance_category.dart';

/// Menghasilkan kategori performa dan rekomendasi latihan berdasarkan
/// jumlah repetisi dan jenis exercise.
///
/// Standar yang digunakan bersifat generik (bukan standar TNI/POLRI spesifik)
/// karena perlu disesuaikan lebih lanjut.
class ExerciseRecommendationService {
  /// Hitung kategori performa berdasarkan [repCount] dan [exerciseType].
  PerformanceCategory getCategory({
    required ExerciseType exerciseType,
    required int repCount,
  }) {
    final thresholds = _thresholds[exerciseType];
    if (thresholds == null) return PerformanceCategory.kurang;

    if (repCount >= thresholds.baik) return PerformanceCategory.baik;
    if (repCount >= thresholds.cukup) return PerformanceCategory.cukup;
    return PerformanceCategory.kurang;
  }

  /// Hasilkan daftar rekomendasi latihan.
  List<String> generate({
    required ExerciseType exerciseType,
    required int repCount,
  }) {
    final category = getCategory(exerciseType: exerciseType, repCount: repCount);
    return _recommendations(exerciseType, repCount, category);
  }

  // ── Threshold per exercise ─────────────────────────────────────────────────

  static final Map<ExerciseType, _Thresholds> _thresholds = {
    ExerciseType.pushUp: const _Thresholds(baik: 25, cukup: 15),
    ExerciseType.pullUp: const _Thresholds(baik: 10, cukup: 5),
    ExerciseType.sitUp:  const _Thresholds(baik: 30, cukup: 20),
    ExerciseType.squatJump: const _Thresholds(baik: 25, cukup: 15),
  };

  // ── Rekomendasi ────────────────────────────────────────────────────────────

  List<String> _recommendations(
    ExerciseType type,
    int repCount,
    PerformanceCategory category,
  ) {
    final recs = <String>[];

    switch (type) {
      case ExerciseType.pushUp:
        if (category == PerformanceCategory.baik) {
          recs.add('Push up kamu sudah sangat baik ($repCount repetisi). '
              'Pertahankan postur lurus dari kepala sampai tumit.');
          recs.add(
              'Coba variasikan dengan wide-grip atau diamond push up untuk menambah tantangan.');
        } else if (category == PerformanceCategory.cukup) {
          recs.add('Push up cukup baik ($repCount repetisi). '
              'Fokus pada kedalaman gerakan — dada harus hampir menyentuh lantai.');
          recs.add('Latihan rutin 3 set × 15 repetisi dengan jeda 60 detik '
              'akan meningkatkan kekuatan otot dada dan trisep.');
        } else {
          recs.add('Push up masih perlu ditingkatkan ($repCount repetisi). '
              'Mulai dari push up lutut (knee push up) jika kesulitan.');
          recs.add(
              'Pastikan inti tubuh (core) dikencangkan agar tubuh tetap lurus '
              'dan tidak membungkuk saat bergerak.');
        }

      case ExerciseType.pullUp:
        if (category == PerformanceCategory.baik) {
          recs.add('Pull up luar biasa ($repCount repetisi)! '
              'Jaga rentang gerak penuh dari posisi tergantung hingga dagu di atas bar.');
          recs.add('Tingkatkan dengan weighted pull up atau L-sit pull up '
              'untuk level berikutnya.');
        } else if (category == PerformanceCategory.cukup) {
          recs.add('Pull up cukup baik ($repCount repetisi). '
              'Fokus pada kontrol gerakan — hindari mengayun untuk mendapatkan momentum.');
          recs.add(
              'Latihan negative pull up (turun perlahan) sangat efektif untuk '
              'membangun kekuatan tarikan.');
        } else {
          recs.add('Pull up masih perlu banyak latihan ($repCount repetisi). '
              'Mulai dari assisted pull up menggunakan resistance band.');
          recs.add(
              'Latih kekuatan genggaman dan otot punggung dengan deadlift ringan '
              'dan rowing sebagai fondasi.');
        }

      case ExerciseType.sitUp:
        if (category == PerformanceCategory.baik) {
          recs.add('Sit up sangat baik ($repCount repetisi)! '
              'Pastikan gerakan terkontrol dan tidak menggunakan momentum ayunan.');
          recs.add('Tambahkan variasi crunch oblique atau bicycle crunch '
              'untuk memperkuat otot perut secara menyeluruh.');
        } else if (category == PerformanceCategory.cukup) {
          recs.add('Sit up cukup baik ($repCount repetisi). '
              'Jaga agar kaki tetap menempel di lantai selama gerakan.');
          recs.add(
              'Latihan plank 30–60 detik setiap hari akan memperkuat core '
              'dan membantu meningkatkan performa sit up.');
        } else {
          recs.add('Sit up perlu ditingkatkan ($repCount repetisi). '
              'Mulai dari crunch (hanya angkat kepala dan bahu) jika sit up penuh terasa berat.');
          recs.add(
              'Fokus pada penguatan otot perut secara bertahap dengan '
              'latihan core ringan seperti dead bug dan hollow hold.');
        }

      case ExerciseType.squatJump:
        if (category == PerformanceCategory.baik) {
          recs.add('Squat jump sangat baik ($repCount repetisi)! '
              'Pertahankan pendaratan yang lembut dengan lutut sedikit ditekuk untuk keamanan sendi.');
          recs.add('Coba box jump atau depth jump untuk meningkatkan '
              'kekuatan eksplosif lebih lanjut.');
        } else if (category == PerformanceCategory.cukup) {
          recs.add('Squat jump cukup baik ($repCount repetisi). '
              'Pastikan kedalaman squat mencapai paha sejajar lantai sebelum melompat.');
          recs.add(
              'Latihan squat reguler (non-jump) dan calf raise akan memperkuat '
              'fondasi otot kaki untuk melompat lebih tinggi.');
        } else {
          recs.add('Squat jump perlu ditingkatkan ($repCount repetisi). '
              'Kuasai teknik squat biasa terlebih dahulu sebelum menambahkan lompatan.');
          recs.add(
              'Latihan leg press dan lunges secara teratur akan membantu '
              'membangun kekuatan dasar otot kaki dan pinggul.');
        }
    }

    // Rekomendasi umum berdasarkan kategori
    if (category == PerformanceCategory.baik) {
      recs.add('Performa keseluruhan sangat baik. '
          'Jaga konsistensi latihan dan pastikan pemulihan yang cukup.');
    } else if (category == PerformanceCategory.cukup) {
      recs.add('Ada potensi yang baik. '
          'Latihan terstruktur 4–5 hari per minggu akan membawa peningkatan signifikan.');
    } else {
      recs.add('Masih banyak ruang untuk berkembang. '
          'Konsistensi adalah kunci — mulai dari yang ringan dan tingkatkan secara bertahap.');
    }

    return recs;
  }
}

class _Thresholds {
  const _Thresholds({required this.baik, required this.cukup});
  final int baik;
  final int cukup;
}
