# Firebase Duplicate App Investigation Report

## Summary Answer

**Root cause:** `Firebase.initializeApp()` is called exactly once in Dart code (`lib/main.dart`, line 40), correctly guarded by `Firebase.apps.isEmpty`. However, the `options:` parameter passes a `DefaultFirebaseOptions` built entirely from `.env` values — while `google-services.json` is simultaneously present and wired into the native Android build via the `com.google.gms.google-services` Gradle plugin. The native Firebase Android SDK auto-initialises a `[DEFAULT]` app from `google-services.json` when the process starts. When the Dart code then calls `Firebase.initializeApp(options: ...)`, the FlutterFire plugin's native bridge (`FlutterFirebaseCorePlugin`) attempts to initialise the same `[DEFAULT]` app a second time with potentially different options — which the Firebase Android SDK rejects as `[core/duplicate-app]`.

The `Firebase.apps.isEmpty` guard in Dart **does not prevent this** because `Firebase.apps` is a Dart-side list that is empty until Dart code registers an app. The native-side `[DEFAULT]` app already exists before the Dart guard is evaluated.

---

## Evidence

### 1. How many times is `Firebase.initializeApp()` called and from which files?

**Exactly once in Dart code**, in `lib/main.dart` lines 39–44:

```dart
// lib/main.dart lines 39–44
if (Firebase.apps.isEmpty) {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('✓ Firebase initialized');
```

No other Dart file calls `Firebase.initializeApp()`. The `auth_service.dart`, `firestore_service.dart`, `firestore_migration.dart`, `login_screen.dart`, `splash_screen.dart`, and `connect_screen.dart` all use `FirebaseAuth.instance`, `FirebaseFirestore.instance`, and `FirebaseDatabase.instance` — they assume init already happened and do not call `initializeApp` themselves.

However, there is a **second init path at the native level**: the `com.google.gms.google-services` Gradle plugin reads `android/app/google-services.json` and injects the Firebase options as Android resources at build time. The Firebase Android SDK (`firebase-core`) reads those resources and calls `FirebaseApp.initializeApp(context)` automatically during `Application.onCreate()` — before any Flutter/Dart code runs.

So the sequence at runtime is:

1. Android process starts → `Application.onCreate()` → Firebase Android SDK auto-inits `[DEFAULT]` from `google-services.json`.
2. Flutter engine starts → `main()` → Dart guard `Firebase.apps.isEmpty` is checked → **evaluates to `true`** (Dart hasn't registered anything yet).
3. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` is called → the FlutterFire native bridge tries to initialise the native `[DEFAULT]` app again → **crash: `[core/duplicate-app]`**.

### 2. Is there a `google-services.json` present?

**Yes.** File confirmed at `android/app/google-services.json`.

Contents (key fields):
- `project_number`: `871753390635`
- `project_id`: `t-smart-65ff1`
- `mobilesdk_app_id`: `1:871753390635:android:80bec9e1faf622978b286e`
- `package_name`: `com.example.t_smart`
- `api_key[0].current_key`: `AIzaSyBXSpsxjP0L4gzg0746T-iJ0I3C5g-9j_I`

The Gradle plugin is correctly wired:
- `android/settings.gradle.kts` line 24: `id("com.google.gms.google-services") version "4.4.2" apply false`
- `android/app/build.gradle.kts` lines 1–6: `id("com.google.gms.google-services")` applied to the `:app` module.

This means `google-services.json` IS active and DOES trigger native auto-initialisation.

### 3. Is there a `.env` file and what Firebase-related keys does it contain?

**Yes.** File at `c:\...\sprintify\.env` (also bundled as a Flutter asset via `pubspec.yaml`).

Firebase keys in `.env`:
```
FIREBASE_API_KEY=AIzaSyBXSpsxjP0L4gzg0746T-iJ0I3C5g-9j_I
FIREBASE_APP_ID=1:871753390635:android:80bec9e1faf622978b286e
FIREBASE_MESSAGING_SENDER_ID=871753390635
FIREBASE_PROJECT_ID=t-smart-65ff1
FIREBASE_AUTH_DOMAIN=t-smart-65ff1.firebaseapp.com
FIREBASE_STORAGE_BUCKET=t-smart-65ff1.firebasestorage.app
FIREBASE_DATABASE_URL=https://t-smart-65ff1-default-rtdb.firebaseio.com/
```

The values in `.env` match `google-services.json` for the core fields (`api_key`, `app_id`, `project_id`). This is the same Firebase project — the data is not conflicting, but the dual-init path is the conflict.

### 4. Is there a `firebase_options.dart` and what does it configure?

**Yes.** `lib/firebase_options.dart` — a **custom hand-written file** (not FlutterFire CLI-generated). It builds `FirebaseOptions` entirely from `flutter_dotenv` values:

```dart
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: dotenv.get('FIREBASE_API_KEY'),
        appId: dotenv.get('FIREBASE_APP_ID'),
        messagingSenderId: dotenv.get('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: dotenv.get('FIREBASE_PROJECT_ID'),
        authDomain: dotenv.get('FIREBASE_AUTH_DOMAIN', fallback: ''),
        storageBucket: dotenv.get('FIREBASE_STORAGE_BUCKET', fallback: ''),
        databaseURL: dotenv.get('FIREBASE_DATABASE_URL', fallback: ''),
      );
}
```

There is **no platform branching** (no `defaultTargetPlatform` checks, no separate Android/iOS options). This is a purely `.env`-driven approach.

### 5. What is `main.dart` doing regarding Firebase initialisation?

`lib/main.dart` does the following:

1. Calls `WidgetsFlutterBinding.ensureInitialized()`.
2. Loads `.env` via `dotenv.load(fileName: ".env")`.
3. Checks `Firebase.apps.isEmpty` (Dart-side list).
4. Calls `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

The guard `Firebase.apps.isEmpty` is correct in intent but **does not work** against native auto-initialisation. The Firebase Android SDK has already created the `[DEFAULT]` app in the native layer before Dart runs. The FlutterFire bridge's `Firebase.apps` getter reflects the Dart-registered list, not the native one, so it returns empty even though native already has `[DEFAULT]`.

When `initializeApp(options: ...)` is called with an explicit `options` parameter, the FlutterFire native bridge **does not reuse** the already-existing native app — it attempts to create a new one with the provided options, which triggers the duplicate-app error.

### 6. Are there any service/provider/repository files that also call `Firebase.initializeApp()`?

**No.** Full search across all 50+ Dart files in `lib/` confirms zero additional calls to `Firebase.initializeApp()`. The services that use Firebase (`auth_service.dart`, `firestore_service.dart`, `firestore_migration.dart`, `connect_screen.dart`, `login_screen.dart`, `splash_screen.dart`) all access Firebase singletons (`FirebaseAuth.instance`, `FirebaseFirestore.instance`, `FirebaseDatabase.instance`) and correctly assume that initialisation has already occurred.

---

## Conclusions

| Question | Finding |
|---|---|
| Number of `initializeApp()` calls | 1 in Dart (main.dart); 1 native auto-init from google-services.json = 2 total |
| `google-services.json` present? | Yes — `android/app/google-services.json`, Gradle plugin active |
| `.env` present? | Yes — all Firebase keys match google-services.json values |
| `firebase_options.dart` type | Custom `.env`-driven, not FlutterFire CLI generated |
| Native auto-init active? | Yes — `com.google.gms.google-services` plugin triggers it |
| Dart guard effective? | No — `Firebase.apps.isEmpty` is Dart-only, misses native state |

The fundamental conflict: **both `google-services.json` (native) AND `Firebase.initializeApp(options:...)` (Dart/FlutterFire) try to initialise `[DEFAULT]`**. The native one wins because it runs first, and the Dart call then fails.

---

## Recommendations

The user's requirement is: **prioritise `google-services.json` unless something cannot be obtained from it, then use hybrid (some from `.env`, some from `google-services.json`)**.

### Recommended Fix: Remove `options:` from `initializeApp()` (prioritise `google-services.json`)

`google-services.json` already contains all core Firebase fields (`api_key`, `app_id`, `messaging_sender_id`, `project_id`, `storage_bucket`). The only field in `.env` not in `google-services.json` is `FIREBASE_DATABASE_URL` and `FIREBASE_AUTH_DOMAIN`.

**For Android: call `Firebase.initializeApp()` without `options:`**

```dart
// lib/main.dart — recommended change
if (Firebase.apps.isEmpty) {
  await Firebase.initializeApp(); // no options: parameter on Android
  debugPrint('✓ Firebase initialized from google-services.json');
}
```

When called without `options:`, the FlutterFire Android plugin reads the native `[DEFAULT]` app that was already auto-initialised from `google-services.json` and returns it — no duplicate init, no crash.

**Hybrid aspect — `databaseURL` and `authDomain`:** These two values are NOT present in `google-services.json`. They ARE in `.env`. Since `firebase_database` needs `databaseURL`, one approach is:

- Keep `.env` loaded (it already is in `main.dart`).
- After calling `Firebase.initializeApp()` (no options), configure the database URL separately if needed. `FirebaseDatabase.instance` on Android uses the `databaseURL` from `google-services.json` if present — but `google-services.json` in this project does NOT contain a `database_url` field. This means `FIREBASE_DATABASE_URL` from `.env` IS necessary for Realtime Database.

**The safest hybrid fix** that satisfies the user's priority rule:

```dart
// lib/firebase_options.dart — add platform branching
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  /// On Android: returns null so initializeApp() uses google-services.json natively.
  /// On other platforms: falls back to .env values.
  static FirebaseOptions? get currentPlatformOrNull {
    if (Platform.isAndroid) return null; // let google-services.json handle it
    return _fromEnv();
  }

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
```

```dart
// lib/main.dart — updated initializeApp call
final opts = DefaultFirebaseOptions.currentPlatformOrNull;
if (Firebase.apps.isEmpty) {
  await Firebase.initializeApp(
    options: opts, // null on Android → uses google-services.json
  );
  debugPrint('✓ Firebase initialized');
}
```

> **Note:** `Firebase.initializeApp(options: null)` is equivalent to `Firebase.initializeApp()` — the FlutterFire API accepts a nullable `options` parameter.

**For `databaseURL` on Android:** Because `google-services.json` in this project does not include a `database_url` field, `FirebaseDatabase.instance` on Android will use the `.firebaseio.com` default derived from `projectId`. If `connect_screen.dart` hits issues with the database URL, the `databaseURL` from `.env` can be passed explicitly to `FirebaseDatabase.instanceFor(databaseURL: dotenv.get('FIREBASE_DATABASE_URL'))` in `connect_screen.dart` — leaving the core init clean.

### Alternative Fix: Remove `google-services.json` (pure `.env` approach)

Not recommended per user's explicit preference to prioritise `google-services.json`.

### Alternative Fix: Keep `options:` but delete `google-services.json` from the project

Not recommended — this breaks the native Gradle build and CI/CD workflow already configured in `.github/workflows/main.yml`.

### Summary of changes needed

| File | Change |
|---|---|
| `lib/firebase_options.dart` | Add `currentPlatformOrNull` getter that returns `null` on Android |
| `lib/main.dart` | Pass `options: DefaultFirebaseOptions.currentPlatformOrNull` (null on Android = use native) |
| `android/app/google-services.json` | No change — keep as authoritative source on Android |
| `.env` | No change — keep as source for `databaseURL`, `authDomain`, and non-Android fallback |

This approach:
- Eliminates the duplicate-app error on Android.
- Keeps `google-services.json` as the primary source on Android.
- Retains `.env` for `databaseURL` (hybrid, as requested) and non-Android platform fallback.
- Requires zero Gradle changes.
