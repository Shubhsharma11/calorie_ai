enum PlannedMealStatus { next, upcoming, completed }

class PlannedMeal {
  const PlannedMeal({
    required this.id,
    required this.mealType,
    required this.name,
    required this.timeLabel,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.status,
    required this.description,
    required this.ingredients,
    required this.why,
    this.alternatives = const [],
  });

  final String id;
  final String mealType;
  final String name;
  final String timeLabel;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final PlannedMealStatus status;
  final String description;
  final List<String> ingredients;
  final String why;

  /// API-provided swap options for this slot (when present).
  final List<PlannedMeal> alternatives;

  PlannedMeal copyWith({
    String? id,
    String? mealType,
    String? name,
    String? timeLabel,
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    PlannedMealStatus? status,
    String? description,
    List<String>? ingredients,
    String? why,
    List<PlannedMeal>? alternatives,
  }) {
    return PlannedMeal(
      id: id ?? this.id,
      mealType: mealType ?? this.mealType,
      name: name ?? this.name,
      timeLabel: timeLabel ?? this.timeLabel,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      status: status ?? this.status,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      why: why ?? this.why,
      alternatives: alternatives ?? this.alternatives,
    );
  }

  factory PlannedMeal.fromJson(Map<String, dynamic> json) {
    final mealTypeLabel =
        _string(json, const [
          'mealTypeLabel',
          'meal_type_label',
          'title',
          'type',
        ]) ??
        '';
    final mealTypeRaw =
        _string(json, const ['mealType', 'meal_type', 'slot']) ?? mealTypeLabel;
    final mealType = _normalizeMealType(mealTypeLabel, mealTypeRaw);

    final name =
        _string(json, const ['name', 'mealName', 'meal_name', 'displayName']) ??
        mealType;

    final id =
        _string(json, const ['id', 'mealId', 'meal_id']) ??
        '${mealType}_$name'.toLowerCase().replaceAll(' ', '_');

    final embeddedAlts = <PlannedMeal>[];
    final altsRaw =
        json['alternatives'] ?? json['swapOptions'] ?? json['swap_options'];
    if (altsRaw is List) {
      for (final item in altsRaw.whereType<Map>()) {
        embeddedAlts.add(
          PlannedMeal.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    return PlannedMeal(
      id: id,
      mealType: mealType,
      name: name,
      timeLabel:
          _string(json, const [
            'timeLabel',
            'time_label',
            'scheduledTime',
            'scheduled_time',
            'time',
          ]) ??
          '',
      calories: _int(json, const ['calories', 'kcal']) ?? 0,
      proteinG: _int(json, const ['proteinG', 'protein', 'protein_g']) ?? 0,
      carbsG: _int(json, const ['carbsG', 'carbs', 'carbs_g']) ?? 0,
      fatG: _int(json, const ['fatG', 'fat', 'fat_g']) ?? 0,
      status: _parseStatus(json['status']?.toString()),
      description:
          _string(json, const ['description', 'summary', 'tagline']) ?? '',
      ingredients: _stringList(json, const [
        'ingredients',
        'items',
        'foods',
        'foodItems',
      ]),
      why: _string(json, const ['why', 'reason', 'insight']) ?? '',
      alternatives: embeddedAlts,
    );
  }

  static PlannedMealStatus _parseStatus(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return switch (value) {
      'next' => PlannedMealStatus.next,
      'completed' ||
      'complete' ||
      'done' ||
      'logged' => PlannedMealStatus.completed,
      _ => PlannedMealStatus.upcoming,
    };
  }

  static String _normalizeMealType(String label, String raw) {
    final combined = '$label $raw'.toLowerCase();
    if (combined.contains('breakfast')) return 'Breakfast';
    if (combined.contains('lunch')) return 'Lunch';
    if (combined.contains('dinner')) return 'Dinner';
    if (combined.contains('snack')) {
      if (combined.contains('morning')) return 'Morning Snack';
      if (combined.contains('evening')) return 'Evening Snack';
      return 'Snack';
    }
    if (label.trim().isNotEmpty) return label.trim();
    if (raw.trim().isNotEmpty) {
      return raw.trim()[0].toUpperCase() + raw.trim().substring(1);
    }
    return 'Meal';
  }
}

class WeeklyMealPlanDay {
  const WeeklyMealPlanDay({
    required this.date,
    required this.meals,
    this.weekday,
    this.weekdayNumberOverride,
  });

  final DateTime? date;
  final String? weekday;
  final int? weekdayNumberOverride;
  final List<PlannedMeal> meals;

  factory WeeklyMealPlanDay.fromJson(Map<String, dynamic> json) {
    final dateRaw = _string(json, const ['date', 'dayDate', 'day_date']);
    DateTime? date;
    if (dateRaw != null) {
      date = DateTime.tryParse(dateRaw);
    }
    // Some APIs use `day` as an ISO date string.
    final dayValue = json['day'];
    if (date == null && dayValue is String) {
      date = DateTime.tryParse(dayValue);
    }

    final weekday = _string(json, const [
      'weekday',
      'dayLabel',
      'day_label',
      'label',
      'dayName',
      'day_name',
    ]);

    // Prefer explicit weekday number when the API sends Mon=1…Sun=7 (or 0-based).
    final weekdayIndex = _int(json, const [
      'weekdayNumber',
      'weekday_number',
      'dayOfWeek',
      'day_of_week',
      'dayIndex',
      'day_index',
    ]);
    final dayAsIndex = dayValue is num ? dayValue.round() : null;

    final mealsRaw = json['meals'] ?? json['plan'] ?? json['items'];
    final meals = <PlannedMeal>[];
    if (mealsRaw is List) {
      for (final item in mealsRaw.whereType<Map>()) {
        meals.add(PlannedMeal.fromJson(Map<String, dynamic>.from(item)));
      }
    } else if (mealsRaw is Map) {
      // `{ breakfast: {...}, lunch: {...} }`
      for (final entry in mealsRaw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final mealJson = Map<String, dynamic>.from(value);
        mealJson.putIfAbsent('mealType', () => entry.key.toString());
        mealJson.putIfAbsent('mealTypeLabel', () => entry.key.toString());
        meals.add(PlannedMeal.fromJson(mealJson));
      }
    }

    return WeeklyMealPlanDay(
      date: date,
      weekday: weekday,
      weekdayNumberOverride: _normalizeWeekdayIndex(weekdayIndex ?? dayAsIndex),
      meals: meals,
    );
  }

  /// DateTime.weekday: Mon=1 … Sun=7
  int? get weekdayNumber {
    if (weekdayNumberOverride != null) return weekdayNumberOverride;
    // Prefer label when present — some APIs send mismatched date/label pairs.
    final fromLabel = _weekdayFromLabel(weekday);
    if (fromLabel != null) return fromLabel;
    if (date != null) return date!.weekday;
    return null;
  }

  static int? _normalizeWeekdayIndex(int? raw) {
    if (raw == null) return null;
    if (raw >= 1 && raw <= 7) return raw;
    // 0=Sun … 6=Sat
    if (raw >= 0 && raw <= 6) {
      return raw == 0 ? DateTime.sunday : raw;
    }
    return null;
  }

  static int? _weekdayFromLabel(String? raw) {
    final label = (raw ?? '').trim().toLowerCase();
    if (label.isEmpty) return null;
    if (label.startsWith('mon') || label == '1') return DateTime.monday;
    if (label.startsWith('tue') || label == '2') return DateTime.tuesday;
    if (label.startsWith('wed') || label == '3') return DateTime.wednesday;
    if (label.startsWith('thu') || label == '4') return DateTime.thursday;
    if (label.startsWith('fri') || label == '5') return DateTime.friday;
    if (label.startsWith('sat') || label == '6') return DateTime.saturday;
    if (label.startsWith('sun') || label == '7' || label == '0') {
      return DateTime.sunday;
    }
    return null;
  }
}

class WeeklyMealPlanData {
  const WeeklyMealPlanData({
    required this.days,
    this.weekStart,
    this.dailyCalorieTarget,
    this.goalLabel,
  });

  final DateTime? weekStart;
  final int? dailyCalorieTarget;
  final String? goalLabel;
  final List<WeeklyMealPlanDay> days;

  bool get isEmpty => days.every((day) => day.meals.isEmpty);
  bool get isNotEmpty => !isEmpty;

  factory WeeklyMealPlanData.fromJson(Map<String, dynamic> json) {
    final weekStartRaw = _string(json, const [
      'weekStart',
      'week_start',
      'startDate',
      'start_date',
    ]);
    final daysRaw = json['days'] ?? json['dayPlans'] ?? json['schedule'];
    final days = <WeeklyMealPlanDay>[];
    if (daysRaw is List) {
      for (final item in daysRaw.whereType<Map>()) {
        days.add(WeeklyMealPlanDay.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    return WeeklyMealPlanData(
      weekStart: weekStartRaw == null ? null : DateTime.tryParse(weekStartRaw),
      dailyCalorieTarget: _int(json, const [
        'dailyCalorieTarget',
        'daily_calorie_target',
        'calories',
      ]),
      goalLabel: _string(json, const ['goalLabel', 'goal_label', 'goal']),
      days: days,
    );
  }

  /// Meals for [weekday] where Mon=1 … Sun=7.
  List<PlannedMeal> mealsForWeekday(int weekday) {
    for (final day in days) {
      if (day.weekdayNumber == weekday && day.meals.isNotEmpty) {
        return day.meals;
      }
    }
    return const [];
  }

  /// Unique swap candidates for [current] from this week's plan (same slot type).
  List<PlannedMeal> swapAlternativesFor(
    PlannedMeal current, {
    Set<String> suppressedNames = const {},
  }) {
    final typeKey = current.mealType.trim().toLowerCase();
    final currentName = current.name.trim().toLowerCase();
    final seen = <String>{currentName};
    final options = <PlannedMeal>[];

    for (final day in days) {
      for (final meal in day.meals) {
        final nameKey = meal.name.trim().toLowerCase();
        if (nameKey.isEmpty || seen.contains(nameKey)) continue;
        if (suppressedNames.contains(nameKey)) continue;
        if (meal.mealType.trim().toLowerCase() != typeKey) continue;
        seen.add(nameKey);
        options.add(meal);
      }
    }
    return options;
  }

  /// Broader pool for “more options” (same type first, then other week meals).
  List<PlannedMeal> moreOptionsFor(
    PlannedMeal current, {
    String query = '',
    Set<String> suppressedNames = const {},
  }) {
    final sameType = swapAlternativesFor(
      current,
      suppressedNames: suppressedNames,
    );
    final currentName = current.name.trim().toLowerCase();
    final seen = <String>{
      currentName,
      ...sameType.map((m) => m.name.trim().toLowerCase()),
    };
    final extras = <PlannedMeal>[];
    for (final day in days) {
      for (final meal in day.meals) {
        final nameKey = meal.name.trim().toLowerCase();
        if (nameKey.isEmpty || seen.contains(nameKey)) continue;
        if (suppressedNames.contains(nameKey)) continue;
        seen.add(nameKey);
        extras.add(meal);
      }
    }
    final pool = [...sameType, ...extras];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return pool;
    return pool
        .where(
          (m) =>
              m.name.toLowerCase().contains(q) ||
              m.ingredients.any((i) => i.toLowerCase().contains(q)),
        )
        .toList();
  }
}

String? _string(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

int? _int(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
  }
  return null;
}

List<String> _stringList(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is List) {
      return value
          .map((item) {
            if (item is String) return item.trim();
            if (item is Map) {
              return _string(Map<String, dynamic>.from(item), const [
                    'name',
                    'title',
                    'text',
                    'label',
                    'food',
                    'ingredient',
                  ]) ??
                  '';
            }
            return item?.toString().trim() ?? '';
          })
          .where((item) => item.isNotEmpty)
          .toList();
    }
  }
  return const [];
}
