import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/sprintify_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SprintifyLogo(size: 100),
              const SizedBox(height: 48),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Memuat…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
