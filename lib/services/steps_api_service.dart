import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/safe_api_log.dart';
import '../core/api_timezone.dart';
import '../models/api_steps_mapper.dart';
import '../models/step_log_entry.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class StepsApiException implements Exception {
  const StepsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class StepsApiService {
  StepsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const int defaultPageLimit = 30;

  /// GET /api/v1/steps?date=YYYY-MM-DD
  Future<StepsFetchResult> fetchStepsByDate({
    required String accessToken,
    required DateTime date,
  }) {
    return _fetch(
      accessToken: accessToken,
      endpoint: ApiEndpoints.stepsWithQuery(date: date),
      fallbackDate: date,
    );
  }

  /// GET /api/v1/steps?page=1&limit=30
  Future<StepsFetchResult> fetchStepsHistory({
    required String accessToken,
    int page = 1,
    int limit = defaultPageLimit,
  }) {
    return _fetch(
      accessToken: accessToken,
      endpoint: ApiEndpoints.stepsWithQuery(page: page, limit: limit),
    );
  }

  Future<StepsFetchResult> _fetch({
    required String accessToken,
    required String endpoint,
    DateTime? fallbackDate,
  }) async {
    debugPrint(
      'StepsApiService: GET ${ApiEndpoints.url(endpoint)} '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.get(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseFetchResponse(response, fallbackDate: fallbackDate);
  }

  /// POST /api/v1/steps — upsert today's (or [date]) step total.
  Future<StepLogResponse> syncSteps({
    required String accessToken,
    required int steps,
    required int caloriesBurned,
    DateTime? date,
  }) async {
    final body = ApiStepsMapper.requestBody(
      steps: steps,
      caloriesBurned: caloriesBurned,
      date: date,
    );

    debugPrint(
      'StepsApiService: POST ${ApiEndpoints.stepsUrl} (payload redacted) '
      'bearerTokenLength=${accessToken.length} '
      'timezone=${resolveApiTimezone()}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.steps,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    return _parseLogResponse(response);
  }

  StepsFetchResult _parseFetchResponse(
    http.Response response, {
    DateTime? fallbackDate,
  }) {
    final body = response.body.trim();
    debugPrint('StepsApiService: GET response ${safeHttpResponseLog(response.statusCode, body)}');

    final decoded = _tryDecodeJson(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw StepsApiException(
        message ?? 'Steps request failed (${response.statusCode}). ${safeHttpErrorDetail(response.statusCode, body)}',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const StepsFetchResult();
    }

    return ApiStepsMapper.fetchResultFromResponse(
      decoded,
      fallbackDate: fallbackDate,
    );
  }

  StepLogResponse _parseLogResponse(http.Response response) {
    final body = response.body.trim();
    debugPrint('StepsApiService: POST response ${safeHttpResponseLog(response.statusCode, body)}');

    final decoded = _tryDecodeJson(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw StepsApiException(
        message ?? 'Save steps failed (${response.statusCode}). ${safeHttpErrorDetail(response.statusCode, body)}',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const StepLogResponse();
    }

    return ApiStepsMapper.logResponseFromJson(decoded);
  }

  Object? _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
