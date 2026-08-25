import 'dart:convert';


import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/api_endpoints.dart';   
import 'package:calorie_ai/services/weight_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';                                                                 
   
void main() {
  test('WeightApiService posts weight payload with bearer token', () async {
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
            'weightEntry': {
              'id': 'w-1',
              'weightKg': 68,
              'recordedAt': '2026-06-29T12:00:00.000Z',
            },
            'profileUpdated': true,
          },
        }),
        201,
      );
    });

    final service = WeightApiService(apiClient: ApiClient(client: client));

    final response = await service.logWeight(
      accessToken: 'token-123',
      weight: 68,
      weightUnit: 'kg',
      recordedAt: DateTime(2026, 6, 29),
    );

    expect(capturedUri.path, ApiEndpoints.weight);
    expect(capturedHeaders['Authorization'], 'Bearer token-123');
    expect(capturedBody, {
      'weight': 68,
      'weightUnit': 'kg',
      'recordedAt': '2026-06-29',
    }); 
    expect(response.entry?.kg, 68);
    expect(response.profileUpdated, isTrue);
  });

  test('WeightApiService fetches weight history by period', () async {
    late Uri capturedUri;

    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'entries': [
              {
                '_id': 'w-1',
                'weight': 68,
                'weightUnit': 'kg',
                'weightKg': 68,
                'recordedAt': '2026-06-29T12:00:00.000Z',
              },
            ],
            'meta': {
              'page': 1,
              'limit': 30,
              'total': 1, 
              'totalPages': 1,
              'period': 'today',
            },
          },
        }),
        200,
      );
    });

    final service = WeightApiService(apiClient: ApiClient(client: client));
    final entries = await service.fetchWeights(
      accessToken: 'token-123',
      period: 'today',
    );

    expect(capturedUri.path, ApiEndpoints.weight);
    expect(capturedUri.queryParameters, {'period': 'today'});
    expect(entries, hasLength(1));
    expect(entries.first.kg, 68);
    expect(entries.first.id, 'w-1');
  });

  test('WeightApiService fetches paginated weight history', () async {
    late Uri capturedUri;

    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'entries': [
              {
                'id': 'w-1',
                'weightKg': 70,
                'recordedAt': '2026-06-27T08:00:00.000Z',
              },
            ],
          },
        }),
        200,
      );
    });

    final service = WeightApiService(apiClient: ApiClient(client: client));
    final entries = await service.fetchWeights(
      accessToken: 'token-123',
      page: 1,
      limit: 30,
    );

    expect(capturedUri.path, ApiEndpoints.weight);
    expect(capturedUri.queryParameters, {'page': '1', 'limit': '30'});
    expect(entries, hasLength(1));
    expect(entries.first.kg, 70);
  });

  test('WeightApiService fetches weight for a specific date', () async {
    late Uri capturedUri;

    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'weightEntry': {
              'id': 'w-2',
              'weightKg': 68,
              'recordedAt': '2026-06-29T12:00:00.000Z',
            },
          },
        }),
        200,
      );
    });

    final service = WeightApiService(apiClient: ApiClient(client: client));
    final entries = await service.fetchWeights(
      accessToken: 'token-123',
      date: DateTime(2026, 6, 29),
    );

    expect(capturedUri.queryParameters['date'], '2026-06-29');
    expect(capturedUri.queryParameters.containsKey('page'), isFalse);
    expect(entries.single.kg, 68);
  });

  test('WeightApiService throws on non-success response', () async {
    final client = MockClient(
      (_) async => http.Response('{"message":"Unauthorized"}', 401),
    );
    final service = WeightApiService(apiClient: ApiClient(client: client));

    expect(
      () => service.logWeight(
        accessToken: 'bad-token',
        weight: 70,
      ),
      throwsA(isA<WeightApiException>()),
    );
  });

  test('WeightApiService deletes weight entry by id', () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      return http.Response(
        jsonEncode({'success': true, 'message': 'Deleted'}),
        200,
      );
    });

    final service = WeightApiService(apiClient: ApiClient(client: client));

    await service.deleteWeight(
      accessToken: 'token-123',
      weightId: 'w-42',
    );

    expect(capturedUri.path, ApiEndpoints.weightById('w-42'));
    expect(capturedHeaders['Authorization'], 'Bearer token-123');
  });
}
