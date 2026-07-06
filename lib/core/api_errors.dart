import '../services/api_endpoints.dart';

/// User-facing network error text for API calls.
String apiNetworkErrorMessage(
  Object error, {
  required String action,
}) {
  final text = error.toString();
  if (text.contains('Failed host lookup') ||
      text.contains('SocketException') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable')) {
    return 'Cannot reach the server at ${ApiEndpoints.baseUrl}. '
        'Start your backend (Cloudflare tunnel) and update the API base URL '
        'if the tunnel URL changed.';
  }
  return 'Network error while $action.';
}
