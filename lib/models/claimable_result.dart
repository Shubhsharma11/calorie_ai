/// One claimable coin chunk from GET /api/v1/coins/claimable.
class ClaimableCoinItem {
  const ClaimableCoinItem({
    required this.id,
    required this.amount,
    this.rewardTypeId,
    this.rewardType,
    this.status,
    this.dayKey,
    this.chunkIndex,
    this.expiresAt,
    this.claimedAt,
    this.timezone,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int amount;
  final String? rewardTypeId;
  final String? rewardType;
  final String? status;
  final String? dayKey;
  final int? chunkIndex;
  final String? expiresAt;
  final String? claimedAt;
  final String? timezone;
  final String? createdAt;
  final String? updatedAt;

  bool get isClaimable =>
      status == null || status!.toLowerCase() == 'claimable';

  factory ClaimableCoinItem.fromJson(Map<String, dynamic> json) {
    final amount =
        _readInt(
          json['amount'] ?? json['coins'] ?? json['claimable'] ?? json['value'],
        ) ??
        0;
    return ClaimableCoinItem(
      id: _readId(json['id'] ?? json['_id']) ?? '',
      amount: amount < 0 ? 0 : amount,
      rewardTypeId: _readId(json['rewardTypeId'] ?? json['reward_type_id']),
      rewardType: _readString(json['rewardType'] ?? json['reward_type']),
      status: _readString(json['status']),
      dayKey: _readString(json['dayKey'] ?? json['day_key']),
      chunkIndex: _readInt(json['chunkIndex'] ?? json['chunk_index']),
      expiresAt: _readString(json['expiresAt'] ?? json['expires_at']),
      claimedAt: _readString(json['claimedAt'] ?? json['claimed_at']),
      timezone: _readString(json['timezone']),
      createdAt: _readString(json['createdAt'] ?? json['created_at']),
      updatedAt: _readString(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _readId(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : text;
    }
    if (value is Map) {
      return _readId(
        value[r'$oid'] ?? value['oid'] ?? value['id'] ?? value['_id'],
      );
    }
    return _readString(value);
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Parsed GET /api/v1/coins/claimable payload.
///
/// New backend shape:
/// ```json
/// {
///   "claimable": [{ "id": "...", "amount": 10, "status": "claimable", ... }],
///   "totalClaimable": 10,
///   "expiresAt": "...",
///   "timezone": "Asia/Kolkata"
/// }
/// ```
class ClaimableResult {
  const ClaimableResult({
    this.claimableCoins = 0,
    this.earnedCoins,
    this.balance,
    this.canClaim = false,
    this.items = const [],
    this.expiresAt,
    this.timezone,
  });

  /// Coins available to claim right now (`totalClaimable` or sum of items).
  final int claimableCoins;

  /// Coins earned for that day (when API sends it).
  final int? earnedCoins;

  /// Optional wallet total from the API (when provided).
  final int? balance;

  /// Explicit claim flag from backend (`canClaim` / status / items).
  final bool canClaim;

  /// Individual claimable chunks (new API).
  final List<ClaimableCoinItem> items;

  /// Earliest / envelope expiry from the payload.
  final String? expiresAt;

  final String? timezone;

  bool get hasClaimable => claimableCoins > 0 || canClaim || items.isNotEmpty;

  /// Best single number to show for history: earned, else claimable.
  int get displayCoins {
    if (earnedCoins != null && earnedCoins! > 0) return earnedCoins!;
    return claimableCoins > 0 ? claimableCoins : 0;
  }

  /// Ids of chunks still claimable (for POST /coins/claim when needed).
  List<String> get claimableIds => items
      .where((item) => item.id.isNotEmpty && item.isClaimable)
      .map((item) => item.id)
      .toList(growable: false);
}

/// Parsed GET /api/v1/wallet document / list.
///
/// New backend shape:
/// ```json
/// {
///   "wallets": [{ "id": "...", "rewardType": "steps", "balance": 26, ... }],
///   "totalBalance": 26,
///   "totalLifetimeEarned": 26
/// }
/// ```
class CoinsWalletResult {
  const CoinsWalletResult({
    this.balance = 0,
    this.id,
    this.userId,
    this.rewardTypeId,
    this.rewardType,
    this.lifetimeEarned,
    this.timezone,
    this.createdAt,
    this.updatedAt,
    this.wallets = const [],
  });

  /// Spendable wallet total (home coin chip) — prefers `totalBalance`.
  final int balance;

  final String? id;
  final String? userId;
  final String? rewardTypeId;

  /// e.g. `"steps"`.
  final String? rewardType;

  /// Lifetime coins ever credited (`totalLifetimeEarned` or primary wallet).
  final int? lifetimeEarned;

  final String? timezone;
  final String? createdAt;
  final String? updatedAt;

  /// Individual wallets when API returns `wallets[]`.
  final List<CoinsWalletResult> wallets;
}

/// Parsed POST /api/v1/coins/claim response.
class CoinClaimResult {
  const CoinClaimResult({
    this.claimedCoins = 0,
    this.balance,
    this.lifetimeEarned,
  });

  final int claimedCoins;
  final int? balance;
  final int? lifetimeEarned;
}
