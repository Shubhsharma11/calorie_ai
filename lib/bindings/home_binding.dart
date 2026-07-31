import 'package:get/get.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../controllers/nutrition_plan_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/notifications_controller.dart';
import '../controllers/scan_controller.dart';
import '../controllers/settings_controller.dart';
// import '../controllers/streak_controller.dart';
import '../controllers/tracker_controller.dart';

/// Registers controllers for the main app shell (tabs + features).
class HomeBinding extends Bindings {  
  @override
  void dependencies() {
    if (!Get.isRegistered<MainController>()) {
      Get.put(MainController(), permanent: true);
    }
    if (!Get.isRegistered<FoodController>()) {
      Get.put(FoodController(), permanent: true);
    }

    // Streak temporarily disabled on home.
    // if (!Get.isRegistered<StreakController>()) {
    //   Get.put(StreakController(), permanent: true);
    // }
  
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController(), permanent: true);
    }
    if (!Get.isRegistered<ScanController>()) {
      Get.put(ScanController());
    }
    if (!Get.isRegistered<AnalyticsController>()) {
      Get.put(AnalyticsController());
    }
    if (!Get.isRegistered<SettingsController>()) {
      Get.put(SettingsController(), permanent: true);
    }
    if (!Get.isRegistered<TrackerController>()) {
      // Weight is hydrated from GET /api/v1/weight — not local profile defaults.
      Get.put(TrackerController(), permanent: true);
    }
    if (!Get.isRegistered<NutritionPlanController>()) {
      Get.put(NutritionPlanController(), permanent: true);
    }
    if (!Get.isRegistered<NotificationsController>()) {
      Get.put(NotificationsController(), permanent: true);
    }
  }
}
