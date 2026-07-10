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
}
