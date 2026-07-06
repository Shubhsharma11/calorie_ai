import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_endpoints.dart';

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiEndpoints.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    return _client.get(
      _uri(endpoint, baseUrl: baseUrl),
      headers: _headers(headers),
    );
  }

  Future<http.Response> post(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    return _client.post(
      _uri(endpoint, baseUrl: baseUrl),
      headers: _headers(headers),
      body: _encodeBody(body),
    );
  }

  Future<http.Response> put(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    return _client.put(
      _uri(endpoint, baseUrl: baseUrl),
      headers: _headers(headers),
      body: _encodeBody(body),
    );
  }

  Future<http.Response> patch(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    return _client.patch(
      _uri(endpoint, baseUrl: baseUrl),
      headers: _headers(headers),
      body: _encodeBody(body),
    );
  }

  Future<http.Response> delete(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    String? baseUrl,
  }) {
    return _client.delete(
      _uri(endpoint, baseUrl: baseUrl),
      headers: _headers(headers),
      body: _encodeBody(body),
    );
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
}
