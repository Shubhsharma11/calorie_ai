import 'dart:convert';

import 'package:calorie_ai/models/custom_meal_preset.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:calorie_ai/models/saved_meal_item.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/api_endpoints.dart';
import 'package:calorie_ai/services/custom_meals_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('CustomMealsApiService posts custom meal with bearer token', () async {
    late Map<String, dynamic> capturedBody;
    late Map<String, String> capturedHeaders;
    late Uri capturedUri;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      capturedBody = jsonDecode(request.body as String) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 'custom-1',
            'name': 'Oat Meal',
            'mealTime': 'breakfast',
            'visibility': 'public',
            'totalNutrients': {
              'calories': 473,
              'protein': 14,
              'fat': 7,
              'carbs': 88,
            },
            'items': capturedBody['items'],
          },
        }),
        201,
      );
    });

    final service = CustomMealsApiService(apiClient: ApiClient(client: client));

    const oats = FoodItem(
      name: 'oats',
      caloriesPer100g: 389,
      protein: 13,
      carbs: 66,
      fat: 7,
    );

    final preset = CustomMealPreset(
      id: 'local-1',
      name: 'Oat Meal',
      createdAt: DateTime(2026, 7, 10),
      meal: MealType.breakfast,
      visibility: MealShareVisibility.public,
      items: const [
        SavedMealItem(
          food: oats,
          grams: 100,
          meal: MealType.breakfast,
        ),
      ],
    );

    final response = await service.createCustomMeal(
      accessToken: 'token-123',
      preset: preset,
    );

    expect(capturedUri.path, ApiEndpoints.mealsCustom);
    expect(capturedHeaders['Authorization'], 'Bearer token-123');
    expect(capturedHeaders['X-Timezone'], isNotEmpty);
    expect(capturedBody['name'], 'Oat Meal');
    expect(capturedBody['mealTime'], 'breakfast');
    expect(capturedBody['visibility'], 'public');
    expect(response.id, 'custom-1');
    expect(response.name, 'Oat Meal');
  });

  test('CustomMealsApiService fetches custom meals with bearer token', () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 'custom-1',
              'name': 'Oat Meal',
              'mealTime': 'breakfast',
              'visibility': 'public',
              'items': [
                {
                  'name': 'oats',
                  'quantity': 100,
                  'unit': 'gm',
                  'calories': 389,
                  'protein': 13,
                  'fat': 7,
                  'carbs': 66,
                },
              ],
            },
          ],
        }),
        200,
      );
    });

    final service = CustomMealsApiService(apiClient: ApiClient(client: client));

    final presets = await service.fetchCustomMeals(accessToken: 'token-123');

    expect(capturedUri.path, ApiEndpoints.mealsCustom);
    expect(capturedHeaders['Authorization'], 'Bearer token-123');
    expect(capturedHeaders['X-Timezone'], isNotEmpty);
    expect(presets.length, 1);
    expect(presets.first.id, 'custom-1');
    expect(presets.first.name, 'Oat Meal');
  });
}
