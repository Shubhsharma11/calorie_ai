import 'planned_meal.dart';

class NutritionPlanMeal {
  const NutritionPlanMeal({
    required this.title,
    required this.calories,
    required this.items,
    this.name = '',
    this.proteinG = 0,
    this.timeLabel,
  });

  /// Meal slot label (Breakfast / Lunch / Dinner / Snack).
  final String title;

  /// Display name for the meal (e.g. "Oats + Banana + Almonds").
  final String name;

  final int calories;
  final int proteinG;
  final String? timeLabel;
  final List<String> items;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (items.isNotEmpty) return items.take(3).join(' + ');
    return title;
  }

  factory NutritionPlanMeal.fromJson(Map<String, dynamic> json) {
    final items = _readStringList(json, const [
      'items',
      'foods',
      'foodItems',
      'ingredients',
    ]);
    final title =
        _readString(json, const [
          'mealTypeLabel',
          'meal_type_label',
          'title',
          'type',
          'mealType',
          'meal_type',
          'meal',
          'slot',
        ]) ??
        'Meal';
    final name =
        _readString(json, const [
          'name',
          'mealName',
          'meal_name',
          'foodName',
          'displayName',
          'titleName',
        ]) ??
        (items.isNotEmpty ? items.take(3).join(' + ') : '');

    return NutritionPlanMeal(
      title: title,
      name: name,
      calories:
          _readInt(json, const [
            'calories',
            'kcal',
            'calorieGoal',
            'totalCalories',
          ]) ??
          0,
      proteinG:
          _readInt(json, const [
            'proteinG',
            'protein',
            'proteinGoalG',
            'protein_g',
          ]) ??
          0,
      timeLabel: _readString(json, const [
        'timeLabel',
        'time_label',
        'scheduledTime',
        'scheduled_time',
        'time',
        'mealTime',
        'meal_time',
      ]),
      items: items,
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
    this.homePreview,
    this.weeklyPlan,
    this.goalLabel,
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

  /// Optional dedicated preview for Home AI Meal Plan card.
  final NutritionPlanMeal? homePreview;

  /// Full 7-day schedule from nutrition plan API.
  final WeeklyMealPlanData? weeklyPlan;

  /// Display label e.g. "Muscle Gain".
  final String? goalLabel;

  /// Best meal to show on Home: homePreview → first planned meal.
  NutritionPlanMeal? get previewMeal {
    final preview = homePreview;
    if (preview != null) return preview;
    if (meals.isNotEmpty) return meals.first;
    return null;
  }

  factory NutritionPlanModel.fromJson(Map<String, dynamic> json) {
    final data = _unwrapData(json);
    final nutritionPlan =
        _firstMap(data, const ['nutritionPlan', 'nutrition_plan']) ?? data;
    final plan = _firstMap(nutritionPlan, const ['plan']) ?? nutritionPlan;
    final macros = _firstMap(plan, const ['macros']) ?? plan;

    final homePreviewMap =
        _firstMap(data, const ['homePreview', 'home_preview']) ??
        _firstMap(nutritionPlan, const ['homePreview', 'home_preview']) ??
        _firstMap(plan, const ['homePreview', 'home_preview']);

    final weeklyPlan = _readWeeklyPlan(data, nutritionPlan, plan);
    final meals = _readMeals(plan);
    final weeklyMeals = _readWeeklyMeals(data, nutritionPlan, plan);
    final mergedMeals = meals.isNotEmpty ? meals : weeklyMeals;

    final calories =
        _readInt(plan, const [
          'dailyCalories',
          'dailyCalorieGoal',
          'calories',
          'calorieGoal',
          'recommendedCalories',
        ]) ??
        _readInt(macros, const ['calories', 'dailyCalories']) ??
        _readInt(data, const ['dailyCalorieTarget', 'daily_calorie_target']) ??
        weeklyPlan?.dailyCalorieTarget ??
        0;

    return NutritionPlanModel(
      calories: calories,
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
      meals: mergedMeals,
      foodsToAvoid: _readStringList(plan, const [
        'foodsToAvoid',
        'foods_to_avoid',
        'avoid',
        'avoidFoods',
      ]),
      tips: _collectTips(data, nutritionPlan, plan),
      summary:
          _readString(plan, const ['summary', 'description']) ??
          _readString(nutritionPlan, const ['summary', 'description']) ??
          _readString(data, const ['summary', 'description']),
      targetWeightKg: _readDouble(plan, const [
        'targetWeightKg',
        'goalWeightKg',
        'targetWeight',
      ]),
      bmr: _readInt(plan, const ['bmr']),
      tdee: _readInt(plan, const ['tdee']),
      homePreview: homePreviewMap == null
          ? null
          : NutritionPlanMeal.fromJson(homePreviewMap),
      weeklyPlan: weeklyPlan,
      goalLabel:
          _readString(plan, const ['goalLabel', 'goal_label']) ??
          _readString(nutritionPlan, const ['goalLabel', 'goal_label']) ??
          weeklyPlan?.goalLabel,
    );
  }
}

List<String> _collectTips(
  Map<String, dynamic> data,
  Map<String, dynamic> nutritionPlan,
  Map<String, dynamic> plan,
) {
  const keys = [
    'tips',
    'aiTips',
    'ai_tips',
    'recommendations',
    'lifestyleTips',
    'lifestyle_tips',
  ];

  for (final map in [plan, nutritionPlan, data]) {
    final tips = _readStringList(map, keys);
    if (tips.isNotEmpty) return tips;
  }

  final summary =
      _readString(plan, const ['summary', 'description']) ??
      _readString(nutritionPlan, const ['summary', 'description']) ??
      _readString(data, const ['summary', 'description']);
  if (summary != null && summary.isNotEmpty) {
    return [summary];
  }

  return const [];
}

Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return json;
}

Map<String, dynamic>? _firstMap(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return null;
}

List<NutritionPlanMeal> _readMeals(Map<String, dynamic> data) {
  for (final key in const [
    'meals',
    'mealPlan',
    'mealPlans',
    'dailyMeals',
    'todayMeals',
    'today_meals',
  ]) {
    final value = data[key];
    if (value is List) {
      final meals = value
          .whereType<Map>()
          .map(
            (item) =>
                NutritionPlanMeal.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      if (meals.isNotEmpty) return meals;
    }
  }
  return const [];
}

WeeklyMealPlanData? _readWeeklyPlan(
  Map<String, dynamic> data,
  Map<String, dynamic> nutritionPlan,
  Map<String, dynamic> plan,
) {
  const keys = [
    'weeklyMealPlan',
    'weekly_meal_plan',
    'weeklyPlan',
    'weekly_plan',
    'weekPlan',
    'week_plan',
    'mealPlan',
    'meal_plan',
    'week',
  ];

  for (final root in [data, nutritionPlan, plan]) {
    for (final key in keys) {
      final value = root[key];
      if (value == null) continue;

      // `{ days: [...] }` object
      if (value is Map) {
        final parsed = WeeklyMealPlanData.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (parsed.isNotEmpty || parsed.days.isNotEmpty) return parsed;
      }

      // Bare list of day objects
      if (value is List) {
        final parsed = WeeklyMealPlanData.fromJson({'days': value});
        if (parsed.isNotEmpty || parsed.days.isNotEmpty) return parsed;
      }
    }

    // Some APIs put `days` directly on the plan root.
    final daysRaw = root['days'] ?? root['dayPlans'] ?? root['schedule'];
    if (daysRaw is List && daysRaw.isNotEmpty) {
      final parsed = WeeklyMealPlanData.fromJson({
        'days': daysRaw,
        'dailyCalorieTarget':
            root['dailyCalorieTarget'] ??
            root['daily_calorie_target'] ??
            root['calories'],
        'goalLabel': root['goalLabel'] ?? root['goal_label'] ?? root['goal'],
        'weekStart': root['weekStart'] ?? root['week_start'],
      });
      if (parsed.isNotEmpty || parsed.days.isNotEmpty) return parsed;
    }
  }
  return null;
}

List<NutritionPlanMeal> _readWeeklyMeals(
  Map<String, dynamic> data,
  Map<String, dynamic> nutritionPlan,
  Map<String, dynamic> plan,
) {
  final weekly = _readWeeklyPlan(data, nutritionPlan, plan);
  if (weekly == null || weekly.isEmpty) return const [];

  final todayWeekday = DateTime.now().weekday;
  var dayMeals = weekly.mealsForWeekday(todayWeekday);
  if (dayMeals.isEmpty) {
    for (final day in weekly.days) {
      if (day.meals.isNotEmpty) {
        dayMeals = day.meals;
        break;
      }
    }
  }
  if (dayMeals.isEmpty) return const [];

  PlannedMeal? preferred;
  for (final meal in dayMeals) {
    if (meal.status == PlannedMealStatus.next) {
      preferred = meal;
      break;
    }
  }
  if (preferred == null) {
    for (final meal in dayMeals) {
      if (meal.status == PlannedMealStatus.upcoming) {
        preferred = meal;
        break;
      }
    }
  }
  if (preferred == null) {
    for (final meal in dayMeals) {
      if (meal.status != PlannedMealStatus.completed) {
        preferred = meal;
        break;
      }
    }
  }
  preferred ??= dayMeals.first;

  final ordered = [
    preferred,
    ...dayMeals.where((meal) => meal.id != preferred!.id),
  ];

  return ordered
      .map(
        (meal) => NutritionPlanMeal(
          title: meal.mealType,
          name: meal.name,
          calories: meal.calories,
          proteinG: meal.proteinG,
          timeLabel: meal.timeLabel.isEmpty ? null : meal.timeLabel,
          items: meal.ingredients,
        ),
      )
      .toList();
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

List<String> _readStringList(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is List) {
      return value
          .map((item) {
            if (item is String) return item.trim();
            if (item is Map) {
              return _readString(Map<String, dynamic>.from(item), const [
                    'text',
                    'tip',
                    'message',
                    'content',
                    'description',
                    'name',
                    'title',
                    'label',
                    'food',
                  ]) ??
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
