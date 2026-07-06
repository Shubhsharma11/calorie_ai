import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../models/onboarding_request_model.dart';
import '../models/onboarding_response_model.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class OnboardingApiException implements Exception {
  const OnboardingApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class OnboardingApiService {
  OnboardingApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<OnboardingResponseModel> submitOnboarding({
    required String accessToken,
    required OnboardingRequestModel request,
  }) {
    return _sendOnboarding(
      method: 'PUT',
      accessToken: accessToken,
      payload: request.toJson(),
    );
  }

  Future<OnboardingResponseModel> patchOnboarding({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) {
    return _sendOnboarding(
      method: 'PATCH',
      accessToken: accessToken,
      payload: payload,
    );
  }

  Future<OnboardingResponseModel> fetchOnboarding({
    required String accessToken,
  }) async {
    debugPrint('OnboardingApiService: GET ${ApiEndpoints.onboardingUrl}');

    final response = await _apiClient.get(
      ApiEndpoints.onboarding,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final body = response.body.trim();
    log(
      'OnboardingApiService: GET response ${response.statusCode}: $body',
    );

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw OnboardingApiException(
        message ??
            'Onboarding request failed (${response.statusCode}). $body',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return OnboardingResponseModel.fromJson(decoded);
    }

    return const OnboardingResponseModel(message: 'Onboarding loaded');
  }

  Future<OnboardingResponseModel> _sendOnboarding({
    required String method,
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    debugPrint('OnboardingApiService: $method ${ApiEndpoints.onboardingUrl}');
    if (kDebugMode) {
      debugPrint(
        'OnboardingApiService: request body:\n'
        '${const JsonEncoder.withIndent('  ').convert(payload)}',
      );
    }

    final response = method == 'PATCH'
        ? await _apiClient.patch(
            ApiEndpoints.onboarding,
            body: payload,
            headers: {'Authorization': 'Bearer $accessToken'},
          )
        : await _apiClient.put(
            ApiEndpoints.onboarding,
            body: payload,
            headers: {'Authorization': 'Bearer $accessToken'},
          );

    final body = response.body.trim();
    log(
      'OnboardingApiService: response ${response.statusCode}: $body',
    );

    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw OnboardingApiException(
        message ??
            'Onboarding submission failed (${response.statusCode}). $body',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) {
      return OnboardingResponseModel.fromJson(decoded);
    }

    return const OnboardingResponseModel(message: 'Onboarding completed');
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
