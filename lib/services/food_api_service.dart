import 'dart:convert';

import '../data/indian_foods_data.dart';
import '../models/food_item.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

/// Food search uses a curated Indian foods database.
/// Barcode lookup still uses Open Food Facts for packaged products.
class FoodApiService {
  FoodApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  List<FoodItem> get popularFoods => popularIndianFoods;

  Future<List<FoodItem>> searchFoods(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final lower = trimmed.toLowerCase();
    final words = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

    final matches = indianFoods.where((food) {
      final name = food.name.toLowerCase();
      if (name.contains(lower)) return true;
      return words.every((word) => name.contains(word));
    }).toList();

    matches.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      final aStarts = aName.startsWith(lower);
      final bStarts = bName.startsWith(lower);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return aName.compareTo(bName);
    });

    return matches;
  }

  Future<FoodItem?> lookupBarcode(String barcode) async {
    final response = await _apiClient.get(
      ApiEndpoints.openFoodFactsProduct(barcode),
      baseUrl: ApiEndpoints.openFoodFactsBaseUrl,
    );
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 1) return null;

    final product = data['product'] as Map<String, dynamic>?;
    if (product == null) return null;

    return _parseProduct(product);
  }

  FoodItem _parseProduct(Map<String, dynamic> item) {
    final nutriments = item['nutriments'] as Map<String, dynamic>? ?? {};

    return FoodItem(
      name: (item['product_name'] as String?)?.trim() ?? 'Unknown',
      caloriesPer100g: (nutriments['energy-kcal_100g'] as num?)?.round() ?? 0,
      protein: (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0,
      carbs: (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0,
      fat: (nutriments['fat_100g'] as num?)?.toDouble() ?? 0,
      emoji: '🍱',
    );
  }
}
