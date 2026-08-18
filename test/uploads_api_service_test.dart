import 'dart:convert';

import 'package:calorie_ai/core/media_url.dart';
import 'package:calorie_ai/models/image_upload_result.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/api_endpoints.dart';
import 'package:calorie_ai/services/uploads_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _uploadPayload = {
  'success': true,
  'data': {
    'key': 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
    'url':
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg?X-Amz-Signature=abc',
    'expiresIn': 3600,
    'contentType': 'image/jpeg',
    'size': 184203,
  },
};

void main() {
  test('ImageUploadResult prefers object key over signed URL', () {
    final result = ImageUploadResult.fromJson(_uploadPayload);

    expect(result.key, 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg');
    expect(
      result.url,
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
      'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg?X-Amz-Signature=abc',
    );
    expect(result.expiresIn, 3600);
    expect(result.contentType, 'image/jpeg');
    expect(result.size, 184203);
  });

  test('MediaUrl keeps signed S3 upload URLs so private objects still load', () {
    const signed =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
        'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg?X-Amz-Signature=abc';
    expect(MediaUrl.resolve(signed), signed);
    expect(
      MediaUrl.resolve('uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg'),
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
      'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
    );
    expect(MediaUrl.apiImageKey(signed), 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg');
  });

  test('MediaUrl resolves uploads keys to unsigned S3, not the API host', () {
    expect(
      MediaUrl.resolve('uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg'),
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
      'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
    );
    expect(
      MediaUrl.apiImageKey(
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
        'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg?X-Amz-Signature=abc',
      ),
      'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
    );
  });

  test('MediaUrl keeps API-relative catalog /uploads/ paths on the API host', () {
    expect(
      MediaUrl.resolve('/uploads/aam-panna.png'),
      'https://fitbuddyai.srhsoftwares.com/uploads/aam-panna.png',
    );
    expect(MediaUrl.apiImageKey('/uploads/aam-panna.png'), isNull);
  });

  test('MediaUrl.fromJson prefers a signed S3 URL over the uploads key', () {
    const signed =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
        'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg?X-Amz-Signature=abc';
    expect(
      MediaUrl.fromJson({
        'image': 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
        'imageUrl': signed,
      }),
      signed,
    );
    expect(
      MediaUrl.fromJson({
        'image': {
          'key': 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
          'signedUrl': signed,
        },
      }),
      signed,
    );
  });

  test('MediaUrl.fromJson uses a catalog icon URL and ignores emoji icons', () {
    expect(
      MediaUrl.fromJson({
        'icon': '/uploads/aam-panna.png',
      }),
      'https://fitbuddyai.srhsoftwares.com/uploads/aam-panna.png',
    );
    expect(MediaUrl.fromJson({'icon': '🥣', 'image': ''}), isNull);
  });

  test('UploadsApiService posts multipart image field', () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;
    late String capturedBody;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      capturedBody = latin1.decode(request.bodyBytes);
      return http.Response(jsonEncode(_uploadPayload), 200);
    });

    final service = UploadsApiService(apiClient: ApiClient(client: client));
    final result = await service.uploadImage(
      accessToken: 'token-123',
      imageBytes: const [0xFF, 0xD8, 0xFF, 0xD9],
      filename: 'image.jpg',
    );

    expect(capturedUri.path, ApiEndpoints.uploadsImage);
    expect(capturedHeaders['authorization'], 'Bearer token-123');
    expect(capturedBody, contains('name="image"'));
    expect(capturedBody, contains('filename="image.jpg"'));
    expect(capturedBody.toLowerCase(), contains('content-type: image/jpeg'));
    expect(result.key, 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg');
  });
}
