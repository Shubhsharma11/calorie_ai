import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const _userAgent = 'FitBuddyAI/1.0';
const _connectionTimeout = Duration(seconds: 20);

http.Client? _shared;

http.Client createPlatformHttpClient() =>
    _shared ??= _createPlatformHttpClient();

http.Client _createPlatformHttpClient() {
  if (Platform.isAndroid) {
    try {
      final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 2 * 1024 * 1024,
        userAgent: _userAgent,
      );
      return CronetClient.fromCronetEngine(engine, closeEngine: true);
    } catch (_) {
      return _ioClient();
    }
  }
  return _ioClient();
}

http.Client _ioClient() {
  return IOClient(
    HttpClient()
      ..userAgent = _userAgent
      ..connectionTimeout = _connectionTimeout
      ..idleTimeout = _connectionTimeout,
  );
}

void installPlatformHttpOverrides() {
  HttpOverrides.global = _TimeoutHttpOverrides();
}

class _TimeoutHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..userAgent = _userAgent
      ..connectionTimeout = _connectionTimeout
      ..idleTimeout = _connectionTimeout;
  }
}
