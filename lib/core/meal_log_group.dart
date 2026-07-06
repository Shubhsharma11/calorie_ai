import '../models/meal_entry.dart';

/// Groups identical logged foods (same name + portion) within a meal slot.
class MealLogGroup {
  const MealLogGroup({
    required this.representative,
    required this.entries,
  });

  final MealEntry representative;
  final List<MealEntry> entries;

  int get count => entries.length;

  int get totalCalories =>
      entries.fold(0, (sum, entry) => sum + entry.calories);

  /// Most recently added entry in the group (used for swipe-to-delete).
  MealEntry get lastEntry => entries.last;

  static List<MealLogGroup> fromEntries(List<MealEntry> entries) {
    if (entries.isEmpty) return const [];

    final order = <String>[];
    final grouped = <String, List<MealEntry>>{};

    for (final entry in entries) {
      final key = _groupKey(entry);
      grouped.putIfAbsent(key, () => []).add(entry);
      if (!order.contains(key)) order.add(key);
    }

    return order
        .map(
          (key) => MealLogGroup(
            representative: grouped[key]!.first,
            entries: grouped[key]!,
          ),
        )
        .toList();
  }

  static String _groupKey(MealEntry entry) =>
      '${entry.food.name.toLowerCase()}|${entry.grams}';
}
