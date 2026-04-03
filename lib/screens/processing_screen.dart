import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/sprintify_state.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _step = 0;
  final _messages = const [
    'Mengunggah cuplikan…',
    'Computer vision: mendeteksi start & finish…',
    'Menghitung waktu tempuh…',
    'Scoring & kategori performa…',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..forward();

    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _step = 1);
    });
    Future<void>.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _step = 2);
    });
    Future<void>.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _step = 3);
    });
    Future<void>.delayed(const Duration(milliseconds: 4500), () {
      if (!mounted) return;
      context.read<SprintifyState>().completeRunWithSimulatedResult();
      if (!mounted) return;
      context.go('/result');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              Text(
                'Demo: simulasi tanpa backend.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return LinearProgressIndicator(
                    value: _controller.value.clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  );
                },
              ),
              const SizedBox(height: 28),
              ...List.generate(_messages.length, (i) {
                final active = i <= _step;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        active ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 22,
                        color: active
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _messages[i],
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: active
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.outline,
                                fontWeight: i == _step ? FontWeight.w600 : null,
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Spacer(),
              Text(
                'Status: CV processing • scoring',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
