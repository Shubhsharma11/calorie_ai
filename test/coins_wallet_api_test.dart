import 'dart:convert';

import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/api_endpoints.dart';
import 'package:calorie_ai/services/coins_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('GET /wallet parses wallets[] + totalBalance', () async {
    late Uri capturedUri;
    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'Wallet balances retrieved',
          'data': {
            'wallets': [
              {
                'id': '6ab262abae7ca2804554f768',
                'rewardTypeId': '6aa90991ae7ca2804551dc3c',
                'rewardType': 'steps',
                'balance': 26,
                'lifetimeEarned': 26,
                'timezone': 'Asia/Kolkata',
                'createdAt': '2026-09-22T11:12:43.284Z',
                'updatedAt': '2026-09-22T11:12:43.284Z',
              },
            ],
            'totalBalance': 26,
            'totalLifetimeEarned': 26,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = CoinsApiService(apiClient: ApiClient(client: client));
    final result = await service.fetchWallet(accessToken: 'token-123');

    expect(capturedUri.path, ApiEndpoints.wallet);
    expect(result.balance, 26);
    expect(result.lifetimeEarned, 26);
    expect(result.rewardType, 'steps');
    expect(result.id, '6ab262abae7ca2804554f768');
    expect(result.wallets, hasLength(1));
    expect(result.wallets.first.balance, 26);
  });

  test('GET /wallet parses Mongo wallet document fields', () async {
    late Uri capturedUri;
    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            '_id': '6ab241ffae7ca2804554f299',
            'rewardTypeId': '6aa90991ae7ca2804551dc3c',
            'userId': '6a941507de2c9dc0939f1eac',
            'balance': 21,
            'lifetimeEarned': 21,
            'rewardType': 'steps',
            'timezone': 'Asia/Kolkata',
            'createdAt': '2026-09-22T08:53:19.763Z',
            'updatedAt': '2026-09-22T08:53:19.763Z',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = CoinsApiService(apiClient: ApiClient(client: client));
    final result = await service.fetchWallet(accessToken: 'token-123');

    expect(capturedUri.path, ApiEndpoints.wallet);
    expect(result.balance, 21);
    expect(result.lifetimeEarned, 21);
    expect(result.id, '6ab241ffae7ca2804554f299');
    expect(result.userId, '6a941507de2c9dc0939f1eac');
    expect(result.rewardTypeId, '6aa90991ae7ca2804551dc3c');
    expect(result.rewardType, 'steps');
    expect(result.timezone, 'Asia/Kolkata');
    expect(result.createdAt, '2026-09-22T08:53:19.763Z');
    expect(result.updatedAt, '2026-09-22T08:53:19.763Z');
  });

  test(r'GET /wallet reads $oid-style Mongo ids', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'data': {
            '_id': {r'$oid': '6ab241ffae7ca2804554f299'},
            'balance': 7,
            'lifetime_earned': 12,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = CoinsApiService(apiClient: ApiClient(client: client));
    final result = await service.fetchWallet(accessToken: 'token-123');

    expect(result.balance, 7);
    expect(result.lifetimeEarned, 12);
    expect(result.id, '6ab241ffae7ca2804554f299');
  });

  test('GET /coins/claimable parses totalClaimable + claimable array', () async {
    late Uri capturedUri;
    final client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'Claimable coins retrieved',
          'data': {
            'claimable': [
              {
                'id': '6ab25520ae7ca2804554f535',
                'rewardTypeId': '6aa90991ae7ca2804551dc3c',
                'rewardType': 'steps',
                'amount': 10,
                'status': 'claimable',
                'dayKey': '2026-09-22',
                'chunkIndex': 1,
                'expiresAt': '2026-09-22T18:29:59.999Z',
                'claimedAt': null,
                'timezone': 'Asia/Kolkata',
                'createdAt': '2026-09-22T10:14:56.673Z',
                'updatedAt': '2026-09-22T10:14:56.673Z',
              },
            ],
            'totalClaimable': 10,
            'expiresAt': '2026-09-22T18:29:59.999Z',
            'timezone': 'Asia/Kolkata',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = CoinsApiService(apiClient: ApiClient(client: client));
    final result = await service.fetchClaimable(
      accessToken: 'token-123',
      date: DateTime(2026, 9, 22),
      timezone: 'Asia/Kolkata',
    );

    expect(capturedUri.path, ApiEndpoints.claimable);
    expect(capturedUri.queryParameters['date'], '2026-09-22');
    expect(capturedUri.queryParameters['timezone'], 'Asia/Kolkata');
    expect(result.claimableCoins, 10);
    expect(result.canClaim, isTrue);
    expect(result.expiresAt, '2026-09-22T18:29:59.999Z');
    expect(result.timezone, 'Asia/Kolkata');
    expect(result.items, hasLength(1));
    expect(result.items.first.id, '6ab25520ae7ca2804554f535');
    expect(result.items.first.amount, 10);
    expect(result.items.first.rewardType, 'steps');
    expect(result.items.first.dayKey, '2026-09-22');
    expect(result.claimableIds, ['6ab25520ae7ca2804554f535']);
  });

  test('claimableFromMap still supports legacy numeric claimable', () {
    final result = CoinsApiService.claimableFromMap({
      'claimable': 25,
      'canClaim': true,
    });
    expect(result.claimableCoins, 25);
    expect(result.canClaim, isTrue);
    expect(result.items, isEmpty);
  });

  test('claimableFromMap treats claimed chunks as earned after claim', () {
    final result = CoinsApiService.claimableFromMap({
      'claimable': [
        {
          'id': 'chunk-1',
          'amount': 10,
          'status': 'claimed',
          'dayKey': '2026-09-22',
        },
        {
          'id': 'chunk-2',
          'amount': 5,
          'status': 'claimed',
          'dayKey': '2026-09-22',
        },
      ],
      'totalClaimable': 0,
    });
    expect(result.claimableCoins, 0);
    expect(result.canClaim, isFalse);
    expect(result.earnedCoins, 15);
    expect(result.displayCoins, 15);
  });

  test('POST /coins/claim parses totalBalance wallet list shape', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'claimed': 10,
            'wallets': [
              {'rewardType': 'steps', 'balance': 31},
            ],
            'totalBalance': 31,
            'totalLifetimeEarned': 31,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = CoinsApiService(apiClient: ApiClient(client: client));
    final result = await service.claimCoins(
      accessToken: 'token-123',
      date: DateTime(2026, 9, 22),
      timezone: 'Asia/Kolkata',
    );

    expect(result.claimedCoins, 10);
    expect(result.balance, 31);
    expect(result.lifetimeEarned, 31);
  });

  test('POST /coins/claim sends claimableIds with date/timezone', () async {
    late Map<String, dynamic> capturedBody;
    late Uri capturedUri;
    final client = MockClient((request) async {
      capturedUri = request.url;
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'claimed': 10,
            'balance': 31,
            'lifetimeEarned': 31,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = CoinsApiService(apiClient: ApiClient(client: client));
    final result = await service.claimCoins(
      accessToken: 'token-123',
      date: DateTime(2026, 9, 22),
      timezone: 'Asia/Kolkata',
      claimableIds: const ['6ab25520ae7ca2804554f535'],
    );

    expect(capturedUri.path, ApiEndpoints.coinsClaim);
    expect(capturedBody['date'], '2026-09-22');
    expect(capturedBody['timezone'], 'Asia/Kolkata');
    expect(capturedBody['claimableIds'], ['6ab25520ae7ca2804554f535']);
    expect(result.claimedCoins, 10);
    expect(result.balance, 31);
    expect(result.lifetimeEarned, 31);
  });
}
