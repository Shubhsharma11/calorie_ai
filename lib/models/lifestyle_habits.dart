import 'diet_type.dart';

/// Lifestyle / habits answers collected after health concerns.
///
/// Kept as plain strings for draft persistence and future API mapping.
class LifestyleHabits {
  const LifestyleHabits({
    this.mediterraneanFamiliarity,
    this.idealWeightTiming,
    this.dailyWater,
    this.dietPlanInterest,
    this.foodPreferences = const [],
    this.meatPreferences = const [],
    this.cookingSkills,
    this.medications = const [],
  });

  final String? mediterraneanFamiliarity;
  final String? idealWeightTiming;
  final String? dailyWater;
  final String? dietPlanInterest;
  final List<String> foodPreferences;
  final List<String> meatPreferences;
  final String? cookingSkills;
  final List<String> medications;

  bool get isComplete =>
      mediterraneanFamiliarity != null &&
      idealWeightTiming != null &&
      dailyWater != null &&
      dietPlanInterest != null &&
      foodPreferences.length >= 5 &&
      meatPreferences.isNotEmpty &&
      cookingSkills != null &&
      medications.isNotEmpty;

  LifestyleHabits copyWith({
    String? mediterraneanFamiliarity,
    String? idealWeightTiming,
    String? dailyWater,
    String? dietPlanInterest,
    List<String>? foodPreferences,
    List<String>? meatPreferences,
    String? cookingSkills,
    List<String>? medications,
  }) {
    return LifestyleHabits(
      mediterraneanFamiliarity:
          mediterraneanFamiliarity ?? this.mediterraneanFamiliarity,
      idealWeightTiming: idealWeightTiming ?? this.idealWeightTiming,
      dailyWater: dailyWater ?? this.dailyWater,
      dietPlanInterest: dietPlanInterest ?? this.dietPlanInterest,
      foodPreferences: foodPreferences ?? this.foodPreferences,
      meatPreferences: meatPreferences ?? this.meatPreferences,
      cookingSkills: cookingSkills ?? this.cookingSkills,
      medications: medications ?? this.medications,
    );
  }

  Map<String, dynamic> toJson() => {
    'mediterraneanFamiliarity': mediterraneanFamiliarity,
    'idealWeightTiming': idealWeightTiming,
    'dailyWater': dailyWater,
    'dietPlanInterest': dietPlanInterest,
    'foodPreferences': List<String>.from(foodPreferences),
    'meatPreferences': List<String>.from(meatPreferences),
    'cookingSkills': cookingSkills,
    'medications': List<String>.from(medications),
  };

  factory LifestyleHabits.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LifestyleHabits();
    return LifestyleHabits(
      mediterraneanFamiliarity: _string(json['mediterraneanFamiliarity']),
      idealWeightTiming: _string(json['idealWeightTiming']),
      dailyWater: _string(json['dailyWater']),
      dietPlanInterest: _string(json['dietPlanInterest']),
      foodPreferences: _stringList(json['foodPreferences']),
      meatPreferences: _stringList(json['meatPreferences']),
      cookingSkills: _string(json['cookingSkills']),
      medications: _stringList(json['medications']),
    );
  }

  static String? _string(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

/// Option catalogs for each Habits screen (match product copy).
abstract final class LifestyleHabitOptions {
  static const mediterraneanFamiliarity = <HabitOption>[
    HabitOption(value: 'beginner', label: "I'm a beginner", emoji: '😊'),
    HabitOption(
      value: 'basic',
      label: 'I have some basic knowledge',
      emoji: '😎',
    ),
    HabitOption(value: 'experienced', label: "I'm experienced", emoji: '😉'),
  ];

  static const idealWeightTiming = <HabitOption>[
    HabitOption(value: 'less_than_year', label: 'Less than a year ago'),
    HabitOption(value: '1_to_2_years', label: '1 to 2 years ago'),
    HabitOption(value: 'more_than_3_years', label: 'More than 3 years ago'),
    HabitOption(value: 'never', label: 'Never'),
  ];

  static const dailyWater = <HabitOption>[
    HabitOption(
      value: 'coffee_tea_only',
      label: 'I only have coffee or tea',
      emoji: '☕',
    ),
    HabitOption(
      value: 'less_than_2',
      label: 'Less than 2 glasses',
      emoji: '💧',
    ),
    HabitOption(value: '3_to_6', label: 'About 3-6 glasses', emoji: '💦'),
    HabitOption(
      value: 'more_than_6',
      label: 'More than 6 glasses',
      emoji: '🌊',
    ),
  ];

  static const dietPlanInterest = <HabitOption>[
    HabitOption(value: 'heartHealthy', label: 'Heart-Healthy'),
    HabitOption(value: 'highProtein', label: 'High-Protein'),
    HabitOption(value: 'healthyNatural', label: 'Healthy & Natural'),
  ];

  /// “How would you describe your eating habits?”
  static const eatingHabits = <HabitOption>[
    HabitOption(
      value: 'same_every_day',
      label: 'I eat the same food every day',
    ),
    HabitOption(
      value: 'similar_some_variation',
      label: 'I eat similar foods, with some variation',
    ),
    HabitOption(
      value: 'rotate_familiar',
      label: 'I rotate between familiar foods',
    ),
    HabitOption(
      value: 'experiment',
      label: 'I like to experiment with different foods',
    ),
  ];

  /// “Which region’s food do you usually eat?” (cuisine culture, not residence).
  /// First pick a region, then a state cuisine within it.
  static const livingRegions = <IndiaLivingRegion>[
    IndiaLivingRegion(
      value: 'north_india',
      label: 'North India',
      emoji: '🇮🇳',
      states: [
        HabitOption(value: 'punjab', label: 'Punjab'),
        HabitOption(value: 'haryana', label: 'Haryana'),
        HabitOption(value: 'himachal_pradesh', label: 'Himachal Pradesh'),
        HabitOption(value: 'jammu_kashmir', label: 'Jammu & Kashmir'),
        HabitOption(value: 'ladakh', label: 'Ladakh'),
        HabitOption(value: 'uttarakhand', label: 'Uttarakhand'),
        HabitOption(value: 'uttar_pradesh', label: 'Uttar Pradesh'),
        HabitOption(value: 'delhi', label: 'Delhi'),
        HabitOption(value: 'chandigarh', label: 'Chandigarh'),
      ],
    ),
    IndiaLivingRegion(
      value: 'west_india',
      label: 'West India',
      emoji: '🌅',
      states: [
        HabitOption(value: 'rajasthan', label: 'Rajasthan'),
        HabitOption(value: 'gujarat', label: 'Gujarat'),
        HabitOption(value: 'maharashtra', label: 'Maharashtra'),
        HabitOption(value: 'goa', label: 'Goa'),
        HabitOption(
          value: 'dadra_nagar_haveli_daman_diu',
          label: 'Dadra & Nagar Haveli and Daman & Diu',
        ),
      ],
    ),
    IndiaLivingRegion(
      value: 'central_india',
      label: 'Central India',
      emoji: '🌳',
      states: [
        HabitOption(value: 'madhya_pradesh', label: 'Madhya Pradesh'),
        HabitOption(value: 'chhattisgarh', label: 'Chhattisgarh'),
      ],
    ),
    IndiaLivingRegion(
      value: 'east_india',
      label: 'East India',
      emoji: '🌾',
      states: [
        HabitOption(value: 'west_bengal', label: 'West Bengal'),
        HabitOption(value: 'odisha', label: 'Odisha'),
        HabitOption(value: 'bihar', label: 'Bihar'),
        HabitOption(value: 'jharkhand', label: 'Jharkhand'),
      ],
    ),
    IndiaLivingRegion(
      value: 'south_india',
      label: 'South India',
      emoji: '🌴',
      states: [
        HabitOption(value: 'andhra_pradesh', label: 'Andhra Pradesh'),
        HabitOption(value: 'telangana', label: 'Telangana'),
        HabitOption(value: 'karnataka', label: 'Karnataka'),
        HabitOption(value: 'tamil_nadu', label: 'Tamil Nadu'),
        HabitOption(value: 'kerala', label: 'Kerala'),
        HabitOption(value: 'puducherry', label: 'Puducherry'),
      ],
    ),
    IndiaLivingRegion(
      value: 'northeast_india',
      label: 'Northeast India',
      emoji: '🏔️',
      states: [
        HabitOption(value: 'assam', label: 'Assam'),
        HabitOption(value: 'arunachal_pradesh', label: 'Arunachal Pradesh'),
        HabitOption(value: 'manipur', label: 'Manipur'),
        HabitOption(value: 'meghalaya', label: 'Meghalaya'),
        HabitOption(value: 'mizoram', label: 'Mizoram'),
        HabitOption(value: 'nagaland', label: 'Nagaland'),
        HabitOption(value: 'sikkim', label: 'Sikkim'),
        HabitOption(value: 'tripura', label: 'Tripura'),
      ],
    ),
  ];

  static IndiaLivingRegion? livingRegionByValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final region in livingRegions) {
      if (region.value == value) return region;
    }
    return null;
  }

  static const meatPreferences = <HabitOption>[
    HabitOption(value: 'chicken', label: 'Chicken', emoji: '🍗'),
    HabitOption(value: 'pork', label: 'Pork', emoji: '🐷'),
    HabitOption(value: 'bacon', label: 'Bacon', emoji: '🥓'),
    HabitOption(value: 'beef', label: 'Beef', emoji: '🐄'),
    HabitOption(value: 'turkey', label: 'Turkey', emoji: '🦃'),
    HabitOption(value: 'fish', label: 'Fish', emoji: '🐟'),
    HabitOption(value: 'lamb', label: 'Lamb', emoji: '🐑'),
    HabitOption(value: 'vegetarian', label: "I'm a vegetarian", emoji: '🌱'),
  ];

  static const cookingSkills = <HabitOption>[
    HabitOption(value: 'expert', label: "I'm an expert cook"),
    HabitOption(value: 'learning', label: "I'm learning to be a better cook"),
    HabitOption(value: 'beginner', label: "I don't know how to cook at all"),
  ];

  static const foodPreferences = <HabitOption>[
    HabitOption(value: 'avocados', label: 'Avocados', emoji: '🥑'),
    HabitOption(value: 'eggs', label: 'Eggs', emoji: '🥚'),
    HabitOption(value: 'mushrooms', label: 'Mushrooms', emoji: '🍄'),
    HabitOption(value: 'onions', label: 'Onions', emoji: '🧅'),
    HabitOption(value: 'cheese', label: 'Cheese', emoji: '🧀'),
    HabitOption(value: 'nuts', label: 'Nuts', emoji: '🌰'),
    HabitOption(value: 'butter', label: 'Butter', emoji: '🧈'),
    HabitOption(value: 'coconut', label: 'Coconut', emoji: '🥥'),
    HabitOption(value: 'milk', label: 'Milk', emoji: '🥛'),
    HabitOption(value: 'seafood', label: 'Seafood', emoji: '🦐'),
    HabitOption(value: 'olives', label: 'Olives', emoji: '🫒'),
    HabitOption(value: 'tofu', label: 'Tofu', emoji: '🍢'),
  ];

  static const foodAllergies = <HabitOption>[
    HabitOption(value: 'none', label: 'None'),
    HabitOption(value: 'lactose', label: 'Lactose', emoji: '🥛'),
    HabitOption(value: 'milk_protein', label: 'Milk protein'),
    HabitOption(value: 'nuts', label: 'Nuts', emoji: '🌰'),
    HabitOption(value: 'egg_protein', label: 'Egg protein', emoji: '🥚'),
    HabitOption(value: 'honey', label: 'Honey', emoji: '🍯'),
    HabitOption(value: 'fish', label: 'Fish', emoji: '🐟'),
    HabitOption(value: 'citrus', label: 'Citrus fruits', emoji: '🍋'),
    HabitOption(value: 'prefer_not', label: 'Prefer not to answer'),
  ];

  /// Foods the user prefers to leave out of meal plans.
  static const foodsToAvoid = <HabitOption>[
    HabitOption(value: 'none', label: 'Nothing — I eat everything'),
    HabitOption(value: 'seafood', label: 'Seafood', emoji: '🦐'),
    HabitOption(value: 'spicy', label: 'Spicy food', emoji: '🌶️'),
    HabitOption(value: 'dairy', label: 'Dairy', emoji: '🧀'),
    HabitOption(value: 'eggs', label: 'Eggs', emoji: '🥚'),
    HabitOption(value: 'red_meat', label: 'Red meat', emoji: '🥩'),
    HabitOption(value: 'pork', label: 'Pork', emoji: '🐷'),
    HabitOption(value: 'nuts', label: 'Nuts', emoji: '🌰'),
    HabitOption(value: 'tofu', label: 'Tofu / soy', emoji: '🍢'),
    HabitOption(value: 'processed', label: 'Processed foods'),
  ];

  static const medications = <HabitOption>[
    HabitOption(value: 'vitamins', label: 'Vitamins'),
    HabitOption(value: 'hormones', label: 'Hormones'),
    HabitOption(value: 'antibiotics', label: 'Antibiotics'),
    HabitOption(value: 'anxiety', label: 'Anxiety medications'),
    HabitOption(value: 'other', label: 'Other'),
    HabitOption(value: 'no', label: 'No'),
  ];

  /// Meat chips for diets that still ask (no redundant “I’m a vegetarian”).
  static List<HabitOption> meatPreferencesFor(DietType? diet) {
    final options = meatPreferences
        .where((o) => o.value != 'vegetarian')
        .toList();
    if (diet == null || diet.includesFish) return options;
    return options.where((o) => o.value != 'fish').toList();
  }

  static List<HabitOption> foodPreferencesFor(DietType? diet) {
    if (diet == null) return List<HabitOption>.from(foodPreferences);
    return foodPreferences
        .where((o) => diet.allowsFoodPreference(o.value))
        .toList();
  }

  static List<HabitOption> foodsToAvoidFor(DietType? diet) {
    if (diet == null) return List<HabitOption>.from(foodsToAvoid);
    return foodsToAvoid.where((o) => diet.allowsFoodToAvoid(o.value)).toList();
  }

  static List<HabitOption> foodAllergiesFor(DietType? diet) {
    if (diet == null) return List<HabitOption>.from(foodAllergies);
    return foodAllergies
        .where((o) => diet.allowsFoodAllergy(o.value))
        .toList();
  }
}

/// One India zone for the living-area question (region → states).
class IndiaLivingRegion {
  const IndiaLivingRegion({
    required this.value,
    required this.label,
    required this.states,
    this.emoji,
  });

  final String value;
  final String label;
  final String? emoji;
  final List<HabitOption> states;

  HabitOption get asOption =>
      HabitOption(value: value, label: label, emoji: emoji);
}

class HabitOption {
  const HabitOption({required this.value, required this.label, this.emoji});

  final String value;
  final String label;
  final String? emoji;
}
