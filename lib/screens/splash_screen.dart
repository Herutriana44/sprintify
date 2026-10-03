import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added
import 'package:provider/provider.dart'; // Added
import '../providers/t_smart_state.dart'; // Added

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

    final auth = FirebaseAuth.instance;
    final smartState = Provider.of<TSmartState>(context, listen: false);

    if (auth.currentUser == null) {
      // User not logged in, go to login screen
      context.go('/login');
    } else {
      // User is logged in, set account ID and check role
      smartState.setCurrentAccountId(auth.currentUser!.uid);
      final role = smartState.deviceRole;
      if (role == null) {
        // Role not set, go to role selection
        context.go('/role-selection');
      } else if (role == 'start') {
        // Go to start-related screen (e.g., dashboard or a specific start screen)
        context.go('/dashboard'); // Or a dedicated start screen if exists
      } else if (role == 'finish') {
        // Go to finish-related screen (e.g., dashboard or a specific finish screen)
        context.go('/dashboard'); // Or a dedicated finish screen if exists
      } else {
        // Unknown role, treat as not logged in/configured
        context.go('/login');
      }
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

