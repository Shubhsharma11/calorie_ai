import '../models/meal_type.dart';
import '../routes/app_routes.dart';

/// Supported push notification categories for MyCaloriePal.
enum NotificationType {
  mealReminder('meal_reminder'),
  breakfastReminder('breakfast_reminder'),
  lunchReminder('lunch_reminder'),
  dinnerReminder('dinner_reminder'),
  waterReminder('water_reminder'),
  workoutReminder('workout_reminder'),
  dailyStreakReminder('daily_streak_reminder'),
  goalAchieved('goal_achieved'),
  weeklyReport('weekly_report'),
  weightReminder('weight_reminder'),
  aiNutritionTips('ai_nutrition_tips'),
  motivational('motivational'),
  unknown('unknown');

  const NotificationType(this.value);

  final String value;

  static NotificationType fromValue(String? raw) {
    if (raw == null || raw.isEmpty) return NotificationType.unknown;
    final normalized = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    for (final type in NotificationType.values) {
      if (type.value == normalized) return type;
    }
    switch (normalized) {
      case 'lunch':
      case 'lunchtime':
      case 'lunch_time':
        return NotificationType.lunchReminder;
      case 'breakfast':
      case 'breakfasttime':
      case 'breakfast_time':
        return NotificationType.breakfastReminder;
      case 'dinner':
      case 'dinnertime':
      case 'dinner_time':
        return NotificationType.dinnerReminder;
      case 'meal':
        return NotificationType.mealReminder;
      default:
        return NotificationType.unknown;
    }
  }

  static NotificationType fromData(Map<String, dynamic> data) {
    return fromValue(
      _stringFrom(data, const [
        'type',
        'notification_type',
        'notificationType',
        'category',
      ]),
    );
  }

  /// Resolves type from payload fields, meal slot, or title/body text.
  static NotificationType resolve({
    String? type,
    String? title,
    String? body,
    Map<String, dynamic> data = const {},
  }) {
    var parsed = fromValue(type);
    if (parsed == NotificationType.unknown) {
      parsed = fromData(data);
    }

    if (parsed == NotificationType.lunchReminder ||
        parsed == NotificationType.breakfastReminder ||
        parsed == NotificationType.dinnerReminder) {
      return parsed;
    }

    final canInferMeal = parsed == NotificationType.unknown ||
        parsed == NotificationType.mealReminder;
    if (canInferMeal) {
      final inferred = inferMealReminder(
        title: title,
        body: body,
        data: data,
      );
      if (inferred != null) return inferred;
    }

    return parsed;
  }

  static NotificationType? inferMealReminder({
    String? title,
    String? body,
    Map<String, dynamic> data = const {},
  }) {
    final meal = _stringFrom(data, const [
      'mealTime',
      'meal_time',
      'mealtime',
      'meal',
    ])?.toLowerCase();
    switch (meal) {
      case 'lunch':
        return NotificationType.lunchReminder;
      case 'breakfast':
        return NotificationType.breakfastReminder;
      case 'dinner':
        return NotificationType.dinnerReminder;
    }

    final haystack = '${title ?? ''} ${body ?? ''}'.toLowerCase();
    if (haystack.contains('lunch')) return NotificationType.lunchReminder;
    if (haystack.contains('breakfast')) {
      return NotificationType.breakfastReminder;
    }
    if (haystack.contains('dinner')) return NotificationType.dinnerReminder;
    return null;
  }

  static String? _stringFrom(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String routeForMealTime(String? mealTime) {
    switch (mealTime?.toLowerCase()) {
      case 'breakfast':
      case 'lunch':
      case 'dinner':
      case 'snack':
        return AppRoutes.addFood;
      default:
        return AppRoutes.addFood;
    }
  }

  /// Meal slot to pre-select when opening Add Food from this notification.
  String? get targetMeal {
    switch (this) {
      case NotificationType.breakfastReminder:
        return MealType.breakfast;
      case NotificationType.lunchReminder:
        return MealType.lunch;
      case NotificationType.dinnerReminder:
        return MealType.dinner;
      case NotificationType.mealReminder:
      default:
        return null;
    }
  }

  static String? mealFromData(Map<String, dynamic> data) {
    return mealFromMealTime(
      _stringFrom(data, const [
        'mealTime',
        'meal_time',
        'mealtime',
        'meal',
      ]),
    );
  }

  static String? mealFromMealTime(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
      case 'snacks':
        return MealType.snacks;
      default:
        return null;
    }
  }

  String get route {
    switch (this) {
      case NotificationType.mealReminder:
      case NotificationType.breakfastReminder:
      case NotificationType.lunchReminder:
      case NotificationType.dinnerReminder:
        return AppRoutes.addFood;
      case NotificationType.waterReminder:
        return AppRoutes.waterTracker;
      case NotificationType.workoutReminder:
        return AppRoutes.caloriesBurn;
      case NotificationType.dailyStreakReminder:
        return AppRoutes.streak;
      case NotificationType.goalAchieved:
        return AppRoutes.dailySummary;
      case NotificationType.weeklyReport:
        return AppRoutes.progress;
      case NotificationType.weightReminder:
        return AppRoutes.weightTracker;
      case NotificationType.aiNutritionTips:
        return AppRoutes.aiNutritionPlan;
      case NotificationType.motivational:
        return AppRoutes.main;
      case NotificationType.unknown:
        return AppRoutes.notifications;
    }
  }

  String get channelId {
    switch (this) {
      case NotificationType.mealReminder:
      case NotificationType.breakfastReminder:
      case NotificationType.lunchReminder:
      case NotificationType.dinnerReminder:
        return 'calorie_ai_meals';
      case NotificationType.waterReminder:
        return 'calorie_ai_water';
      case NotificationType.workoutReminder:
        return 'calorie_ai_fitness';
      case NotificationType.dailyStreakReminder:
      case NotificationType.goalAchieved:
        return 'calorie_ai_goals';
      case NotificationType.weeklyReport:
        return 'calorie_ai_reports';
      case NotificationType.weightReminder:
        return 'calorie_ai_weight';
      case NotificationType.aiNutritionTips:
        return 'calorie_ai_ai_tips';
      case NotificationType.motivational:
      case NotificationType.unknown:
        return 'calorie_ai_general';
    }
  }

  String get channelName {
    switch (this) {
      case NotificationType.mealReminder:
      case NotificationType.breakfastReminder:
      case NotificationType.lunchReminder:
      case NotificationType.dinnerReminder:
        return 'Meal Reminders';
      case NotificationType.waterReminder:
        return 'Water Reminders';
      case NotificationType.workoutReminder:
        return 'Workout Reminders';
      case NotificationType.dailyStreakReminder:
      case NotificationType.goalAchieved:
        return 'Goals & Streaks';
      case NotificationType.weeklyReport:
        return 'Weekly Reports';
      case NotificationType.weightReminder:
        return 'Weight Reminders';
      case NotificationType.aiNutritionTips:
        return 'AI Nutrition Tips';
      case NotificationType.motivational:
        return 'Motivation';
      case NotificationType.unknown:
        return 'General';
    }
  }

  String get channelDescription {
    switch (this) {
      case NotificationType.mealReminder:
      case NotificationType.breakfastReminder:
      case NotificationType.lunchReminder:
      case NotificationType.dinnerReminder:
        return 'Breakfast, lunch, and dinner logging reminders';
      case NotificationType.waterReminder:
        return 'Hydration reminders throughout the day';
      case NotificationType.workoutReminder:
        return 'Workout and activity reminders';
      case NotificationType.dailyStreakReminder:
      case NotificationType.goalAchieved:
        return 'Streak updates and goal achievements';
      case NotificationType.weeklyReport:
        return 'Weekly nutrition and progress summaries';
      case NotificationType.weightReminder:
        return 'Weight tracking reminders';
      case NotificationType.aiNutritionTips:
        return 'Personalized AI nutrition suggestions';
      case NotificationType.motivational:
        return 'Daily motivational messages';
      case NotificationType.unknown:
        return 'General MyCaloriePal notifications';
    }
  }
}
