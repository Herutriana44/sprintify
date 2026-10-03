import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sprintify/firebase_options.dart';

import 'app.dart';
import 'providers/t_smart_state.dart';

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

  // Initialize Firebase after loading .env
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('✓ Firebase initialized');


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TSmartState>(
          create: (_) => TSmartState(),
        ),
      ],
      child: const TSmartApp(),
    ),
  );
}

