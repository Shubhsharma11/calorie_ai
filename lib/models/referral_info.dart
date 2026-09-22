/// Frontend model for GET /api/v1/referrals/me (backend contract TBD).
///
/// Expected JSON shape (snake_case or camelCase both accepted):
/// ```json
/// {
///   "referralCode": "AB12CD",
///   "referralLink": "https://mycaloriepal.com/r/AB12CD",
///   "successfulReferralCount": 3,
///   "coinsEarned": 300
/// }
/// ```
class ReferralInfo {
  const ReferralInfo({
    required this.referralCode,
    this.referralLink,
    this.successfulReferralCount = 0,
    this.coinsEarned = 0,
  });

  final String referralCode;
  final String? referralLink;
  final int successfulReferralCount;
  final int coinsEarned;

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    final code = _string(json, const [
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
    final count = _int(json, const [
          'successfulReferralCount',
          'successful_referral_count',
          'friendsJoined',
          'friends_joined',
          'referralCount',
          'referral_count',
          'count',
        ]) ??
        0;
    final coins = _int(json, const [
          'coinsEarned',
          'coins_earned',
          'earnedCoins',
          'earned_coins',
          'rewardCoins',
          'reward_coins',
        ]) ??
        0;

    return ReferralInfo(
      referralCode: code.trim().toUpperCase(),
      referralLink: (link == null || link.trim().isEmpty) ? null : link.trim(),
      successfulReferralCount: count < 0 ? 0 : count,
      coinsEarned: coins < 0 ? 0 : coins,
    );
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
    final success = json['success'] == true ||
        json['ok'] == true ||
        json['claimed'] == true ||
        (json['status'] is String &&
            (json['status'] as String).toLowerCase() == 'ok');
    final message = ReferralInfo._string(json, const [
      'message',
      'detail',
      'error',
    ]);
    final reward = json['rewardConfirmed'] == true ||
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
