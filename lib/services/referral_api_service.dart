import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../core/safe_api_log.dart';
import '../models/referral_info.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class ReferralApiException implements Exception {
  const ReferralApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Flutter API client for referral endpoints.
///
/// Backend must still ship:
/// - `GET /api/v1/referrals/me`
/// - `POST /api/v1/referrals/claim`
///
/// This service does not invent rewards — it only parses responses.
class ReferralApiService {
  ReferralApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// GET /api/v1/referrals/me
  Future<ReferralInfo> fetchMyReferral({
    required String accessToken,
  }) async {
    debugPrint(
      'ReferralApiService: GET ${ApiEndpoints.referralsMe} '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.get(
      ApiEndpoints.referralsMe,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseInfo(response);
  }

  /// POST /api/v1/referrals/claim  body: `{ "code": "AB12CD" }`
  Future<ReferralClaimResult> claimReferral({
    required String accessToken,
    required String code,
  }) async {
    final normalized = code.trim().toUpperCase();
    debugPrint(
      'ReferralApiService: POST ${ApiEndpoints.referralsClaim} '
      'codeLength=${normalized.length}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.referralsClaim,
      headers: {
        ...apiAuthHeaders(accessToken),
        'Content-Type': 'application/json',
      },
      body: {'code': normalized},
    );

    return _parseClaim(response);
  }

  ReferralInfo _parseInfo(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReferralApiException(
        _errorMessage(
          response,
          fallback: 'Unable to load your invite details.',
        ),
        statusCode: response.statusCode,
      );
    }

    final decoded = _decodeMap(response.body);
    if (decoded == null) {
      throw const ReferralApiException('Invite details response was empty.');
    }

    final nested = decoded['data'] ?? decoded['referral'] ?? decoded['result'];
    final map = nested is Map
        ? Map<String, dynamic>.from(nested)
        : decoded;

    final info = ReferralInfo.fromJson(map);
    if (info.referralCode.isEmpty) {
      throw const ReferralApiException(
        'Invite details did not include a referral code.',
      );
    }
    return info;
  }

  ReferralClaimResult _parseClaim(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReferralApiException(
        _errorMessage(
          response,
          fallback: 'Unable to apply that invite code.',
        ),
        statusCode: response.statusCode,
      );
    }

    if (response.body.trim().isEmpty) {
      return const ReferralClaimResult(
        success: true,
        rewardConfirmed: true,
      );
    }

    final decoded = _decodeMap(response.body);
    if (decoded == null) {
      return const ReferralClaimResult(
        success: true,
        rewardConfirmed: true,
      );
    }

    final nested = decoded['data'] ?? decoded['result'];
    final map = nested is Map
        ? Map<String, dynamic>.from(nested)
        : decoded;
    return ReferralClaimResult.fromJson(map);
  }

  Map<String, dynamic>? _decodeMap(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String _errorMessage(http.Response response, {required String fallback}) {
    final detail = safeHttpErrorDetail(response.statusCode, response.body);
    if (detail.trim().isEmpty) {
      return '$fallback (${response.statusCode})';
    }
    return detail;
  }
}
