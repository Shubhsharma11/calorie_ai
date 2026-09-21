import 'dart:async';
import 'dart:convert';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_log.dart';
import '../core/auth_token_debug.dart';
import '../core/home_stuck_debug.dart'; // TEMPORARY — HOME_STUCK_DEBUG
import 'analytics_service.dart';
import 'api_endpoints.dart';
import 'platform_http_client.dart';

/// One row in the debug request ring buffer (for 429 diagnosis).
class ApiRequestLogEntry {
  const ApiRequestLogEntry({
    required this.id,
    required this.method,
    required this.path,
    required this.startedAt,
    this.endedAt,
    this.statusCode,
    this.outcome,
  });

  final int id;
  final String method;
  final String path;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? statusCode;

  /// `ok` | `http` | `local_429` | `error`
  final String? outcome;

  String get summary {
    final code = statusCode?.toString() ?? '-';
    final result = outcome ?? 'pending';
    return '#$id $method $path → $code ($result)';
  }
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? createPlatformHttpClient(),
      _baseUrl = baseUrl ?? ApiEndpoints.baseUrl;

  /// Bounded production timeout for normal API calls (not uploads).
  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration uploadTimeout = Duration(seconds: 45);

  /// Shared across every [ApiClient] instance so HomeBinding onInit cannot
  /// stampede the backend with parallel GETs (which trip 429s).
  static const _maxConcurrentRequests = 2;
  static const Duration rateLimitFallbackCooldown = Duration(seconds: 90);
  static const Duration _maxRetryAfter = Duration(seconds: 120);

  /// Extra attempts after the first for idempotent GET only.
  static const int maxGetRetries = 2;
  static const Duration _getRetryBaseBackoff = Duration(milliseconds: 300);

  static int _inFlight = 0;
  static final List<Completer<void>> _waitQueue = <Completer<void>>[];
  static DateTime? _rateLimitedUntil;

  static int _nextRequestId = 1;
  static const int _requestLogLimit = 40;
  static final List<ApiRequestLogEntry> _requestLog = <ApiRequestLogEntry>[];

  final http.Client _client;
  final String _baseUrl;

  /// True while a recent 429 is forcing a global pause.
  static bool get isRateLimited =>
      _rateLimitedUntil != null &&
      DateTime.now().isBefore(_rateLimitedUntil!);

  static DateTime? get rateLimitedUntil => _rateLimitedUntil;

  /// Recent requests (oldest → newest) for debug / 429 diagnosis.
  static List<ApiRequestLogEntry> get recentRequestLog =>
      List<ApiRequestLogEntry>.unmodifiable(_requestLog);

  /// Call when a higher-level client learns of a 429 (e.g. profile).
  static void noteRateLimited({Duration? cooldown}) {
    final resolved = _boundedCooldown(cooldown ?? rateLimitFallbackCooldown);
    final until = DateTime.now().add(resolved);
    if (_rateLimitedUntil == null || until.isAfter(_rateLimitedUntil!)) {
      _rateLimitedUntil = until;
    }
  }

  /// Clears the global 429 cooldown (logout / new login).
  static void clearRateLimit() {
    _rateLimitedUntil = null;
  }

  /// Test-only: reset concurrency / rate-limit / log ring between cases.
  @visibleForTesting
  static void debugReset() {
    _inFlight = 0;
    _waitQueue.clear();
    _rateLimitedUntil = null;
    _requestLog.clear();
    debugTimeoutOverride = null;
  }

  /// Test-only: shorten timeouts without changing production defaults.
  @visibleForTesting
  static Duration? debugTimeoutOverride;

  static Duration get effectiveRequestTimeout =>
      debugTimeoutOverride ?? requestTimeout;

  /// Parses `Retry-After` (seconds or HTTP-date). Returns null if missing/invalid.
  @visibleForTesting
  static Duration? parseRetryAfterHeader(Map<String, String> headers) {
    final raw = headers['retry-after'] ?? headers['Retry-After'];
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final asSeconds = int.tryParse(trimmed);
    if (asSeconds != null) {
      if (asSeconds < 0) return null;
      return _boundedCooldown(Duration(seconds: asSeconds));
    }

    try {
      final when = DateTime.parse(trimmed).toUtc();
      final wait = when.difference(DateTime.now().toUtc());
      if (wait.isNegative) return Duration.zero;
      return _boundedCooldown(wait);
    } on FormatException {
      return null;
    }
  }

  static Duration _boundedCooldown(Duration value) {
    if (value > _maxRetryAfter) return _maxRetryAfter;
    if (value.isNegative) return Duration.zero;
    return value;
  }

  static void noteRateLimitedFromResponse(http.Response response) {
    final fromHeader = parseRetryAfterHeader(response.headers);
    noteRateLimited(cooldown: fromHeader ?? rateLimitFallbackCooldown);
  }

  static Duration _getRetryBackoff(int attemptIndex) {
    // attemptIndex 0 → 300ms, 1 → 600ms (bounded).
    final ms = _getRetryBaseBackoff.inMilliseconds * (1 << attemptIndex);
    return Duration(milliseconds: ms.clamp(300, 2000));
  }

  static bool _isTransientGetStatus(int statusCode) {
    return statusCode == 502 || statusCode == 503 || statusCode == 504;
  }

  static bool _isTransientNetworkError(Object error) {
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;
    final text = error.toString();
    return text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused') ||
        text.contains('Network is unreachable') ||
        text.contains('HandshakeException');
  }

  static void _recordRequest(ApiRequestLogEntry entry) {
    _requestLog.add(entry);
    while (_requestLog.length > _requestLogLimit) {
      _requestLog.removeAt(0);
    }
  }

  static void _finishRequest({
    required int id,
    required int? statusCode,
    required String outcome,
  }) {
    final index = _requestLog.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final prev = _requestLog[index];
    _requestLog[index] = ApiRequestLogEntry(
      id: prev.id,
      method: prev.method,
      path: prev.path,
      startedAt: prev.startedAt,
      endedAt: DateTime.now(),
      statusCode: statusCode,
      outcome: outcome,
    );
  }

  /// Dump recent requests when a real or local 429 is observed.
  static void log429Context(String endpoint, {required bool local}) {
    if (!kDebugMode) return;
    appLog(
      'API 429 ${local ? "(local cooldown)" : "(server)"} on $endpoint',
    );
    appLog('API 429 sequence (last ${_requestLog.length}):');
    for (final entry in _requestLog) {
      appLog('  ${entry.summary}');
    }
  }

  static http.Response _rateLimitedResponse() {
    return http.Response(
      '{"success":false,"message":"Too many requests, please try again later"}',
      429,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  /// Concurrency gate only — rate-limit is fail-fast in [_tracedRequest].
  static Future<void> _acquireSlot() async {
    if (_inFlight < _maxConcurrentRequests) {
      _inFlight++;
      return;
    }
    final gate = Completer<void>();
    _waitQueue.add(gate);
    await gate.future;
  }

  static void _releaseSlot() {
    if (_waitQueue.isNotEmpty) {
      _waitQueue.removeAt(0).complete();
      return;
    }
    if (_inFlight > 0) _inFlight--;
  }

  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    return _tracedRequest(
      method: HttpMethod.Get,
      endpoint: endpoint,
      baseUrl: baseUrl,
      send: (uri, requestHeaders) => _client.get(uri, headers: requestHeaders),
      headers: headers,
    );
  }

  Future<http.Response> post(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    final encoded = _encodeBody(body);
    return _tracedRequest(
      method: HttpMethod.Post,
      endpoint: endpoint,
      baseUrl: baseUrl,
      send: (uri, requestHeaders) => _client.post(
        uri,
        headers: requestHeaders,
        body: encoded,
      ),
      headers: headers,
      requestPayloadSize: _payloadSize(encoded),
    );
  }

  Future<http.Response> put(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    final encoded = _encodeBody(body);
    return _tracedRequest(
      method: HttpMethod.Put,
      endpoint: endpoint,
      baseUrl: baseUrl,
      send: (uri, requestHeaders) => _client.put(
        uri,
        headers: requestHeaders,
        body: encoded,
      ),
      headers: headers,
      requestPayloadSize: _payloadSize(encoded),
    );
  }

  Future<http.Response> patch(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    final encoded = _encodeBody(body);
    return _tracedRequest(
      method: HttpMethod.Patch,
      endpoint: endpoint,
      baseUrl: baseUrl,
      send: (uri, requestHeaders) => _client.patch(
        uri,
        headers: requestHeaders,
        body: encoded,
      ),
      headers: headers,
      requestPayloadSize: _payloadSize(encoded),
    );
  }

  Future<http.Response> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    return _tracedRequest(
      method: HttpMethod.Post,
      endpoint: endpoint,
      baseUrl: baseUrl,
      mergeDefaultJsonHeaders: false,
      headers: headers,
      timeout: uploadTimeout,
      allowGetRetry: false,
      send: (uri, requestHeaders) {
        return Future(() async {
          final request = http.MultipartRequest('POST', uri);
          request.headers.addAll(requestHeaders);
          request.fields.addAll(fields);
          request.files.addAll(files);
          final streamed = await _client.send(request);
          return http.Response.fromStream(streamed);
        });
      },
    );
  }

  Future<http.Response> delete(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    final encoded = _encodeBody(body);
    final mergedHeaders = body == null
        ? <String, String>{...?headers}
        : _headers(headers);
    return _tracedRequest(
      method: HttpMethod.Delete,
      endpoint: endpoint,
      baseUrl: baseUrl,
      send: (uri, requestHeaders) => _client.delete(
        uri,
        headers: requestHeaders.isEmpty ? null : requestHeaders,
        body: encoded,
      ),
      headers: mergedHeaders,
      requestPayloadSize: _payloadSize(encoded),
      mergeDefaultJsonHeaders: body != null,
    );
  }

  Future<http.Response> _tracedRequest({
    required HttpMethod method,
    required String endpoint,
    required Future<http.Response> Function(
      Uri uri,
      Map<String, String> headers,
    ) send,
    Map<String, String>? headers,
    String? baseUrl,
    int? requestPayloadSize,
    bool mergeDefaultJsonHeaders = true,
    Duration? timeout,
    bool allowGetRetry = true,
  }) async {
    final resolvedTimeout = timeout ?? effectiveRequestTimeout;
    final uri = _uri(endpoint, baseUrl: baseUrl);
    final requestHeaders = mergeDefaultJsonHeaders
        ? _headers(headers)
        : <String, String>{...?headers};
    final methodName = method.name.toUpperCase();
    final path = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final requestId = _nextRequestId++;
    final isGet = method == HttpMethod.Get && allowGetRetry;
    final maxAttempts = isGet ? (1 + maxGetRetries) : 1;

    _recordRequest(
      ApiRequestLogEntry(
        id: requestId,
        method: methodName,
        path: path,
        startedAt: DateTime.now(),
      ),
    );
    appLog(
      'API START #$requestId $methodName $path '
      '(slots=$_inFlight/$_maxConcurrentRequests)',
    );
    final bearer = requestHeaders['Authorization'];
    if (bearer != null && bearer.startsWith('Bearer ')) {
      final token = bearer.substring(7);
      AuthTokenDebug.log('API AUTH #$requestId $methodName $path', token);
    }

    HttpMetric? metric;
    try {
      metric = AnalyticsService.newHttpMetric(uri.toString(), method);
      await metric.start();
      if (requestPayloadSize != null) {
        metric.requestPayloadSize = requestPayloadSize;
      }
    } catch (_) {
      metric = null;
    }

    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        // Fail fast while cooling down — do not wait and stampede the server.
        if (isRateLimited) {
          _finishRequest(id: requestId, statusCode: 429, outcome: 'local_429');
          appLog(
            'API END #$requestId $methodName $path → 429 (local cooldown)',
          );
          // TEMPORARY — HOME_STUCK_DEBUG
          HomeStuckDebug.logHttpStatus(
            method: methodName,
            path: path,
            statusCode: 429,
          );
          log429Context(path, local: true);
          return _rateLimitedResponse();
        }

        var heldSlot = false;
        try {
          await _acquireSlot();
          heldSlot = true;

          if (isRateLimited) {
            _finishRequest(
              id: requestId,
              statusCode: 429,
              outcome: 'local_429',
            );
            appLog(
              'API END #$requestId $methodName $path → 429 (local cooldown)',
            );
            // TEMPORARY — HOME_STUCK_DEBUG
            HomeStuckDebug.logHttpStatus(
              method: methodName,
              path: path,
              statusCode: 429,
            );
            log429Context(path, local: true);
            return _rateLimitedResponse();
          }

          final response =
              await send(uri, requestHeaders).timeout(resolvedTimeout);

          if (response.statusCode == 429) {
            noteRateLimitedFromResponse(response);
            _finishRequest(id: requestId, statusCode: 429, outcome: 'http');
            appLog('API END #$requestId $methodName $path → 429 (server)');
            // TEMPORARY — HOME_STUCK_DEBUG
            HomeStuckDebug.logHttpStatus(
              method: methodName,
              path: path,
              statusCode: 429,
            );
            log429Context(path, local: false);
            final activeMetric = metric;
            if (activeMetric != null) {
              activeMetric.httpResponseCode = 429;
              activeMetric.responsePayloadSize = response.bodyBytes.length;
            }
            return response;
          }

          // Never generic-retry auth / client errors.
          if (response.statusCode == 401 ||
              response.statusCode == 403 ||
              (response.statusCode >= 400 && response.statusCode < 500)) {
            _finishRequest(
              id: requestId,
              statusCode: response.statusCode,
              outcome: 'ok',
            );
            appLog(
              'API END #$requestId $methodName $path → ${response.statusCode}',
            );
            // TEMPORARY — HOME_STUCK_DEBUG
            if (response.statusCode == 401 || response.statusCode == 403) {
              HomeStuckDebug.logHttpStatus(
                method: methodName,
                path: path,
                statusCode: response.statusCode,
              );
            }
            final activeMetric = metric;
            if (activeMetric != null) {
              activeMetric.httpResponseCode = response.statusCode;
              activeMetric.responsePayloadSize = response.bodyBytes.length;
            }
            return response;
          }

          if (isGet &&
              _isTransientGetStatus(response.statusCode) &&
              attempt < maxAttempts - 1) {
            appLog(
              'API RETRY #$requestId $methodName $path '
              'status=${response.statusCode} attempt=${attempt + 1}/$maxAttempts',
            );
            if (heldSlot) {
              _releaseSlot();
              heldSlot = false;
            }
            await Future<void>.delayed(_getRetryBackoff(attempt));
            continue;
          }

          _finishRequest(
            id: requestId,
            statusCode: response.statusCode,
            outcome: 'ok',
          );
          appLog(
            'API END #$requestId $methodName $path → ${response.statusCode}',
          );
          final activeMetric = metric;
          if (activeMetric != null) {
            activeMetric.httpResponseCode = response.statusCode;
            activeMetric.responsePayloadSize = response.bodyBytes.length;
            final contentType = response.headers['content-type'];
            if (contentType != null && contentType.isNotEmpty) {
              activeMetric.responseContentType = contentType;
            }
          }
          return response;
        } catch (error, stackTrace) {
          if (isGet &&
              _isTransientNetworkError(error) &&
              attempt < maxAttempts - 1) {
            appLog(
              'API RETRY #$requestId $methodName $path '
              'error=$error attempt=${attempt + 1}/$maxAttempts',
            );
            if (heldSlot) {
              _releaseSlot();
              heldSlot = false;
            }
            await Future<void>.delayed(_getRetryBackoff(attempt));
            continue;
          }
          _finishRequest(id: requestId, statusCode: null, outcome: 'error');
          appLog('API END #$requestId $methodName $path → ERROR $error');
          // TEMPORARY — HOME_STUCK_DEBUG
          if (error is TimeoutException) {
            HomeStuckDebug.logTimeout(method: methodName, path: path);
          } else {
            HomeStuckDebug.log(
              'HTTP_ERROR',
              {
                'method': methodName,
                'endpoint': path,
                'errorType': error.runtimeType.toString(),
              },
            );
          }
          try {
            await AnalyticsService.recordError(
              error,
              stackTrace,
              reason: 'api_${method.name.toLowerCase()}_${uri.path}',
            );
          } catch (_) {}
          rethrow;
        } finally {
          if (heldSlot) _releaseSlot();
        }
      }

      throw StateError('ApiClient: exhausted retries without response');
    } finally {
      await metric?.stop();
    }
  }

  Uri _uri(String endpoint, {String? baseUrl}) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint);
    }

    final root = (baseUrl ?? _baseUrl).replaceFirst(RegExp(r'/$'), '');
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$root$path');
  }

  Map<String, String> _headers(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      ...?headers,
    };
  }

  Object? _encodeBody(Object? body) {
    if (body == null || body is String) return body;
    return jsonEncode(body);
  }

  int? _payloadSize(Object? encoded) {
    if (encoded is String) return utf8.encode(encoded).length;
    return null;
  }
}
