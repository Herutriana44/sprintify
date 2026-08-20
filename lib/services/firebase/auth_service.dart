import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firestore_service.dart';
import 'firestore_migration.dart';

class AuthService extends ChangeNotifier {
  AuthService({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
    FirestoreMigration? migration,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestoreService = firestoreService ?? FirestoreService(),
        _migration = migration ?? FirestoreMigration();

  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final FirestoreMigration _migration;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get uid => _auth.currentUser?.uid;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Email / Password
  // ---------------------------------------------------------------------------

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _postLoginSetup(cred.user!);
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendlyError(e.code));
    } catch (e) {
      return AuthResult.failure('Terjadi kesalahan: $e');
    }
  }

  Future<AuthResult> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.updateDisplayName(name.trim());
      await _postLoginSetup(cred.user!, name: name.trim());
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendlyError(e.code));
    } catch (e) {
      return AuthResult.failure('Terjadi kesalahan: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Login Google dibatalkan.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      await _postLoginSetup(cred.user!, name: googleUser.displayName);
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_friendlyError(e.code));
    } catch (e) {
      return AuthResult.failure('Terjadi kesalahan: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Post-login setup: buat user doc, jalankan migration, seed jika perlu
  // ---------------------------------------------------------------------------

  Future<void> _postLoginSetup(User user, {String? name}) async {
    try {
      await _firestoreService.createUserIfNotExists(
        uid: user.uid,
        email: user.email ?? '',
        name: name ?? user.displayName ?? '',
      );
      await _migration.runMigrations(user.uid);
      await _migration.seedIfEmpty(user.uid);
    } catch (e) {
      debugPrint('AuthService post-login setup error: $e');
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Error messages (Bahasa Indonesia)
  // ---------------------------------------------------------------------------

  static String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau kata sandi salah.';
      case 'email-already-in-use':
        return 'Email sudah digunakan oleh akun lain.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah (minimal 6 karakter).';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan.';
      default:
        return 'Gagal masuk ($code). Coba lagi.';
    }
  }
}

/// Hasil operasi autentikasi.
class AuthResult {
  const AuthResult._({required this.success, this.user, this.error});

  factory AuthResult.success(User user) =>
      AuthResult._(success: true, user: user);

  factory AuthResult.failure(String error) =>
      AuthResult._(success: false, error: error);

  final bool success;
  final User? user;
  final String? error;
}
