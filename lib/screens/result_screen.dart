import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/sprintify_state.dart';
import '../widgets/performance_chip.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SprintifyState>();
    final r = state.lastRunResult;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hasil Analisis')),
        body: const Center(
            child: Text('Belum ada hasil. Rekam video dari beranda.')),
      );
    }

    final hasBersedia = r.bersediaScore != null;
    final hasBerlari = r.berlariScore != null;
    final hasScore = hasBersedia || hasBerlari;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Analisis'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Athlete name
            Text(
              r.athleteName,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Direkam: ${_formatDate(r.recordedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),

            // ---------------------------------------------------------------
            // Waktu & kategori
            // ---------------------------------------------------------------
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waktu Rekaman',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${r.timeSeconds.toStringAsFixed(1)} detik',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Kategori: ',
                            style: Theme.of(context).textTheme.bodyLarge),
                        PerformanceChip(category: r.category),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------------------------------------------------------------
            // Skor posisi
            // ---------------------------------------------------------------
            if (hasScore) ...[
              Text(
                'Skor Posisi',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (hasBersedia)
                    Expanded(
                      child: _ScoreCard(
                        label: 'Bersedia',
                        score: r.bersediaScore!,
                        frameCount: r.bersediaFrameCount,
                        color: Colors.blue,
                      ),
                    ),
                  if (hasBersedia && hasBerlari) const SizedBox(width: 12),
                  if (hasBerlari)
                    Expanded(
                      child: _ScoreCard(
                        label: 'Berlari',
                        score: r.berlariScore!,
                        frameCount: r.berlariFrameCount,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
              if (!hasBersedia || !hasBerlari)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    !hasBersedia && !hasBerlari
                        ? 'Tidak ada frame posisi yang terdeteksi. Pastikan tubuh terlihat jelas di kamera.'
                        : !hasBersedia
                            ? 'Posisi bersedia tidak terdeteksi dalam video.'
                            : 'Posisi berlari tidak terdeteksi dalam video.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
              const SizedBox(height: 20),
            ],

            // ---------------------------------------------------------------
            // Analisis dari AI
            // ---------------------------------------------------------------
            if (r.analysisNote != null && r.analysisNote!.isNotEmpty) ...[
              Text(
                'Evaluasi Teknik',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.4),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Analisis AI',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        r.analysisNote!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ---------------------------------------------------------------
            // Rekomendasi latihan
            // ---------------------------------------------------------------
            if (r.recommendations.isNotEmpty) ...[
              Text(
                'Saran Pengembangan',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...r.recommendations.asMap().entries.map((entry) {
                final idx = entry.key;
                final rec = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          rec,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // ---------------------------------------------------------------
            // Tombol aksi
            // ---------------------------------------------------------------
            TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Kembali ke beranda'),
            ),
            const SizedBox(height: 24),

            // Log JSON
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Log Hasil',
                    style: Theme.of(context).textTheme.titleSmall),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: r.toString()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Log berhasil disalin')),
                    );
                  },
                ),
              ],
            ),
            Container(
              height: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  r.toString(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Score card widget
// ---------------------------------------------------------------------------

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.score,
    required this.frameCount,
    required this.color,
  });

  final String label;
  final double score;
  final int frameCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              score.toStringAsFixed(1),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
            Text(
              '/ 100',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: score / 100,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            const SizedBox(height: 6),
            Text(
              '$frameCount frame',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
