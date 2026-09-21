import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/nutrition_plan_controller.dart';
import '../controllers/rewards_controller.dart';
import '../controllers/scan_controller.dart';
import '../controllers/tracker_controller.dart';
import '../routes/app_routes.dart';
import 'app_log.dart';

/// Post-logout / post-delete navigation: wipe the authenticated stack and land
/// on the signed-out login route so system Back cannot reveal Main/Home.
abstract final class SignedOutNavigation {
  /// Completely replaces the navigator stack with [AppRoutes.login].
  ///
  /// Uses a zero-duration transition so Main is not left underneath during an
  /// animated push (Back mid-transition would otherwise reveal it).
  ///
  /// Disposes permanent Home-shell controllers on the next frame — deleting
  /// them synchronously while [Navigator.pushNamedAndRemoveUntil] is still
  /// processing can leave the Main route mounted.
  static void goToLoginAndClearAuthenticatedStack({
    VoidCallback? afterFrame,
  }) {
    // Overlays can keep a route from being removed cleanly on some devices.
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }

    appLog('Nav: signed-out reset → ${AppRoutes.login}');

    // Prefer a zero-duration [Get.offAll] built from the registered login page
    // so we do not import LoginView (avoids a cycle with login_view.dart).
    final loginPage = Get.routeTree.matchRoute(AppRoutes.login).route;
    final builder = loginPage?.page;
    if (builder != null) {
      Get.offAll(
        builder,
        routeName: AppRoutes.login,
        binding: loginPage?.binding,
        predicate: (_) => false,
        popGesture: false,
        transition: Transition.noTransition,
        duration: Duration.zero,
      );
    } else {
      // Fallback if the route tree is not populated yet.
      Get.offAllNamed(
        AppRoutes.login,
        predicate: (_) => false,
      );
    }

    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      disposeAuthenticatedShellControllers();
      afterFrame?.call();
    });
    // Ensure a frame runs even when called outside a pump (e.g. early tests).
    binding.ensureVisualUpdate();
  }

  /// Drop permanent Home-shell controllers registered by [HomeBinding].
  /// Keeps [UserController] / theme / notifications (app-lifetime).
  static void disposeAuthenticatedShellControllers() {
    void drop<T>() {
      if (Get.isRegistered<T>()) {
        Get.delete<T>(force: true);
      }
    }

    drop<MainController>();
    drop<FoodController>();
    drop<DashboardController>();
    drop<TrackerController>();
    drop<RewardsController>();
    drop<NutritionPlanController>();
    drop<ScanController>();
    drop<AnalyticsController>();
    // SettingsController stays — also used outside the home shell.
  }

  /// Login/register gate: never pop back into an authenticated route.
  /// Prefer exiting the app when the user presses system Back on Login.
  static Future<void> onSignedOutRootBack() async {
    appLog('Nav: signed-out root Back → SystemNavigator.pop');
    await SystemNavigator.pop();
  }
}
