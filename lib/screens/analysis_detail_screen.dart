import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/t_smart_state.dart';

class AnalysisDetailScreen extends StatelessWidget {
  const AnalysisDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TSmartState>();
    final r = state.lastRunResult;
    final pending = state.pendingAnalysis;

    // Ambil frame terbaik dari pendingAnalysis (kalau masih ada di memori)
    final File? bersediaFrame = pending?.bestBersediaFrame;
    final File? berlariFrame = pending?.bestBerlariFrame;

    return Scaffold(
      appBar: AppBar(title: const Text('Analisis Detail')),
      body: SafeArea(
        child: r == null
            ? const Center(child: Text('Tidak ada data analisis.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    r.athleteName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Frame posisi terbaik & indikator teknis.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // ── Frame terbaik ──────────────────────────────────────────
                  Text(
                    'Frame Posisi Terbaik',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _FrameCard(
                          label: 'Bersedia',
                          score: r.bersediaScore,
                          imageFile: bersediaFrame,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FrameCard(
                          label: 'Berlari',
                          score: r.berlariScore,
                          imageFile: berlariFrame,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Metrik ─────────────────────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metrik Rekaman',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          _metricRow(context, 'Waktu tempuh',
                              '${r.timeSeconds.toStringAsFixed(1)} detik'),
                          _metricRow(context, 'Frame bersedia',
                              '${r.bersediaFrameCount} frame'),
                          _metricRow(context, 'Frame berlari',
                              '${r.berlariFrameCount} frame'),
                          _metricRow(
                            context,
                            'Kecepatan rata-rata',
                            '${r.avgSpeedKmh.toStringAsFixed(1)} km/jam',
                          ),
                          _metricRow(context, 'Langkah (estimasi)',
                              '${r.stepCount}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Analisis AI ────────────────────────────────────────────
                  if (r.analysisNote != null && r.analysisNote!.isNotEmpty) ...[
                    Text(
                      'Analisis AI',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          r.analysisNote!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Log JSON ───────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Log Hasil (JSON)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push('/recommendation'),
                    child: const Text('Lanjut ke rekomendasi'),
                  ),
                ],
              ),
      ),
    );
  }

  static Widget _metricRow(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            v,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Frame card — tampilkan gambar asli jika ada, fallback placeholder
// ---------------------------------------------------------------------------

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.label,
    required this.color,
    this.score,
    this.imageFile,
  });

  final String label;
  final Color color;
  final double? score;
  final File? imageFile;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null && imageFile!.existsSync();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gambar atau placeholder
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: hasImage
                  ? Image.file(imageFile!, fit: BoxFit.cover)
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported_outlined,
                              size: 36,
                              color:
                                  Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 6),
                          Text(
                            'Tidak tersedia',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline,
                                ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          // Label & skor
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
                if (score != null)
                  Text(
                    'Skor: ${score!.toStringAsFixed(1)} / 100',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                  )
                else
                  Text(
                    'Tidak terdeteksi',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
