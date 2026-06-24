## Context
The user wants to rename the project from "Sprintify" to "T-Smart". This involves updating occurrences of the name in various files, including code, configuration, and project files for both Android and iOS.

## Plan

1.  **Rename `SprintifyApp` and `_SprintifyAppState` to `TSmartApp` and `_TSmartAppState` in `lib/app.dart`.**
2.  **Rename `SprintifyState` to `TSmartState` in `lib/providers/sprintify_state.dart` and update its usages.**
3.  **Update `lib/main.dart` to use `TSmartApp` and `TSmartState`.**
4.  **Update usages of `SprintifyState` in various screens and services.**
    *   `lib/screens/analysis_detail_screen.dart`
    *   `lib/screens/athlete_detail_screen.dart`
    *   `lib/screens/athlete_form_screen.dart`
    *   `lib/screens/athletes_screen.dart`
    *   `lib/screens/dashboard_screen.dart`
    *   `lib/screens/processing_screen.dart`
    *   `lib/screens/recommendation_screen.dart`
    *   `lib/screens/recording_screen.dart`
    *   `lib/screens/result_screen.dart`
    *   `lib/screens/results_history_screen.dart`
    *   `lib/screens/test_prep_screen.dart`
    *   `lib/services/analysis/frame_extractor.dart`
5.  **Rename `SprintifyLogo` to `TSmartLogo` in `lib/widgets/sprintify_logo.dart` and update its usages.**
    *   `lib/screens/login_screen.dart`
    *   `lib/screens/splash_screen.dart`
6.  **Rename the `sprintify` package directory in `android/app/src/main/kotlin/com/example/sprintify` to `t_smart`.**
7.  **Update the application name in `android/app/src/main/AndroidManifest.xml` and `android/app/src/main/res/values/styles.xml` (if applicable).**
8.  **Update the bundle identifier and product name in `ios/Runner/Info.plist` and `ios/Runner.xcodeproj/project.pbxproj`.**
9.  **Update the project description in `pubspec.yaml`.**
10. **Update `ABOUT.md`.**
11. **Update `test/widget_test.dart`.**

## Verification
1.  Run `flutter clean` and `flutter pub get`.
2.  Run the application on both Android and iOS to ensure it builds and runs correctly.
3.  Verify that the application name displayed is "T-Smart".
4.  Verify all functionalities (e.g., recording, analysis) still work as expected.
5.  Run `grep -r "Sprintify" .` again to ensure no occurrences remain.