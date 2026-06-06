import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/sprintify_state.dart';
import '../services/analysis/gemini_service.dart';
import '../services/analysis/recommendation_service.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final GeminiService _geminiService = GeminiService();
  final RecommendationService _recommendationService = RecommendationService();

  var _step = 0;
  String? _errorMessage;

  static const _messages = [
    'Membaca data pose dari video…',
    'Menilai posisi bersedia & berlari…',
    'Evaluasi AI dari gambar terbaik…',
    'Menyusun rekomendasi…',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..forward();

    // Delay satu frame agar context tersedia
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPipeline());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runPipeline() async {
    final state = context.read<SprintifyState>();
    final pending = state.pendingAnalysis;

    // -----------------------------------------------------------------------
    // Step 0 – ambil data dari rekaman
    // -----------------------------------------------------------------------
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _step = 0);

    if (pending == null) {
      setState(() => _errorMessage = 'Data rekaman tidak ditemukan.');
      return;
    }

    // -----------------------------------------------------------------------
    // Step 1 – hitung skor rata-rata tiap posisi
    // -----------------------------------------------------------------------
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _step = 1);

    final double? bersediaScore = pending.avgBersediaScore;
    final double? berlariScore = pending.avgBerlariScore;

    // -----------------------------------------------------------------------
    // Step 2 – kirim frame terbaik ke Gemini (multimodal)
    // -----------------------------------------------------------------------
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _step = 2);

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

${pending.bestFrames.isNotEmpty ? 'Gambar frame terbaik dari posisi bersedia dan berlari dilampirkan.' : 'Tidak ada frame gambar yang tersedia.'}

Berikan evaluasi singkat (3–4 kalimat) tentang teknik keseluruhan atlet, lalu sebutkan 1–2 poin yang perlu diperbaiki. Gunakan bahasa Indonesia yang mudah dipahami.
''';

    String aiAnalysis;
    try {
      aiAnalysis = await _geminiService.getAnalysisWithImages(
        imageFiles: pending.bestFrames,
        textPrompt: prompt,
      );
    } catch (e) {
      // Fallback: jika Gemini gagal, tetap lanjutkan pipeline
      aiAnalysis =
          'Analisis AI tidak tersedia saat ini. Silakan periksa koneksi internet dan GEMINI_API_KEY.';
      debugPrint('Gemini error: $e');
    }

    // -----------------------------------------------------------------------
    // Step 3 – buat rekomendasi berbasis logika kondisional
    // -----------------------------------------------------------------------
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _step = 3);

    final recommendations = _recommendationService.generate(
      bersediaScore: bersediaScore ?? 0,
      berlariScore: berlariScore ?? 0,
    );

    // -----------------------------------------------------------------------
    // Simpan hasil & navigasi
    // -----------------------------------------------------------------------
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    state.completeRunWithFullResult(
      aiAnalysis: aiAnalysis,
      bersediaScore: bersediaScore,
      berlariScore: berlariScore,
      recommendations: recommendations,
      bersediaFrameCount: pending.bersediaScores.length,
      berlariFrameCount: pending.berlariScores.length,
    );

    if (!mounted) return;
    context.go('/result');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memproses')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sedang menganalisis video…',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                )
              else
                Text(
                  'Harap tunggu, sedang mengevaluasi teknik larimu.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => LinearProgressIndicator(
                  value: _controller.value.clamp(0.0, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 28),
              ...List.generate(_messages.length, (i) {
                final done = i < _step;
                final active = i == _step;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle
                            : active
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                        size: 22,
                        color: done || active
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _messages[i],
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: done || active
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                        : Theme.of(context)
                                            .colorScheme
                                            .outline,
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Spacer(),
              Text(
                'Pose scoring • AI evaluation • rekomendasi',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
