/// One row in the Coin History list (earn or spend).
enum CoinHistorySource { referral, steps, giftShop, other }

class CoinHistoryItem {
  const CoinHistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.source,
    this.at,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Positive = earned, negative = spent.
  final int amount;
  final CoinHistorySource source;
  final DateTime? at;

  bool get isCredit => amount >= 0;
}
