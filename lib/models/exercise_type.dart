/// Jenis-jenis tes kebugaran fisik yang didukung.
enum ExerciseType {
  pushUp,
  pullUp,
  sitUp,
  squatJump,
}

extension ExerciseTypeLabel on ExerciseType {
  /// Label yang ditampilkan ke pengguna.
  String get label {
    switch (this) {
      case ExerciseType.pushUp:
        return 'Push Up';
      case ExerciseType.pullUp:
        return 'Pull Up';
      case ExerciseType.sitUp:
        return 'Sit Up';
      case ExerciseType.squatJump:
        return 'Squat Jump';
    }
  }

  /// Instruksi singkat posisi kamera untuk setiap jenis exercise.
  String get cameraInstruction {
    switch (this) {
      case ExerciseType.pushUp:
        return 'Posisikan kamera dari samping agar seluruh tubuh terlihat. '
            'Tubuh harus berada di dalam salah satu area deteksi.';
      case ExerciseType.pullUp:
        return 'Posisikan kamera dari samping agar kepala, tangan, dan bar terlihat. '
            'Pastikan tubuh berada di area deteksi.';
      case ExerciseType.sitUp:
        return 'Posisikan kamera dari samping. '
            'Deteksi wajah digunakan untuk menghitung repetisi.';
      case ExerciseType.squatJump:
        return 'Posisikan kamera dari samping agar seluruh tubuh terlihat. '
            'Tubuh harus berada di dalam salah satu area deteksi.';
    }
  }

  /// Icon yang merepresentasikan jenis exercise.
  String get iconPath {
    switch (this) {
      case ExerciseType.pushUp:
        return 'push_up';
      case ExerciseType.pullUp:
        return 'pull_up';
      case ExerciseType.sitUp:
        return 'sit_up';
      case ExerciseType.squatJump:
        return 'squat_jump';
    }
  }

  /// Satuan yang ditampilkan.
  String get unit => 'repetisi';
}
