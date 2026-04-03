import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SprintifyApp extends StatefulWidget {
  const SprintifyApp({super.key});

  @override
  State<SprintifyApp> createState() => _SprintifyAppState();
}

class _SprintifyAppState extends State<SprintifyApp> {
  late final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sprintify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
