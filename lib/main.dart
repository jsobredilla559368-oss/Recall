import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/services/auth_service.dart';
import 'core/services/deck_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/ai_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/user_service.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/decks/screens/home_screen.dart';
import 'features/decks/screens/deck_detail_screen.dart';
import 'features/decks/screens/create_deck_screen.dart';
import 'features/study/study_service.dart';
import 'features/study/screens/study_session_screen.dart';
import 'features/study/screens/results_screen.dart';
import 'firebase_options.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("Notice: .env file not found or could not be loaded ($e). Using defaults.");
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
          ChangeNotifierProvider<DeckService>(create: (_) => DeckService()),
          ChangeNotifierProvider<StorageService>(create: (_) => StorageService()),
          ChangeNotifierProvider<AIService>(create: (_) => AIService()),
          ChangeNotifierProvider<StudyService>(create: (_) => StudyService()),
          ChangeNotifierProvider<UserService>(create: (_) => UserService()),
          ChangeNotifierProvider<ThemeService>.value(value: ThemeService.instance),
        ],
        child: const RecallApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('🔥 FATAL UNCAUGHT DART ERROR: $error');
    debugPrint('$stack');
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class RecallApp extends StatelessWidget {
  const RecallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Recall',
          debugShowCheckedModeBanner: false,
          theme: ThemeService.instance.themeData,
          routerConfig: _router,
        );
      },
    );
  }
}

final _router = GoRouter(
  initialLocation: '/splash',
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
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/deck/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DeckDetailScreen(deckId: id);
      },
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) => const CreateDeckScreen(),
    ),
    GoRoute(
      path: '/study/:deckId',
      builder: (context, state) {
        final id = state.pathParameters['deckId']!;
        final mode = state.uri.queryParameters['mode'] ?? 'due';
        final timerParam = state.uri.queryParameters['timer'];
        final timer = timerParam != null ? int.tryParse(timerParam) : null;
        return StudySessionScreen(deckId: id, studyMode: mode, timerDuration: timer);
      },
    ),
    GoRoute(
      path: '/study/:deckId/results',
      builder: (context, state) {
        final deckId = state.pathParameters['deckId'] ?? '';
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final mode = extra['studyMode'] as String? ?? 'due';
        return ResultsScreen(
          deckId: deckId,
          totalCards: extra['totalCards'] as int? ?? 0,
          correctCount: extra['correctCount'] as int? ?? 0,
          studyMode: mode,
        );
      },
    ),
  ],
);
