import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../models/food_item.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class FoodApiException implements Exception {
  const FoodApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Food search via `GET /api/v1/search/foods` only — no local catalog.
/// Barcode lookup still uses Open Food Facts for packaged products.
class FoodApiService {
  FoodApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Search foods from the FitBuddy API only.
  Future<List<FoodItem>> searchFoods(
    String query, {
    String? accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    if (accessToken == null || accessToken.isEmpty) {
      throw const FoodApiException('Sign in to search foods.');
    }

    final endpoint = ApiEndpoints.searchFoodsWithQuery(
      search: trimmed,
      page: page < 1 ? 1 : page,
      limit: limit.clamp(1, 100),
    );

    debugPrint('FoodApiService: GET ${ApiEndpoints.url(endpoint)}');
    final response = await _apiClient.get(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );
    final foods = _parseSearchResponse(response);
    debugPrint(
      'FoodApiService: search "$trimmed" → ${foods.length} result(s)',
    );
    return foods;
  }

  List<FoodItem> _parseSearchResponse(http.Response response) {
    final body = response.body.trim();
    debugPrint(
      'FoodApiService: search response ${response.statusCode}: '
      '${body.length > 400 ? '${body.substring(0, 400)}…' : body}',
    );

    dynamic decoded;
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message'] as String?) ?? (decoded['error'] as String?)
          : null;
      throw FoodApiException(
        message ?? 'Food search failed (${response.statusCode}). $body',
        statusCode: response.statusCode,
      );
    }

    return foodsFromSearchPayload(decoded);
  }

  /// Parses common backend shapes: `data: []`, `data.foods`, `data.results`, etc.
  static List<FoodItem> foodsFromSearchPayload(dynamic decoded) {
    final maps = _foodMapsFromPayload(decoded);
    final foods = <FoodItem>[];
    for (final map in maps) {
      final food = foodFromApiJson(map);
      if (food != null) foods.add(food);
    }
    return foods;
  }

  static List<Map<String, dynamic>> _foodMapsFromPayload(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (decoded is! Map) return const [];

    final root = Map<String, dynamic>.from(decoded);
    final data = root['data'];

    if (data is List) {
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }

    if (data is Map) {
      final nested = data['foods'] ??
          data['items'] ??
          data['results'] ??
          data['records'] ??
          data['docs'];
      if (nested is List) {
        return nested.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    }

    final top = root['foods'] ?? root['items'] ?? root['results'];
    if (top is List) {
      return top.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }

    return const [];
  }

  static FoodItem? foodFromApiJson(Map<String, dynamic> json) {
    final nestedFood = json['food'];
    final source = nestedFood is Map
        ? Map<String, dynamic>.from(nestedFood)
        : json;

    final name = _readString(source, const [
      'name',
      'foodName',
      'food_name',
      'title',
      'productName',
      'product_name',
    ]);
    if (name == null || name.isEmpty) return null;

    final calories = _readNum(source, const [
          'caloriesPer100g',
          'calories_per_100g',
          'calories',
          'kcal',
          'energyKcal',
          'energy_kcal',
        ])?.round() ??
        0;

    final protein = _readNum(source, const [
          'protein',
          'proteins',
          'proteinG',
          'protein_g',
        ])?.toDouble() ??
        0;
    final carbs = _readNum(source, const [
          'carbs',
          'carbohydrates',
          'carb',
          'carbsG',
          'carbs_g',
        ])?.toDouble() ??
        0;
    final fat = _readNum(source, const [
          'fat',
          'fats',
          'fatG',
          'fat_g',
        ])?.toDouble() ??
        0;

    final emoji = _readString(source, const ['emoji', 'icon']) ?? '🍽️';
    final imageUrl = _readString(source, const [
      'image',
      'imageUrl',
      'image_url',
      'photo',
      'photoUrl',
      'thumbnail',
      'thumbnailUrl',
    ]);

    return FoodItem(
      name: name,
      caloriesPer100g: calories.clamp(0, 2000),
      protein: protein.clamp(0, 200),
      carbs: carbs.clamp(0, 200),
      fat: fat.clamp(0, 200),
      emoji: emoji,
      imageUrl: imageUrl,
    );
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
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

    final imageUrl = (item['image_front_small_url'] as String?)?.trim().isNotEmpty == true
        ? (item['image_front_small_url'] as String).trim()
        : (item['image_front_url'] as String?)?.trim().isNotEmpty == true
            ? (item['image_front_url'] as String).trim()
            : (item['image_url'] as String?)?.trim().isNotEmpty == true
                ? (item['image_url'] as String).trim()
                : null;

    return FoodItem(
      name: name,
      caloriesPer100g: _readKcal(nutriments),
      protein: _asDouble(nutriments['proteins_100g']),
      carbs: _asDouble(nutriments['carbohydrates_100g']),
      fat: _asDouble(nutriments['fat_100g']),
      emoji: '🍱',
      imageUrl: imageUrl,
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
