import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'bindings/initial_binding.dart';
import 'controllers/settings_controller.dart';
import 'controllers/theme_controller.dart';
import 'controllers/user_controller.dart';
import 'core/app_page_transitions.dart';
import 'core/app_route_observer.dart';
import 'firebase_options.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'services/analytics_service.dart';
import 'services/firebase_messaging_background.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One splash only: native launch screen stays up while startup finishes,
  // then we open the real first screen (no second Flutter splash).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await AnalyticsService.initialize();

  // Catch Flutter framework errors.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Catch async / platform errors outside Flutter's zone.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  final startupTrace = FirebasePerformance.instance.newTrace('app_startup');
  await startupTrace.start();

  try {
    await AnalyticsService.logAppOpen();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    Get.put(ThemeController(), permanent: true);
    Get.put(SettingsController(), permanent: true);
    Get.put(UserController(), permanent: true);

    final initialRoute = await _resolveInitialRoute();
    runApp(FitBuddyAiApp(initialRoute: initialRoute));
  } finally {
    await startupTrace.stop();
  }
}

Future<String> _resolveInitialRoute() async {
  final theme = Get.find<ThemeController>();
  final settings = Get.find<SettingsController>();
  final user = Get.find<UserController>();

  try {
    await LocalStorageService().wipeLegacyApiCachesIfNeeded();
    await user.loadAuthSession();
    if (user.isLoggedIn) {
      await AnalyticsService.setUser(
        userId: user.userId.isEmpty ? null : user.userId,
        email: user.user.email,
        name: user.user.name,
        provider: user.authProvider,
      );
    }
  } catch (error, stackTrace) {
    debugPrint('Startup auth restore failed: $error\n$stackTrace');
    await AnalyticsService.recordError(
      error,
      stackTrace,
      reason: 'startup_auth_restore',
    );
  }

  await Future.any<void>([
    Future.wait<void>([
      _ignoreInitErrors(theme.loadTheme(), 'theme'),
      _ignoreInitErrors(settings.settingsReady, 'settings'),
    ]),
    Future<void>.delayed(const Duration(seconds: 2)),
  ]);

  unawaited(
    _ignoreInitErrors(
      NotificationService.instance.initialize(),
      'notifications',
    ),
  );
  unawaited(
    _ignoreInitErrors(
      GoogleSignIn.instance.initialize(
        serverClientId:
            '950645223660-73fq24ua6hn9h7u92bc9nhtg22rjag1d.apps.googleusercontent.com',
      ),
      'google_sign_in',
    ),
  );

  if (user.isLoggedIn && user.accessToken.isNotEmpty) {
    unawaited(
      NotificationService.instance.syncTokenWithBackend(
        accessToken: user.accessToken,
      ),
    );
    try {
      await LocalStorageService().saveWelcomeIntroSeen(seen: true);
    } catch (_) {}
    return user.resolveSetupResumeRoute();
  }

  try {
    if (await LocalStorageService().isWelcomeIntroSeen()) {
      return AppRoutes.login;
    }
  } catch (_) {}
  return AppRoutes.onboarding;
}

Future<void> _ignoreInitErrors(Future<void> future, String label) async {
  try {
    await future;
  } catch (error, stackTrace) {
    debugPrint('Startup $label init failed: $error\n$stackTrace');
    await AnalyticsService.recordError(
      error,
      stackTrace,
      reason: 'startup_$label',
    );
  }
}

class FitBuddyAiApp extends StatefulWidget {
  const FitBuddyAiApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  State<FitBuddyAiApp> createState() => _FitBuddyAiAppState();
}

class _FitBuddyAiAppState extends State<FitBuddyAiApp> {
  bool _handledLaunchNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AnalyticsService.logScreenView(widget.initialRoute));
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    AppColors.syncWithBrightness(themeController.effectiveBrightness);

    return GetMaterialApp(
      title: 'FitBuddy AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      initialBinding: InitialBinding(),
      initialRoute: widget.initialRoute,
      getPages: AppPages.pages,
      navigatorObservers: [
        appRouteObserver,
        ...AnalyticsService.navigatorObservers,
      ],
      defaultTransition: AppPageTransitions.transition,
      transitionDuration: AppPageTransitions.duration,
      builder: (context, child) {
        if (!_handledLaunchNotification) {
          _handledLaunchNotification = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (NotificationService.instance.isInitialized) {
              NotificationService.instance.handlePendingLaunchNavigation();
            }
          });
        }

        return Obx(() {
          final theme = Get.find<ThemeController>();
          final brightness = theme.appliedBrightness.value;
          AppColors.syncWithBrightness(brightness);
          return Theme(
            data: brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light,
            child: child ?? const SizedBox.shrink(),
          );
        });
      },
    );
  }
}
