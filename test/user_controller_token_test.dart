import 'package:calorie_ai/controllers/auth_controller.dart';
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

  test('readDisplayName reads nested user.name and ignores empty values', () {
    expect(
      UserController.readDisplayName({
        'success': true,
        'data': {
          'user': {'id': 'user-1', 'name': 'Ramji RN'},
        },
      }),
      'Ramji RN',
    );

    expect(
      UserController.readDisplayName({
        'user': {'name': ''},
      }),
      '',
    );

    expect(
      UserController.readDisplayName({
        'data': {
          'user': {
            'fullName': {'givenName': 'Ramji', 'familyName': 'RN'},
          },
        },
      }),
      'Ramji RN',
    );
  });

  test('resolveLoginDisplayName keeps backend name when Apple sends empty', () {
    const backend = {
      'data': {
        'user': {'name': 'Ramji RN'},
      },
    };

    expect(
      UserController.resolveLoginDisplayName(
        backendResponse: backend,
        providerName: '',
      ),
      'Ramji RN',
    );
    expect(
      UserController.resolveLoginDisplayName(
        backendResponse: backend,
        providerName: 'Ignored Apple Empty',
      ),
      'Ramji RN',
    );
    expect(
      UserController.resolveLoginDisplayName(
        backendResponse: const {},
        providerName: 'First Login Name',
      ),
      'First Login Name',
    );
  });

  test('appleDisplayName joins given and family name', () {
    expect(
      AuthController.appleDisplayName(givenName: 'Ramji', familyName: 'RN'),
      'Ramji RN',
    );
    expect(
      AuthController.appleDisplayName(givenName: 'Ramji', familyName: '  '),
      'Ramji',
    );
    expect(
      AuthController.appleDisplayName(givenName: null, familyName: null),
      '',
    );
  });
}
