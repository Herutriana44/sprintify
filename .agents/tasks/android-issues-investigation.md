# Android Issues Investigation Report
**Project:** sprintify (t_smart)  
**Flutter:** 3.47.8 (stable) · Dart 3.13.7  
**Date:** Investigation run against current working tree

---

## Summary Answers

| # | Question | Answer |
|---|----------|--------|
| 1 | Kotlin version | `2.2.20` — in `android/settings.gradle.kts` plugins block |
| 2 | app/build.gradle.kts manually applies KGP? | Yes — `id("kotlin-android")` is listed explicitly |
| 3 | Gradle wrapper version | `9.3.1` (gradle-wrapper.properties) |
| 4 | camera_android_camerax version | `0.7.1+2` (transitive via `camera: ^0.12.0+1`) |
| 5 | main.dart startup | Loads `.env` → initialises Firebase → runs app |
| 6 | Root cause of force close | **`FIREBASE_DATABASE_URL` key is missing from `.env`** — Firebase Realtime Database initialises with an empty `databaseURL`, which causes a fatal crash at runtime |
| 7 | Fixes needed | See Recommendations section below |

---

## Evidence

### 1. Kotlin version — `android/settings.gradle.kts`

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false   // ← 2.2.20
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

Flutter 3.47 requires Kotlin ≥ 2.3.20. The current version `2.2.20` triggers the first build warning.

Note: `android/settings.gradle` does **not** exist; only `settings.gradle.kts` is present.

---

### 2. Manual KGP application — `android/app/build.gradle.kts`

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")                         // ← explicit KGP application
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
```

Flutter 3.47 warns that applying `kotlin-android` (KGP) manually is deprecated and will become a build failure in a future Flutter version. The migration path is to remove this explicit apply and rely on Flutter's built-in Kotlin support.

---

### 3. Gradle wrapper — `android/gradle/wrapper/gradle-wrapper.properties`

```
distributionUrl=https\://services.gradle.org/distributions/gradle-9.3.1-all.zip
```

Gradle 9.3.1 is modern and not itself a problem.

---

### 4. `gradle.properties` — `android/gradle.properties`

```
android.builtInKotlin=false
android.newDsl=false
```

The Flutter migrator already ran and set these compatibility flags. They suppress the immediate build failure but are not the final state — these flags need to be flipped to `true` once KGP is fully removed.

---

### 5. `camera_android_camerax` — version `0.7.1+2`

Resolved in `pubspec.lock` as a transitive dependency of `camera: ^0.12.0+1`. Flutter's build checker detects that this plugin version still applies KGP internally, generating the third build warning. This is not a code issue the app author can fix directly — it requires upgrading the `camera` package to a version whose underlying `camera_android_camerax` has been migrated to built-in Kotlin.

---

### 6. Force-close root cause — missing `FIREBASE_DATABASE_URL` in `.env`

**`firebase_options.dart`** reads all Firebase config from `.env` via `flutter_dotenv`:

```dart
databaseURL: dotenv.get('FIREBASE_DATABASE_URL', fallback: ''),
```

The `fallback: ''` silently passes an **empty string** as the `databaseURL` to `FirebaseOptions`. The app declares `firebase_database: ^11.3.10` as a direct dependency, which means `FirebaseDatabase.instance` is referenced and it will attempt to connect to the URL at runtime.

**`.env` keys present (8 total):**
```
GEMINI_API_KEY
GEMINI_MODEL_ID
FIREBASE_API_KEY
FIREBASE_APP_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_PROJECT_ID
FIREBASE_AUTH_DOMAIN
FIREBASE_STORAGE_BUCKET
```

**`FIREBASE_DATABASE_URL` is absent.** The `fallback: ''` masks the missing key at load time, but when the Firebase Realtime Database SDK tries to use an empty URL it throws a fatal error:

> `FIREBASE FATAL ERROR: Cannot parse Firebase url. Please use https://<YOUR FIREBASE>.firebaseio.com`

This is an unhandled exception outside the `try/catch` in `main()` — the Firebase init itself succeeds (since `FirebaseOptions` only stores the value), but any code that actually accesses `FirebaseDatabase.instance` will crash the app hard.

Additionally, `google-services.json` is present in `android/app/` (confirmed `True`) and its `package_name` matches the app's `applicationId` (`com.example.t_smart`), so that is **not** a problem.

---

### 7. `tflite_flutter` — pinned to git HEAD

```yaml
tflite_flutter:
  git:
    url: https://github.com/tensorflow/flutter-tflite.git
```

`pubspec.lock` resolves this to commit `85fb92ecea445b1949da35b35b92b0792c29ddba`. This is a floating HEAD reference, meaning every cold `pub get` can pull a different commit. This is a latent risk but not the current crash cause.

---

### 8. AndroidManifest.xml — no issues found

All required permissions are declared:
- `CAMERA`, `RECORD_AUDIO`, `INTERNET` (unrestricted)
- `WRITE_EXTERNAL_STORAGE` / `READ_EXTERNAL_STORAGE` (capped at API 28/32)
- `READ_MEDIA_VIDEO`, `READ_MEDIA_IMAGES` (API 33+)

No missing permissions relative to the declared plugins.

---

## Root Cause Summary

**Force close:** `FIREBASE_DATABASE_URL` is not in `.env`. The `fallback: ''` in `firebase_options.dart` hides the error at load time but passes an invalid empty URL to the Firebase Realtime Database SDK, causing a fatal crash when any database reference is first used.

**Build warnings (3):** All stem from the same underlying issue — the Kotlin/KGP migration is incomplete:
1. `settings.gradle.kts` pins Kotlin to `2.2.20` (need ≥ 2.3.20)
2. `app/build.gradle.kts` explicitly applies `id("kotlin-android")` (need to remove, rely on built-in Kotlin)
3. `camera_android_camerax 0.7.1+2` still applies KGP internally (need newer `camera` package version)

---

## Recommendations (do not implement here)

### Fix 1 — Force close: Add `FIREBASE_DATABASE_URL` to `.env`

Add the missing key to `.env`:
```
FIREBASE_DATABASE_URL=https://<your-project-id>-default-rtdb.firebaseio.com
```

The actual URL is in the Firebase Console → Realtime Database → copy the database URL. It should match `project_id: t-smart-65ff1`, so the URL is likely `https://t-smart-65ff1-default-rtdb.firebaseio.com` (or a regional variant like `-default-rtdb.asia-southeast1.firebaseio.com`).

**Also harden `firebase_options.dart`:** Change the `databaseURL` fallback from `''` to a loud failure — either throw or assert — so a missing key is caught at startup rather than silently passed through:

```dart
// Before (silent failure):
databaseURL: dotenv.get('FIREBASE_DATABASE_URL', fallback: ''),

// After (fail fast):
databaseURL: dotenv.get('FIREBASE_DATABASE_URL'),  // throws if missing
```

### Fix 2 — Kotlin version warning: Bump Kotlin to 2.3.20+

In `android/settings.gradle.kts`, change:
```kotlin
id("org.jetbrains.kotlin.android") version "2.2.20" apply false
```
to:
```kotlin
id("org.jetbrains.kotlin.android") version "2.3.20" apply false
```

### Fix 3 — KGP migration warning: Remove explicit `kotlin-android` from app

In `android/app/build.gradle.kts`, remove the line:
```kotlin
id("kotlin-android")
```

`gradle.properties` already has `android.builtInKotlin=false` so removing the explicit apply is safe right now. Once `camera_android_camerax` is also migrated (Fix 4), flip that flag to `true`.

### Fix 4 — camera_android_camerax KGP warning: Upgrade `camera` package

Check the latest `camera` version on pub.dev. Version `0.12.0+1` resolves `camera_android_camerax 0.7.1+2` which still applies KGP. Upgrade to a newer minor/patch that resolves a `camera_android_camerax` version with built-in Kotlin support. Run `flutter pub upgrade camera` and verify the resolved `camera_android_camerax` version in `pubspec.lock`.

### Fix 5 (optional risk reduction) — Pin `tflite_flutter` to a specific commit

Change the git dependency to use `ref: "<commit-sha>"` instead of floating HEAD to ensure reproducible builds.

---

## Priority Order

1. **[CRITICAL]** Fix 1 — Add `FIREBASE_DATABASE_URL` to `.env` (this is the force close)
2. **[HIGH]** Fix 2 — Bump Kotlin to 2.3.20 (removes first warning, required before it becomes an error)
3. **[HIGH]** Fix 3 — Remove `id("kotlin-android")` from app/build.gradle.kts (removes second warning)
4. **[MEDIUM]** Fix 4 — Upgrade `camera` package for camerax KGP warning (third-party; may need to wait for plugin release)
5. **[LOW]** Fix 5 — Pin tflite_flutter to a specific git commit
