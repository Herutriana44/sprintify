import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TSmartApp extends StatefulWidget {
  const TSmartApp({super.key});

  @override
  State<TSmartApp> createState() => _TSmartAppState();
}

class _TSmartAppState extends State<TSmartApp> {
  late final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'T-Smart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
