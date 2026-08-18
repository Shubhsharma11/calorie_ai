import 'dart:async';
import 'dart:convert';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:http/http.dart' as http;

import 'analytics_service.dart';
import 'api_endpoints.dart';
import 'platform_http_client.dart';

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? createPlatformHttpClient(),
      _baseUrl = baseUrl ?? ApiEndpoints.baseUrl;

  static const _requestTimeout = Duration(seconds: 25);
  static const _uploadTimeout = Duration(seconds: 45);

  final http.Client _client;
  final String _baseUrl;

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
      timeout: _uploadTimeout,
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
    // Avoid sending Content-Type without a body — some APIs reject that on DELETE.
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
    Duration timeout = _requestTimeout,
  }) async {
    final uri = _uri(endpoint, baseUrl: baseUrl);
    final requestHeaders = mergeDefaultJsonHeaders
        ? _headers(headers)
        : <String, String>{...?headers};

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
      final response = await send(uri, requestHeaders).timeout(timeout);
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
      try {
        await AnalyticsService.recordError(
          error,
          stackTrace,
          reason: 'api_${method.name.toLowerCase()}_${uri.path}',
        );
      } catch (_) {}
      rethrow;
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
