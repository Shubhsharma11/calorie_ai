import 'dart:async';

import 'package:get/get.dart';


import '../bindings/home_binding.dart';
import '../controllers/auth_controller.dart';
import '../controllers/nutrition_plan_controller.dart';
import '../controllers/onboarding_setup_loading_controller.dart';
import '../controllers/onboarding_controller.dart';
import '../controllers/rewards_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../views/activity_level_view.dart';
import '../views/ai_nutrition_plan_view.dart';
import '../views/help_support_view.dart';
import '../views/add_food_view.dart';
import '../views/daily_calorie_goal_view.dart';
import '../views/daily_summary_view.dart';
import '../views/health_problem_view.dart';
import '../views/diet_preferences_view.dart';
import '../controllers/daily_summary_controller.dart';
import '../views/create_meal_view.dart';
import '../views/create_custom_food_view.dart';
import '../views/edit_meal_view.dart';
import '../views/food_details_view.dart';
import '../views/goal_amount_view.dart';
import '../views/goal_setup_view.dart';
import '../views/goal_weight_view.dart';
import '../views/my_goals_view.dart';
import '../views/settings_view.dart';
import '../views/login_view.dart';
import '../views/main_view.dart';
import '../views/nutrition_plan_loading_view.dart';
import '../views/notifications_view.dart';
import '../views/onboarding_view.dart';
import '../views/otp_verify_view.dart';

import '../views/splash_view.dart';
import '../views/personal_details_view.dart';
import '../views/personal_information_view.dart';
import '../views/progress_view.dart';
import '../views/register_view.dart';
import '../controllers/streak_controller.dart';
import '../views/streak_view.dart';
import '../views/calories_burn_view.dart';
import '../views/water_tracker_view.dart';
import '../views/weight_tracker_view.dart';
import '../views/weekly_meal_plan_view.dart';
import '../views/buddy_gifts_view.dart';
import '../views/rewards_shop_view.dart';
import '../views/invite_friends_view.dart';
import '../controllers/referral_controller.dart';
import '../core/app_page_transitions.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage<dynamic>> pages = [
    AppPageTransitions.getPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingView(),
      binding: BindingsBuilder(() => Get.lazyPut(OnboardingController.new)),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: BindingsBuilder(() => Get.lazyPut(AuthController.new)),
      // Prevent iOS swipe-back from revealing authenticated Main after logout.
      popGesture: false,
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.otpVerify,
      page: () => const OtpVerifyView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<AuthController>()) {
          Get.lazyPut(AuthController.new);
        }
      }),
    ),
   
    AppPageTransitions.getPage(
      name: AppRoutes.register,
      page: () => const RegisterView(),
      binding: BindingsBuilder(() => Get.lazyPut(AuthController.new)),
    ),
    AppPageTransitions.onboardingPage(
      name: AppRoutes.goalSetup,
      page: () => const GoalSetupView(),
    ),
    AppPageTransitions.onboardingPage(
      name: AppRoutes.goalAmount,
      page: () => const GoalAmountView(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.myGoals,
      page: () => const MyGoalsView(),
    ),
    AppPageTransitions.onboardingPage(
      name: AppRoutes.personalDetails,
      page: () => const PersonalDetailsView(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.personalInformation,
      page: () => const PersonalInformationView(),
    ),
    AppPageTransitions.onboardingPage(
      name: AppRoutes.goalWeight,
      page: () => const GoalWeightView(),
    ),
    AppPageTransitions.onboardingPage(
      name: AppRoutes.activityLevel,
      page: () => const ActivityLevelView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<UserController>()) {
          Get.put(UserController(), permanent: true);
        }
      }),
    ),
    AppPageTransitions.onboardingPage(
      name: AppRoutes.healthProblem,
      page: () => const HealthProblemView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<UserController>()) {
          Get.put(UserController(), permanent: true);
        }
      }),
    ),
    AppPageTransitions.onboardingPage(
      name: AppRoutes.dietPreferences,
      page: () => const DietPreferencesView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<UserController>()) {
          Get.put(UserController(), permanent: true);
        }
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.nutritionPlanLoading,
      page: () => const NutritionPlanLoadingView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<UserController>()) {
          Get.put(UserController(), permanent: true);
        }
        Get.lazyPut(OnboardingSetupLoadingController.new);
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.dailyCalorieGoal,
      page: () => const DailyCalorieGoalView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<UserController>()) {
          Get.put(UserController(), permanent: true);
        }
        if (!Get.isRegistered<NutritionPlanController>()) {
          Get.put(NutritionPlanController(), permanent: true);
        }
        final planController = Get.find<NutritionPlanController>();
        if (planController.plan.value == null) {
          unawaited(planController.loadPlan());
        }
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.main,
      page: () => const MainView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.addFood,
      page: () => const AddFoodView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.createMeal,
      page: () => const CreateMealView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.createCustomFood,
      page: () => const CreateCustomFoodView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.foodDetails,
      page: () => const FoodDetailsView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.editMeal,
      page: () => const EditMealView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.progress,
      page: () => const ProgressView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.waterTracker,
      page: () => const WaterTrackerView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SettingsController>()) {
          Get.put(SettingsController(), permanent: true);
        }
        if (!Get.isRegistered<TrackerController>()) {
          Get.put(TrackerController(), permanent: true);
        }
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.caloriesBurn,
      page: () => const CaloriesBurnView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<TrackerController>()) {
          Get.lazyPut(TrackerController.new);
        }
        if (!Get.isRegistered<RewardsController>()) {
          Get.put(RewardsController(), permanent: true);
        }
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.weightTracker,
      page: () => const WeightTrackerView(),
      binding: BindingsBuilder(() {
        HomeBinding().dependencies();
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<SettingsController>()) {
          Get.put(SettingsController(), permanent: true);
        }
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.notifications,
      page: () => const NotificationsView(),
      binding: BindingsBuilder(() {
        HomeBinding().dependencies();
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.buddyGifts,
      page: () => const BuddyGiftsView(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.inviteFriends,
      page: () => const InviteFriendsView(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<ReferralController>()) {
          Get.put(ReferralController());
        }
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.rewardsShop,
      page: () => const RewardsShopView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.dailySummary,
      page: () => const DailySummaryView(),
      binding: BindingsBuilder(() {
        HomeBinding().dependencies();
        Get.lazyPut(DailySummaryController.new);
      }),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.aiNutritionPlan,
      page: () => const AiNutritionPlanView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.weeklyMealPlan,
      page: () => const WeeklyMealPlanView(),
      binding: HomeBinding(),
    ),
    AppPageTransitions.getPage(
      name: AppRoutes.streak,
      page: () => const StreakView(),
      binding: BindingsBuilder(() {
        HomeBinding().dependencies();
        if (!Get.isRegistered<StreakController>()) {
          Get.put(StreakController());
        }
      }),
    ),

    AppPageTransitions.getPage(
      name: AppRoutes.helpSupport,
      page: () => const HelpSupportView(),
    ),
  ];
}
