class FoodItem {
  const FoodItem({
    required this.name,
    required this.caloriesPer100g,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.emoji = '🍽️',
    
  });

  final String name;
  final int caloriesPer100g;
  final double protein;
  final double carbs;
  final double fat;
  final String emoji;

  int caloriesForGrams(int grams) =>
      (caloriesPer100g * grams / 100).round();

  double macroForGrams(double per100g, int grams) =>
      per100g * grams / 100;

  Map<String, dynamic> toJson() => {
        'name': name,
        'caloriesPer100g': caloriesPer100g,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'emoji': emoji,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'] as String,
        caloriesPer100g: json['caloriesPer100g'] as int,
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        emoji: json['emoji'] as String? ?? '🍽️',
      );
}
