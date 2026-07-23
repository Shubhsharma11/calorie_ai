import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../models/meal_streak_model.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class MealStreakApiException implements Exception {
  const MealStreakApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MealStreakApiService {
  MealStreakApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<MealStreakModel> fetchStreak({required String accessToken}) async {
    debugPrint('MealStreakApiService: GET ${ApiEndpoints.mealsStreakUrl}');

    final response = await _apiClient.get(
      ApiEndpoints.mealsStreak,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseResponse(response);
  }

  MealStreakModel _parseResponse(http.Response response) {
    final body = response.body.trim();
    debugPrint(
      'MealStreakApiService: response ${response.statusCode}: $body',
    );

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw MealStreakApiException(
        message ??
            'Meal streak request failed (${response.statusCode}). $body',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return MealStreakModel.fromJson(decoded);
    }

    throw const MealStreakApiException(
      'Meal streak response was not valid JSON.',
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
