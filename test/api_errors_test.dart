import 'package:calorie_ai/core/api_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('apiNetworkErrorMessage explains host lookup failures', () {
    const error = 'ClientException: Failed host lookup: example.trycloudflare.com';
    final message = apiNetworkErrorMessage(error, action: 'saving meal');

    expect(message, contains('Cannot reach the server'));
    expect(message, contains('tunnel'));
  });
}
