class WeightEntry {
  const WeightEntry({
    this.id,
    required this.date,
    required this.kg,
    this.loggedAt,
  });

  final String? id;
  final DateTime date;
  final double kg;

  /// Server/client timestamp used to pick the newest log when several share a day.
  final DateTime? loggedAt;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'kg': kg,
        if (loggedAt != null) 'loggedAt': loggedAt!.toIso8601String(),
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'] as String?,
      date: DateTime.parse(json['date'] as String),
      kg: (json['kg'] as num).toDouble(),
      loggedAt: json['loggedAt'] != null
          ? DateTime.tryParse(json['loggedAt'] as String)
          : null,
    );
  }

  /// One entry per calendar day, keeping the newest by [loggedAt].
  /// Without timestamps, later list items win (stable for locally ordered lists).
  static List<WeightEntry> collapseToLatestPerDay(List<WeightEntry> entries) {
    final byDay = <DateTime, WeightEntry>{};
    for (final entry in entries) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final existing = byDay[day];
      if (existing == null || entry.isNewerThan(existing)) {
        byDay[day] = entry;
      }
    }

    return byDay.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
  }

  bool isNewerThan(WeightEntry other) {
    final mine = loggedAt;
    final theirs = other.loggedAt;
    if (mine != null && theirs != null) return mine.isAfter(theirs);
    if (mine != null && theirs == null) return true;
    if (mine == null && theirs != null) return false;
    // No timestamps: treat this candidate as newer (last-seen wins).
    return true;
  }
}
