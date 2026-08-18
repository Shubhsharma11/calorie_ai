import 'dart:convert';

import 'package:calorie_ai/core/media_url.dart';
import 'package:calorie_ai/models/avatar_upload_result.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/api_endpoints.dart';
import 'package:calorie_ai/services/auth_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _uploadPayload = {
  'success': true,
  'message': 'Profile image uploaded',
  'data': {
    'user': {
      'id': 'user-1',
      'avatarUrl':
          'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/photo.jpg?X-Amz-Signature=abc',
    },
    'avatarUrl':
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/photo.jpg?X-Amz-Signature=abc',
    'expiresIn': 3600,
  },
};

void main() {
  test('AvatarUploadResult reads avatarUrl and expiresIn', () {
    final result = AvatarUploadResult.fromJson(_uploadPayload);

    expect(
      result.avatarUrl,
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/photo.jpg?X-Amz-Signature=abc',
    );
    expect(result.expiresIn, 3600);
  });

  test('MediaUrl reads avatarUrl from a user object', () {
    expect(
      MediaUrl.fromJson({
        'id': 'user-1',
        'avatarUrl': 'https://cdn.example.com/avatars/me.jpg',
      }),
      'https://cdn.example.com/avatars/me.jpg',
    );
  });

  test('AvatarUploadResult prefers avatarUrl over Google picture', () {
    expect(
      AvatarUploadResult.urlFromResponse({
        'data': {
          'user': {
            'picture': 'https://lh3.googleusercontent.com/a/ACg8ocGooglePhoto',
            'avatarUrl':
                'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/me.png',
          },
        },
      }),
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/me.png',
    );
  });

  test('MediaUrl.shouldReplaceAvatar keeps uploaded photo over Google', () {
    const uploaded =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/me.png';
    const google = 'https://lh3.googleusercontent.com/a/ACg8ocGooglePhoto';
    const nextUpload =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/new.png';

    expect(MediaUrl.isUploadedAvatar(uploaded), isTrue);
    expect(MediaUrl.isGooglePhoto(google), isTrue);
    expect(MediaUrl.shouldReplaceAvatar(null, google), isTrue);
    expect(MediaUrl.shouldReplaceAvatar(google, uploaded), isTrue);
    expect(MediaUrl.shouldReplaceAvatar(uploaded, google), isFalse);
    expect(MediaUrl.shouldReplaceAvatar(uploaded, nextUpload), isTrue);
  });

  test('MediaUrl resolves backend avatar keys to S3, not the API host', () {
    expect(
      MediaUrl.resolve('avatars/6a7ea990c8f15080402cdea9-cd7d2d761ce63a5e.png'),
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/'
      '6a7ea990c8f15080402cdea9-cd7d2d761ce63a5e.png',
    );
    expect(
      MediaUrl.resolve(
        'https://fitbuddyai.srhsoftwares.com/avatars/'
        '6a7ea990c8f15080402cdea9-cd7d2d761ce63a5e.png',
      ),
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/'
      '6a7ea990c8f15080402cdea9-cd7d2d761ce63a5e.png',
    );
    expect(
      MediaUrl.canonicalUploadedAvatarUrl(
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/me.png'
        '?X-Amz-Signature=abc',
      ),
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/me.png',
    );
  });

  test('MediaUrl keeps a signed S3 avatar URL', () {
    const signed =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/me.png'
        '?X-Amz-Signature=abc';
    expect(MediaUrl.resolve(signed), signed);
  });

  test('MediaUrl upgrades Google profile photos so they are not 96px', () {
    expect(
      MediaUrl.resolve(
        'https://lh3.googleusercontent.com/a/ACg8ocGooglePhoto=s96-c',
      ),
      'https://lh3.googleusercontent.com/a/ACg8ocGooglePhoto=s1024-c',
    );
    expect(
      MediaUrl.upgradeGooglePhoto(
        'https://lh3.googleusercontent.com/a/ACg8ocGooglePhoto',
      ),
      'https://lh3.googleusercontent.com/a/ACg8ocGooglePhoto=s1024-c',
    );
    expect(
      MediaUrl.upgradeGooglePhoto(
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/me.png',
      ),
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/me.png',
    );
  });

  test('login payload prefers uploaded avatars key over Google picture', () {
    expect(
      AvatarUploadResult.urlFromResponse({
        'data': {
          'user': {
            'picture': 'https://lh3.googleusercontent.com/a/ACg8ocGooglePhoto',
            'avatarUrl':
                'avatars/6a7ea990c8f15080402cdea9-cd7d2d761ce63a5e.png',
          },
        },
      }),
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/'
      '6a7ea990c8f15080402cdea9-cd7d2d761ce63a5e.png',
    );
  });

  test(
    'login payload keeps uploaded avatar when avatarUrl is Google photo',
    () {
      expect(
        MediaUrl.preferAvatar([
          'https://lh3.googleusercontent.com/a/ACg8ocGooglePhoto',
          'avatars/6a7ea990c8f15080402cdea9-cd7d2d761ce63a5e.png',
        ]),
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/'
        '6a7ea990c8f15080402cdea9-cd7d2d761ce63a5e.png',
      );
      expect(
        MediaUrl.shouldReplaceAvatar(
          'https://fitbuddyai.s3.ap-south-1.amazonaws.com/avatars/'
              '6a7ea990c8f15080402cdea9-cd7d2d761ce63a5e.png',
          'https://lh3.googleusercontent.com/a/ACg8ocGooglePhoto',
        ),
        isFalse,
      );
    },
  );

  test('AuthApiService uploads image as multipart field', () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;
    late String capturedBody;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      capturedBody = latin1.decode(request.bodyBytes);
      return http.Response('''
{
  "success": true,
  "message": "Profile image uploaded",
  "data": {
    "user": {"id": "user-1", "avatarUrl": "https://cdn.example.com/a.jpg"},
    "avatarUrl": "https://cdn.example.com/a.jpg",
    "expiresIn": 3600
  }
}
''', 200);
    });

    final service = AuthApiService(apiClient: ApiClient(client: client));
    final result = await service.uploadAvatar(
      accessToken: 'token-123',
      imageBytes: const [0xFF, 0xD8, 0xFF, 0xD9],
      filename: 'avatar.jpg',
    );

    expect(capturedUri.path, ApiEndpoints.authMeAvatar);
    expect(capturedHeaders['authorization'], 'Bearer token-123');
    expect(capturedBody, contains('name="image"'));
    expect(capturedBody, contains('filename="avatar.jpg"'));
    expect(capturedBody.toLowerCase(), contains('content-type: image/jpeg'));
    expect(result.avatarUrl, 'https://cdn.example.com/a.jpg');
    expect(result.expiresIn, 3600);
  });

  test('AuthApiService fetchMe uses bearer token', () async {
    late Uri capturedUri;
    late Map<String, String> capturedHeaders;

    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedHeaders = request.headers;
      return http.Response(
        '{"success":true,"data":{"user":{"avatarUrl":"https://cdn.example.com/me.jpg"}}}',
        200,
      );
    });

    final service = AuthApiService(apiClient: ApiClient(client: client));
    final me = await service.fetchMe(accessToken: 'token-123');

    expect(capturedUri.path, ApiEndpoints.authMe);
    expect(capturedHeaders['authorization'], 'Bearer token-123');
    expect(
      AvatarUploadResult.urlFromResponse(me),
      'https://cdn.example.com/me.jpg',
    );
  });

  test('AuthApiService sends image/png for png uploads', () async {
    late String capturedBody;

    final client = MockClient((request) async {
      capturedBody = latin1.decode(request.bodyBytes);
      return http.Response(
        '{"success":true,"data":{"avatarUrl":"https://cdn.example.com/a.png"}}',
        200,
      );
    });

    final service = AuthApiService(apiClient: ApiClient(client: client));
    await service.uploadAvatar(
      accessToken: 'token-123',
      imageBytes: const [0x89, 0x50, 0x4E, 0x47],
      filename: 'avatar.png',
    );

    expect(capturedBody, contains('filename="avatar.png"'));
    expect(capturedBody.toLowerCase(), contains('content-type: image/png'));
  });

  test('AuthApiService throws when avatar upload fails', () async {
    final client = MockClient((request) async {
      return http.Response('{"message":"File too large"}', 413);
    });

    final service = AuthApiService(apiClient: ApiClient(client: client));
    expect(
      () => service.uploadAvatar(
        accessToken: 'token-123',
        imageBytes: const [0xFF, 0xD8, 0xFF, 0xD9],
      ),
      throwsA(
        isA<AuthApiException>().having(
          (e) => e.message,
          'message',
          'File too large',
        ),
      ),
    );
  });
}
