import 'dart:convert';

/// Safe HTTP diagnostics for debug logs — never dumps full bodies or secrets.
String safeHttpResponseLog(int statusCode, String body, {int maxMessage = 120}) {
  final message = _extractErrorMessage(body);
  if (message != null && message.isNotEmpty) {
    return 'HTTP $statusCode: ${_truncate(message, maxMessage)}';
  }
  return 'HTTP $statusCode (body ${body.length} chars)';
}

/// Short summary for exception fallbacks (no full body dump).
String safeHttpErrorDetail(int statusCode, String body, {int maxMessage = 80}) {
  final message = _extractErrorMessage(body);
  if (message != null && message.isNotEmpty) {
    return _truncate(message, maxMessage);
  }
  return 'HTTP $statusCode';
}

String? _extractErrorMessage(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      for (final key in ['message', 'error', 'detail', 'title']) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
  } on FormatException {
    // Non-JSON bodies: never return the raw payload.
  }
  return null;
}

String _truncate(String value, int max) {
  if (value.length <= max) return value;
  return '${value.substring(0, max)}…';
}
