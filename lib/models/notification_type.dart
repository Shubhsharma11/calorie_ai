import '../routes/app_routes.dart';

/// Supported push notification categories for Fit Buddy AI.
enum NotificationType {
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
    for (final type in NotificationType.values) {
      if (type.value == raw) return type;
    }
    return NotificationType.unknown;
  }

  static NotificationType fromData(Map<String, dynamic> data) {
    return fromValue(
      data['type'] as String? ??
          data['notification_type'] as String? ??
          data['category'] as String?,
    );
  }

  String get route {
    switch (this) {
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
        return 'General Fit Buddy AI notifications';
    }
  }
}
