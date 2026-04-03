import 'package:flutter/material.dart';

class SprintifyLogo extends StatelessWidget {
  const SprintifyLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.directions_run_rounded,
            size: size * 0.55,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sprintify',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: scheme.onSurface,
              ),
        ),
        Text(
          'Tes lari 60 meter',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
