import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only helper for Google's Phone Number Hint API (SIM-based numbers).
class PhoneHintService {
  PhoneHintService._();

  static const _channel = MethodChannel(
    'com.srhsoftwares.mycaloriepal/phone_hint',
  );

  /// Shows the system phone-number picker. Returns E.164 when the user selects
  /// a number, or `null` if cancelled / unavailable (iOS, errors, no SIM).
  static Future<String?> requestHint() async {
    if (!Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<String>('requestHint');
      if (result == null || result.trim().isEmpty) return null;
      return result.trim();
    } on PlatformException catch (e) {
      debugPrint('PhoneHintService: requestHint failed code=${e.code}');
      return null;
    } catch (e) {
      debugPrint('PhoneHintService: requestHint failed $e');
      return null;
    }
  }

  /// Converts a hint like `+919876543210` into a 10-digit Indian mobile.
  static String? extractIndiaLocalDigits(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    late final String local;

    if (digits.length == 12 && digits.startsWith('91')) {
      local = digits.substring(2);
    } else if (digits.length == 10) {
      local = digits;
    } else if (digits.length > 10) {
      local = digits.substring(digits.length - 10);
    } else {
      return null;
    }

    if (local.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(local)) {
      return local;
    }
    return null;
  }
}
