import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/athlete.dart';
import '../models/exercise_type.dart';
import '../providers/t_smart_state.dart';

class ExercisePrepScreen extends StatefulWidget {
  const ExercisePrepScreen({super.key});

  @override
  State<ExercisePrepScreen> createState() => _ExercisePrepScreenState();
}

class _ExercisePrepScreenState extends State<ExercisePrepScreen> {
  int _selectedCountdown = 5;
  final List<int> _countdownOptions = [3, 5, 10];

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

    final selectedType = state.selectedExerciseType;

    return Scaffold(
      appBar: AppBar(title: const Text('Persiapan Tes Fisik')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tes Kebugaran Fisik',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih jenis tes, siswa, dan durasi hitung mundur.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),

            // ── Pilih Jenis Exercise ────────────────────────────────────────
            Text(
              'Jenis tes',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: ExerciseType.values.map((type) {
                final isSelected = selectedType == type;
                return _ExerciseTypeCard(
                  type: type,
                  isSelected: isSelected,
                  onTap: () =>
                      context.read<TSmartState>().setSelectedExerciseType(type),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Instruksi Kamera ───────────────────────────────────────────
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Instruksi Kamera',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedType.cameraInstruction,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Pilih Atlet ────────────────────────────────────────────────
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
                  if (a != null) {
                    context.read<TSmartState>().setSelectedAthlete(a);
                  }
                },
              ),
            const SizedBox(height: 24),

            // ── Hitung Mundur ──────────────────────────────────────────────
            Text(
              'Durasi hitung mundur',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Waktu persiapan sebelum pengambilan dimulai.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: _countdownOptions.map((sec) {
                final isSelected = _selectedCountdown == sec;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: sec != _countdownOptions.last ? 8.0 : 0,
                    ),
                    child: _CountdownOption(
                      seconds: sec,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedCountdown = sec),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // ── Tombol Mulai ───────────────────────────────────────────────
            FilledButton.icon(
              onPressed: athletes.isEmpty || selected == null
                  ? null
                  : () {
                      context.read<TSmartState>().setSelectedAthlete(selected);
                      context.push(
                        '/exercise-recording',
                        extra: {
                          'countdownSeconds': _selectedCountdown,
                        },
                      );
                    },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Lanjut ke Rekaman'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exercise Type Card ──────────────────────────────────────────────────────

class _ExerciseTypeCard extends StatelessWidget {
  const _ExerciseTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final ExerciseType type;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (type) {
      case ExerciseType.pushUp:
        return Icons.fitness_center;
      case ExerciseType.pullUp:
        return Icons.accessibility_new;
      case ExerciseType.sitUp:
        return Icons.self_improvement;
      case ExerciseType.squatJump:
        return Icons.directions_run;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icon,
              size: 36,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              type.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Countdown Option ────────────────────────────────────────────────────────

class _CountdownOption extends StatelessWidget {
  const _CountdownOption({
    required this.seconds,
    required this.isSelected,
    required this.onTap,
  });

  final int seconds;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.secondary
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$seconds',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurface,
                  ),
            ),
            Text(
              'detik',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
