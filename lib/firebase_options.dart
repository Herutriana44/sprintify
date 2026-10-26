import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Membaca konfigurasi Firebase dari file .env sehingga tidak perlu
/// meng-commit google-services.json atau GoogleService-Info.plist.
///
/// Pastikan .env sudah diload sebelum memanggil [firebaseOptions].
class DefaultFirebaseOptions {
  /// Returns null on Android — google-services.json already handled native
  /// Firebase init via the Gradle plugin before Dart runs. Passing null to
  /// Firebase.initializeApp() is equivalent to calling it with no options,
  /// which lets the native layer use the already-created [DEFAULT] app without
  /// creating a duplicate.
  ///
  /// Returns .env-based FirebaseOptions on all other platforms.
  static FirebaseOptions? get currentPlatformOrNull {
    if (Platform.isAndroid) return null;
    return _fromEnv();
  }

  /// Always returns .env-based FirebaseOptions regardless of platform.
  /// Keep this getter for any existing call sites or non-Android usage.
  static FirebaseOptions get currentPlatform => _fromEnv();

  static FirebaseOptions _fromEnv() => FirebaseOptions(
        apiKey: dotenv.get('FIREBASE_API_KEY'),
        appId: dotenv.get('FIREBASE_APP_ID'),
        messagingSenderId: dotenv.get('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: dotenv.get('FIREBASE_PROJECT_ID'),
        authDomain: dotenv.get('FIREBASE_AUTH_DOMAIN', fallback: ''),
        storageBucket: dotenv.get('FIREBASE_STORAGE_BUCKET', fallback: ''),
        databaseURL: dotenv.get('FIREBASE_DATABASE_URL', fallback: ''),
      );
}
