import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/safe_api_log.dart';
import '../core/api_timezone.dart';
import '../models/claimable_result.dart';
import '../models/meal_entry.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class CoinsApiException implements Exception {
  const CoinsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Claimable preview, wallet balance, and claim endpoints.
class CoinsApiService {
  CoinsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// GET /api/v1/coins/claimable?date=&timezone= (both required).
  Future<ClaimableResult> fetchClaimable({
    required String accessToken,
    required DateTime date,
    String? timezone,
  }) async {
    final dateKey = MealEntry.dateToKey(date);
    final tz = timezone ?? resolveApiTimezone();
    final endpoint = ApiEndpoints.claimableWithQuery(
      date: dateKey,
      timezone: tz,
    );

    debugPrint(
      'CoinsApiService: GET ${ApiEndpoints.url(endpoint)} '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.get(
      endpoint,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseClaimable(response);
  }

  /// GET /api/v1/coins — total wallet balance.
  Future<CoinsWalletResult> fetchWallet({
    required String accessToken,
  }) async {
    debugPrint(
      'CoinsApiService: GET ${ApiEndpoints.coinsUrl} '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.get(
      ApiEndpoints.coins,
      headers: apiAuthHeaders(accessToken),
    );

    return _parseWallet(response);
  }

  /// POST /api/v1/coins/claim — move claimable coins into wallet.
  Future<CoinClaimResult> claimCoins({
    required String accessToken,
    DateTime? date,
    String? timezone,
  }) async {
    final body = <String, dynamic>{
      'date': MealEntry.dateToKey(date ?? DateTime.now()),
      'timezone': timezone ?? resolveApiTimezone(),
    };

    debugPrint(
      'CoinsApiService: POST ${ApiEndpoints.coinsClaimUrl} (payload redacted) '
      'bearerTokenLength=${accessToken.length}',
    );

    final response = await _apiClient.post(
      ApiEndpoints.coinsClaim,
      headers: apiAuthHeaders(accessToken),
      body: body,
    );

    return _parseClaim(response);
  }

  ClaimableResult _parseClaimable(http.Response response) {
    final data = _requireDataMap(response, action: 'loading claimable');
    return claimableFromMap(data);
  }

  CoinsWalletResult _parseWallet(http.Response response) {
    final data = _requireDataMap(response, action: 'loading wallet');
    final balance = _readWalletBalanceOnly(data) ??
        _readInt(
          data['coins'] ??
              data['totalCoins'] ??
              data['total_coins'] ??
              data['amount'] ??
              data['value'],
        ) ??
        0;
    return CoinsWalletResult(balance: balance < 0 ? 0 : balance);
  }

  CoinClaimResult _parseClaim(http.Response response) {
    final data = _requireDataMap(response, action: 'claiming coins');
    final claimed = _readInt(
          data['claimed'] ??
              data['claimedCoins'] ??
              data['claimed_coins'] ??
              data['earnableCoins'] ??
              data['earnable_coins'] ??
              data['coins'] ??  
              data['amount'] ??
              data['claimable'],
        ) ??
        0;
    return CoinClaimResult(
      claimedCoins: claimed < 0 ? 0 : claimed,
      balance: _readBalance(data),
    );
  }

  /// Shared parser for claimable payloads (GET /claimable or steps.coins).
  static ClaimableResult claimableFromMap(Map<String, dynamic> raw) {
    var data = Map<String, dynamic>.from(raw);
    final nested = data['coins'];
    if (nested is Map) {
      data = {...data, ...Map<String, dynamic>.from(nested)};
    }

    final claimable = _readIntStatic(
          data['earnableCoins'] ??  
              data['earnable_coins'] ??
              data['claimable'] ??
              data['claimableCoins'] ??
              data['claimable_coins'] ??
              data['amount'] ??   
              data['pending'] ??
              data['pendingCoins'] ??
              data['pending_coins'],
        ) ??
        0;

    final canClaimFlag = data['canClaim'] == true ||
        data['can_claim'] == true ||
        (data['status']?.toString().toLowerCase() == 'claimable');

    final amount = claimable < 0 ? 0 : claimable;
    final earned = _readIntStatic(
      data['earnedCoins'] ??
          data['earned_coins'] ??
          data['coinsEarned'] ??
          data['coins_earned'] ??
          data['totalEarned'] ??
          data['total_earned'] ??
          data['totalCoins'] ??
          data['total_coins'] ??
          data['rewardCoins'] ??
          data['reward_coins'] ??
          data['claimedCoins'] ??
          data['claimed_coins'],
    );

    return ClaimableResult(
      claimableCoins: (amount > 0 || canClaimFlag) ? amount : 0,
      earnedCoins: earned != null && earned > 0 ? earned : null,
      // Only real wallet fields — never day totals like totalCoins.
      balance: _readWalletBalanceOnly(data),
      canClaim: canClaimFlag || amount > 0,
    );
  }

  Map<String, dynamic> _requireDataMap(
    http.Response response, {
    required String action,
  }) {
    final body = response.body.trim();
    debugPrint('CoinsApiService: response ${safeHttpResponseLog(response.statusCode, body)}');

    final decoded = _tryDecodeJson(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String? ?? decoded['error'] as String?
          : null;
      throw CoinsApiException(
        message ?? 'Error while $action (${response.statusCode}). ${safeHttpErrorDetail(response.statusCode, body)}',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const {};
    }
    return _unwrapData(decoded);
  }

  int? _readBalance(Map<String, dynamic> data) => _readWalletBalanceOnly(data);

  /// Wallet total only. Do not use day fields (`totalCoins`, `claimedCoins`,
  /// `steps`) — those appear on claimable payloads and are not wallet balance.
  static int? _readWalletBalanceOnly(Map<String, dynamic> data) {
    final nestedWallet = data['wallet'];
    if (nestedWallet is Map) {
      final fromWallet = _readIntStatic(
        nestedWallet['balance'] ??
            nestedWallet['coins'] ??
            nestedWallet['total'] ??
            nestedWallet['available'] ??
            nestedWallet['availableBalance'],
      );
      if (fromWallet != null) return fromWallet;
    }
    return _readIntStatic(
      data['balance'] ??
          data['walletBalance'] ??
          data['wallet_balance'] ??
          data['availableBalance'] ??
          data['available_balance'] ??
          data['currentBalance'] ??
          data['current_balance'],
    );
  }

  Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is num || data is String) {
      return {'balance': data, 'claimable': data, 'earnableCoins': data};
    }
    return json;
  }

  int? _readInt(dynamic value) => _readIntStatic(value);

  static int? _readIntStatic(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Object? _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

/// Back-compat alias used by older imports.
typedef ClaimableApiService = CoinsApiService;
typedef ClaimableApiException = CoinsApiException;
