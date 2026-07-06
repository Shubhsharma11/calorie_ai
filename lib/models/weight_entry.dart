class WeightEntry {
  const WeightEntry({
    this.id,
    required this.date,
    required this.kg,
  });

  final String? id;
  final DateTime date;
  final double kg;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'kg': kg,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'] as String?,
      date: DateTime.parse(json['date'] as String),
      kg: (json['kg'] as num).toDouble(),
    );
  }
}
