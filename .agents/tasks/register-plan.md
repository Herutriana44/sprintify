# Implementation Plan — Register Account Page & Firebase Duplicate-App Fix

## Codebase findings (mandatory reading for the coder)

| Item | Finding |
|---|---|
| Login screen | `lib/screens/login_screen.dart` — bare `TextField`+`ElevatedButton`, no Form/validator, calls `FirebaseAuth.instance` directly (not via `AuthService`), no `TSmartLogo`, uses `ScaffoldMessenger` for errors. Missing a "Register" button entirely. |
| Register screen | `lib/screens/register_screen.dart` — **already exists and is fully implemented**. Uses `Form`+`TextFormField`, `FilledButton`, `TSmartLogo`, `AuthService.registerWithEmail`, `context.go('/dashboard')` after success, `context.pop()` on "Sudah punya akun? Masuk". Only wiring needed is the button on the login screen. |
| Auth service | `lib/services/firebase/auth_service.dart` — `registerWithEmail({name, email, password})` already exists. Returns `AuthResult`. No changes needed. |
| Router | `lib/router/app_router.dart` — `/register` route already exists, points to `RegisterScreen`. No changes needed. |
| main.dart | `lib/main.dart` — calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatformOrNull)`. This getter **already exists** in the current `firebase_options.dart` (returns `null` on Android). The guard reads `if (Firebase.apps.isEmpty)`. **This is the correct fix already written** in `firebase_options.dart`. |
| firebase_options.dart | `lib/firebase_options.dart` — **already has** `currentPlatformOrNull` that returns `null` on Android. main.dart still calls `DefaultFirebaseOptions.currentPlatformOrNull`. The Firebase duplicate-app fix is already in place in these files. |
| Navigation | GoRouter is used throughout. `context.go()` for hard redirects, `context.push()` / `context.pop()` for stack-based navigation. The register screen uses `context.pop()` to return to login — so login must use `context.push('/register')` to push (not `go`) so pop works. |
| Theme | Material3, seed color `0xFF0D9488` (teal). `FilledButton` is the primary CTA. `InputDecoration` with `OutlineInputBorder`, radius 12. `TextButton` for secondary actions. |
| Build command | `flutter build apk` / `flutter run`. Syntax check: `dart analyze lib/`. |

---

## What is actually missing

After reading all files, the task reduces to **two concrete changes**:

1. **`lib/screens/login_screen.dart`** — add a `TextButton` that navigates to `/register`. This is the only missing piece for the "register account page" requirement. The register screen, its route, and its auth method all already exist.

2. **`lib/screens/login_screen.dart`** — the login screen bypasses `AuthService` and calls `FirebaseAuth.instance` directly. This is inconsistent with the rest of the app and should be refactored to use `AuthService.signInWithEmail` (which already handles errors in Bahasa Indonesia). This also aligns the login screen's style with the register screen (Form, TextFormField, FilledButton, TSmartLogo).

The Firebase duplicate-app fix (`currentPlatformOrNull` + null on Android) **is already implemented** in the current codebase. No additional changes are needed for that fix.

---

## Implementation Plan

- [ ] 1. Rewrite `lib/screens/login_screen.dart` to match the register screen's style and add the "Daftar" (Register) navigation button.

  **What to do:**
  - Replace the bare `TextField`/`ElevatedButton` layout with `Form`, `TextFormField` (with validators), `FilledButton`, and `TSmartLogo(size: 56)` — exactly mirroring `register_screen.dart`'s structure.
  - Replace direct `FirebaseAuth.instance.signInWithEmailAndPassword` with `context.read<AuthService>().signInWithEmail(email: ..., password: ...)`.
  - Show the `AuthResult.error` string in the same `errorContainer` box pattern used in `register_screen.dart` (not a SnackBar).
  - Remove the `import 'package:firebase_auth/firebase_auth.dart'` import (no longer needed directly).
  - Add `import '../services/firebase/auth_service.dart'` and `import '../widgets/t_smart_logo.dart'`.
  - After successful login via `AuthService`, call `context.go('/role-selection')` (same destination as the old code).
  - Add a `TextButton` at the bottom: label `'Belum punya akun? Daftar'`, onPressed: `context.push('/register')`. Use `context.push` (not `go`) so the register screen can `context.pop()` back to login.
  - Field labels in Bahasa Indonesia: `'Email'`, `'Kata sandi'`, with `prefixIcon: Icon(Icons.mail_outline)` and `prefixIcon: Icon(Icons.lock_outline)`.
  - Add `suffixIcon` toggle for password visibility (same `_obscure` bool pattern from register screen).
  - AppBar title: `'Masuk'`.

  **Files:**
  - Modify: `lib/screens/login_screen.dart`

  **Verify:** Run `dart analyze lib/screens/login_screen.dart` — zero errors/warnings.

- [ ] 2. Verify the Firebase duplicate-app fix is correctly wired in `main.dart`.

  **What to do:**
  - Confirm `lib/main.dart` line with `Firebase.initializeApp` passes `options: DefaultFirebaseOptions.currentPlatformOrNull` (not `.currentPlatform`).
  - Confirm `lib/firebase_options.dart` has `currentPlatformOrNull` returning `null` when `Platform.isAndroid`.
  - If either is missing, apply the fix described in the investigation report at `.agents/tasks/firebase-duplicate-app-investigation.md`.
  - Based on reading both files: `firebase_options.dart` already has `currentPlatformOrNull` with `if (Platform.isAndroid) return null` and `main.dart` already calls `DefaultFirebaseOptions.currentPlatformOrNull`. **No code changes are needed** for this item — just confirm.

  **Files:**
  - Read-only verification: `lib/main.dart`, `lib/firebase_options.dart`

  **Verify:** Run `dart analyze lib/main.dart lib/firebase_options.dart` — zero errors.

- [ ] 3. Run full syntax analysis to confirm no errors across the affected screens.

  **What to do:**
  - Run `dart analyze lib/` and confirm zero errors on the login screen, register screen, auth service, and router files.
  - If any errors are found (e.g. unused import from old `firebase_auth` import in `login_screen.dart`), fix them.

  **Files:**
  - `lib/screens/login_screen.dart` (modified in step 1)
  - `lib/screens/register_screen.dart` (existing, no change expected)
  - `lib/services/firebase/auth_service.dart` (existing, no change expected)
  - `lib/router/app_router.dart` (existing, no change expected)

  **Verify:** `dart analyze lib/` — output shows `No issues found!` or only pre-existing warnings unrelated to these files.

---

## Design decisions

**Why rewrite login_screen.dart instead of just adding a button?**
The current login screen is inconsistent with the rest of the app: it calls Firebase directly (bypassing `AuthService`), uses `ScaffoldMessenger` for errors (while the rest uses inline error containers), and has no form validation. Rewriting it to match the register screen's pattern costs minimal effort during this same change and avoids having a visually and architecturally inconsistent login flow.

**Why `context.push('/register')` instead of `context.go('/register')`?**
The register screen's "Sudah punya akun? Masuk" button calls `context.pop()`. `go()` replaces the navigation stack so `pop()` would silently fail or navigate to an unexpected route. `push()` stacks the register screen on top of login so `pop()` correctly returns to login.

**Why no changes to `auth_service.dart`, `app_router.dart`, or `main.dart`?**
All three already contain the necessary code: `registerWithEmail` exists in the auth service, `/register` is already a route in the router, and the Firebase duplicate-app fix (`currentPlatformOrNull` returning `null` on Android) is already in `firebase_options.dart` and correctly used in `main.dart`.

---

## Reference: final shape of `login_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/firebase/auth_service.dart';
import '../widgets/t_smart_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthService>();
    final result = await auth.signInWithEmail(
      email: _email.text.trim(),
      password: _password.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      context.go('/role-selection');
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TSmartLogo(size: 56),
                const SizedBox(height: 24),
                Text(
                  'Selamat datang',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Masuk untuk melanjutkan.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                    if (!v.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Kata sandi',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Kata sandi wajib diisi' : null,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Masuk'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Belum punya akun? Daftar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```
