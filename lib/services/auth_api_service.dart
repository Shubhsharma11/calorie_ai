import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/api_timezone.dart';
import '../models/avatar_upload_result.dart';
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

  Future<Map<String, dynamic>> loginWithAppleIdToken(
  String identityToken,
) async {
  debugPrint(
    'AuthApiService: posting Apple ID token to ${ApiEndpoints.appleAuthUrl}',
  );

  final response = await _apiClient.post(
    ApiEndpoints.appleAuth,
    body: {
      'idToken': identityToken,
    },
  );

  final body = response.body.trim();

  debugPrint(
    'AuthApiService: Apple login response ${response.statusCode}: '
    '${_redactTokenFields(body)}',
  );

  final decoded = _tryDecodeJson(body);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final message = decoded is Map<String, dynamic>
        ? decoded['message'] as String? ?? decoded['error'] as String?
        : null;

    throw AuthApiException(
      message ??
          'Apple backend login failed (${response.statusCode}). $body',
    );
  }

  if (decoded is Map<String, dynamic>) {
    return decoded;
  }

  return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> loginWithPhoneIdToken(String idToken) async {
    debugPrint(
      'AuthApiService: posting phone ID token to ${ApiEndpoints.phoneAuthUrl}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.phoneAuth,
      body: {'idToken': idToken},
    );

    final body = response.body.trim();
    debugPrint(
      'AuthApiService: phone login response ${response.statusCode}: '
      '${_redactTokenFields(body)}',
    );
    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw AuthApiException(
        message ?? 
            'Phone backend login failed (${response.statusCode}). $body',
      );
    }

    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  Future<AvatarUploadResult> uploadAvatar({
    required String accessToken,
    required List<int> imageBytes,
    String filename = 'avatar.jpg',
  }) async {
    if (imageBytes.isEmpty) {
      throw const AuthApiException('Selected photo could not be read.');
    }

    final safeName = filename.trim().isEmpty ? 'avatar.jpg' : filename.trim();
    final mimeType = _avatarMimeType(safeName);
    debugPrint(
      'AuthApiService: POST ${ApiEndpoints.authMeAvatarUrl} '
      'Authorization: Bearer *** file=$safeName contentType=$mimeType '
      'bytes=${imageBytes.length}',
    );

    final response = await _apiClient.postMultipart(
      ApiEndpoints.authMeAvatar,
      fields: const {},
      files: [
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: safeName,
          contentType: MediaType.parse(mimeType),
        ),
      ],
      headers: apiAuthHeaders(accessToken),
    );

    final decoded = _decodeSuccessMap(
      response,
      fallback: 'Profile image upload failed',
    );
    try {
      return AvatarUploadResult.fromJson(decoded);
    } on FormatException {
      throw const AuthApiException(
        'Profile image uploaded, but the server did not return an image URL.',
      );
    }
  }

  Future<Map<String, dynamic>> fetchMe({required String accessToken}) async {
    debugPrint(
      'AuthApiService: GET ${ApiEndpoints.authMeUrl} Authorization: Bearer ***',
    );

    final response = await _apiClient.get(
      ApiEndpoints.authMe,
      headers: apiAuthHeaders(accessToken),
    );

    return _decodeSuccessMap(response, fallback: 'Could not load profile image');
  }

  Map<String, dynamic> _decodeSuccessMap(
    http.Response response, {
    required String fallback,
  }) {
    final body = response.body.trim();
    debugPrint(
      'AuthApiService: response ${response.statusCode}: '
      '${_logBody(body)}',
    );
    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw AuthApiException(
        message ?? '$fallback (${response.statusCode}). $body',
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

  /// Revokes session on the server.
  /// Prefer [refreshToken]; always send [accessToken] as Bearer when available
  /// so logout still hits the API even if refresh is missing.
  Future<void> logout({
    String? refreshToken,
    String? accessToken,
  }) async {
    final hasRefresh = refreshToken != null && refreshToken.isNotEmpty;
    final hasAccess = accessToken != null && accessToken.isNotEmpty;

    if (!hasRefresh && !hasAccess) {
      throw const AuthApiException(
        'No access or refresh token available for logout.',
      );
    }

    final body = <String, dynamic>{};
    if (hasRefresh) body['refreshToken'] = refreshToken;
    if (hasAccess) body['accessToken'] = accessToken;

    debugPrint(
      'AuthApiService: POST ${ApiEndpoints.logoutUrl} '
      'refresh=${hasRefresh ? 'yes' : 'no'} '
      'access=${hasAccess ? 'yes' : 'no'}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.logout,
      headers: hasAccess ? apiAuthHeaders(accessToken) : null,
      body: body,
    );

    final responseBody = response.body.trim();
    debugPrint(
      'AuthApiService: logout response ${response.statusCode}: '
      '${_redactTokenFields(responseBody)}',
    );
    final decoded = _tryDecodeJson(responseBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw AuthApiException(
        message ?? 'Backend logout failed (${response.statusCode}). $responseBody',
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

  static String _avatarMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _logBody(String body, {int maxChars = 400}) {
    final redacted = _redactTokenFields(body);
    if (redacted.length <= maxChars) return redacted;
    return '${redacted.substring(0, maxChars)}…';
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
