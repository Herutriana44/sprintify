/// Layanan rekomendasi berbasis logika kondisional.
///
/// Menghasilkan saran latihan/perbaikan berdasarkan skor posisi bersedia
/// dan berlari tanpa memanggil API eksternal.
class RecommendationService {
  /// Kembalikan daftar poin rekomendasi berdasarkan [bersediaScore] dan
  /// [berlariScore] (masing-masing 0–100).
  List<String> generate({
    required double bersediaScore,
    required double berlariScore,
  }) {
    final List<String> recs = [];

    // --- Posisi Bersedia ---
    if (bersediaScore >= 80) {
      recs.add(
        'Posisi start kamu sudah sangat baik. '
        'Pertahankan kuda-kuda yang rendah dan fokus pada ledakan awal.',
      );
    } else if (bersediaScore >= 60) {
      recs.add(
        'Posisi start cukup baik. '
        'Pastikan lutut ditekuk lebih dalam agar ledakan awal lebih maksimal.',
      );
    } else if (bersediaScore >= 40) {
      recs.add(
        'Posisi start perlu diperbaiki. '
        'Latih posisi jongkok dalam (deep squat) dan condongkan badan ke depan '
        'saat aba-aba "bersedia".',
      );
    } else {
      recs.add(
        'Posisi start masih jauh dari ideal. '
        'Fokus pada drill start blok atau start jongkok secara rutin '
        'hingga posisi tubuh menjadi refleks.',
      );
    }

    // --- Posisi Berlari ---
    if (berlariScore >= 80) {
      recs.add(
        'Teknik berlari sangat baik. '
        'Jaga konsistensi ayunan lengan dan angkat lutut untuk mempertahankan kecepatan.',
      );
    } else if (berlariScore >= 60) {
      recs.add(
        'Teknik berlari cukup baik. '
        'Tingkatkan frekuensi langkah dan pastikan badan tetap condong ke depan.',
      );
    } else if (berlariScore >= 40) {
      recs.add(
        'Teknik berlari memerlukan perhatian. '
        'Latih high-knee drill dan arm-swing drill untuk memperbaiki koordinasi '
        'gerakan tungkai dan lengan.',
      );
    } else {
      recs.add(
        'Teknik berlari perlu banyak diperbaiki. '
        'Mulai dengan latihan dasar seperti A-skip, B-skip, dan jogging pelan '
        'sambil fokus pada postur tubuh yang benar.',
      );
    }

    // --- Penilaian Gabungan ---
    final avg = (bersediaScore + berlariScore) / 2;
    if (avg >= 75) {
      recs.add(
        'Secara keseluruhan performamu bagus. '
        'Tingkatkan dengan latihan kecepatan reaksi dan interval sprint.',
      );
    } else if (avg >= 55) {
      recs.add(
        'Secara keseluruhan ada potensi yang baik. '
        'Konsistensi latihan 3–4 kali seminggu akan sangat membantu peningkatan.',
      );
    } else {
      recs.add(
        'Masih banyak ruang untuk berkembang. '
        'Prioritaskan teknik dasar sebelum menambah intensitas latihan.',
      );
    }

    return recs;
  }

  /// Label kategori performa gabungan (untuk ditampilkan di UI).
  String overallLabel({
    required double bersediaScore,
    required double berlariScore,
  }) {
    final avg = (bersediaScore + berlariScore) / 2;
    if (avg >= 75) return 'Baik';
    if (avg >= 55) return 'Cukup';
    return 'Perlu Latihan';
  }
}
