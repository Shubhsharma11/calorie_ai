import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'services/notification_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationService.instance.initialize();

  await GoogleSignIn.instance.initialize(
    serverClientId:
        '950645223660-73fq24ua6hn9h7u92bc9nhtg22rjag1d.apps.googleusercontent.com',
  );

  Get.put(ThemeController(), permanent: true);
  await Get.find<ThemeController>().loadTheme();

  Get.put(SettingsController(), permanent: true);
  await Get.find<SettingsController>().settingsReady;
  Get.put(UserController(), permanent: true);
  final userController = Get.find<UserController>();
  await userController.loadAuthSession();
  await userController.restoreOnboardingProgress();

  // One FCM upload on cold start when already signed in.
  // Login path also syncs once via UserController.saveGoogleLoginDetails.
  if (userController.isLoggedIn && userController.accessToken.isNotEmpty) {
    unawaited(
      NotificationService.instance.syncTokenWithBackend(
        accessToken: userController.accessToken,
      ),
    );
  }

  runApp(
    CalorieAiApp(
      initialRoute: await _resolveInitialRoute(userController),
    ),
  );
}

Future<String> _resolveInitialRoute(UserController userController) async {
  if (userController.isLoggedIn && userController.accessToken.isNotEmpty) {
    return userController.resolveSetupResumeRoute();
  }
  return AppRoutes.onboarding;
}

class CalorieAiApp extends StatefulWidget {
  const CalorieAiApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  State<CalorieAiApp> createState() => _CalorieAiAppState();
}

class _CalorieAiAppState extends State<CalorieAiApp> {
  bool _handledLaunchNotification = false;

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    AppColors.syncWithBrightness(themeController.effectiveBrightness);

    // Do not wrap GetMaterialApp in Obx — recreating it rebuilds Get.key and
    // can crash with Duplicate GlobalKeys. Theme is applied in [builder]
    // instead (see below), without Get.changeThemeMode / AnimatedTheme.
    return GetMaterialApp(
      title: 'Fit Buddy AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // themeMode is owned by ThemeController and applied in [builder].
      // Keeping MaterialApp on light avoids GetX AnimatedTheme lerps.
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

        // Listens to [appliedBrightness] so Appearance toggles update the
        // navigator Theme immediately (tabs stay frozen while Settings is open).
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
