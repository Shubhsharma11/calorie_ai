import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/api_timezone.dart';
import '../core/image_downscale.dart';
import '../models/image_upload_result.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class UploadsApiException implements Exception {
  const UploadsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class UploadsApiService {
  UploadsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// POST `/api/v1/uploads/image` — authenticated multipart, single `image` part.
  Future<ImageUploadResult> uploadImage({
    required String accessToken,
    required List<int> imageBytes,
    String filename = 'image.jpg',
  }) async {
    if (imageBytes.isEmpty) {
      throw const UploadsApiException('Selected photo could not be read.');
    }

    final safeName = filename.trim().isEmpty ? 'image.jpg' : filename.trim();
    final mimeType = uploadImageMimeTypeForFilename(safeName);
    debugPrint(
      'UploadsApiService: POST ${ApiEndpoints.uploadsImageUrl} '
      'Authorization: Bearer *** file=$safeName contentType=$mimeType '
      'bytes=${imageBytes.length}',
    );

    final response = await _apiClient.postMultipart(
      ApiEndpoints.uploadsImage,
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
      fallback: 'Image upload failed',
    );
    try {
      return ImageUploadResult.fromJson(decoded);
    } on FormatException {
      throw const UploadsApiException(
        'Image uploaded, but the server did not return an object key.',
      );
    }
  }

  Map<String, dynamic> _decodeSuccessMap(
    http.Response response, {
    required String fallback,
  }) {
    final body = response.body.trim();
    debugPrint(
      'UploadsApiService: response ${response.statusCode}: '
      '${_logBody(body)}',
    );
    final decoded = _tryDecodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw UploadsApiException(
        message ?? '$fallback (${response.statusCode}). $body',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  dynamic _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  String _logBody(String body, {int maxChars = 400}) {
    if (body.length <= maxChars) return body;
    return '${body.substring(0, maxChars)}…';
  }
}
