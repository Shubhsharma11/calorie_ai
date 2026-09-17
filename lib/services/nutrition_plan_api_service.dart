import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../models/nutrition_plan_model.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class NutritionPlanApiException implements Exception {
  const NutritionPlanApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class NutritionPlanApiService {
  NutritionPlanApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Creates/regenerates the plan. Optional [body] sends profile + diet context
  /// so the backend can persist meals even if onboarding fields were just saved.
  Future<NutritionPlanModel> createPlan({
    required String accessToken,
    Map<String, dynamic>? body,
  }) async {
    debugPrint(
      'NutritionPlanApiService: POST ${ApiEndpoints.nutritionPlanUrl}',
    );
    if (kDebugMode && body != null) {
      debugPrint(
        'NutritionPlanApiService: request body:\n'
        '${const JsonEncoder.withIndent('  ').convert(body)}',
      );
    }

    final response = await _apiClient.post(
      ApiEndpoints.nutritionPlan,
      body: body ?? const <String, dynamic>{},
      headers: apiAuthHeaders(accessToken),
    );

    return _parsePlanResponse(response);
  }

  Future<NutritionPlanModel> fetchPlan({required String accessToken}) async {
    debugPrint(
      'NutritionPlanApiService: GET ${ApiEndpoints.nutritionPlanUrl}',
    );

    final response = await _apiClient.get(
      ApiEndpoints.nutritionPlan,
      headers: apiAuthHeaders(accessToken),
    );

    return _parsePlanResponse(response);
  }

  NutritionPlanModel _parsePlanResponse(http.Response response) {
    final body = response.body.trim();
    debugPrint(
      'NutritionPlanApiService: response ${response.statusCode}: $body',
    );

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw NutritionPlanApiException(
        message ??
            'Nutrition plan request failed (${response.statusCode}). $body',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return NutritionPlanModel.fromJson(decoded);
    }

    throw const NutritionPlanApiException(
      'Nutrition plan response was not valid JSON.',
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
