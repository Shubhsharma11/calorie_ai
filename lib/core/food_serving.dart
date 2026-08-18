/// Household servings (bowl, plate, piece) vs grams for Indian food portions.
abstract final class FoodServing {
  static const _unitAliases = {
    'bowls': 'bowl',
    'plates': 'plate',
    'pieces': 'piece',
    'pcs': 'piece',
    'pc': 'piece',
    'cups': 'cup',
    'glasses': 'glass',
    'slices': 'slice',
    'servings': 'serving',
    'tablespoon': 'tbsp',
    'tablespoons': 'tbsp',
    'teaspoon': 'tsp',
    'teaspoons': 'tsp',
    'katoris': 'katori',
    'rotis': 'roti',
    'chapatis': 'chapati',
    'chapathi': 'chapati',
    'pooris': 'poori',
    'idlis': 'idli',
    'dosas': 'dosa',
    'scoops': 'scoop',
    'burger': 'piece',
    'burgers': 'piece',
    'sandwich': 'piece',
    'sandwiches': 'piece',
    'patty': 'piece',
    'patties': 'piece',
    'item': 'piece',
    'items': 'piece',
    'each': 'piece',
    'ea': 'piece',
    'gm': 'g',
    'gram': 'g',
    'grams': 'g',
    'milliliter': 'ml',
    'milliliters': 'ml',
    'millilitre': 'ml',
    'millilitres': 'ml',
  };

  /// Typical cooked weight for one household unit when the API omits grams.
  static const typicalGramsPerUnit = {
    'bowl': 220,
    'katori': 150,
    'plate': 300,
    'cup': 240,
    'glass': 250,
    'piece': 40,
    'roti': 40,
    'chapati': 40,
    'poori': 30,
    'idli': 40,
    'dosa': 80,
    'slice': 30,
    'tbsp': 15,
    'tsp': 5,
    'serving': 150,
    'scoop': 30,
    'handful': 30,
  };

  static final _descriptionPattern = RegExp(
    r'^\s*(\d+(?:\.\d+)?)\s*'
    r'([A-Za-z][A-Za-z\s]*?)'
    r'(?:\s*\(\s*(\d+(?:\.\d+)?)\s*(g|gm|grams?|ml)\s*\))?'
    r'\s*$',
    caseSensitive: false,
  );

  static bool isMetricUnit(String unit) {
    final normalized = normalizeUnit(unit);
    return normalized == 'g' || normalized == 'ml';
  }

  static bool isHouseholdUnit(String unit) => !isMetricUnit(unit);

  /// Piece / bowl / serving counts use the count stepper, not grams.
  static bool usesCountStepper(String unit) => isHouseholdUnit(unit);

  static double quantityMin(String unit) => usesCountStepper(unit) ? 0.5 : 1;

  /// +/- amount for the portion stepper.
  ///
  /// Gram foods used to jump by 50, so a burger stored as `1 serving`
  /// (or `1 g`) became 51. Count units step by 0.5; grams/ml scale with size.
  static double quantityStep({required String unit, required double quantity}) {
    if (usesCountStepper(unit)) return 0.5;
    if (quantity <= 10) return 1;
    if (quantity < 100) return 5;
    return 10;
  }

  static double steppedQuantity({
    required String unit,
    required double quantity,
    required int direction,
  }) {
    if (direction == 0) return quantity;
    final step = quantityStep(unit: unit, quantity: quantity);
    final min = quantityMin(unit);
    final next = quantity + direction * step;
    final rounded = usesCountStepper(unit)
        ? (next * 2).round() / 2
        : next.roundToDouble();
    if (rounded < min) return min;
    if (rounded > 5000) return 5000;
    return rounded;
  }

  static int typicalGramsFor(String unit) {
    final normalized = normalizeUnit(unit);
    if (isMetricUnit(normalized)) return 1;
    return typicalGramsPerUnit[normalized] ?? 100;
  }

  static int gramsForQuantity({
    required double quantity,
    required String unit,
  }) {
    if (isMetricUnit(unit)) {
      return quantity.round().clamp(1, 5000);
    }
    return (quantity * typicalGramsFor(unit)).round().clamp(1, 5000);
  }

  static String normalizeUnit(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return 'g';
    return _unitAliases[trimmed] ?? trimmed;
  }

  static String format({required double quantity, required String unit}) {
    final normalized = normalizeUnit(unit);
    final formatted = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(1);
    return '$formatted ${pluralize(normalized, quantity)}';
  }

  /// User-facing label: `1 Bowl (220 g)`, `1 Glass (250 g)`.
  static String formatVisible({
    required double quantity,
    required String unit,
    int? grams,
  }) {
    final normalized = normalizeUnit(unit);
    final formatted = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(1);
    var unitLabel = pluralize(normalized, quantity);
    if (isHouseholdUnit(normalized) && unitLabel.isNotEmpty) {
      unitLabel = '${unitLabel[0].toUpperCase()}${unitLabel.substring(1)}';
    }
    final base = '$formatted $unitLabel';
    if (grams != null && grams > 0 && isHouseholdUnit(normalized)) {
      return '$base ($grams g)';
    }
    return base;
  }

  static String pluralize(String unit, double quantity) {
    final normalized = normalizeUnit(unit);
    if (normalized == 'g' ||
        normalized == 'ml' ||
        normalized == 'tbsp' ||
        normalized == 'tsp') {
      return normalized;
    }
    if (quantity == 1) return normalized;
    return switch (normalized) {
      'piece' => 'pieces',
      'serving' => 'servings',
      'cup' => 'cups',
      'bowl' => 'bowls',
      'plate' => 'plates',
      'glass' => 'glasses',
      'slice' => 'slices',
      'katori' => 'katoris',
      'roti' => 'rotis',
      'chapati' => 'chapatis',
      'poori' => 'pooris',
      'idli' => 'idlis',
      'dosa' => 'dosas',
      'scoop' => 'scoops',
      _ => normalized,
    };
  }

  static FoodServingInfo parseFromApi(Map<String, dynamic> json) {
    final servingWeight = _readNum(json, const [
      'servingWeight',
      'serving_weight',
    ]);
    final fromText = _firstDescription(json);
    if (fromText != null) {
      if (fromText.isHousehold &&
          servingWeight != null &&
          servingWeight > 0 &&
          fromText.quantity > 0) {
        return FoodServingInfo(
          quantity: fromText.quantity,
          unit: fromText.unit,
          gramsPerServing: (servingWeight / fromText.quantity).round().clamp(
            1,
            5000,
          ),
        );
      }
      return fromText;
    }

    final nested = json['serving'] ?? json['portion'] ?? json['servingSize'];
    if (nested is Map) {
      final fromNested = parseFromApi(Map<String, dynamic>.from(nested));
      if (fromNested.isHousehold ||
          fromNested.quantity != 100 ||
          fromNested.unit != 'g') {
        return fromNested;
      }
    }

    return _fromStructuredFields(json);
  }

  static String? categoryFromApi(Map<String, dynamic> json) {
    return _readString(json, const [
      'category',
      'foodCategory',
      'food_category',
      'foodType',
      'food_type',
      'cuisine',
    ]);
  }

  static FoodServingInfo? parseDescription(String raw) {
    final match = _descriptionPattern.firstMatch(raw.trim());
    if (match == null) return null;

    final quantity = double.tryParse(match.group(1) ?? '') ?? 1;
    final unit = normalizeUnit(match.group(2) ?? 'g');
    final grams = double.tryParse(match.group(3) ?? '');

    if (isMetricUnit(unit)) {
      final amount = grams?.round() ?? quantity.round().clamp(1, 5000);
      return FoodServingInfo(
        quantity: amount.toDouble(),
        unit: unit == 'ml' ? 'ml' : 'g',
        gramsPerServing: 1,
      );
    }

    final perUnit = grams != null && quantity > 0
        ? (grams / quantity).round().clamp(1, 5000)
        : (typicalGramsPerUnit[unit] ?? 100);
    return FoodServingInfo(
      quantity: quantity <= 0 ? 1 : quantity,
      unit: unit,
      gramsPerServing: perUnit,
    );
  }

  static FoodServingInfo _fromStructuredFields(Map<String, dynamic> json) {
    final quantity = _readNum(json, const [
      'servingQuantity',
      'quantity',
      'serving_quantity',
      'portionQuantity',
    ]);
    final unitRaw = _readString(json, const [
      'servingUnit',
      'unit',
      'serving_unit',
      'portionUnit',
    ]);
    final grams = _readNum(json, const [
      'gramsPerServing',
      'grams_per_serving',
      'servingGrams',
      'serving_grams',
      'weightGrams',
      'weight_grams',
      'grams',
      'weight',
    ]);

    if (quantity == null && unitRaw == null && grams == null) {
      return const FoodServingInfo(
        quantity: 100,
        unit: 'g',
        gramsPerServing: 1,
      );
    }

    final unit = normalizeUnit(unitRaw ?? 'g');
    if (isHouseholdUnit(unit)) {
      final count = (quantity == null || quantity <= 0)
          ? 1.0
          : quantity.toDouble();
      final perUnit = grams != null && count > 0
          ? (grams / count).round().clamp(1, 5000)
          : (typicalGramsPerUnit[unit] ?? 100);
      return FoodServingInfo(
        quantity: count,
        unit: unit,
        gramsPerServing: perUnit,
      );
    }

    if (unitRaw == null &&
        grams == null &&
        quantity != null &&
        quantity <= 10) {
      return const FoodServingInfo(
        quantity: 100,
        unit: 'g',
        gramsPerServing: 1,
      );
    }

    final metricAmount = (grams?.round() ?? quantity?.round() ?? 100).clamp(
      1,
      5000,
    );
    return FoodServingInfo(
      quantity: metricAmount.toDouble(),
      unit: unit == 'ml' ? 'ml' : 'g',
      gramsPerServing: 1,
    );
  }

  static FoodServingInfo? _firstDescription(Map<String, dynamic> json) {
    const keys = [
      'serving',
      'servingSize',
      'serving_size',
      'portion',
      'portionSize',
      'portion_size',
      'servingDescription',
      'serving_description',
    ];
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final parsed = parseDescription(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static num? _readNum(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

class FoodServingInfo {
  const FoodServingInfo({
    required this.quantity,
    required this.unit,
    required this.gramsPerServing,
  });

  final double quantity;
  final String unit;
  final int gramsPerServing;

  bool get isHousehold => FoodServing.isHouseholdUnit(unit);

  int get defaultGrams {
    if (isHousehold) {
      return (quantity * gramsPerServing).round().clamp(1, 5000);
    }
    return quantity.round().clamp(1, 5000);
  }
}
