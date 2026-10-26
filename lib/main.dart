import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:t_smart/firebase_options.dart';

import 'app.dart';
import 'providers/t_smart_state.dart';
import 'services/firebase/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrint('FLUTTER ERROR stack: ${details.stack}');
  };

  // Tangkap semua unhandled async errors (termasuk native platform errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PLATFORM ERROR: $error');
    debugPrint('PLATFORM ERROR stack: $stack');
    return true;
  };

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✓ Environment variables loaded');
  } catch (e) {
    // Jika .env gagal load, tampilkan error screen daripada crash silent
    debugPrint('✗ FATAL: Failed to load .env: $e');
    runApp(_ErrorApp('Gagal memuat konfigurasi aplikasi.\n\n$e'));
    return;
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatformOrNull,
      );
      debugPrint('✓ Firebase initialized');
    } else {
      debugPrint('✓ Firebase already initialized, skipping');
    }
  } catch (e, stack) {
    debugPrint('✗ FATAL: Firebase initialization failed: $e');
    debugPrint('Stack: $stack');
    runApp(_ErrorApp('Gagal menginisialisasi Firebase.\n\n$e'));
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TSmartState>(
          create: (_) => TSmartState(),
        ),
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: const TSmartApp(),
    ),
  );
}

/// Widget fallback yang ditampilkan jika inisialisasi gagal.
/// Menampilkan pesan error agar mudah di-debug di release build.
class _ErrorApp extends StatelessWidget {
  const _ErrorApp(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Aplikasi gagal dimulai',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
