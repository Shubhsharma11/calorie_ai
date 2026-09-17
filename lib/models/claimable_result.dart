/// Parsed GET /api/v1/claimable payload.
class ClaimableResult {
  const ClaimableResult({
    this.claimableCoins = 0,
    this.balance,
    this.canClaim = false,
  });

  /// Coins available to claim right now.
  final int claimableCoins;

  /// Optional wallet total from the API (when provided).
  final int? balance;

  /// Explicit claim flag from backend (`canClaim` / status).
  final bool canClaim;

  bool get hasClaimable => claimableCoins > 0 || canClaim;
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
