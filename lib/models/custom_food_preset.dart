import 'dart:convert';
import 'dart:typed_data';

import 'food_item.dart';

class CustomFoodPreset {
  const CustomFoodPreset({
    required this.id,
    required this.food,
    required this.defaultGrams,
    required this.createdAt,
    this.servingQuantity,
    this.servingUnit = 'g',
    this.nutritionBasisQuantity,
    this.imageBytes,
  });

  final String id;
  final FoodItem food;
  final int defaultGrams;
  final DateTime createdAt;
  final double? servingQuantity;
  final String servingUnit;
  final double? nutritionBasisQuantity;
  final Uint8List? imageBytes;

  double get displayedServingQuantity =>
      servingQuantity ?? defaultGrams.toDouble();

  CustomFoodPreset copyWith({
    String? id,
    FoodItem? food,
    int? defaultGrams,
    DateTime? createdAt,
    double? servingQuantity,
    String? servingUnit,
    double? nutritionBasisQuantity,
    Uint8List? imageBytes,
  }) {
    return CustomFoodPreset(
      id: id ?? this.id,
      food: food ?? this.food,
      defaultGrams: defaultGrams ?? this.defaultGrams,
      createdAt: createdAt ?? this.createdAt,
      servingQuantity: servingQuantity ?? this.servingQuantity,
      servingUnit: servingUnit ?? this.servingUnit,
      nutritionBasisQuantity:
          nutritionBasisQuantity ?? this.nutritionBasisQuantity,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'food': food.toJson(),
        'defaultGrams': defaultGrams,
        'createdAt': createdAt.toIso8601String(),
        if (servingQuantity != null) 'servingQuantity': servingQuantity,
        'servingUnit': servingUnit,
        if (nutritionBasisQuantity != null)
          'nutritionBasisQuantity': nutritionBasisQuantity,
        if (imageBytes != null) 'imageBase64': base64Encode(imageBytes!),
      };

  factory CustomFoodPreset.fromJson(Map<String, dynamic> json) {
    Uint8List? imageBytes;
    final encodedImage = json['imageBase64'];
    if (encodedImage is String && encodedImage.isNotEmpty) {
      try {
        imageBytes = base64Decode(encodedImage);
      } on FormatException {
        imageBytes = null;
      }
    }
    return CustomFoodPreset(
      id: json['id'] as String,
      food: FoodItem.fromJson(json['food'] as Map<String, dynamic>),
      defaultGrams: json['defaultGrams'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      servingQuantity: (json['servingQuantity'] as num?)?.toDouble(),
      servingUnit: json['servingUnit'] as String? ?? 'g',
      nutritionBasisQuantity:
          (json['nutritionBasisQuantity'] as num?)?.toDouble(),
      imageBytes: imageBytes,
    );
  }
}
