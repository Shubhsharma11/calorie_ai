/// Frontend model for GET /api/v1/referrals/me (backend contract TBD).
///
/// Expected JSON shape (snake_case or camelCase both accepted):
/// ```json
/// {
///   "referralCode": "AB12CD",
///   "referralLink": "https://mycaloriepal.com/r/AB12CD",
///   "successfulReferralCount": 3,
///   "coinsEarned": 300,
///   "recentJoins": [
///     { "name": "Aman", "joinedAt": "2026-09-24", "coins": 100 }
///   ]
/// }
/// ```
class ReferralInfo {
  const ReferralInfo({
    required this.referralCode,
    this.referralLink,
    this.successfulReferralCount = 0,
    this.coinsEarned = 0,
    this.recentJoins = const [],
  });

  final String referralCode;
  final String? referralLink;
  final int successfulReferralCount;
  final int coinsEarned;

  /// Friend-join events only (no voucher / spend rows).
  final List<ReferralJoinEvent> recentJoins;

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    final code =
        _string(json, const [
          'referralCode',
          'referral_code',
          'code',
          'inviteCode',
          'invite_code',
        ]) ??
        '';
    final link = _string(json, const [
      'referralLink',
      'referral_link',
      'inviteLink',
      'invite_link',
      'shareUrl',
      'share_url',
      'url',
    ]);
    final count =
        _int(json, const [
          'successfulReferralCount',
          'successful_referral_count',
          'friendsJoined',
          'friends_joined',
          'referralCount',
          'referral_count',
          'count',
        ]) ??
        0;
    final coins =
        _int(json, const [
          'coinsEarned',
          'coins_earned',
          'earnedCoins',
          'earned_coins',
          'rewardCoins',
          'reward_coins',
        ]) ??
        0;

    final joins = _readJoins(json);

    return ReferralInfo(
      referralCode: code.trim().toUpperCase(),
      referralLink: (link == null || link.trim().isEmpty) ? null : link.trim(),
      successfulReferralCount: count < 0 ? 0 : count,
      coinsEarned: coins < 0 ? 0 : coins,
      recentJoins: joins,
    );
  }

  static List<ReferralJoinEvent> _readJoins(Map<String, dynamic> json) {
    final raw =
        json['recentJoins'] ??
        json['recent_joins'] ??
        json['referrals'] ??
        json['history'] ??
        json['events'];
    if (raw is! List) return const [];

    final out = <ReferralJoinEvent>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final type =
          (_string(map, const ['type', 'kind', 'event', 'eventType']) ?? '')
              .toLowerCase();
      // Skip spend / voucher style rows.
      if (type.contains('voucher') ||
          type.contains('redeem') ||
          type.contains('spend') ||
          type.contains('shop') ||
          type.contains('gift')) {
        continue;
      }
      final event = ReferralJoinEvent.fromJson(map);
      if (event != null) out.add(event);
    }
    return List<ReferralJoinEvent>.unmodifiable(out);
  }

  static String? _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

/// One friend who joined via the user's code (join credits only).
class ReferralJoinEvent {
  const ReferralJoinEvent({
    required this.name,
    required this.coins,
    this.joinedAt,
  });

  final String name;
  final int coins;
  final DateTime? joinedAt;

  static ReferralJoinEvent? fromJson(Map<String, dynamic> json) {
    final name =
        ReferralInfo._string(json, const [
          'name',
          'displayName',
          'display_name',
          'friendName',
          'friend_name',
          'userName',
          'user_name',
          'title',
        ]) ??
        'Friend';
    final coins =
        ReferralInfo._int(json, const [
          'coins',
          'amount',
          'reward',
          'coinsEarned',
          'coins_earned',
        ]) ??
        100;
    if (coins <= 0) return null;

    final dateRaw = ReferralInfo._string(json, const [
      'joinedAt',
      'joined_at',
      'createdAt',
      'created_at',
      'date',
      'at',
    ]);
    DateTime? at;
    if (dateRaw != null) {
      at = DateTime.tryParse(dateRaw);
    }

    return ReferralJoinEvent(
      name: name.trim().isEmpty ? 'Friend' : name.trim(),
      coins: coins,
      joinedAt: at,
    );
  }
}

/// Frontend model for POST /api/v1/referrals/claim.
class ReferralClaimResult {
  const ReferralClaimResult({
    required this.success,
    this.message,
    this.rewardConfirmed = false,
  });

  final bool success;
  final String? message;

  /// When true, Flutter should refresh the existing wallet from the API.
  final bool rewardConfirmed;

  factory ReferralClaimResult.fromJson(Map<String, dynamic> json) {
    final success =
        json['success'] == true ||
        json['ok'] == true ||
        json['claimed'] == true ||
        (json['status'] is String &&
            (json['status'] as String).toLowerCase() == 'ok');
    final message = ReferralInfo._string(json, const [
      'message',
      'detail',
      'error',
    ]);
    final reward =
        json['rewardConfirmed'] == true ||
        json['reward_confirmed'] == true ||
        json['coinsAwarded'] == true ||
        json['coins_awarded'] == true ||
        (json['awardedCoins'] is num && (json['awardedCoins'] as num) > 0) ||
        (json['awarded_coins'] is num && (json['awarded_coins'] as num) > 0) ||
        success;

    return ReferralClaimResult(
      success: success,
      message: message,
      rewardConfirmed: reward && success,
    );
  }
}
