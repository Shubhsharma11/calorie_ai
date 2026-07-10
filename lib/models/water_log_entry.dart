import 'meal_entry.dart';

class WaterLogEntry {
  const WaterLogEntry({
    this.id,
    required this.date,
    required this.amountMl,
  });

  final String? id;
  final DateTime date;
  final int amountMl;

  DateTime get normalizedDate => MealEntry.normalizeDate(date);
}

class WaterLogResponse {
  const WaterLogResponse({
    this.entry,
    this.dailyTotalMl,
  });

  final WaterLogEntry? entry;
  final int? dailyTotalMl;
}

/// Parsed GET /api/v1/water response — entries plus per-day totals in ml.
class WaterFetchResult {
  const WaterFetchResult({
    this.entries = const [],
    this.dailyTotalsMl = const {},
  });

  final List<WaterLogEntry> entries;
  final Map<DateTime, int> dailyTotalsMl;

  int dailyTotalFor(DateTime date) =>
      dailyTotalsMl[MealEntry.normalizeDate(date)] ?? 0;
}
