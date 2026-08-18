import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/problem_report.dart';

class DeviceInfoService {
  DeviceInfoService({
    DeviceInfoPlugin? deviceInfo,
    Future<PackageInfo> Function()? packageInfo,
  })  : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _packageInfo = packageInfo ?? PackageInfo.fromPlatform; 

  final DeviceInfoPlugin _deviceInfo;
  final Future<PackageInfo> Function() _packageInfo;

  Future<AppDeviceInfo> collect() async {
    var appVersion = '';
    var buildNumber = '';
    var platform = Platform.operatingSystem;
    var osVersion = Platform.operatingSystemVersion;
    var deviceModel = '';

    try {
      final package = await _packageInfo();
      if (package.version.trim().isNotEmpty) {
        appVersion = package.version.trim();
      }
      if (package.buildNumber.trim().isNotEmpty) {
        buildNumber = package.buildNumber.trim();
      }
    } catch (error, stackTrace) {
      debugPrint('DeviceInfoService: package info failed: $error\n$stackTrace');
    }

    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        platform = 'Android';
        osVersion = 'Android ${info.version.release}';
        deviceModel = info.model.trim();
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        platform = 'iOS';
        osVersion = 'iOS ${info.systemVersion}';
        final modelName = info.modelName.trim();
        deviceModel = modelName.isNotEmpty
            ? modelName
            : info.utsname.machine.trim();
      } else {
        platform = Platform.operatingSystem;
        osVersion = Platform.operatingSystemVersion;
      }
    } catch (error, stackTrace) {
      debugPrint('DeviceInfoService: device info failed: $error\n$stackTrace');
    }

    return AppDeviceInfo(
      appVersion: appVersion,
      buildNumber: buildNumber,
      platform: platform,
      osVersion: osVersion,
      deviceModel: deviceModel,
    );
  }
}
