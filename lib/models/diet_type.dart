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
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '');
    return switch (normalized) {
      'nonvegetarian' || 'nonveg' || 'non_veg' => DietType.nonVegetarian,
      'eggetarian' || 'eggitarian' => DietType.eggetarian,
      'vegetarian' || 'veg' => DietType.vegetarian,
      'vegan' => DietType.vegan,
      'pescatarian' || 'pescetarian' => DietType.pescatarian,
      'flexitarian' => DietType.flexitarian,
      'lactovegetarian' || 'lacto' => DietType.lactoVegetarian,
      'lactoovovegetarian' || 'lactoovo' || 'ovo' => DietType.lactoOvoVegetarian,
      _ => null,
    };
  }
}

/// Allergy chips shown during diet preferences setup (matches onboarding design).
abstract final class FoodAllergyOptions {
  static const none = 'None';
  static const other = 'Other';

  static const values = <String>[
    'Dairy',
    'Nuts',
    'Gluten',
    'Seafood',
    other,
  ];

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
    if (lower == 'seafood' ||
        lower == 'shellfish' ||
        lower == 'fish') {
      return 'Seafood';
    }
    if (lower == 'other') return other;
    return other;
  }
}

/// Preferred meals-per-day choices.
abstract final class MealsPerDayOptions {
  static const values = <int>[3, 4, 5];
}
