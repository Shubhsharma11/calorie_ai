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

  /// Increments only when a real HTTP GET to `/my-meals` is sent.
  static int _getListNetworkCount = 0;

  /// GET `/api/v1/my-meals` — list saved meal templates.
  Future<List<CustomMealPreset>> fetchCustomMeals({
    required String accessToken,
  }) async {
    final requestId = ++_getListNetworkCount;
    debugPrint(
      'CustomMealsApiService: NETWORK GET /my-meals '
      'requestId=#$requestId url=${ApiEndpoints.myMealsUrl}',
    );

    final response = await _apiClient.get(
      ApiEndpoints.myMeals,
      headers: apiAuthHeaders(accessToken),
    );

    debugPrint(
      'CustomMealsApiService: NETWORK GET /my-meals '
      'requestId=#$requestId status=${response.statusCode}',
    );

    return _parseListResponse(response, requestId: requestId);
  }

  /// POST `/api/v1/my-meals` — create a meal template.
  Future<CustomMealPreset> createCustomMeal({
    required String accessToken,
    required CustomMealPreset preset,
  }) async {
    final body = ApiCustomMealMapper.toCreateRequestBody(preset);

    debugPrint(
      'CustomMealsApiService: POST ${ApiEndpoints.myMealsUrl} $body',
    );

    final response = await _apiClient.post(
      ApiEndpoints.myMeals,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    return _parseCreateResponse(response, source: preset);
  }

  /// PATCH `/api/v1/my-meals/:myMealId` — update an existing meal template.
  Future<CustomMealPreset> updateCustomMeal({
    required String accessToken,
    required String myMealId,
    required CustomMealPreset preset,
    String? imageUrl,
  }) async {
    final endpoint = ApiEndpoints.myMealById(myMealId);
    final body = ApiCustomMealMapper.toPatchRequestBody(
      preset: preset,
      imageUrl: imageUrl,
    );

    debugPrint(
      'CustomMealsApiService: PATCH ${ApiEndpoints.url(endpoint)} $body',
    );

    final response = await _apiClient.patch(
      endpoint,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    return _parseUpdateResponse(
      response,
      source: preset,
      url: ApiEndpoints.myMealByIdUrl(myMealId),
    );
  }

  /// DELETE `/api/v1/my-meals/:myMealId` — delete a saved meal.
  Future<void> deleteCustomMeal({
    required String accessToken,
    required String myMealId,
  }) async {
    final endpoint = ApiEndpoints.myMealById(myMealId);
    debugPrint(
      'CustomMealsApiService: DELETE ${ApiEndpoints.url(endpoint)}',
    );

    final response = await _apiClient.delete(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    _parseVoidResponse(
      response,
      action: 'Delete my meal',
      url: ApiEndpoints.myMealByIdUrl(myMealId),
    );
  }

  List<CustomMealPreset> _parseListResponse(
    http.Response response, {
    required int requestId,
  }) {
    final body = response.body.trim();
    debugPrint(
      'CustomMealsApiService: NETWORK GET /my-meals '
      'requestId=#$requestId bodyLen=${body.length}',
    );

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
            'Fetch my meals failed (${response.statusCode}).$statusHint '
            'URL: ${ApiEndpoints.myMealsUrl}',
        statusCode: response.statusCode,
      );
    }

    if (decoded == null) return [];

    if (decoded is Map) {
      debugPrint(
        'CustomMealsApiService: NETWORK GET /my-meals '
        'requestId=#$requestId topKeys=${decoded.keys.toList()} '
        'dataType=${decoded['data'].runtimeType}',
      );
    }

    final presets = ApiCustomMealMapper.presetsFromResponse(decoded);
    for (final meal in presets.take(8)) {
      debugPrint(
        'CustomMealsApiService:   id=${meal.id} name=${meal.name} '
        'image=${meal.imageUrl}',
      );
    }
    return presets;
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
            'Create my meal failed (${response.statusCode}).$statusHint '
            'URL: ${ApiEndpoints.myMealsUrl}',
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
      'Create my meal response was not valid JSON.',
    );
  }

  CustomMealPreset _parseUpdateResponse(
    http.Response response, {
    required CustomMealPreset source,
    required String url,
  }) {
    final body = response.body.trim();
    debugPrint(
      'CustomMealsApiService: PATCH update ${response.statusCode}: $body',
    );

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
            'Update my meal failed (${response.statusCode}).$statusHint '
            'URL: $url',
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
      'Update my meal response was not valid JSON.',
    );
  }

  void _parseVoidResponse(
    http.Response response, {
    required String action,
    required String url,
  }) {
    final body = response.body.trim();
    debugPrint(
      'CustomMealsApiService: $action ${response.statusCode}: $body',
    );

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
    throw CustomMealsApiException(
      message ??
          '$action failed (${response.statusCode}).$statusHint URL: $url',
      statusCode: response.statusCode,
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
