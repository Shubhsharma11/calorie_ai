import 'dart:convert';

import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/api_endpoints.dart';
import 'package:calorie_ai/services/meals_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('MealsApiService deletes meal with bearer token', () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      return http.Response('', 204);
    });

    final service = MealsApiService(apiClient: ApiClient(client: client));

    await service.deleteMeal(
      accessToken: 'token-123',
      mealId: 'meal-42',
    );

    expect(capturedUri.path, '${ApiEndpoints.meals}/meal-42');
    expect(capturedHeaders['Authorization'], 'Bearer token-123');
    expect(capturedHeaders['X-Timezone'], isNotEmpty);
  });

  test('MealsApiService fetches meals with period and custom dates', () async {
    late Uri capturedUri;

    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(jsonEncode({'data': []}), 200);
    });

    final service = MealsApiService(apiClient: ApiClient(client: client));

    await service.fetchMeals(
      accessToken: 'token-123',
      period: 'custom',
      fromDate: DateTime(2026, 7, 1),
      toDate: DateTime(2026, 7, 23),
    );

    expect(capturedUri.path, ApiEndpoints.meals);
    expect(capturedUri.queryParameters['period'], 'custom');
    expect(capturedUri.queryParameters['from_date'], '2026-07-01');
    expect(capturedUri.queryParameters['to_date'], '2026-07-23');
  });

  test('mealsWithQuery builds period and date URLs', () {
    expect(
      ApiEndpoints.mealsWithQuery(period: '1week'),
      '${ApiEndpoints.meals}?period=1week',
    );
    expect(
      ApiEndpoints.mealsWithQuery(period: 'today'),
      '${ApiEndpoints.meals}?period=today',
    );
    expect(
      ApiEndpoints.mealsWithQuery(date: DateTime(2026, 7, 23)),
      '${ApiEndpoints.meals}?date=2026-07-23',
    );
  });
}
