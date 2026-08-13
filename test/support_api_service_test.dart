import 'package:calorie_ai/models/problem_report.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/api_endpoints.dart';
import 'package:calorie_ai/services/support_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _deviceInfo = AppDeviceInfo(
  appVersion: '1.0.0',
  buildNumber: '12',
  platform: 'Android',
  osVersion: 'Android 15',
  deviceModel: 'Pixel 8',
);

void main() {
  test('AppDeviceInfo footer is read-only version text', () {
    expect(_deviceInfo.footerLabel, 'FitBuddy AI • v1.0.0 (Build 12)');
  });

  test('ProblemCategory omits subscription until the app has IAP', () {
    expect(
      ProblemCategory.values.map((c) => c.label),
      [
        'Food Search',
        'Meal Tracking',
        'Water Tracking',
        'Weight & Goals',
        'Notifications',
        'Login / Account',
        'App Crash',
        'Other',
      ],
    );
  });

  test('SupportApiService posts report fields with bearer token', () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;
    late String capturedBody;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      capturedBody = request.body;
      return http.Response('{"success":true}', 201);
    });

    final service = SupportApiService(apiClient: ApiClient(client: client));

    await service.submitReport(
      accessToken: 'token-123',
      category: ProblemCategory.foodSearch,
      description: 'Search crashes when I search for paneer',
      deviceInfo: _deviceInfo,
    );

    expect(capturedUri.path, ApiEndpoints.supportReports);
    expect(capturedHeaders['authorization'], 'Bearer token-123');
    expect(capturedBody, contains('food_search'));
    expect(capturedBody, contains('Search crashes when I search for paneer'));
    expect(capturedBody, contains('1.0.0'));
    expect(capturedBody, contains('Pixel 8'));
  });

  test('SupportApiService throws on server error', () async {
    final client = MockClient((request) async {
      return http.Response('{"message":"Unavailable"}', 500);
    });

    final service = SupportApiService(apiClient: ApiClient(client: client));

    expect(
      () => service.submitReport(
        accessToken: 'token-123',
        category: ProblemCategory.other,
        description: 'Something broke',
        deviceInfo: _deviceInfo,
      ),
      throwsA(
        isA<SupportApiException>().having(
          (e) => e.message,
          'message',
          'Unavailable',
        ),
      ),
    );
  });

  test('SupportApiService throws 401 with status code', () async {
    final client = MockClient((request) async {
      return http.Response('{"message":"Unauthorized"}', 401);
    });

    final service = SupportApiService(apiClient: ApiClient(client: client));

    expect(
      () => service.submitReport(
        accessToken: 'expired',
        category: ProblemCategory.appCrash,
        description: 'App closed on launch',
        deviceInfo: _deviceInfo,
      ),
      throwsA(
        isA<SupportApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'Unauthorized'),
      ),
    );
  });
}
