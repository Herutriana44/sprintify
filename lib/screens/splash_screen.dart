import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/t_smart_state.dart';
import '../widgets/t_smart_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([
      _requestAllPermissions(),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Sambungkan Firestore sebelum redirect ke dashboard
      await context.read<TSmartState>().connectFirestore(user.uid);
      if (!mounted) return;
      context.go('/dashboard');
    } else {
      context.go('/login');
    }
  }

  Future<void> _requestAllPermissions() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await [
        Permission.camera,
        Permission.microphone,
        Permission.videos,
        Permission.photos,
      ].request();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TSmartLogo(size: 100),
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
