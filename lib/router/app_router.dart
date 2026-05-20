import 'package:go_router/go_router.dart';

import '../screens/analysis_detail_screen.dart';
import '../screens/athlete_detail_screen.dart';
import '../screens/athlete_form_screen.dart';
import '../screens/athletes_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/processing_screen.dart';
import '../screens/recommendation_screen.dart';
import '../screens/recording_screen.dart';
import '../screens/register_screen.dart';
import '../screens/result_screen.dart';
import '../screens/results_history_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/test_prep_screen.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/test-prep',
        builder: (context, state) => const TestPrepScreen(),
      ),
      GoRoute(
        path: '/recording',
        builder: (context, state) => const RecordingScreen(),
      ),
      GoRoute(
        path: '/processing',
        builder: (context, state) => const ProcessingScreen(),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) => const ResultScreen(),
      ),
      GoRoute(
        path: '/analysis',
        builder: (context, state) => const AnalysisDetailScreen(),
      ),
      GoRoute(
        path: '/recommendation',
        builder: (context, state) => const RecommendationScreen(),
      ),
      GoRoute(
        path: '/results-history',
        builder: (context, state) => const ResultsHistoryScreen(),
      ),
      GoRoute(
        path: '/athletes',
        builder: (context, state) => const AthletesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const AthleteFormScreen(),
          ),
          GoRoute(
            path: ':athleteId',
            builder: (context, state) {
              final id = state.pathParameters['athleteId']!;
              return AthleteDetailScreen(athleteId: id);
            },
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final id = state.pathParameters['athleteId']!;
                  return AthleteFormScreen(athleteId: id);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
