import 'dart:async';

import 'package:http/http.dart' as http;

/// User-facing network error text for API calls.
String apiNetworkErrorMessage(
  Object error, {
  required String action,
}) {
  if (isApiNetworkError(error)) {
    return 'Cannot reach the server. Check your internet connection and try again.';
  }
  return 'Network error while $action.';
}

bool isApiNetworkError(Object error) {
  if (error is TimeoutException) return true;
  if (error is http.ClientException) return true;
  final text = error.toString();
  return text.contains('Failed host lookup') ||
      text.contains('SocketException') ||
      text.contains('HandshakeException') ||
      text.contains('CERTIFICATE_VERIFY_FAILED') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable') ||
      text.contains('TimeoutException') ||
      text.contains('ClientException');
}
