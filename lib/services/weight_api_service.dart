import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_weight_mapper.dart';
import '../models/meal_entry.dart';
import '../models/weight_entry.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class WeightApiException implements Exception {
  const WeightApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class WeightApiService {
  WeightApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<WeightEntry>> fetchWeights({
    required String accessToken,
    DateTime? date,
    int page = 1,
    int limit = 30,
  }) async {
    final endpoint = ApiEndpoints.weightWithQuery(
      date: date,
      page: date == null ? page : null,
      limit: date == null ? limit : null,
    );
    debugPrint(
      'WeightApiService: GET ${ApiEndpoints.url(endpoint)} '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.get(
      endpoint,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    return _parseListResponse(response, fallbackDate: date);
  }

  Future<WeightLogResponse> logWeight({
    required String accessToken,
    required double weight,
    String weightUnit = 'kg',
    DateTime? recordedAt,
  }) async {
    final body = {
      'weight': _roundWeight(weight),
      'weightUnit': weightUnit,
      if (recordedAt != null) 'recordedAt': MealEntry.dateToKey(recordedAt),
    };

    debugPrint(
      'WeightApiService: POST ${ApiEndpoints.weightUrl} $body '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.weight,
      headers: {'Authorization': 'Bearer $accessToken'},
      body: body,
    );

    return _parseLogResponse(response);
  }

  Future<void> deleteWeight({
    required String accessToken,
    required String weightId,
  }) async {
    final endpoint = ApiEndpoints.weightById(weightId);
    debugPrint(
      'WeightApiService: DELETE ${ApiEndpoints.url(endpoint)} '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.delete(
      endpoint,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    _parseDeleteResponse(response, weightId: weightId);
  }

  void _parseDeleteResponse(http.Response response, {required String weightId}) {
    final body = response.body.trim();
    debugPrint('WeightApiService: DELETE response ${response.statusCode}: $body');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('WeightApiService: DELETE /api/v1/weight/$weightId OK');
      return;
    }

    final decoded = _tryDecodeJson(body);
    final message = decoded is Map<String, dynamic>
        ? decoded['message'] as String? ?? decoded['error'] as String?
        : null;
    throw WeightApiException(
      message ??
          'Delete weight failed (${response.statusCode}). '
          'URL: ${ApiEndpoints.weightByIdUrl(weightId)}',
      statusCode: response.statusCode,
    );
  }

  List<WeightEntry> _parseListResponse(
    http.Response response, {
    DateTime? fallbackDate,
  }) {
    final body = response.body.trim();
    debugPrint('WeightApiService: response ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw WeightApiException(
        message ?? 'Weight request failed (${response.statusCode}). $body',
        statusCode: response.statusCode,
      );
    }

    if (decoded == null) {
      return const <WeightEntry>[];
    }

    if (decoded is Map<String, dynamic>) {
      return ApiWeightMapper.entriesFromResponse(
        decoded,
        fallbackDate: fallbackDate,
      );
    }

    if (decoded is List) {
      return ApiWeightMapper.entriesFromResponse(
        {'data': decoded},
        fallbackDate: fallbackDate,
      );
    }

    throw const WeightApiException('Weight response was not valid JSON.');
  }

  WeightLogResponse _parseLogResponse(http.Response response) {
    final body = response.body.trim();
    final statusCode = response.statusCode;
    debugPrint('WeightApiService: POST response HTTP $statusCode: $body');

    if (statusCode >= 200 && statusCode < 300 && body.isEmpty) {
      if (statusCode == 200 || statusCode == 201) {
        debugPrint('WeightApiService: POST /api/v1/weight OK HTTP $statusCode');
      }
      return const WeightLogResponse();
    }

    final decoded = _tryDecodeJson(body);

    if (statusCode < 200 || statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw WeightApiException(
        message ?? 'Weight sync failed ($statusCode). $body',
        statusCode: statusCode,
      );
    }

    if (statusCode == 200 || statusCode == 201) {
      debugPrint('WeightApiService: POST /api/v1/weight OK HTTP $statusCode');
    } else {
      debugPrint(
        'WeightApiService: POST /api/v1/weight HTTP $statusCode (2xx, not 200/201)',
      );
    }

    if (decoded is Map<String, dynamic>) {
      final parsed = ApiWeightMapper.logResponseFromJson(decoded);
      debugPrint(
        'WeightApiService: parsed weightEntry '
        'kg=${parsed.entry?.kg} '
        'date=${parsed.entry?.date} '
        'profileUpdated=${parsed.profileUpdated}',
      );
      return parsed;
    }

    debugPrint('WeightApiService: POST body was not JSON object');
    return const WeightLogResponse();
  }

  num _roundWeight(double weight) {
    final rounded = double.parse(weight.toStringAsFixed(1));
    return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
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
