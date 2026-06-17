import 'package:get/get.dart';

import '../bindings/home_binding.dart';
import '../controllers/auth_controller.dart';
import '../controllers/onboarding_controller.dart';
import '../controllers/analytics_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/tracker_controller.dart';
import '../views/activity_level_view.dart';
import '../views/help_support_view.dart';
import '../views/add_food_view.dart';
import '../views/daily_calorie_goal_view.dart';
import '../views/daily_summary_view.dart';
import '../controllers/daily_summary_controller.dart';
import '../views/edit_meal_view.dart';
import '../views/food_details_view.dart';
import '../views/goal_setup_view.dart';
import '../views/goal_weight_view.dart';
import '../views/my_goals_view.dart';
import '../views/settings_view.dart';
import '../views/login_view.dart';
import '../views/main_view.dart';
import '../views/onboarding_view.dart';
import '../views/personal_details_view.dart';
import '../views/progress_view.dart';
import '../views/register_view.dart';
import '../controllers/streak_controller.dart';
import '../views/splash_view.dart';
import '../views/streak_view.dart';
import '../views/water_tracker_view.dart';
import '../views/weight_tracker_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage<dynamic>> pages = [
    GetPage(name: AppRoutes.splash, page: () => const SplashView()),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingView(),
      binding: BindingsBuilder(
        () => Get.lazyPut(OnboardingController.new),
      ),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: BindingsBuilder(() => Get.lazyPut(AuthController.new)),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterView(),
      binding: BindingsBuilder(() => Get.lazyPut(AuthController.new)),
    ),
    GetPage(name: AppRoutes.goalSetup, page: () => const GoalSetupView()),
    GetPage(name: AppRoutes.myGoals, page: () => const MyGoalsView()),
    GetPage(
      name: AppRoutes.personalDetails,
      page: () => const PersonalDetailsView(),
    ),
    GetPage(
      name: AppRoutes.goalWeight,
      page: () => const GoalWeightView(),
    ),
    GetPage(
      name: AppRoutes.activityLevel,
      page: () => const ActivityLevelView(),
    ),
    GetPage(
      name: AppRoutes.dailyCalorieGoal,
      page: () => const DailyCalorieGoalView(),
    ),
    GetPage(
      name: AppRoutes.main,
      page: () => const MainView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.addFood,
      page: () => const AddFoodView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.foodDetails,
      page: () => const FoodDetailsView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.editMeal,
      page: () => const EditMealView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.progress,
      page: () => const ProgressView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.waterTracker,
      page: () => const WaterTrackerView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<TrackerController>()) {
          Get.lazyPut(TrackerController.new);
        }
      }),
    ),
    GetPage(
      name: AppRoutes.weightTracker,
      page: () => const WeightTrackerView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<TrackerController>()) {
          Get.lazyPut(TrackerController.new);
        }
        if (!Get.isRegistered<AnalyticsController>()) {
          Get.lazyPut(AnalyticsController.new);
        }
      }),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      binding: BindingsBuilder(() => Get.lazyPut(SettingsController.new)),
    ),
    GetPage(
      name: AppRoutes.dailySummary,
      page: () => const DailySummaryView(),
      binding: BindingsBuilder(() {
        HomeBinding().dependencies();
        Get.lazyPut(DailySummaryController.new);
      }),
    ),
    GetPage(
      name: AppRoutes.streak,
      page: () => const StreakView(),
      binding: BindingsBuilder(() {
        HomeBinding().dependencies();
        if (!Get.isRegistered<StreakController>()) {
          Get.put(StreakController());
        }
      }),
    ),
    GetPage(name: AppRoutes.helpSupport, page: () => const HelpSupportView()),
  ];
}
