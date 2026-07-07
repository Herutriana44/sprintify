import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/t_smart_state.dart';
import '../services/analysis/gemini_service.dart';
import '../services/analysis/rate_limiter.dart';
import '../services/analysis/recommendation_service.dart';

// ---------------------------------------------------------------------------
// Model untuk setiap entri log
// ---------------------------------------------------------------------------
enum _LogLevel { info, success, warning, error }

class _LogEntry {
  _LogEntry(this.message, {this.level = _LogLevel.info});
  final String message;
  final _LogLevel level;
  final DateTime time = DateTime.now();
}

// ---------------------------------------------------------------------------
// Model untuk setiap step pipeline
// ---------------------------------------------------------------------------
enum _StepStatus { pending, running, done, failed }

class _PipelineStep {
  _PipelineStep(this.label);
  final String label;
  _StepStatus status = _StepStatus.pending;
  String? detail;
}

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late final GeminiService _geminiService;
  final RecommendationService _recommendationService = RecommendationService();

  final List<_LogEntry> _logs = [];
  final ScrollController _logScroll = ScrollController();

  late final List<_PipelineStep> _steps = [
    _PipelineStep('Membaca data rekaman'),
    _PipelineStep('Menghitung skor posisi'),
    _PipelineStep('Evaluasi AI (Gemini)'),
    _PipelineStep('Menyusun rekomendasi'),
  ];

  // Spinner animation untuk step yang sedang running
  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  // Pulse animation untuk indikator "sedang menunggu AI"
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
    // Inisialisasi GeminiService secara aman (tidak throw)
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Pipeline
  // ---------------------------------------------------------------------------

  Future<void> _runPipeline() async {
    final state = context.read<TSmartState>();

    // ── Step 0: Baca data rekaman ──────────────────────────────────────────
    _setStepRunning(0);
    _addLog('Membaca data rekaman dari session…');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final pending = state.pendingAnalysis;
    if (pending == null) {
      _setStepFailed(0, detail: 'Data tidak ditemukan');
      _addLog('Data rekaman tidak ditemukan!', level: _LogLevel.error);
      if (mounted) setState(() => _hasError = true);
      return;
    }

    _addLog(
      'Video: ${pending.videoPath.split('/').last}',
      level: _LogLevel.info,
    );
    _addLog('Durasi rekaman: ${pending.timerSeconds} detik');
    _addLog(
      'Frame bersedia terkumpul: ${pending.bersediaScores.length} frame',
    );
    _addLog(
      'Frame berlari terkumpul : ${pending.berlariScores.length} frame',
    );
    _setStepDone(
      0,
      detail:
          '${pending.bersediaScores.length + pending.berlariScores.length} frame total',
    );

    // ── Step 1: Hitung skor posisi ─────────────────────────────────────────
    _setStepRunning(1);
    _addLog('Menghitung rata-rata skor posisi…');
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final double? bersediaScore = pending.avgBersediaScore;
    final double? berlariScore = pending.avgBerlariScore;

    if (bersediaScore != null) {
      _addLog(
        'Skor bersedia : ${bersediaScore.toStringAsFixed(1)} / 100'
        '  (${pending.bersediaScores.length} frame)',
        level: _LogLevel.success,
      );
    } else {
      _addLog(
        'Posisi bersedia tidak terdeteksi dalam video.',
        level: _LogLevel.warning,
      );
    }

    if (berlariScore != null) {
      _addLog(
        'Skor berlari  : ${berlariScore.toStringAsFixed(1)} / 100'
        '  (${pending.berlariScores.length} frame)',
        level: _LogLevel.success,
      );
    } else {
      _addLog(
        'Posisi berlari tidak terdeteksi dalam video.',
        level: _LogLevel.warning,
      );
    }

    final avgOverall = ((bersediaScore ?? 0) + (berlariScore ?? 0)) / 2;
    _addLog(
      'Rata-rata keseluruhan: ${avgOverall.toStringAsFixed(1)} / 100',
    );
    _setStepDone(
      1,
      detail:
          'Bersedia ${bersediaScore?.toStringAsFixed(1) ?? "–"}  •  Berlari ${berlariScore?.toStringAsFixed(1) ?? "–"}',
    );

    // ── Step 2: Evaluasi Gemini AI ─────────────────────────────────────────
    _setStepRunning(2);
    _addLog('Mengirim data ke Gemini AI…');

    // Pilih hingga 10 gambar: best frames + sample frames
    final selectedImages = pending.selectImagesForAnalysis(maxImages: 10);
    if (selectedImages.isNotEmpty) {
      _addLog('Melampirkan ${selectedImages.length} frame (maks 10).');
    } else {
      _addLog(
        'Tidak ada frame gambar tersedia, analisis berbasis teks saja.',
        level: _LogLevel.warning,
      );
    }

    final bersediaDisplay =
        bersediaScore != null ? bersediaScore.toStringAsFixed(1) : 'N/A';
    final berlariDisplay =
        berlariScore != null ? berlariScore.toStringAsFixed(1) : 'N/A';

    final prompt = '''
Kamu adalah pelatih lari sprint profesional.
Berikut adalah hasil analisis teknik lari atlet:

- Skor posisi bersedia/start: $bersediaDisplay / 100
  (jumlah frame terdeteksi: ${pending.bersediaScores.length})
- Skor posisi berlari: $berlariDisplay / 100
  (jumlah frame terdeteksi: ${pending.berlariScores.length})
- Durasi rekaman: ${pending.timerSeconds} detik

${selectedImages.isNotEmpty ? 'Gambar frame terbaik dari posisi bersedia dan berlari dilampirkan (${selectedImages.length} gambar).' : 'Tidak ada frame gambar yang tersedia.'}

Berikan evaluasi singkat (3–4 kalimat) tentang teknik keseluruhan atlet, lalu sebutkan 1–2 poin yang perlu diperbaiki. Gunakan bahasa Indonesia yang mudah dipahami.
''';

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
        aiAnalysis =
            'Analisis AI tertunda (rate limit). ${e.message}';
        _addLog('Rate limit: ${e.message}', level: _LogLevel.warning);
      } else {
        aiAnalysis =
            'Analisis AI tidak tersedia saat ini. Silakan periksa koneksi internet dan GEMINI_API_KEY.';
        _addLog('Gemini gagal: $e', level: _LogLevel.error);
      }
      _addLog(
        'Melanjutkan tanpa evaluasi AI.',
        level: _LogLevel.warning,
      );
      _setStepFailed(2, detail: 'Gagal — dilanjutkan');
    }

    if (!mounted) return;

    // ── Step 3: Buat rekomendasi ───────────────────────────────────────────
    _setStepRunning(3);
    _addLog('Menyusun rekomendasi latihan…');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final recommendations = _recommendationService.generate(
      bersediaScore: bersediaScore ?? 0,
      berlariScore: berlariScore ?? 0,
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

    state.completeRunWithFullResult(
      aiAnalysis: aiAnalysis,
      bersediaScore: bersediaScore,
      berlariScore: berlariScore,
      recommendations: recommendations,
      bersediaFrameCount: pending.bersediaScores.length,
      berlariFrameCount: pending.berlariScores.length,
    );

    if (!mounted) return;
    setState(() => _isDone = true);

    // Jeda sebentar agar user sempat melihat status selesai
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    context.go('/result');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      // Cegah back button selama proses berlangsung
      canPop: _isDone || _hasError,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Memproses Rekaman'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────
                Text(
                  _hasError
                      ? 'Terjadi kesalahan'
                      : _isDone
                          ? 'Analisis selesai!'
                          : 'Menganalisis rekaman…',
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

                // ── Banner menunggu AI ───────────────────────────────────
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
                              'Menunggu respons Gemini AI… ini bisa memakan beberapa detik.',
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

                // ── Progress bar ─────────────────────────────────────────
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
                        backgroundColor:
                            colorScheme.primaryContainer.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_doneCount)}/${_steps.length} langkah',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Step list ────────────────────────────────────────────
                ..._steps.asMap().entries.map((entry) {
                  final step = entry.value;
                  return _StepTile(
                    step: step,
                    spinController: _spinController,
                  );
                }),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // ── Log panel header ─────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.terminal,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
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
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // ── Log list ─────────────────────────────────────────────
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
                                    color: colorScheme.onSurfaceVariant,
                                  ),
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

                // ── Error action ─────────────────────────────────────────
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

// ---------------------------------------------------------------------------
// Widget: satu baris step
// ---------------------------------------------------------------------------

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
        leading = Icon(
          Icons.radio_button_unchecked,
          size: 20,
          color: colorScheme.outline,
        );
        labelColor = colorScheme.outline;
      case _StepStatus.running:
        leading = RotationTransition(
          turns: spinController,
          child: Icon(
            Icons.sync,
            size: 20,
            color: colorScheme.primary,
          ),
        );
        labelColor = colorScheme.onSurface;
      case _StepStatus.done:
        leading = Icon(
          Icons.check_circle,
          size: 20,
          color: colorScheme.primary,
        );
        labelColor = colorScheme.onSurface;
      case _StepStatus.failed:
        leading = Icon(
          Icons.warning_rounded,
          size: 20,
          color: colorScheme.error,
        );
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

// ---------------------------------------------------------------------------
// Widget: satu baris log
// ---------------------------------------------------------------------------

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
