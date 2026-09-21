import 'dart:async';

import 'package:calorie_ai/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    ApiClient.debugReset();
  });

  tearDown(() {
    ApiClient.debugReset();
  });

  test('normal API timeout is bounded (15–30s production default)', () {
    expect(
      ApiClient.requestTimeout.inSeconds,
      inInclusiveRange(15, 30),
    );
    expect(ApiClient.requestTimeout, const Duration(seconds: 20));
  });

  test('timeout produces a controlled TimeoutException', () async {
    ApiClient.debugTimeoutOverride = const Duration(milliseconds: 80);
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return http.Response('ok', 200);
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');

    await expectLater(
      api.get('/slow'),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('Retry-After: 5 sets ~5s rate-limit cooldown', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"message":"rate limited"}',
        429,
        headers: const {'retry-after': '5'},
      );
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');
    final before = DateTime.now();

    final response = await api.get('/limited');
    expect(response.statusCode, 429);
    expect(ApiClient.isRateLimited, isTrue);

    final until = ApiClient.rateLimitedUntil!;
    final wait = until.difference(before);
    expect(wait.inMilliseconds, greaterThanOrEqualTo(4500));
    expect(wait.inMilliseconds, lessThanOrEqualTo(5500));
  });

  test('missing Retry-After uses bounded fallback cooldown', () async {
    final client = MockClient((request) async {
      return http.Response('{"message":"rate limited"}', 429);
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');
    final before = DateTime.now();

    await api.get('/limited');
    final wait = ApiClient.rateLimitedUntil!.difference(before);
    expect(
      wait.inSeconds,
      closeTo(ApiClient.rateLimitFallbackCooldown.inSeconds, 1),
    );
  });

  test('invalid Retry-After uses bounded fallback cooldown', () async {
    expect(
      ApiClient.parseRetryAfterHeader({'retry-after': 'not-a-number'}),
      isNull,
    );
    expect(
      ApiClient.parseRetryAfterHeader({'retry-after': '-3'}),
      isNull,
    );

    final client = MockClient((request) async {
      return http.Response(
        '{"message":"rate limited"}',
        429,
        headers: const {'retry-after': 'nope'},
      );
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');
    final before = DateTime.now();

    await api.get('/limited');
    final wait = ApiClient.rateLimitedUntil!.difference(before);
    expect(
      wait.inSeconds,
      closeTo(ApiClient.rateLimitFallbackCooldown.inSeconds, 1),
    );
  });

  test('429 does not create an unbounded retry loop', () async {
    var hits = 0;
    final client = MockClient((request) async {
      hits++;
      return http.Response(
        '{"message":"rate limited"}',
        429,
        headers: const {'retry-after': '30'},
      );
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');

    final first = await api.get('/limited');
    expect(first.statusCode, 429);
    expect(hits, 1);

    // Subsequent calls fail fast on local cooldown — no extra network hits.
    for (var i = 0; i < 5; i++) {
      final response = await api.get('/limited');
      expect(response.statusCode, 429);
    }
    expect(hits, 1);
  });

  test('transient GET network failure retries a bounded number of times', () async {
    var hits = 0;
    final client = MockClient((request) async {
      hits++;
      throw http.ClientException('connection reset');
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');

    await expectLater(api.get('/flaky'), throwsA(isA<http.ClientException>()));
    expect(hits, 1 + ApiClient.maxGetRetries);
  });

  test('5xx GET failures get bounded retries then return', () async {
    var hits = 0;
    final client = MockClient((request) async {
      hits++;
      return http.Response('unavailable', 503);
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');

    final response = await api.get('/flaky');
    expect(response.statusCode, 503);
    expect(hits, 1 + ApiClient.maxGetRetries);
  });

  test('GET succeeds after transient failures within retry budget', () async {
    var hits = 0;
    final client = MockClient((request) async {
      hits++;
      if (hits < 3) {
        return http.Response('bad gateway', 502);
      }
      return http.Response('{"ok":true}', 200);
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');

    final response = await api.get('/recover');
    expect(response.statusCode, 200);
    expect(hits, 3);
  });

  test('POST is not automatically retried by GET retry policy', () async {
    var hits = 0;
    final client = MockClient((request) async {
      hits++;
      throw http.ClientException('connection reset');
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');

    await expectLater(
      api.post('/mutate', body: {'a': 1}),
      throwsA(isA<http.ClientException>()),
    );
    expect(hits, 1);
  });

  test('PUT/PATCH/DELETE are not automatically retried', () async {
    Future<void> assertOnce(Future<http.Response> Function(ApiClient) call) async {
      var hits = 0;
      final client = MockClient((request) async {
        hits++;
        throw http.ClientException('connection reset');
      });
      final api = ApiClient(client: client, baseUrl: 'https://example.test');
      await expectLater(call(api), throwsA(isA<http.ClientException>()));
      expect(hits, 1);
      ApiClient.debugReset();
    }

    await assertOnce((api) => api.put('/x', body: {'a': 1}));
    await assertOnce((api) => api.patch('/x', body: {'a': 1}));
    await assertOnce((api) => api.delete('/x'));
  });

  test('401 is never retried', () async {
    var hits = 0;
    final client = MockClient((request) async {
      hits++;
      return http.Response('unauthorized', 401);
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');

    final response = await api.get('/secure');
    expect(response.statusCode, 401);
    expect(hits, 1);
  });

  test('403 is never retried', () async {
    var hits = 0;
    final client = MockClient((request) async {
      hits++;
      return http.Response('forbidden', 403);
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');

    final response = await api.get('/secure');
    expect(response.statusCode, 403);
    expect(hits, 1);
  });

  test('400 client errors are not retried', () async {
    var hits = 0;
    final client = MockClient((request) async {
      hits++;
      return http.Response('bad request', 400);
    });
    final api = ApiClient(client: client, baseUrl: 'https://example.test');

    final response = await api.get('/bad');
    expect(response.statusCode, 400);
    expect(hits, 1);
  });

  test('parseRetryAfterHeader accepts integer seconds', () {
    expect(
      ApiClient.parseRetryAfterHeader({'retry-after': '5'}),
      const Duration(seconds: 5),
    );
    expect(
      ApiClient.parseRetryAfterHeader({'Retry-After': '12'}),
      const Duration(seconds: 12),
    );
  });
}
