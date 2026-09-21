/// Parsed GET /api/v1/coins/claimable payload.
class ClaimableResult {
  const ClaimableResult({
    this.claimableCoins = 0,
    this.earnedCoins,
    this.balance,
    this.canClaim = false,
  });

  /// Coins available to claim right now.
  final int claimableCoins;

  /// Coins earned for that day (when API sends it).
  final int? earnedCoins;

  /// Optional wallet total from the API (when provided).
  final int? balance;

  /// Explicit claim flag from backend (`canClaim` / status).
  final bool canClaim;

  bool get hasClaimable => claimableCoins > 0 || canClaim;

  /// Best single number to show for history: earned, else claimable.
  int get displayCoins {
    if (earnedCoins != null && earnedCoins! > 0) return earnedCoins!;
    return claimableCoins > 0 ? claimableCoins : 0;
  }
}

/// Parsed GET /api/v1/coins wallet balance.
class CoinsWalletResult {
  const CoinsWalletResult({this.balance = 0});

  final int balance;
}

/// Parsed POST /api/v1/coins/claim response.
class CoinClaimResult {
  const CoinClaimResult({
    this.claimedCoins = 0,
    this.balance,
  });

  final int claimedCoins;
  final int? balance;
}
