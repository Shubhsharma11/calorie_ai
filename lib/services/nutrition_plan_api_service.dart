import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  Future<NutritionPlanModel> createPlan({required String accessToken}) async {
    debugPrint(
      'NutritionPlanApiService: POST ${ApiEndpoints.nutritionPlanUrl}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.nutritionPlan,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    return _parsePlanResponse(response);
  }

  Future<NutritionPlanModel> fetchPlan({required String accessToken}) async {
    debugPrint(
      'NutritionPlanApiService: GET ${ApiEndpoints.nutritionPlanUrl}',
    );

    final response = await _apiClient.get(
      ApiEndpoints.nutritionPlan,
      headers: {'Authorization': 'Bearer $accessToken'},
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
