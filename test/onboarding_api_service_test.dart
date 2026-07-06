import 'dart:convert';

import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/api_endpoints.dart';
import 'package:calorie_ai/services/onboarding_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('OnboardingApiService fetches onboarding profile', () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'personalDetails': {
              'age': 29,
              'gender': 'Female',
              'heightCm': 165,
              'weight': 62,
              'weightUnit': 'kg',
            },
            'activityLevel': 'moderatelyActive',
            'goal': 'loseWeight',
          },
        }),
        200,
      );
    });

    final service = OnboardingApiService(apiClient: ApiClient(client: client));
    final response = await service.fetchOnboarding(accessToken: 'token-123');

    expect(capturedUri.path, ApiEndpoints.onboarding);
    expect(capturedHeaders['Authorization'], 'Bearer token-123');
    expect(response.success, isTrue);
    expect(response.raw?['data'], isNotNull);
  });
}
