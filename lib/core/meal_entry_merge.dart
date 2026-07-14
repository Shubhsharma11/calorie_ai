import '../models/meal_entry.dart';

/// Merges API meal payloads with local entries without dropping unsynced logs.
abstract final class MealEntryMerge {
  static List<MealEntry> mergeAll({
    required List<MealEntry> current,
    required List<MealEntry> fetched,
  }) {
    if (fetched.isEmpty) return current;

    final fetchedIds = fetched.map((entry) => entry.id).toSet();
    final unmatched = _contentCounts(fetched);

    // Entries already synced (id known) consume their fetched copy first so
    // intentional duplicates (same food logged twice) survive the merge.
    for (final entry in current) {
      if (fetchedIds.contains(entry.id)) {
        _consume(unmatched, _contentKey(entry));
      }
    }

    final localOnly = <MealEntry>[];
    for (final entry in current) {
      if (fetchedIds.contains(entry.id)) continue;
      // A fetched meal with identical content is the server copy of this
      // local entry (the POST completed while a refresh was in flight).
      if (_consume(unmatched, _contentKey(entry))) continue;
      localOnly.add(entry);
    }
    return [...fetched, ...localOnly];
  }

  static List<MealEntry> mergeForDay({
    required List<MealEntry> current,
    required DateTime day,
    required List<MealEntry> fetched,
  }) {
    if (fetched.isEmpty) return current;

    final normalized = MealEntry.normalizeDate(day);
    final fetchedIds = fetched.map((entry) => entry.id).toSet();
    final unmatched = _contentCounts(fetched);

    for (final entry in current) {
      if (entry.date == normalized && fetchedIds.contains(entry.id)) {
        _consume(unmatched, _contentKey(entry));
      }
    }

    final kept = <MealEntry>[];
    for (final entry in current) {
      if (entry.date != normalized) {
        kept.add(entry);
        continue;
      }
      if (fetchedIds.contains(entry.id)) continue;
      if (_consume(unmatched, _contentKey(entry))) continue;
      kept.add(entry);
    }
    kept.addAll(fetched);
    return kept;
  }

  static Map<String, int> _contentCounts(List<MealEntry> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final key = _contentKey(entry);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Decrements the count for [key]; returns true when a copy was available.
  static bool _consume(Map<String, int> counts, String key) {
    final available = counts[key] ?? 0;
    if (available <= 0) return false;
    counts[key] = available - 1;
    return true;
  }

  static String _contentKey(MealEntry entry) {
    return '${MealEntry.dateToKey(entry.date)}|${entry.meal}|'
        '${entry.food.name.toLowerCase()}|${entry.grams}';
  }
}
