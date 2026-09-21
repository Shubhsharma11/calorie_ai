import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_log.dart';

/// Safe JWT / access-token diagnostics — never logs the full token.
class AuthTokenDebug {
  AuthTokenDebug._();

  /// Last 6 chars + length (enough to see token changes, not enough to reuse).
  static String fingerprint(String? token) {
    if (token == null || token.isEmpty) return 'empty';
    final tail = token.length <= 6 ? token : token.substring(token.length - 6);
    return 'len=${token.length} …$tail';
  }

  static Map<String, dynamic> claims(String? token) {
    if (token == null || token.isEmpty) return const {};
    final parts = token.split('.');
    if (parts.length < 2) return const {};
    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    } catch (_) {
      return const {};
    }
  }

  static DateTime? expiry(String? token) {
    final exp = claims(token)['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    }
    return null;
  }

  /// One-line metadata: fingerprint, exp, iat, iss, sub, skew vs device now.
  static String describe(String? token, {String source = ''}) {
    final fp = fingerprint(token);
    if (token == null || token.isEmpty) {
      return source.isEmpty ? fp : '$fp source=$source';
    }
    final c = claims(token);
    final exp = expiry(token);
    final now = DateTime.now().toUtc();
    final iat = c['iat'];
    final iss = c['iss'];
    final sub = c['sub'];
    final expired = exp == null ? 'unknown' : (exp.isBefore(now) ? 'YES' : 'no');
    final skew = exp == null
        ? 'n/a'
        : '${exp.difference(now).inSeconds}s';
    final src = source.isEmpty ? '' : ' source=$source';
    return '$fp$src exp=${exp?.toIso8601String() ?? 'n/a'} '
        'now=${now.toIso8601String()} expired=$expired skew=$skew '
        'iat=$iat iss=$iss sub=$sub';
  }

  static void log(String label, String? token, {String source = ''}) {
    if (!kDebugMode) return;
    appLog('$label ${describe(token, source: source)}');
  }
}
