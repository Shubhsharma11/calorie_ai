import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../models/api_favourite_meal_mapper.dart';
import '../models/saved_meal_item.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class FavouriteMealsApiException implements Exception {
  const FavouriteMealsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class FavouriteMealsApiService {
  FavouriteMealsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// GET `/api/v1/favourite-meals` — list favourites.
  Future<List<SavedMealItem>> fetchFavourites({
    required String accessToken,
  }) async {
    debugPrint(
      'FavouriteMealsApiService: GET ${ApiEndpoints.favouriteMealsUrl}',
    );

    final response = await _apiClient.get(
      ApiEndpoints.favouriteMeals,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseListResponse(response);
  }

  /// GET `/api/v1/favourite-meals/:favouriteMealId` — get one.
  Future<SavedMealItem> fetchFavourite({
    required String accessToken,
    required String favouriteMealId,
  }) async {
    final endpoint = ApiEndpoints.favouriteMealById(favouriteMealId);
    debugPrint(
      'FavouriteMealsApiService: GET ${ApiEndpoints.url(endpoint)}',
    );

    final response = await _apiClient.get(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseSingleResponse(
      response,
      action: 'Fetch favourite meal',
      url: ApiEndpoints.favouriteMealByIdUrl(favouriteMealId),
    );
  }

  /// POST `/api/v1/favourite-meals` — add favourite.
  Future<SavedMealItem> addFavourite({
    required String accessToken,
    required SavedMealItem item,
    String? imageUrl,
  }) async {
    final body = ApiFavouriteMealMapper.toCreateRequestBody(
      item: item,
      imageUrl: imageUrl,
    );

    debugPrint(
      'FavouriteMealsApiService: POST ${ApiEndpoints.favouriteMealsUrl} $body',
    );

    final response = await _apiClient.post(
      ApiEndpoints.favouriteMeals,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    return _parseSaveResponse(response, source: item);
  }

  /// POST `/api/v1/favourite-meals/:favouriteMealId/log` — log to daily meals.
  Future<void> logFavourite({
    required String accessToken,
    required String favouriteMealId,
    required SavedMealItem item,
    required DateTime date,
    required String mealtime,
  }) async {
    final endpoint = ApiEndpoints.favouriteMealLog(favouriteMealId);
    final body = ApiFavouriteMealMapper.toLogRequestBody(
      date: date,
      mealtime: mealtime,
      item: item,
    );

    debugPrint(
      'FavouriteMealsApiService: POST ${ApiEndpoints.url(endpoint)} $body',
    );

    final response = await _apiClient.post(
      endpoint,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    _parseVoidResponse(
      response,
      action: 'Log favourite meal',
      url: ApiEndpoints.favouriteMealLogUrl(favouriteMealId),
    );
  }

  /// DELETE `/api/v1/favourite-meals/:favouriteMealId` — remove favourite.
  Future<void> deleteFavourite({
    required String accessToken,
    required String favouriteMealId,
  }) async {
    final endpoint = ApiEndpoints.favouriteMealById(favouriteMealId);
    debugPrint(
      'FavouriteMealsApiService: DELETE ${ApiEndpoints.url(endpoint)}',
    );

    final response = await _apiClient.delete(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    _parseVoidResponse(
      response,
      action: 'Delete favourite meal',
      url: ApiEndpoints.favouriteMealByIdUrl(favouriteMealId),
    );
  }

  List<SavedMealItem> _parseListResponse(http.Response response) {
    final body = response.body.trim();
    debugPrint(
      'FavouriteMealsApiService: GET list ${response.statusCode}: $body',
    );

    final decoded = _tryDecodeJson(body);
    _throwIfFailed(
      response,
      decoded,
      action: 'Fetch favourite meals',
      url: ApiEndpoints.favouriteMealsUrl,
    );

    if (decoded == null) return [];
    return ApiFavouriteMealMapper.itemsFromResponse(decoded);
  }

  SavedMealItem _parseSingleResponse(
    http.Response response, {
    required String action,
    required String url,
    SavedMealItem? source,
  }) {
    final body = response.body.trim();
    debugPrint(
      'FavouriteMealsApiService: GET one ${response.statusCode}: $body',
    );

    final decoded = _tryDecodeJson(body);
    _throwIfFailed(response, decoded, action: action, url: url);

    if (decoded is Map<String, dynamic>) {
      final item = ApiFavouriteMealMapper.itemFromResponse(
        decoded,
        source: source,
      );
      if (item != null) return item;
    } else if (decoded is Map) {
      final item = ApiFavouriteMealMapper.itemFromResponse(
        Map<String, dynamic>.from(decoded),
        source: source,
      );
      if (item != null) return item;
    }

    if (source != null) return source;

    throw FavouriteMealsApiException(
      '$action response was not valid JSON. URL: $url',
      statusCode: response.statusCode,
    );
  }

  SavedMealItem _parseSaveResponse(
    http.Response response, {
    required SavedMealItem source,
  }) {
    final body = response.body.trim();
    debugPrint(
      'FavouriteMealsApiService: POST save ${response.statusCode}: $body',
    );

    final decoded = _tryDecodeJson(body);
    _throwIfFailed(
      response,
      decoded,
      action: 'Add favourite meal',
      url: ApiEndpoints.favouriteMealsUrl,
    );

    if (decoded is Map<String, dynamic>) {
      return ApiFavouriteMealMapper.itemFromResponse(decoded, source: source) ??
          source;
    }
    if (decoded is Map) {
      return ApiFavouriteMealMapper.itemFromResponse(
            Map<String, dynamic>.from(decoded),
            source: source,
          ) ??
          source;
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
      'FavouriteMealsApiService: $action ${response.statusCode}: $body',
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
        ? _formatErrorMessage(decoded)
        : null;
    final statusHint = response.statusCode == 530 || response.statusCode == 502
        ? ' The backend tunnel may be offline.'
        : '';
    throw FavouriteMealsApiException(
      message ??
          '$action failed (${response.statusCode}).$statusHint URL: $url',
      statusCode: response.statusCode,
    );
  }

  static String? _formatErrorMessage(Map<String, dynamic> decoded) {
    final base = decoded['message'] as String? ?? decoded['error'] as String?;
    final details = decoded['details'];
    if (details is! List || details.isEmpty) return base;

    final parts = <String>[];
    for (final detail in details) {
      if (detail is! Map) continue;
      final field = detail['field']?.toString();
      final msg = detail['message']?.toString();
      if (field != null && msg != null) {
        parts.add('$field: $msg');
      } else if (msg != null) {
        parts.add(msg);
      }
    }
    if (parts.isEmpty) return base;
    if (base == null || base.isEmpty) return parts.join('; ');
    return '$base (${parts.join('; ')})';
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
