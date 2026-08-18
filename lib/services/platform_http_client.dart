import 'package:http/http.dart' as http;

import 'platform_http_client_stub.dart'
    if (dart.library.io) 'platform_http_client_io.dart' as impl;

/// Shared HTTP client. Android uses Cronet (device TLS store) so HTTPS
/// works on Android 8–12 the same way it does on newer versions.
http.Client createPlatformHttpClient() => impl.createPlatformHttpClient();

/// Timeouts for dart:io `Image.network` / `HttpClient` (not Cronet).
void installPlatformHttpOverrides() => impl.installPlatformHttpOverrides();
