import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'android_sdk.dart';

/// Gallery on Android 12 / 12L still needs `READ_EXTERNAL_STORAGE`.
bool galleryNeedsStoragePermission(int androidSdkInt) =>
    androidSdkInt < android13Sdk;

String photoPermissionDeniedMessage(ImageSource source) {
  if (source == ImageSource.camera) {
    return 'Camera permission is required to take a photo.';
  }
  return 'Photo access is required to choose an image.';
}

/// Requests camera or storage permission for [source] on versions that need it.
///
/// Android 13+ gallery uses the system picker and does not need a grant.
Future<bool> ensureImageSourcePermission(
  ImageSource source, {
  Future<int> Function()? androidSdkInt,
  Future<PermissionStatus> Function(Permission permission)? request,
}) async {
  Future<PermissionStatus> requestPermission(Permission permission) {
    if (request != null) return request(permission);
    return permission.request();
  }

  if (source == ImageSource.camera) {
    final status = await requestPermission(Permission.camera);
    return status.isGranted;
  }

  if (kIsWeb) return true;

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final status = await requestPermission(Permission.photos);
    return status.isGranted || status.isLimited;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    final sdk = androidSdkInt != null
        ? await androidSdkInt()
        : await readAndroidSdkInt();
    if (sdk == null || !galleryNeedsStoragePermission(sdk)) return true;
    final status = await requestPermission(Permission.storage);
    return status.isGranted;
  }

  return true;
}
