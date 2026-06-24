import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/athlete.dart';
import '../models/test_mode.dart';
import '../providers/t_smart_state.dart';

class TestPrepScreen extends StatefulWidget {
  const TestPrepScreen({super.key});

  @override
  State<TestPrepScreen> createState() => _TestPrepScreenState();
}

class _TestPrepScreenState extends State<TestPrepScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<TSmartState>();
      final list = state.athletes;
      if (list.isEmpty) return;
      final sel = state.selectedAthlete;
      if (sel == null || !list.any((a) => a.id == sel.id)) {
        state.setSelectedAthlete(list.first);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TSmartState>();
    final athletes = state.athletes;
    final Athlete? selected = athletes.isEmpty
        ? null
        : () {
            final sel = state.selectedAthlete;
            if (sel != null && athletes.any((a) => a.id == sel.id)) return sel;
            return athletes.first;
          }();

    return Scaffold(
      appBar: AppBar(title: const Text('Persiapan tes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Sebelum rekaman',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih subjek dan mode pengujian.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pilih siswa / atlet',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (athletes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Belum ada data atlet.'),
                      TextButton(
                        onPressed: () => context.push('/athletes/new'),
                        child: const Text('Tambah atlet dulu'),
                      ),
                    ],
                  ),
                ),
              )
            else
              DropdownButtonFormField<Athlete>(
                // ignore: deprecated_member_use
                value: selected,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_search),
                ),
                items: athletes
                    .map(
                      (a) => DropdownMenuItem(
                        value: a,
                        child: Text(a.name),
                      ),
                    )
                    .toList(),
                onChanged: (a) {
                  if (a != null) context.read<TSmartState>().setSelectedAthlete(a);
                },
              ),
            const SizedBox(height: 24),
            Text(
              'Mode pengujian',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TestMode>(
              segments: TestMode.values
                  .map(
                    (m) => ButtonSegment<TestMode>(
                      value: m,
                      label: Text(m.label),
                    ),
                  )
                  .toList(),
              selected: {state.testMode},
              onSelectionChanged: (Set<TestMode> next) {
                if (next.isNotEmpty) {
                  context.read<TSmartState>().setTestMode(next.first);
                }
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Instruksi',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('• Posisikan kamera memuat seluruh lintasan 60 m.'),
                    const SizedBox(height: 8),
                    const Text('• Pastikan garis start dan finish terlihat jelas.'),
                    const SizedBox(height: 8),
                    const Text('• Jarak yang diukur: 60 meter.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: athletes.isEmpty || selected == null
                  ? null
                  : () {
                      context.read<TSmartState>().setSelectedAthlete(selected);
                      context.push('/recording');
                    },
              child: const Text('Lanjut ke rekaman'),
            ),
          ],
        ),
      ),
    );
  }
}
