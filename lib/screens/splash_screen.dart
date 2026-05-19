import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

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
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([
      _requestMobileCameraPermissions(),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted) return;
    context.go('/login');
  }

  /// Meminta izin kamera (dan mikrofon untuk rekaman video) di awal, pada Android & iOS.
  Future<void> _requestMobileCameraPermissions() async {
    // Di `flutter test`, plugin izin tidak terhubung ke native — lewati agar tidak menggantung.
    if (WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding')) {
      return;
    }
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      await Permission.camera.request();
      await Permission.microphone.request();
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
