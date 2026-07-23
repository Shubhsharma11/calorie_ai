import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/api_timezone.dart';
import '../models/notification_model.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class NotificationApiException implements Exception {
  const NotificationApiException(this.message);

  final String message;

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
      );
    }

    if (decoded is Map<String, dynamic>) {
      return NotificationTokenResponse.fromJson(decoded);
    }

    return const NotificationTokenResponse(success: true);
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
}
