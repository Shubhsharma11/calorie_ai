import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'services/firebase_messaging_background.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the native launch screen up while startup finishes — no second
  // Flutter splash with the same FitBuddy logo.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  Get.put(ThemeController(), permanent: true);
  Get.put(SettingsController(), permanent: true);
  Get.put(UserController(), permanent: true);

  final initialRoute = await _resolveInitialRoute();
  runApp(FitBuddyAiApp(initialRoute: initialRoute));
}

Future<String> _resolveInitialRoute() async {
  final theme = Get.find<ThemeController>();
  final settings = Get.find<SettingsController>();
  final user = Get.find<UserController>();

  // Restore auth from disk only — never block launch on network/profile.
  try {
    await LocalStorageService().wipeLegacyApiCachesIfNeeded();
    await user.loadAuthSession();
  } catch (error, stackTrace) {
    debugPrint('Startup auth restore failed: $error\n$stackTrace');
  }

  // Side inits can finish after first frame; cap wait so splash never sticks.
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

    // Route from persisted session; profile continues hydrating in background.
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
      navigatorObservers: [appRouteObserver],
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
