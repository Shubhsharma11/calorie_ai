import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/api_timezone.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthApiService {
  AuthApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> loginWithGoogleIdToken(String idToken) async {
    debugPrint(
      'AuthApiService: posting Google ID token to ${ApiEndpoints.googleAuthUrl}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.googleAuth,
      body: {'idToken': idToken},
    );

    final body = response.body.trim();
    debugPrint(
      'AuthApiService: Google login response ${response.statusCode}: '
      '${_redactTokenFields(body)}',
    );
    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw AuthApiException(
        message ??
            'Google backend login failed (${response.statusCode}). $body',
      );
    }

    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  Future<void> deleteAccount({required String accessToken}) async {
    debugPrint(
      'AuthApiService: DELETE ${ApiEndpoints.deleteAccountUrl} '
      'Authorization: Bearer ***',
    );

    final response = await _apiClient.delete(
      ApiEndpoints.deleteAccount,
      headers: apiAuthHeaders(accessToken),
    );

    final body = response.body.trim();
    debugPrint(
      'AuthApiService: delete account response ${response.statusCode}: '
      '${_redactTokenFields(body)}',
    );
    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw AuthApiException(
        message ??
            'Account deletion failed (${response.statusCode}). $body',
      );
    }
  }

  Future<void> logoutWithRefreshToken(String refreshToken) async {
    debugPrint(
      'AuthApiService: POST ${ApiEndpoints.logoutUrl} '
      'Content-Type: application/json body: {refreshToken: ***}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.logout,
      body: {'refreshToken': refreshToken},
    );

    final body = response.body.trim();
    debugPrint(
      'AuthApiService: logout response ${response.statusCode}: '
      '${_redactTokenFields(body)}',
    );
    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw AuthApiException(
        message ?? 'Backend logout failed (${response.statusCode}). $body',
      );
    }
  }

  dynamic _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  String _redactTokenFields(String body) {
    final decoded = _tryDecodeJson(body);
    if (decoded == null) return body;
    return jsonEncode(_redactTokens(decoded));
  }

  dynamic _redactTokens(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, fieldValue) {
        final lowerKey = key.toLowerCase();
        if (lowerKey.contains('token')) {
          return MapEntry(key, '***redacted***');
        }
        return MapEntry(key, _redactTokens(fieldValue));
      });
    }

    if (value is List) {
      return value.map(_redactTokens).toList();
    }

    return value;
  }
}
