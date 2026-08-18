import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../models/api_my_food_mapper.dart';
import '../models/custom_food_preset.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class MyFoodsApiException implements Exception {
  const MyFoodsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MyFoodsApiService {
  MyFoodsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// GET `/api/v1/my-foods` — list saved foods.
  Future<List<CustomFoodPreset>> fetchMyFoods({
    required String accessToken,
  }) async {
    debugPrint('MyFoodsApiService: GET ${ApiEndpoints.myFoodsUrl}');

    final response = await _apiClient.get(
      ApiEndpoints.myFoods,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseListResponse(response);
  }

  /// GET `/api/v1/my-foods/:myFoodId` — get one food.
  Future<CustomFoodPreset> fetchMyFood({
    required String accessToken,
    required String myFoodId,
  }) async {
    final endpoint = ApiEndpoints.myFoodById(myFoodId);
    debugPrint('MyFoodsApiService: GET ${ApiEndpoints.url(endpoint)}');

    final response = await _apiClient.get(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseSingleResponse(
      response,
      action: 'Fetch my food',
      url: ApiEndpoints.myFoodByIdUrl(myFoodId),
    );
  }

  /// POST `/api/v1/my-foods` — save a custom food to My Food.
  Future<CustomFoodPreset> saveMyFood({
    required String accessToken,
    required CustomFoodPreset preset,
    required String mealtime,
    String? imageUrl,
  }) async {
    final body = ApiMyFoodMapper.toCreateRequestBody(
      preset: preset,
      mealtime: mealtime,
      imageUrl: imageUrl,
    );

    debugPrint(
      'MyFoodsApiService: POST ${ApiEndpoints.myFoodsUrl} $body',
    );

    final response = await _apiClient.post(
      ApiEndpoints.myFoods,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    return _parseSaveResponse(response, source: preset);
  }

  /// PATCH `/api/v1/my-foods/:myFoodId` — update an existing My Food.
  Future<CustomFoodPreset> updateMyFood({
    required String accessToken,
    required String myFoodId,
    required CustomFoodPreset preset,
    required String mealtime,
    String? imageUrl,
  }) async {
    final endpoint = ApiEndpoints.myFoodById(myFoodId);
    final body = ApiMyFoodMapper.toPatchRequestBody(
      preset: preset,
      mealtime: mealtime,
      imageUrl: imageUrl,
    );

    debugPrint(
      'MyFoodsApiService: PATCH ${ApiEndpoints.url(endpoint)} $body',
    );

    final response = await _apiClient.patch(
      endpoint,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    return _parseUpdateResponse(
      response,
      source: preset,
      url: ApiEndpoints.myFoodByIdUrl(myFoodId),
    );
  }

  /// POST `/api/v1/my-foods/:myFoodId/log` — log food to daily meals.
  Future<void> logMyFood({
    required String accessToken,
    required String myFoodId,
    required CustomFoodPreset preset,
    required DateTime date,
    required String mealtime,
  }) async {
    final endpoint = ApiEndpoints.myFoodLog(myFoodId);
    final body = ApiMyFoodMapper.toLogRequestBody(
      date: date,
      mealtime: mealtime,
      preset: preset,
    );

    debugPrint(
      'MyFoodsApiService: POST ${ApiEndpoints.url(endpoint)} $body',
    );

    final response = await _apiClient.post(
      endpoint,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    _parseVoidResponse(
      response,
      action: 'Log my food',
      url: ApiEndpoints.myFoodLogUrl(myFoodId),
    );
  }

  /// DELETE `/api/v1/my-foods/:myFoodId` — delete food.
  Future<void> deleteMyFood({
    required String accessToken,
    required String myFoodId,
  }) async {
    final endpoint = ApiEndpoints.myFoodById(myFoodId);
    debugPrint('MyFoodsApiService: DELETE ${ApiEndpoints.url(endpoint)}');

    final response = await _apiClient.delete(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    _parseVoidResponse(
      response,
      action: 'Delete my food',
      url: ApiEndpoints.myFoodByIdUrl(myFoodId),
    );
  }

  List<CustomFoodPreset> _parseListResponse(http.Response response) {
    final body = response.body.trim();
    debugPrint('MyFoodsApiService: GET list ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);
    _throwIfFailed(
      response,
      decoded,
      action: 'Fetch my foods',
      url: ApiEndpoints.myFoodsUrl,
    );

    if (decoded == null) return [];
    return ApiMyFoodMapper.presetsFromResponse(decoded);
  }

  CustomFoodPreset _parseSingleResponse(
    http.Response response, {
    required String action,
    required String url,
    CustomFoodPreset? source,
  }) {
    final body = response.body.trim();
    debugPrint('MyFoodsApiService: GET one ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);
    _throwIfFailed(response, decoded, action: action, url: url);

    if (decoded is Map<String, dynamic>) {
      final preset = ApiMyFoodMapper.presetFromResponse(
        decoded,
        source: source,
      );
      if (preset != null) return preset;
    } else if (decoded is Map) {
      final preset = ApiMyFoodMapper.presetFromResponse(
        Map<String, dynamic>.from(decoded),
        source: source,
      );
      if (preset != null) return preset;
    }

    if (source != null) return source;

    throw MyFoodsApiException(
      '$action response was not valid JSON. URL: $url',
      statusCode: response.statusCode,
    );
  }

  CustomFoodPreset _parseSaveResponse(
    http.Response response, {
    required CustomFoodPreset source,
  }) {
    final body = response.body.trim();
    debugPrint('MyFoodsApiService: POST save ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);
    _throwIfFailed(
      response,
      decoded,
      action: 'Save my food',
      url: ApiEndpoints.myFoodsUrl,
    );

    if (decoded is Map<String, dynamic>) {
      return ApiMyFoodMapper.presetFromResponse(decoded, source: source) ??
          source;
    }
    if (decoded is Map) {
      return ApiMyFoodMapper.presetFromResponse(
            Map<String, dynamic>.from(decoded),
            source: source,
          ) ??
          source;
    }

    return source;
  }

  CustomFoodPreset _parseUpdateResponse(
    http.Response response, {
    required CustomFoodPreset source,
    required String url,
  }) {
    final body = response.body.trim();
    debugPrint('MyFoodsApiService: PATCH update ${response.statusCode}: $body');

    final decoded = _tryDecodeJson(body);
    _throwIfFailed(
      response,
      decoded,
      action: 'Update my food',
      url: url,
    );

    // Keep the values we just sent. PATCH responses are often partial/stale and
    // would otherwise wipe name + calories after a successful update.
    if (decoded is Map) {
      final map = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded);
      final data = ApiMyFoodMapper.unwrapDataForId(map);
      final id = data['id']?.toString() ??
          data['_id']?.toString() ??
          data['myFoodId']?.toString() ??
          data['foodId']?.toString();
      if (id != null && id.trim().isNotEmpty) {
        return source.copyWith(id: id.trim());
      }
    }

    return source;
  }

  void _parseVoidResponse(
    http.Response response, {
    required String action,
    required String url,
  }) {
    final body = response.body.trim();
    debugPrint(
      'MyFoodsApiService: $action ${response.statusCode}: $body',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final decoded = _tryDecodeJson(body);
    _throwIfFailed(response, decoded, action: action, url: url);
  }

  void _throwIfFailed(
    http.Response response,
    dynamic decoded, {
    required String action,
    required String url,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message = decoded is Map<String, dynamic>
        ? _messageFromErrorBody(decoded) ??
            decoded['message'] as String? ??
            decoded['error'] as String?
        : null;
    final statusHint = response.statusCode == 530 || response.statusCode == 502
        ? ' The backend tunnel may be offline.'
        : '';
    throw MyFoodsApiException(
      message ??
          '$action failed (${response.statusCode}).$statusHint URL: $url',
      statusCode: response.statusCode,
    );
  }

  String? _messageFromErrorBody(Map<String, dynamic> decoded) {
    final base = decoded['message'] as String? ?? decoded['error'] as String?;
    final details = decoded['details'];
    if (details is! List || details.isEmpty) return base;

    final parts = <String>[];
    for (final detail in details) {
      if (detail is! Map) continue;
      final field = detail['field']?.toString() ?? detail['path']?.toString();
      final msg = detail['message']?.toString() ?? detail['msg']?.toString();
      if (field != null && msg != null) {
        parts.add('$field: $msg');
      } else if (msg != null) {
        parts.add(msg);
      }
    }
    if (parts.isEmpty) return base;
    final detailText = parts.join('; ');
    return base == null || base.isEmpty ? detailText : '$base ($detailText)';
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
