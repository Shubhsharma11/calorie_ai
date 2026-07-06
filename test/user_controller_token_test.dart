import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('readBackendString resolves nested access token', () {
    final token = UserController.readBackendString(
      {
        'success': true,
        'data': {
          'tokens': {
            'accessToken': 'nested-access-token',
            'refreshToken': 'nested-refresh-token',
          },
        },
      },
      'accessToken',
    );

    expect(token, 'nested-access-token');
  });

  test('readBackendString prefers top-level token', () {
    final token = UserController.readBackendString(
      {
        'accessToken': 'top-level-token',
        'tokens': {'accessToken': 'nested-access-token'},
      },
      'accessToken',
    );

    expect(token, 'top-level-token');
  });
}
