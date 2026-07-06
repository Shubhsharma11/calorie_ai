import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_meal_mapper.dart';
import '../models/meal_entry.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class MealsApiException implements Exception {
  const MealsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MealsApiService {
  MealsApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<MealEntry>> fetchMeals({
    required String accessToken,
    DateTime? date,
  }) async {
    final endpoint = ApiEndpoints.mealsWithQuery(date: date);
    debugPrint('MealsApiService: GET ${ApiEndpoints.url(endpoint)}');

    final response = await _apiClient.get(
      endpoint,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    return _parseMealsResponse(response, fallbackDate: date);
  }

  Future<MealEntry> createMeal({
    required String accessToken,
    required MealEntry entry,
  }) async {
    final body = ApiMealMapper.toCreateRequestBody(entry);
    debugPrint('MealsApiService: POST ${ApiEndpoints.mealsUrl} $body');

    final response = await _apiClient.post(
      ApiEndpoints.meals,
      headers: {'Authorization': 'Bearer $accessToken'},
      body: body,
    );

    return _parseCreateResponse(response, source: entry);
  }

  Future<void> deleteMeal({
    required String accessToken,
    required String mealId,
  }) async {
    final endpoint = ApiEndpoints.mealById(mealId);
    debugPrint('MealsApiService: DELETE ${ApiEndpoints.url(endpoint)}');

    final response = await _apiClient.delete(
      endpoint,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    _parseDeleteResponse(response, mealId: mealId);
  }

  void _parseDeleteResponse(http.Response response, {required String mealId}) {
    final body = response.body.trim();
    debugPrint('MealsApiService: response ${response.statusCode}: $body');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final decoded = _tryDecodeJson(body);
    final message = decoded is Map<String, dynamic>
        ? decoded['message'] as String? ?? decoded['error'] as String?
        : null;
    final statusHint = response.statusCode == 530 || response.statusCode == 502
        ? ' The backend tunnel may be offline.'
        : '';
    throw MealsApiException(
      message ??
          'Delete meal failed (${response.statusCode}).$statusHint '
          'URL: ${ApiEndpoints.mealsByIdUrl(mealId)}',
      statusCode: response.statusCode,
    );
  }

  MealEntry _parseCreateResponse(
    http.Response response, {
    required MealEntry source,
  }) {
    final body = response.body.trim();
    debugPrint('MealsApiService: response ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      final statusHint = response.statusCode == 530 || response.statusCode == 502
          ? ' The backend tunnel may be offline.'
          : '';
      throw MealsApiException(
        message ??
            'Create meal failed (${response.statusCode}).$statusHint '
            'URL: ${ApiEndpoints.mealsUrl}',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return ApiMealMapper.mergeCreateResponse(decoded, source: source);
    }

    throw const MealsApiException('Create meal response was not valid JSON.');
  }

  List<MealEntry> _parseMealsResponse(
    http.Response response, {
    DateTime? fallbackDate,
  }) {
    final body = response.body.trim();
    debugPrint('MealsApiService: response ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw MealsApiException(
        message ??
            'Meals request failed (${response.statusCode}). '
            'Check that the backend tunnel is running.',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return ApiMealMapper.entriesFromResponse(
        decoded,
        fallbackDate: fallbackDate,
      );
    }

    if (decoded is Map) {
      return ApiMealMapper.entriesFromResponse(
        Map<String, dynamic>.from(decoded),
        fallbackDate: fallbackDate,
      );
    }

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map(
            (item) => ApiMealMapper.entryFromApiJson(
              Map<String, dynamic>.from(item),
              fallbackDate: fallbackDate,
            ),
          )
          .whereType<MealEntry>()
          .toList();
    }

    throw const MealsApiException('Meals response was not valid JSON.');
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
