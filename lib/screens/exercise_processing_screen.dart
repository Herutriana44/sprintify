import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/t_smart_state.dart';
import '../services/analysis/gemini_service.dart';
import '../services/analysis/rate_limiter.dart';
import '../services/exercise/exercise_recommendation_service.dart';

// ── Log entry ────────────────────────────────────────────────────────────────
enum _LogLevel { info, success, warning, error }

class _LogEntry {
  _LogEntry(this.message, {this.level = _LogLevel.info});
  final String message;
  final _LogLevel level;
  final DateTime time = DateTime.now();
}

// ── Pipeline step ────────────────────────────────────────────────────────────
enum _StepStatus { pending, running, done, failed }

class _PipelineStep {
  _PipelineStep(this.label);
  final String label;
  _StepStatus status = _StepStatus.pending;
  String? detail;
}

// ────────────────────────────────────────────────────────────────────────────

class ExerciseProcessingScreen extends StatefulWidget {
  const ExerciseProcessingScreen({super.key});

  @override
  State<ExerciseProcessingScreen> createState() =>
      _ExerciseProcessingScreenState();
}

class _ExerciseProcessingScreenState extends State<ExerciseProcessingScreen>
    with TickerProviderStateMixin {
  late final GeminiService _geminiService;
  final ExerciseRecommendationService _recommendationService =
      ExerciseRecommendationService();

  final List<_LogEntry> _logs = [];
  final ScrollController _logScroll = ScrollController();

  late final List<_PipelineStep> _steps = [
    _PipelineStep('Membaca data sesi'),
    _PipelineStep('Validasi jumlah repetisi'),
    _PipelineStep('Evaluasi AI (Gemini)'),
    _PipelineStep('Menyusun rekomendasi'),
  ];

  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  bool _isDone = false;
  bool _hasError = false;
  bool _waitingForAi = false;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPipeline());
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _addLog(String message, {_LogLevel level = _LogLevel.info}) {
    if (!mounted) return;
    setState(() => _logs.add(_LogEntry(message, level: level)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setStepRunning(int idx) {
    if (!mounted) return;
    setState(() => _steps[idx].status = _StepStatus.running);
  }

  void _setStepDone(int idx, {String? detail}) {
    if (!mounted) return;
    setState(() {
      _steps[idx].status = _StepStatus.done;
      _steps[idx].detail = detail;
    });
  }

  void _setStepFailed(int idx, {String? detail}) {
    if (!mounted) return;
    setState(() {
      _steps[idx].status = _StepStatus.failed;
      _steps[idx].detail = detail;
    });
  }

  int get _doneCount =>
      _steps.where((s) => s.status == _StepStatus.done).length;

  double get _progress => _steps.isEmpty ? 0 : _doneCount / _steps.length;

  // ── Pipeline ─────────────────────────────────────────────────────────────────

  Future<void> _runPipeline() async {
    final state = context.read<TSmartState>();

    // ── Step 0: Baca data sesi ─────────────────────────────────────────────
    _setStepRunning(0);
    _addLog('Membaca data sesi dari memori…');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final pending = state.pendingExercise;
    if (pending == null) {
      _setStepFailed(0, detail: 'Data tidak ditemukan');
      _addLog('Data sesi tidak ditemukan!', level: _LogLevel.error);
      if (mounted) setState(() => _hasError = true);
      return;
    }

    _addLog('Jenis tes: ${pending.exerciseType.label}');
    _addLog('Durasi sesi: ${pending.durationSeconds} detik');
    _addLog('Jumlah repetisi terdeteksi: ${pending.repCount}');
    _addLog('Frame sample tersedia: ${pending.sampleFramePaths.length}');
    _setStepDone(0, detail: '${pending.exerciseType.label}, ${pending.repCount} rep');

    // ── Step 1: Validasi repetisi ──────────────────────────────────────────
    _setStepRunning(1);
    _addLog('Memvalidasi jumlah repetisi…');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (pending.repCount == 0) {
      _addLog(
        'Tidak ada repetisi terdeteksi. Pastikan posisi tubuh terlihat jelas.',
        level: _LogLevel.warning,
      );
    } else {
      _addLog(
        'Total ${pending.repCount} repetisi ${pending.exerciseType.label} terdeteksi.',
        level: _LogLevel.success,
      );
    }

    final category = _recommendationService.getCategory(
      exerciseType: pending.exerciseType,
      repCount: pending.repCount,
    );
    _addLog('Kategori performa: ${category.label}', level: _LogLevel.info);
    _setStepDone(1, detail: '${pending.repCount} rep — ${category.label}');

    // ── Step 2: Evaluasi Gemini AI ─────────────────────────────────────────
    _setStepRunning(2);
    _addLog('Mengirim data ke Gemini AI…');

    final selectedImages = pending.selectImagesForAnalysis(maxImages: 10);
    if (selectedImages.isNotEmpty) {
      _addLog('Melampirkan ${selectedImages.length} frame sample.');
    } else {
      _addLog(
        'Tidak ada frame tersedia, analisis berbasis teks saja.',
        level: _LogLevel.warning,
      );
    }

    final prompt = _buildGeminiPrompt(
      exerciseLabel: pending.exerciseType.label,
      repCount: pending.repCount,
      durationSeconds: pending.durationSeconds,
      categoryLabel: category.label,
      frameCount: selectedImages.length,
    );

    String aiAnalysis;
    try {
      if (mounted) setState(() => _waitingForAi = true);
      aiAnalysis = await _geminiService.getAnalysisWithImages(
        imageFiles: selectedImages,
        textPrompt: prompt,
      );
      if (mounted) setState(() => _waitingForAi = false);
      _addLog('Respons AI diterima.', level: _LogLevel.success);
      _setStepDone(2, detail: 'Analisis diterima');
    } catch (e) {
      if (mounted) setState(() => _waitingForAi = false);
      if (e is RateLimitExceededException) {
        aiAnalysis = 'Analisis AI tertunda (rate limit). ${e.message}';
        _addLog('Rate limit: ${e.message}', level: _LogLevel.warning);
      } else {
        aiAnalysis = 'Analisis AI gagal: $e';
        _addLog('Gemini gagal: $e', level: _LogLevel.error);
      }
      _addLog('Melanjutkan tanpa evaluasi AI.', level: _LogLevel.warning);
      _setStepFailed(2, detail: 'Gagal — dilanjutkan');
    }

    if (!mounted) return;

    // ── Step 3: Rekomendasi ────────────────────────────────────────────────
    _setStepRunning(3);
    _addLog('Menyusun rekomendasi latihan…');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final recommendations = _recommendationService.generate(
      exerciseType: pending.exerciseType,
      repCount: pending.repCount,
    );
    _addLog(
      '${recommendations.length} rekomendasi dibuat.',
      level: _LogLevel.success,
    );
    _setStepDone(3, detail: '${recommendations.length} saran');

    // ── Selesai ────────────────────────────────────────────────────────────
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _addLog('Pipeline selesai. Menyimpan hasil…', level: _LogLevel.success);

    await state.completeExercise(
      aiAnalysis: aiAnalysis,
      recommendations: recommendations,
      category: category,
    );

    if (!mounted) return;
    setState(() => _isDone = true);

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    context.go('/exercise-result');
  }

  String _buildGeminiPrompt({
    required String exerciseLabel,
    required int repCount,
    required int durationSeconds,
    required String categoryLabel,
    required int frameCount,
  }) {
    return '''
Kamu adalah pelatih kebugaran fisik profesional.
Berikut adalah hasil tes ${exerciseLabel} atlet:

- Jumlah repetisi: $repCount
- Durasi sesi: $durationSeconds detik
- Kategori performa: $categoryLabel
${frameCount > 0 ? '\nGambar frame dari sesi dilampirkan ($frameCount gambar).' : '\nTidak ada gambar yang tersedia.'}

Berikan evaluasi singkat (3–4 kalimat) tentang performa atlet pada tes $exerciseLabel ini. 
Sebutkan apa yang sudah baik dan 1–2 poin teknik yang perlu diperbaiki.
Gunakan bahasa Indonesia yang mudah dipahami dan bersifat memotivasi.
''';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _isDone || _hasError,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Memproses Hasil Tes'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  _hasError
                      ? 'Terjadi kesalahan'
                      : _isDone
                          ? 'Analisis selesai!'
                          : 'Menganalisis hasil tes…',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _hasError
                            ? colorScheme.error
                            : _isDone
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _hasError
                      ? 'Silakan kembali dan coba lagi.'
                      : _isDone
                          ? 'Menuju halaman hasil…'
                          : 'Jangan tutup aplikasi selama proses berlangsung.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),

                // Banner AI
                if (_waitingForAi) ...[
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(
                          alpha: 0.4 + (_pulseController.value * 0.3),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.secondary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Menunggu respons Gemini AI…',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _progress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                        color: _hasError
                            ? colorScheme.error
                            : colorScheme.primary,
                        backgroundColor: colorScheme.primaryContainer
                            .withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_doneCount/${_steps.length} langkah',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Step list
                ..._steps.map((step) => _StepTile(
                      step: step,
                      spinController: _spinController,
                    )),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Log header
                Row(
                  children: [
                    Icon(Icons.terminal,
                        size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'LOG PROSES',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${_logs.length} entri',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Log list
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _logs.isEmpty
                        ? Center(
                            child: Text(
                              'Menunggu…',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: colorScheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            controller: _logScroll,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: _logs.length,
                            itemBuilder: (context, i) =>
                                _LogLine(entry: _logs[i]),
                          ),
                  ),
                ),

                if (_hasError) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Kembali ke beranda'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step tile ─────────────────────────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.spinController});
  final _PipelineStep step;
  final AnimationController spinController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget leading;
    Color labelColor;

    switch (step.status) {
      case _StepStatus.pending:
        leading = Icon(Icons.radio_button_unchecked,
            size: 20, color: colorScheme.outline);
        labelColor = colorScheme.outline;
      case _StepStatus.running:
        leading = RotationTransition(
          turns: spinController,
          child: Icon(Icons.sync, size: 20, color: colorScheme.primary),
        );
        labelColor = colorScheme.onSurface;
      case _StepStatus.done:
        leading = Icon(Icons.check_circle, size: 20, color: colorScheme.primary);
        labelColor = colorScheme.onSurface;
      case _StepStatus.failed:
        leading =
            Icon(Icons.warning_rounded, size: 20, color: colorScheme.error);
        labelColor = colorScheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: labelColor,
                        fontWeight: step.status == _StepStatus.running
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                ),
                if (step.detail != null)
                  Text(
                    step.detail!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: step.status == _StepStatus.failed
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Log line ──────────────────────────────────────────────────────────────────

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});
  final _LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color textColor;
    final String prefix;

    switch (entry.level) {
      case _LogLevel.success:
        textColor = Colors.green.shade700;
        prefix = '✓ ';
      case _LogLevel.warning:
        textColor = Colors.orange.shade700;
        prefix = '⚠ ';
      case _LogLevel.error:
        textColor = colorScheme.error;
        prefix = '✗ ';
      case _LogLevel.info:
        textColor = colorScheme.onSurfaceVariant;
        prefix = '  ';
    }

    final timeStr =
        '${entry.time.hour.toString().padLeft(2, '0')}:'
        '${entry.time.minute.toString().padLeft(2, '0')}:'
        '${entry.time.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$prefix${entry.message}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
