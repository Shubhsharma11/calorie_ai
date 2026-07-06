class NutritionPlanMeal {
  const NutritionPlanMeal({
    required this.title,
    required this.calories,
    required this.items,
  });

  final String title;
  final int calories;
  final List<String> items;

  factory NutritionPlanMeal.fromJson(Map<String, dynamic> json) {
    return NutritionPlanMeal(
      title: _readString(json, const ['title', 'type', 'name', 'meal']) ?? 'Meal',
      calories: _readInt(json, const ['calories', 'kcal', 'calorieGoal']) ?? 0,
      items: _readStringList(json, const ['items', 'foods', 'foodItems']),
    );
  }
}

class NutritionPlanModel {
  const NutritionPlanModel({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.meals,
    required this.foodsToAvoid,
    required this.tips,
    this.summary,
    this.targetWeightKg,
    this.bmr,
    this.tdee,
  });

  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final List<NutritionPlanMeal> meals;
  final List<String> foodsToAvoid;
  final List<String> tips;
  final String? summary;
  final double? targetWeightKg;
  final int? bmr;
  final int? tdee;

  factory NutritionPlanModel.fromJson(Map<String, dynamic> json) {
    final data = _unwrapData(json);
    final nutritionPlan =
        _firstMap(data, const ['nutritionPlan', 'nutrition_plan']) ?? data;
    final plan = _firstMap(nutritionPlan, const ['plan']) ?? nutritionPlan;
    final macros = _firstMap(plan, const ['macros']) ?? plan;

    return NutritionPlanModel(
      calories:
          _readInt(plan, const [
                'dailyCalories',
                'dailyCalorieGoal',
                'calories',
                'calorieGoal',
                'recommendedCalories',
              ]) ??
          _readInt(macros, const ['calories', 'dailyCalories']) ??
          0,
      proteinG:
          _readInt(macros, const ['proteinG', 'proteinGoalG', 'protein']) ??
          _readInt(plan, const ['proteinG', 'proteinGoalG', 'protein']) ??
          0,
      carbsG:
          _readInt(macros, const ['carbsG', 'carbsGoalG', 'carbs']) ??
          _readInt(plan, const ['carbsG', 'carbsGoalG', 'carbs']) ??
          0,
      fatG:
          _readInt(macros, const ['fatG', 'fatGoalG', 'fat']) ??
          _readInt(plan, const ['fatG', 'fatGoalG', 'fat']) ??
          0,
      meals: _readMeals(plan),
      foodsToAvoid: _readStringList(plan, const [
        'foodsToAvoid',
        'foods_to_avoid',
        'avoid',
        'avoidFoods',
      ]),
      tips: _readStringList(plan, const [
        'tips',
        'aiTips',
        'ai_tips',
        'recommendations',
        'lifestyleTips',
      ]),
      summary: _readString(plan, const ['summary', 'description']),
      targetWeightKg: _readDouble(plan, const [
        'targetWeightKg',
        'goalWeightKg',
        'targetWeight',
      ]),
      bmr: _readInt(plan, const ['bmr']),
      tdee: _readInt(plan, const ['tdee']),
    );
  }
}

Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return json;
}

Map<String, dynamic>? _firstMap(
  Map<String, dynamic> map,
  List<String> keys,
) {
  for (final key in keys) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return null;
}

List<NutritionPlanMeal> _readMeals(Map<String, dynamic> data) {
  for (final key in const ['meals', 'mealPlan', 'mealPlans', 'dailyMeals']) {
    final value = data[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) => NutritionPlanMeal.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }
  }
  return const [];
}

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

int? _readInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
  }
  return null;
}

double? _readDouble(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
  }
  return null;
}

List<String> _readStringList(
  Map<String, dynamic> map,
  List<String> keys,
) {
  for (final key in keys) {
    final value = map[key];
    if (value is List) {
      return value
          .map((item) {
            if (item is String) return item.trim();
            if (item is Map) {
              return _readString(
                    Map<String, dynamic>.from(item),
                    const ['name', 'title', 'label', 'food'],
                  ) ??
                  '';
            }
            return item?.toString() ?? '';
          })
          .where((item) => item.isNotEmpty)
          .toList();
    }
  }
  return const [];
}
