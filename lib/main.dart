import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'bindings/initial_binding.dart';
import 'controllers/theme_controller.dart';
import 'controllers/user_controller.dart';
import 'core/app_page_transitions.dart';
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

  Get.put(UserController(), permanent: true);
  final userController = Get.find<UserController>();
  await userController.loadAuthSession();
  await userController.restoreOnboardingProgress();

  runApp(
    CalorieAiApp(
      initialRoute: await _resolveInitialRoute(userController),
    ),
  );
}

Future<String> _resolveInitialRoute(UserController userController) async {
  if (userController.isLoggedIn && userController.accessToken.isNotEmpty) {
    if (userController.isEmailVerified) {
      return AppRoutes.main;
    }
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

    return Obx(() {
      final themeMode = themeController.themeMode.value;
      final brightness = themeController.effectiveBrightness;
      AppColors.syncWithBrightness(brightness);

      return GetMaterialApp(
        title: 'Calorie AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        initialBinding: InitialBinding(),
        initialRoute: widget.initialRoute,
        getPages: AppPages.pages,
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

          final activeBrightness = Theme.of(context).brightness;
          AppColors.syncWithBrightness(activeBrightness);

          final mediaQuery = MediaQuery.of(context);
          final scale = mediaQuery.textScaler.scale(1).clamp(0.9, 1.25);
          return KeyedSubtree(
            key: ValueKey(activeBrightness),
            child: MediaQuery(
              data: mediaQuery.copyWith(textScaler: TextScaler.linear(scale)),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      );
    });
  }
}
