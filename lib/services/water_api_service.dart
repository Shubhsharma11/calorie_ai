import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../models/api_water_mapper.dart';
import '../models/water_log_entry.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class WaterApiException implements Exception {
  const WaterApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class WaterApiService {
  WaterApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const int defaultPageLimit = 30;

  /// GET /api/v1/water?date=YYYY-MM-DD — today's entries + daily total.
  Future<WaterFetchResult> fetchWaterByDate({
    required String accessToken,
    required DateTime date,
  }) {
    return _fetch(
      accessToken: accessToken,
      endpoint: ApiEndpoints.waterWithQuery(date: date),
      fallbackDate: date,
    );
  }

  /// GET /api/v1/water?page=1&limit=30 — paginated history.
  Future<WaterFetchResult> fetchWaterHistory({
    required String accessToken,
    int page = 1,
    int limit = defaultPageLimit,
  }) {
    return _fetch(
      accessToken: accessToken,
      endpoint: ApiEndpoints.waterWithQuery(page: page, limit: limit),
    );
  }

  Future<WaterFetchResult> _fetch({
    required String accessToken,
    required String endpoint,
    DateTime? fallbackDate,
  }) async {
    debugPrint(
      'WaterApiService: GET ${ApiEndpoints.url(endpoint)} '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.get(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseFetchResponse(response, fallbackDate: fallbackDate);
  }

  Future<WaterLogResponse> logWater({
    required String accessToken,
    required int amountMl,
    DateTime? date,
  }) async {
    final body = ApiWaterMapper.requestBodyFromMl(amountMl, date: date);

    debugPrint(
      'WaterApiService: POST ${ApiEndpoints.waterUrl} $body '
      'bearerTokenLength=${accessToken.length} '
      'timezone=${resolveApiTimezone()}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.water,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    return _parseLogResponse(response);
  }

  Future<void> deleteWater({
    required String accessToken,
    required String waterId,
  }) async {
    final endpoint = ApiEndpoints.waterById(waterId);
    debugPrint(
      'WaterApiService: DELETE ${ApiEndpoints.url(endpoint)} '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.delete(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    _parseDeleteResponse(response, waterId: waterId);
  }

  void _parseDeleteResponse(http.Response response, {required String waterId}) {
    final body = response.body.trim();
    debugPrint('WaterApiService: DELETE response ${response.statusCode}: $body');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('WaterApiService: DELETE /api/v1/water/$waterId OK');
      return;
    }

    final decoded = _tryDecodeJson(body);
    final message = decoded is Map<String, dynamic>
        ? decoded['message'] as String? ?? decoded['error'] as String?
        : null;
    throw WaterApiException(
      message ??
          'Delete water failed (${response.statusCode}). '
          'URL: ${ApiEndpoints.waterByIdUrl(waterId)}',
      statusCode: response.statusCode,
    );
  }

  WaterFetchResult _parseFetchResponse(
    http.Response response, {
    DateTime? fallbackDate,
  }) {
    final body = response.body.trim();
    debugPrint('WaterApiService: response ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw WaterApiException(
        message ?? 'Water request failed (${response.statusCode}). $body',
        statusCode: response.statusCode,
      );
    }

    if (decoded == null) {
      return const WaterFetchResult();
    }

    if (decoded is Map<String, dynamic>) {
      return ApiWaterMapper.fetchResultFromResponse(
        decoded,
        fallbackDate: fallbackDate,
      );
    }

    if (decoded is List) {
      return ApiWaterMapper.fetchResultFromResponse(
        {'data': decoded},
        fallbackDate: fallbackDate,
      );
    }

    throw const WaterApiException('Water response was not valid JSON.');
  }

  WaterLogResponse _parseLogResponse(http.Response response) {
    final body = response.body.trim();
    final statusCode = response.statusCode;
    debugPrint('WaterApiService: POST response HTTP $statusCode: $body');

    if (statusCode >= 200 && statusCode < 300 && body.isEmpty) {
      return const WaterLogResponse();
    }

    final decoded = _tryDecodeJson(body);

    if (statusCode < 200 || statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw WaterApiException(
        message ?? 'Water sync failed ($statusCode). $body',
        statusCode: statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return ApiWaterMapper.logResponseFromJson(decoded);
    }

    return const WaterLogResponse();
  }

  dynamic _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
