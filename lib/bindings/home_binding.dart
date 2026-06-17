import 'package:get/get.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/scan_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/streak_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';

/// Registers controllers for the main app shell (tabs + features).
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MainController>()) {
      Get.put(MainController());
    }
    if (!Get.isRegistered<FoodController>()) {
      Get.put(FoodController());
    }
    if (!Get.isRegistered<StreakController>()) {
      Get.put(StreakController());
    }
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController());
    }
    if (!Get.isRegistered<ScanController>()) {
      Get.put(ScanController());
    }
    if (!Get.isRegistered<AnalyticsController>()) {
      Get.put(AnalyticsController());
    }
    if (!Get.isRegistered<TrackerController>()) {
      final weight = Get.isRegistered<UserController>()
          ? Get.find<UserController>().user.weightKg.toDouble()
          : null;
      Get.put(TrackerController(initialWeight: weight));
    }
    if (!Get.isRegistered<SettingsController>()) {
      Get.lazyPut(SettingsController.new);
    }
  }
}
