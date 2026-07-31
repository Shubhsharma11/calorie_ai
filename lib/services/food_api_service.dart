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
    final cleaned = barcode.trim();
    if (cleaned.isEmpty) return null;

    final response = await _apiClient.get(
      ApiEndpoints.openFoodFactsProduct(cleaned),
      baseUrl: ApiEndpoints.openFoodFactsBaseUrl,
      headers: const {
        // Open Food Facts asks clients to identify themselves.
        'User-Agent': 'FitBuddyAI/1.0 (Flutter; https://fitbuddyai.app)',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final status = decoded['status'];
    final found = status == 1 || status == true || status == '1';
    if (!found) return null;

    final product = decoded['product'];
    if (product is! Map<String, dynamic>) return null;

    return _parseProduct(product);
  }

  FoodItem _parseProduct(Map<String, dynamic> item) {
    final nutriments = item['nutriments'] is Map
        ? Map<String, dynamic>.from(item['nutriments'] as Map)
        : <String, dynamic>{};

    final name = (item['product_name'] as String?)?.trim().isNotEmpty == true
        ? (item['product_name'] as String).trim()
        : (item['product_name_en'] as String?)?.trim().isNotEmpty == true
            ? (item['product_name_en'] as String).trim()
            : 'Unknown product';

    return FoodItem(
      name: name,
      caloriesPer100g: _readKcal(nutriments),
      protein: _asDouble(nutriments['proteins_100g']),
      carbs: _asDouble(nutriments['carbohydrates_100g']),
      fat: _asDouble(nutriments['fat_100g']),
      emoji: '🍱',
    );
  }

  int _readKcal(Map<String, dynamic> nutriments) {
    final direct = nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'];
    if (direct is num) return direct.round();

    final kj = nutriments['energy-kj_100g'] ?? nutriments['energy_100g'];
    if (kj is num) return (kj / 4.184).round();
    return 0;
  }

  double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
