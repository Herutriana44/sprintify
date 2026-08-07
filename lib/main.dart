import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/t_smart_state.dart';
import 'services/firebase/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FLUTTER ERROR: ${details.exception}');
  };

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✓ Environment variables loaded');
  } catch (e) {
    debugPrint('⚠ Warning: Failed to load .env: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✓ Firebase initialized');
  } catch (e) {
    debugPrint('⚠ Warning: Firebase init failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<TSmartState>(
          create: (_) => TSmartState(),
        ),
      ],
      child: const TSmartApp(),
    ),
  );
}
