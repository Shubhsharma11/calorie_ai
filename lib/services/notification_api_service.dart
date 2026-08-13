import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../models/notification_model.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class NotificationApiException implements Exception {
  const NotificationApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class NotificationApiService {
  NotificationApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<NotificationTokenResponse> uploadFcmToken({
    required String accessToken,
    required NotificationTokenRequest request,
  }) async {
    if (kDebugMode) {
      debugPrint(
        'NotificationApiService: PUT ${ApiEndpoints.fcmTokenUrl} '
        'fcmToken=${request.fcmToken.isNotEmpty ? '[set]' : '[empty]'}',
      );
    }

    final response = await _apiClient.put(
      ApiEndpoints.fcmToken,
      body: request.toJson(),
      headers: apiAuthHeaders(accessToken),
    );

    final decoded = _tryDecodeJson(response.body.trim());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw NotificationApiException(
        message ??
            'Failed to upload FCM token (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return NotificationTokenResponse.fromJson(decoded);
    }

    return const NotificationTokenResponse(success: true);
  }

  Future<NotificationListResult> fetchNotifications({
    required String accessToken,
    int page = 1,
    int limit = 20,
    bool? unreadOnly,
  }) async {
    final endpoint = ApiEndpoints.notificationsWithQuery(
      page: page,
      limit: limit,
      unreadOnly: unreadOnly,
    );
    if (kDebugMode) {
      debugPrint(
        'NotificationApiService: GET ${ApiEndpoints.url(endpoint)}',
      );
    }

    final response = await _apiClient.get(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseListResponse(response);
  }

  Future<int> fetchUnreadCount({required String accessToken}) async {
    if (kDebugMode) {
      debugPrint(
        'NotificationApiService: GET ${ApiEndpoints.notificationsUnreadCountUrl}',
      );
    }

    final response = await _apiClient.get(
      ApiEndpoints.notificationsUnreadCount,
      headers: apiAuthHeaders(accessToken),
    );

    final decoded = _decodeOrThrow(
      response,
      fallback: 'Failed to fetch unread count',
    );

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return _asInt(data['unreadCount'] ?? data['unread'] ?? data['count']);
    }
    return _asInt(
      decoded['unreadCount'] ?? decoded['unread'] ?? decoded['count'],
    );
  }

  Future<void> markAsRead({
    required String accessToken,
    required String notificationId,
  }) async {
    final endpoint = ApiEndpoints.notificationRead(notificationId);
    if (kDebugMode) {
      debugPrint(
        'NotificationApiService: PATCH ${ApiEndpoints.url(endpoint)}',
      );
    }

    final response = await _apiClient.patch(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    _decodeOrThrow(
      response,
      fallback: 'Failed to mark notification as read',
    );
  }

  Future<void> markAllAsRead({required String accessToken}) async {
    if (kDebugMode) {
      debugPrint(
        'NotificationApiService: PATCH ${ApiEndpoints.notificationsReadAllUrl}',
      );
    }

    final response = await _apiClient.patch(
      ApiEndpoints.notificationsReadAll,
      headers: apiAuthHeaders(accessToken),
    );

    _decodeOrThrow(
      response,
      fallback: 'Failed to mark all notifications as read',
    );
  }

  Future<void> deleteNotification({
    required String accessToken,
    required String notificationId,
  }) async {
    final endpoint = ApiEndpoints.notificationById(notificationId);
    if (kDebugMode) {
      debugPrint(
        'NotificationApiService: DELETE ${ApiEndpoints.url(endpoint)}',
      );
    }

    final response = await _apiClient.delete(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    // 204/empty body is normal for DELETE. 404 = already gone.
    // 405/501 = backend has not added delete yet; local hide still applies.
    if (response.statusCode == 404 ||
        response.statusCode == 405 ||
        response.statusCode == 501) {
      return;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final decoded = _tryDecodeJson(response.body.trim());
    final message = decoded is Map<String, dynamic>
        ? decoded['message'] as String? ?? decoded['error'] as String?
        : null;
    throw NotificationApiException(
      message ??
          'Failed to delete notification (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  NotificationListResult _parseListResponse(http.Response response) {
    final decoded = _decodeOrThrow(
      response,
      fallback: 'Failed to load notifications',
    );
    return NotificationListResult.fromJson(decoded);
  }

  Map<String, dynamic> _decodeOrThrow(
    http.Response response, {
    required String fallback,
  }) {
    final body = response.body.trim();
    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw NotificationApiException(
        message ?? '$fallback (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) return decoded;
    throw NotificationApiException('$fallback: invalid response.');
  }

  Map<String, dynamic>? _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('NotificationApiService: invalid JSON response: $body');
      }
      return null;
    }
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
