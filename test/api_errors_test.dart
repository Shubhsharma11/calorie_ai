import 'package:calorie_ai/core/android_sdk.dart';
import 'package:calorie_ai/core/api_errors.dart';
import 'package:calorie_ai/core/photo_permission.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('apiNetworkErrorMessage explains host lookup failures', () {
    const error = 'ClientException: Failed host lookup: example.trycloudflare.com';
    final message = apiNetworkErrorMessage(error, action: 'saving meal');

    expect(message, contains('Cannot reach the server'));
    expect(message, contains('internet connection'));
  });

  test('apiNetworkErrorMessage treats TLS handshake failures as network errors', () {
    const error =
        'HandshakeException: Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED)';
    expect(isApiNetworkError(error), isTrue);
    expect(
      apiNetworkErrorMessage(error, action: 'loading meals'),
      contains('Cannot reach the server'),
    );
  });

  test('galleryNeedsStoragePermission is true on Android 12 and false on 13+', () {
    expect(galleryNeedsStoragePermission(31), isTrue);
    expect(galleryNeedsStoragePermission(32), isTrue);
    expect(galleryNeedsStoragePermission(33), isFalse);
    expect(galleryNeedsStoragePermission(35), isFalse);
  });

  test('Health Connect is not offered below Android 13', () {
    expect(26 >= androidHealthConnectMinSdk, isFalse);
    expect(31 >= androidHealthConnectMinSdk, isFalse);
    expect(32 >= androidHealthConnectMinSdk, isFalse);
    expect(33 >= androidHealthConnectMinSdk, isTrue);
    expect(34 >= androidHealthConnectMinSdk, isTrue);
  });

  test('ensureImageSourcePermission requests storage on Android 12 gallery', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    Permission? requested;
    final allowed = await ensureImageSourcePermission(
      ImageSource.gallery,
      androidSdkInt: () async => 31,
      request: (permission) async {
        requested = permission;
        return PermissionStatus.granted;
      },
    );

    expect(allowed, isTrue);
    expect(requested, Permission.storage);
  });

  test('ensureImageSourcePermission skips storage on Android 13 gallery', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    var requested = false;
    final allowed = await ensureImageSourcePermission(
      ImageSource.gallery,
      androidSdkInt: () async => 33,
      request: (_) async {
        requested = true;
        return PermissionStatus.denied;
      },
    );

    expect(allowed, isTrue);
    expect(requested, isFalse);
  });

  test('ensureImageSourcePermission requests camera on every Android version', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    Permission? requested;
    final allowed = await ensureImageSourcePermission(
      ImageSource.camera,
      androidSdkInt: () async => 33,
      request: (permission) async {
        requested = permission;
        return PermissionStatus.granted;
      },
    );

    expect(allowed, isTrue);
    expect(requested, Permission.camera);
  });
}
