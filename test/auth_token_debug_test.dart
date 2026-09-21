import 'dart:convert';

import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/auth_token_debug.dart';
import 'package:flutter_test/flutter_test.dart';

String _fakeJwt({
  required String sub,
  required int expEpochSec,
  String iss = 'fitbuddy-api',
  int? iat,
}) {
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': sub,
        'iss': iss,
        'iat': iat ?? (expEpochSec - 3600),
        'exp': expEpochSec,
      }),
    ),
  );
  return '$header.$payload.sig';
}

void main() {
  test('AuthTokenDebug fingerprint never includes the full token', () {
    final token = _fakeJwt(
      sub: 'user-1',
      expEpochSec: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 3600,
    );
    final fp = AuthTokenDebug.fingerprint(token);
    expect(fp.contains(token), isFalse);
    expect(fp, contains('len=${token.length}'));
    expect(fp, contains('…${token.substring(token.length - 6)}'));
  });

  test('AuthTokenDebug describe reports expiry relative to now', () {
    final exp = DateTime.now().toUtc().add(const Duration(hours: 2));
    final token = _fakeJwt(
      sub: 'user-42',
      iss: 'test-issuer',
      expEpochSec: exp.millisecondsSinceEpoch ~/ 1000,
    );
    final desc = AuthTokenDebug.describe(token, source: 'memory');
    expect(desc.contains(token), isFalse);
    expect(desc, contains('source=memory'));
    expect(desc, contains('expired=no'));
    expect(desc, contains('iss=test-issuer'));
    expect(desc, contains('sub=user-42'));
  });

  test('readBackendString prefers nested data.tokens for login payloads', () {
    final token = UserController.readBackendString(
      {
        'success': true,
        'data': {
          'tokens': {
            'accessToken': 'nested-access',
            'refreshToken': 'nested-refresh',
          },
        },
      },
      'accessToken',
    );
    expect(token, 'nested-access');
  });

  test('readBackendString prefers top-level accessToken when present', () {
    final token = UserController.readBackendString(
      {
        'accessToken': 'top-level',
        'data': {
          'tokens': {'accessToken': 'nested'},
        },
      },
      'accessToken',
    );
    expect(token, 'top-level');
  });
}
