import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../models/api_custom_meal_mapper.dart';
import '../models/custom_meal_preset.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class CustomMealsApiException implements Exception {
  const CustomMealsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CustomMealsApiService {
  CustomMealsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<CustomMealPreset>> fetchCustomMeals({
    required String accessToken,
  }) async {
    debugPrint(
      'CustomMealsApiService: GET ${ApiEndpoints.mealsCustomUrl}',
    );

    final response = await _apiClient.get(
      ApiEndpoints.mealsCustom,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseListResponse(response);
  }

  Future<CustomMealPreset> createCustomMeal({
    required String accessToken,
    required CustomMealPreset preset,
  }) async {
    final body = ApiCustomMealMapper.toCreateRequestBody(preset);

    debugPrint(
      'CustomMealsApiService: POST ${ApiEndpoints.mealsCustomUrl} $body',
    );

    final response = await _apiClient.post(
      ApiEndpoints.mealsCustom,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    return _parseCreateResponse(response, source: preset);
  }

  List<CustomMealPreset> _parseListResponse(http.Response response) {
    final body = response.body.trim();
    debugPrint('CustomMealsApiService: GET response ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      final statusHint = response.statusCode == 530 || response.statusCode == 502
          ? ' The backend tunnel may be offline.'
          : '';
      throw CustomMealsApiException(
        message ??
            'Fetch custom meals failed (${response.statusCode}).$statusHint '
            'URL: ${ApiEndpoints.mealsCustomUrl}',
        statusCode: response.statusCode,
      );
    }

    if (decoded == null) return [];

    return ApiCustomMealMapper.presetsFromResponse(decoded);
  }

  CustomMealPreset _parseCreateResponse(
    http.Response response, {
    required CustomMealPreset source,
  }) {
    final body = response.body.trim();
    debugPrint('CustomMealsApiService: response ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      final statusHint = response.statusCode == 530 || response.statusCode == 502
          ? ' The backend tunnel may be offline.'
          : '';
      throw CustomMealsApiException(
        message ??
            'Create custom meal failed (${response.statusCode}).$statusHint '
            'URL: ${ApiEndpoints.mealsCustomUrl}',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return ApiCustomMealMapper.presetFromResponse(decoded, source: source);
    }

    if (decoded is Map) {
      return ApiCustomMealMapper.presetFromResponse(
        Map<String, dynamic>.from(decoded),
        source: source,
      );
    }

    if (body.isEmpty) return source;

    throw const CustomMealsApiException(
      'Create custom meal response was not valid JSON.',
    );
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
