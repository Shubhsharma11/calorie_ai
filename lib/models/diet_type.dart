/// Diet style chosen during onboarding / profile.
enum DietType {
  nonVegetarian,
  eggetarian,
  vegetarian,
  vegan,
  pescatarian,
  flexitarian,
  lactoVegetarian,
  lactoOvoVegetarian,
}

extension DietTypeLabel on DietType {
  String get emoji {
    switch (this) {
      case DietType.nonVegetarian:
        return '🥩';
      case DietType.eggetarian:
        return '🥚';
      case DietType.vegetarian:
        return '🥬';
      case DietType.vegan:
        return '🌱';
      case DietType.pescatarian:
        return '🐟';
      case DietType.flexitarian:
        return '🍗';
      case DietType.lactoVegetarian:
        return '🥛';
      case DietType.lactoOvoVegetarian:
        return '🥚🥛';
    }
  }

  String get title {
    switch (this) {
      case DietType.nonVegetarian:
        return 'Non-Vegetarian';
      case DietType.eggetarian:
        return 'Eggetarian';
      case DietType.vegetarian:
        return 'Vegetarian';
      case DietType.vegan:
        return 'Vegan';
      case DietType.pescatarian:
        return 'Pescatarian';
      case DietType.flexitarian:
        return 'Flexitarian';
      case DietType.lactoVegetarian:
        return 'Lacto-Vegetarian';
      case DietType.lactoOvoVegetarian:
        return 'Lacto-Ovo Vegetarian';
    }
  }

  /// Short label for the stacked choice cards (easier to answer quickly).
  String get choiceTitle {
    switch (this) {
      case DietType.nonVegetarian:
        return 'I eat meat and everything';
      case DietType.eggetarian:
        return 'Vegetarian, but I eat eggs';
      case DietType.vegetarian:
        return 'Vegetarian';
      case DietType.vegan:
        return 'Fully plant-based (vegan)';
      case DietType.pescatarian:
        return 'I eat fish, but not other meat';
      case DietType.flexitarian:
        return 'Mostly vegetarian, meat sometimes';
      case DietType.lactoVegetarian:
        return 'Vegetarian with dairy, no eggs';
      case DietType.lactoOvoVegetarian:
        return 'Vegetarian with dairy and eggs';
    }
  }

  String get choiceSubtitle {
    switch (this) {
      case DietType.nonVegetarian:
        return 'Chicken, fish, eggs, dairy — the works';
      case DietType.eggetarian:
        return 'No meat or fish';
      case DietType.vegetarian:
        return 'No meat or fish; dairy/eggs may vary';
      case DietType.vegan:
        return 'No meat, fish, eggs, or dairy';
      case DietType.pescatarian:
        return 'Seafood plus vegetarian foods';
      case DietType.flexitarian:
        return 'Plant-forward, flexible on meat';
      case DietType.lactoVegetarian:
        return 'Milk and plant foods only';
      case DietType.lactoOvoVegetarian:
        return 'Dairy, eggs, and plant foods';
    }
  }

  String get description {
    switch (this) {
      case DietType.nonVegetarian:
        return 'Meat, chicken, fish, eggs, dairy';
      case DietType.eggetarian:
        return 'Eggs + vegetarian foods, but no meat/fish';
      case DietType.vegetarian:
        return 'No meat or fish; dairy/eggs may vary';
      case DietType.vegan:
        return 'No meat, fish, eggs, dairy, or other animal products';
      case DietType.pescatarian:
        return 'Vegetarian foods + fish/seafood';
      case DietType.flexitarian:
        return 'Mostly vegetarian, but occasionally eats meat';
      case DietType.lactoVegetarian:
        return 'Dairy + plant foods, no eggs/meat/fish';
      case DietType.lactoOvoVegetarian:
        return 'Dairy + eggs + plant foods, no meat/fish';
    }
  }

  /// Compact label for plan summary chips (e.g. "Veg diet type").
  String get shortPlanLabel => switch (this) {
    DietType.nonVegetarian => 'Non-veg',
    DietType.vegan => 'Vegan',
    DietType.pescatarian => 'Pescatarian',
    DietType.flexitarian => 'Flexitarian',
    DietType.eggetarian => 'Eggetarian',
    DietType.vegetarian ||
    DietType.lactoVegetarian ||
    DietType.lactoOvoVegetarian => 'Veg',
  };

  String get apiValue {
    switch (this) {
      case DietType.nonVegetarian:
        return 'nonVegetarian';
      case DietType.eggetarian:
        return 'eggetarian';
      case DietType.vegetarian:
        return 'vegetarian';
      case DietType.vegan:
        return 'vegan';
      case DietType.pescatarian:
        return 'pescatarian';
      case DietType.flexitarian:
        return 'flexitarian';
      case DietType.lactoVegetarian:
        return 'lactoVegetarian';
      case DietType.lactoOvoVegetarian:
        return 'lactoOvoVegetarian';
    }
  }

  static DietType? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-]+'),
      '',
    );
    return switch (normalized) {
      'nonvegetarian' || 'nonveg' || 'non_veg' => DietType.nonVegetarian,
      'eggetarian' || 'eggitarian' => DietType.eggetarian,
      'vegetarian' || 'veg' => DietType.vegetarian,
      'vegan' => DietType.vegan,
      'pescatarian' || 'pescetarian' => DietType.pescatarian,
      'flexitarian' => DietType.flexitarian,
      'lactovegetarian' || 'lacto' => DietType.lactoVegetarian,
      'lactoovovegetarian' ||
      'lactoovo' ||
      'ovo' => DietType.lactoOvoVegetarian,
      _ => null,
    };
  }
}

/// Gates follow-up onboarding questions from the chosen diet type.
///
/// Example: vegetarians/vegans should never see “Which meat do you prefer?”
extension DietTypeOnboardingGates on DietType {
  /// Land meat (chicken, beef, pork, …) — not fish-only diets.
  bool get includesLandMeat => switch (this) {
    DietType.nonVegetarian || DietType.flexitarian => true,
    _ => false,
  };

  bool get includesFish => switch (this) {
    DietType.nonVegetarian ||
    DietType.flexitarian ||
    DietType.pescatarian => true,
    _ => false,
  };

  bool get includesEggs => switch (this) {
    DietType.vegan || DietType.lactoVegetarian => false,
    _ => true,
  };

  bool get includesDairy => switch (this) {
    DietType.vegan => false,
    _ => true,
  };

  /// Show the meat-preference screen only when the user still picks among meats.
  bool get asksMeatPreferences => includesLandMeat;

  /// Auto-filled when [asksMeatPreferences] is false.
  List<String> get impliedMeatPreferences => switch (this) {
    DietType.pescatarian => const ['fish'],
    _ => const ['vegetarian'],
  };

  /// Whether a food-preference chip still makes sense for this diet.
  bool allowsFoodPreference(String value) {
    return switch (value) {
      'eggs' => includesEggs,
      'cheese' || 'butter' || 'milk' => includesDairy,
      'seafood' => includesFish,
      _ => true,
    };
  }

  /// Whether a “don’t eat” chip is still useful (not already ruled out by diet).
  bool allowsFoodToAvoid(String value) {
    return switch (value) {
      'none' => true,
      'red_meat' || 'pork' => includesLandMeat,
      'seafood' => includesFish,
      'eggs' => includesEggs,
      'dairy' => includesDairy,
      _ => true,
    };
  }

  /// Whether an allergy chip is still useful for this diet.
  bool allowsFoodAllergy(String value) {
    return switch (value) {
      'none' || 'prefer_not' => true,
      'fish' => includesFish,
      'egg_protein' => includesEggs,
      'lactose' || 'milk_protein' => includesDairy,
      _ => true,
    };
  }
}

/// Allergy chips shown during diet preferences setup (matches onboarding design).
abstract final class FoodAllergyOptions {
  static const none = 'None';
  static const other = 'Other';

  static const values = <String>['Dairy', 'Nuts', 'Gluten', 'Seafood', other];

  /// All selectable chip labels in display order (includes None).
  static const chips = <String>[
    none,
    'Dairy',
    'Nuts',
    'Gluten',
    'Seafood',
    other,
  ];

  /// Maps legacy saved allergy strings onto the current chip set.
  static String? normalize(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == 'none' || lower == 'no') return none;
    if (lower == 'dairy' || lower == 'milk' || lower == 'lactose') {
      return 'Dairy';
    }
    if (lower == 'nuts' ||
        lower == 'peanuts' ||
        lower == 'tree nuts' ||
        lower == 'treenuts') {
      return 'Nuts';
    }
    if (lower == 'gluten' || lower == 'wheat') return 'Gluten';
    if (lower == 'seafood' || lower == 'shellfish' || lower == 'fish') {
      return 'Seafood';
    }
    if (lower == 'other') return other;
    return other;
  }
}

/// Preferred meals-per-day choices and the AI plan slot layout for each.
abstract final class MealsPerDayOptions {
  static const values = <int>[3, 4, 5];

  /// Display slots for the AI meal plan / preference cards.
  ///
  /// 3 → Breakfast + Lunch + Dinner
  /// 4 → Breakfast + Lunch + Snack + Dinner
  /// 5 → Breakfast + Morning Snack + Lunch + Evening Snack + Dinner
  static List<String> slotsFor(int mealsPerDay) {
    return switch (mealsPerDay) {
      3 => const ['Breakfast', 'Lunch', 'Dinner'],
      4 => const ['Breakfast', 'Lunch', 'Snack', 'Dinner'],
      5 => const [
        'Breakfast',
        'Morning Snack',
        'Lunch',
        'Evening Snack',
        'Dinner',
      ],
      _ => const ['Breakfast', 'Lunch', 'Dinner'],
    };
  }

  /// e.g. `Breakfast + Lunch + Dinner`
  static String structureLabel(int mealsPerDay) =>
      slotsFor(mealsPerDay).join(' + ');

  /// e.g. `3 Meals`
  static String countLabel(int mealsPerDay) => '$mealsPerDay Meals';

  /// Card title line: `3 Meals`
  /// Card subtitle: `Breakfast + Lunch + Dinner`
  static String subtitleFor(int mealsPerDay) => structureLabel(mealsPerDay);

  /// Sort index for a plan meal type within [mealsPerDay] (unknowns go last).
  static int slotIndex(String mealType, int mealsPerDay) {
    final slots = slotsFor(mealsPerDay);
    final key = mealType.trim().toLowerCase();
    final exact = slots.indexWhere((s) => s.toLowerCase() == key);
    if (exact >= 0) return exact;

    // Tolerate API variants like "Snacks" / "Evening Snacks".
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i].toLowerCase();
      if (key.contains(slot) || slot.contains(key)) return i;
      if (slot.contains('snack') && key.contains('snack')) {
        if (slot.contains('morning') && key.contains('morning')) return i;
        if (slot.contains('evening') && key.contains('evening')) return i;
        if (!slot.contains('morning') &&
            !slot.contains('evening') &&
            !key.contains('morning') &&
            !key.contains('evening')) {
          return i;
        }
      }
    }
    return slots.length;
  }

  static List<T> sortBySlotOrder<T>(
    List<T> items,
    int mealsPerDay,
    String Function(T item) mealTypeOf,
  ) {
    final sorted = List<T>.of(items);
    sorted.sort(
      (a, b) => slotIndex(mealTypeOf(a), mealsPerDay).compareTo(
        slotIndex(mealTypeOf(b), mealsPerDay),
      ),
    );
    return sorted;
  }
}
