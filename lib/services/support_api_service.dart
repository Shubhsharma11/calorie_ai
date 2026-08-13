import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_timezone.dart';
import '../models/problem_report.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class SupportApiException implements Exception {
  const SupportApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SupportApiService {
  SupportApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> submitReport({
    required String accessToken,
    required ProblemCategory category,
    required String description,
    required AppDeviceInfo deviceInfo,
    String? screenshotPath,
  }) async {
    final fields = <String, String>{
      'category': category.apiValue,
      'description': description.trim(),
      ...deviceInfo.toApiFields(),
    };

    final files = <http.MultipartFile>[];
    final path = screenshotPath?.trim();
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      files.add(
        await http.MultipartFile.fromPath(
          'screenshot',
          path,
          filename: path.split(Platform.pathSeparator).last,
        ),
      );
    }

    debugPrint(
      'SupportApiService: POST ${ApiEndpoints.supportReportsUrl} '
      'category=${category.apiValue} hasScreenshot=${files.isNotEmpty}',
    );

    try {
      final response = await _apiClient.postMultipart(
        ApiEndpoints.supportReports,
        fields: fields,
        files: files,
        headers: apiAuthHeaders(accessToken),
      );
      _parseResponse(response);
    } on TimeoutException {
      throw const SupportApiException('Request timed out.');
    }
  }

  void _parseResponse(http.Response response) {
    final body = response.body.trim();
    final statusCode = response.statusCode;
    debugPrint('SupportApiService: response HTTP $statusCode: $body');

    if (statusCode >= 200 && statusCode < 300) return;

    String? message;
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          message = decoded['message'] as String? ?? decoded['error'] as String?;
        }
      } catch (_) {}
    }

    throw SupportApiException(
      message ?? 'Couldn\'t submit your report ($statusCode).',
      statusCode: statusCode,
    );
  }
}
