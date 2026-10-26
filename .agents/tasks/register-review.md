# Register Account page and real Firebase auth

The change replaces demo stub auth (hard-coded credentials, direct navigation to `/dashboard`) with real Firebase Email/Password auth backed by a new `AuthService`. A `RegisterScreen` is expanded from a shell to a full four-field form (name, email, password, confirm password) with validation and an error banner. `LoginScreen` gains the same form treatment, validation, loading state, and error display. Both screens wire to `AuthService` via `context.read<AuthService>()`. The router gains `/register`, `/role-selection`, and `/connect` routes. `main.dart` fixes the `duplicate-app` crash by passing `null` options to `Firebase.initializeApp()` on Android (letting the Gradle plugin's native init own the `[DEFAULT]` app) and `.env`-based options on all other platforms.

Watch for: **confirmed** — `signOut()` unconditionally calls `_gsi.signOut()` even when the user authenticated via email, which will throw if the Google Sign-In session has never been established on some platforms. **confirmed** — the password field's `onChanged` runs full-form validation on every keystroke, which means the confirm-password field immediately shows "Kata sandi tidak cocok" before the user has typed anything in it. **confirmed** — the `.env` load failure is now treated as fatal and stops the app; any CI/CD environment that doesn't provision `.env` will show a black error screen instead of running.

**Verdict**: NEEDS_CHANGES

---

## High-level view

`AuthService` is the core new piece: a `ChangeNotifier` wrapping `FirebaseAuth` that handles email/password sign-in, registration, Google Sign-In, and a `_postLoginSetup` hook that creates a Firestore user doc, runs migrations, and seeds data — all non-fatal on failure. The post-login flow lands at `/role-selection` rather than `/dashboard`, which is a new intermediate step also added in this diff.

The duplicate-app fix is clean: `DefaultFirebaseOptions.currentPlatformOrNull` returns `null` on Android, letting the Gradle-managed native `[DEFAULT]` app pass through untouched. The pattern is correct for the Android-only crash being fixed, but it means the Dart layer has no way to detect a missing `google-services.json` on Android at startup time — silent misconfiguration is possible.

The register form now has all four required fields with symmetric UX to the login screen. Both use the same inline error-container pattern for auth failures. The eager-validation `onChanged` on the password field causes premature error display on the confirm-password field, which is a minor but visible UX defect.

`signOut()` calls `_gsi.signOut()` through a lazy getter that initializes `GoogleSignIn` on first access. On platforms where GSI is not configured or the user authenticated via email, this can throw or produce a no-op with side effects depending on the platform implementation.

---

<details>
<summary>Issues (4)</summary>

1. **signOut crashes for email-only sessions** — `signOut()` always calls `_gsi.signOut()` via the lazy `_gsi` getter, which initializes a `GoogleSignIn` instance even for email-only users. On Android this is typically benign (a no-op GSI sign-out), but on iOS and other platforms it can throw or invoke the GSI native layer unexpectedly. Guard with `if (_googleSignIn != null) await _googleSignIn!.signOut()` to skip the call if GSI was never used.

2. **Premature confirm-password error** — `onChanged: (_) => _formKey.currentState?.validate()` on the password field runs full-form validation on every keystroke. The confirm-password validator immediately reports "Kata sandi tidak cocok" while the user is still typing, because the confirm field is empty. Move the `onChanged` call to the confirm-password field instead, or only trigger cross-field validation after `_confirmPassword` has been touched.

3. **Fatal .env load stops all environments** — the `.env` load failure now calls `runApp(_ErrorApp(...))` and returns, making a missing `.env` file a hard launch blocker. The previous behavior swallowed the error and continued. Any environment (CI, emulator-from-scratch, Codelab) that doesn't provision `.env` before running will see a black error screen. This is intentional for production hardening but should be documented in `README` / onboarding instructions as a required setup step.

4. **Android Firebase misconfiguration is now silent** — because Android always passes `null` options to `Firebase.initializeApp()`, a missing or misconfigured `google-services.json` will cause Firebase API calls to fail at runtime with cryptic errors rather than at init time with a clear message. A startup check (e.g., verifying `FirebaseAuth.instance.app.options.projectId.isNotEmpty` after init) would surface this faster during development.

</details>

---

<details>
<summary>Details</summary>

## Firebase duplicate-app fix and Android/non-Android split

The tradeoff in the Android-null approach is observability: a wrong or missing `google-services.json` won't fail at the `initializeApp` call — it will fail later when the first Firebase API call is made, and the error message won't point to the config file. This is a confirmed post-merge risk for development environments.

## AuthService post-login setup: silent production failures

`_postLoginSetup` failures (Firestore user-doc creation, migration, seed) are logged via `debugPrint`, which is stripped in release builds. If Firestore user-doc creation fails consistently — e.g., due to missing security rules — users will authenticate successfully but have no persistent profile. Data-dependent screens will break silently with no visible error.

## signOut crash risk for email-only sessions

```dart
Future<void> signOut() async {
  await Future.wait([
    _auth.signOut(),
    _gsi.signOut(),   // <-- always called
  ]);
  notifyListeners();
}
```

`_gsi` is a lazy getter: `GoogleSignIn get _gsi => _googleSignIn ??= GoogleSignIn()`. For an email-only user, `_googleSignIn` is `null`, so calling `_gsi.signOut()` instantiates a fresh `GoogleSignIn` object and calls `signOut()` on it. On Android this typically returns without error. On iOS the GSI SDK may invoke native sign-out flows that throw `PlatformException` if the Google account was never added. This is confirmed by code inspection; the platform-specific throw behavior makes it "likely" to surface on iOS, "possible" on Android depending on GSI version.

## Eager password validation causing premature error

The password field fires `_formKey.currentState?.validate()` on every `onChanged`. Since the `Form` validator runs all fields simultaneously, the confirm-password field's validator (`v != _password.text`) is evaluated while `_confirmPassword` is still empty — it will show "Kata sandi tidak cocok" before the user has reached that field. This is confirmed behavior: the validator has no `touched` guard, only a null/empty check followed by the equality check.

## Register form completeness and validation coverage

All four fields are present with correct validators. The confirm-password cross-field check compares `_confirmPassword.text` against `_password.text` directly in the validator — this is the correct pattern, but it only works reliably at submit time. The `onChanged`-triggered full-form validation on the password field defeats it during typing (see Issues #2).

</details>

---

<details>
<summary>File map</summary>

| File | What changed |
|---|---|
| `lib/services/firebase/auth_service.dart` | New: `AuthService` with email/password sign-in, registration, Google Sign-In, post-login Firestore setup, and localized error messages |
| `lib/firebase_options.dart` | New: `DefaultFirebaseOptions` reading `.env`; returns `null` on Android to avoid duplicate-app crash |
| `lib/main.dart` | Firebase init with duplicate-app guard; `AuthService` added to `MultiProvider`; fatal `.env` load with `_ErrorApp` fallback |
| `lib/screens/register_screen.dart` | Expanded from stub to full four-field validated form with loading state and inline error display |
| `lib/screens/login_screen.dart` | Real auth wired, form validation added, loading indicator, inline error banner, "Daftar" navigation button |
| `lib/router/app_router.dart` | Added `/role-selection` and `/connect` routes alongside pre-existing `/register` |
| `lib/app.dart` | Minor: removed explicit `GoRouter` type annotation on `_router` |

Full diff: `git diff main -- lib/screens/register_screen.dart lib/screens/login_screen.dart lib/services/firebase/auth_service.dart lib/router/app_router.dart lib/main.dart lib/firebase_options.dart`

</details>
