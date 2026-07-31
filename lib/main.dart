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
  try {
    final theme = Get.find<ThemeController>();
    final settings = Get.find<SettingsController>();
    final user = Get.find<UserController>();

    await Future.wait<void>([
      theme.loadTheme(),
      settings.settingsReady,
      NotificationService.instance.initialize(),
      GoogleSignIn.instance.initialize(
        serverClientId:
            '950645223660-73fq24ua6hn9h7u92bc9nhtg22rjag1d.apps.googleusercontent.com',
      ),
      () async {
        await LocalStorageService().wipeLegacyApiCachesIfNeeded();
        await user.loadAuthSession();
        await user.restoreOnboardingProgress();
      }(),
    ]);

    if (user.isLoggedIn && user.accessToken.isNotEmpty) {
      unawaited(
        NotificationService.instance.syncTokenWithBackend(
          accessToken: user.accessToken,
        ),
      );
      // Returning users should never see welcome slides again after logout.
      await LocalStorageService().saveWelcomeIntroSeen(seen: true);
      return user.resolveSetupResumeRoute();
    }

    if (await LocalStorageService().isWelcomeIntroSeen()) {
      return AppRoutes.login;
    }
    return AppRoutes.onboarding;
  } catch (_) {
    // Still open the app; screens handle their own errors.
    return AppRoutes.login;
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
