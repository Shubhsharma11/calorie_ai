import '../models/meal_entry.dart';

/// Merges API meal payloads with local entries without dropping unsynced logs.
abstract final class MealEntryMerge {
  static List<MealEntry> mergeAll({
    required List<MealEntry> current,
    required List<MealEntry> fetched,
  }) {
    if (fetched.isEmpty) return current;

    final fetchedIds = fetched.map((entry) => entry.id).toSet();
    final localOnly =
        current.where((entry) => !fetchedIds.contains(entry.id)).toList();
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
    final kept = current
        .where(
          (entry) =>
              !(entry.date == normalized && fetchedIds.contains(entry.id)),
        )
        .toList();
    kept.addAll(fetched);
    return kept;
  }
}
