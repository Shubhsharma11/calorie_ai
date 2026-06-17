import 'package:get/get.dart';

import '../models/daily_nutrition.dart';
import '../models/nutrition_trend_metric.dart';
import 'dashboard_controller.dart';
import 'food_controller.dart';

enum AnalyticsPeriod { day, week, month }

class AnalyticsController extends GetxController {
  final Rx<AnalyticsPeriod> period = AnalyticsPeriod.week.obs;
  final Rx<NutritionTrendMetric> trendMetric =
      NutritionTrendMetric.calories.obs;

  // Demo weight data — replace with tracker history later.
  final List<double> weightHistory = [72.0, 71.5, 71.2, 70.8, 70.5, 70.3, 70.0];

  FoodController get _food => Get.find<FoodController>();
  DashboardController get _dash => Get.find<DashboardController>();

  void setPeriod(AnalyticsPeriod value) => period.value = value;

  void setTrendMetric(NutritionTrendMetric metric) =>
      trendMetric.value = metric;

  List<DailyNutrition> get activeDays {
    return switch (period.value) {
      AnalyticsPeriod.day => [_food.nutritionForDate(DateTime.now())],
      AnalyticsPeriod.week => _food.last7Days,
      AnalyticsPeriod.month => _food.nutritionForLastDays(30),
    };
  }

  List<double> get activeValues =>
      activeDays.map((d) => d.valueFor(trendMetric.value)).toList();

  int get averageCalories {
    final days = activeDays;
    if (days.isEmpty) return 0;
    final total = days.fold(0, (sum, d) => sum + d.calories);
    return total ~/ days.length;
  }

  int get calorieGoal => _dash.calorieGoal;

  int get daysOnGoal => _dash.daysOnGoal;

  int get totalMealsLogged =>
      activeDays.fold(0, (sum, d) => sum + d.mealCount);

  String periodLabelFor(AnalyticsPeriod p) => switch (p) {
        AnalyticsPeriod.day => 'Day',
        AnalyticsPeriod.week => 'Week',
        AnalyticsPeriod.month => 'Month',
      };
}
