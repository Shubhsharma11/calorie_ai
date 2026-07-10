import 'dart:convert';

import 'package:calorie_ai/core/api_timezone.dart';
import 'package:calorie_ai/models/api_water_mapper.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/api_endpoints.dart';
import 'package:calorie_ai/services/water_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiWaterMapper.requestBodyFromMl', () {
    test('sends quantity in ml', () {
      expect(
        ApiWaterMapper.requestBodyFromMl(500),
        {'quantity': 500, 'unit': 'ml'},
      );
    });
  });

  group('ApiWaterMapper.fetchResultFromResponse', () {
    test('parses date query with daily total', () {
      final result = ApiWaterMapper.fetchResultFromResponse(
        {
          'success': true,
          'data': {
            'date': '2026-07-09',
            'dailyTotalMl': 1500,
            'entries': [
              {
                'id': 'w-1',
                'quantity': 500,
                'unit': 'ml',
                'recordedAt': '2026-07-09T08:00:00.000Z',
              },
              {
                'id': 'w-2',
                'quantity': 1000,
                'unit': 'ml',
                'recordedAt': '2026-07-09T18:00:00.000Z',
              },
            ],
          },
        },
        fallbackDate: DateTime(2026, 7, 9),
      );

      expect(result.entries.length, 2);
      expect(result.dailyTotalFor(DateTime(2026, 7, 9)), 1500);
    });

    test('aggregates paginated entries by day', () {
      final result = ApiWaterMapper.fetchResultFromResponse({
        'success': true,
        'data': {
          'entries': [
            {
              'quantity': 500,
              'unit': 'ml',
              'recordedAt': '2026-07-09T12:00:00.000Z',
            },
            {
              'quantity': 250,
              'unit': 'ml',
              'recordedAt': '2026-07-08T12:00:00.000Z',
            },
          ],
          'meta': {'page': 1, 'limit': 30, 'total': 2},
        },
      });

      expect(result.dailyTotalsMl.length, 2);
      expect(result.dailyTotalFor(DateTime(2026, 7, 9)), 500);
      expect(result.dailyTotalFor(DateTime(2026, 7, 8)), 250);
    });
  });

  test('WaterApiService posts water payload with timezone header', () async {
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
            'waterEntry': {
              'id': 'water-1',
              'quantity': 500,
              'unit': 'ml',
              'recordedAt': '2026-07-09T12:00:00.000Z',
            },
            'dailyTotalMl': 500,
          },
        }),
        201,
      );
    });

    final service = WaterApiService(apiClient: ApiClient(client: client));

    final response = await service.logWater(
      accessToken: 'token-123',
      amountMl: 500,
    );

    expect(capturedUri.path, ApiEndpoints.water);
    expect(capturedHeaders['Authorization'], 'Bearer token-123');
    expect(capturedHeaders['X-Timezone'], resolveApiTimezone());
    expect(capturedBody, {'quantity': 500, 'unit': 'ml'});
    expect(response.dailyTotalMl, 500);
  });

  test('WaterApiService fetches today by date query', () async {
    late Uri capturedUri;

    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'date': '2026-07-09',
            'dailyTotalMl': 1500,
            'entries': [
              {
                'id': 'water-1',
                'quantity': 500,
                'unit': 'ml',
                'recordedAt': '2026-07-09T12:00:00.000Z',
              },
              {
                'id': 'water-2',
                'quantity': 1000,
                'unit': 'ml',
                'recordedAt': '2026-07-09T18:00:00.000Z',
              },
            ],
          },
        }),
        200,
      );
    });

    final service = WaterApiService(apiClient: ApiClient(client: client));

    final result = await service.fetchWaterByDate(
      accessToken: 'token-123',
      date: DateTime(2026, 7, 9),
    );

    expect(capturedUri.queryParameters['date'], '2026-07-09');
    expect(capturedUri.queryParameters.containsKey('page'), isFalse);
    expect(result.dailyTotalFor(DateTime(2026, 7, 9)), 1500);
    expect(result.entries.length, 2);
  });

  test('WaterApiService fetches paginated history', () async {
    late Uri capturedUri;

    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'entries': [
              {
                'id': 'water-1',
                'quantity': 500,
                'unit': 'ml',
                'recordedAt': '2026-07-09T12:00:00.000Z',
              },
              {
                'id': 'water-2',
                'quantity': 1000,
                'unit': 'ml',
                'recordedAt': '2026-07-08T18:00:00.000Z',
              },
            ],
            'meta': {'page': 1, 'limit': 30, 'total': 2},
          },
        }),
        200,
      );
    });

    final service = WaterApiService(apiClient: ApiClient(client: client));

    final result = await service.fetchWaterHistory(
      accessToken: 'token-123',
      page: 1,
      limit: 30,
    );

    expect(capturedUri.queryParameters['page'], '1');
    expect(capturedUri.queryParameters['limit'], '30');
    expect(capturedUri.queryParameters.containsKey('date'), isFalse);
    expect(result.dailyTotalFor(DateTime(2026, 7, 9)), 500);
    expect(result.dailyTotalFor(DateTime(2026, 7, 8)), 1000);
  });

  test('WaterApiService deletes water entry by id', () async {
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

    final service = WaterApiService(apiClient: ApiClient(client: client));

    await service.deleteWater(
      accessToken: 'token-123',
      waterId: 'water-42',
    );

    expect(capturedUri.path, ApiEndpoints.waterById('water-42'));
    expect(capturedHeaders['Authorization'], 'Bearer token-123');
  });
}
