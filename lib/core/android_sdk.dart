import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Android 13 — system photo picker and `POST_NOTIFICATIONS`.
const android13Sdk = 33;

/// Health Connect APK exists on Android 13; it is a system app on 14+.
const androidHealthConnectMinSdk = 33;

Future<int?> readAndroidSdkInt() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  } catch (_) {
    return null;
  }
}
