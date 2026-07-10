import 'meal_entry.dart';
import 'weight_entry.dart';

class WeightLogResponse {
  const WeightLogResponse({
    this.entry,
    this.profileUpdated = false,
    this.nutritionPlanRegenerated = false,
  });

  final WeightEntry? entry;
  final bool profileUpdated;
  final bool nutritionPlanRegenerated;
}

/// Maps backend weight payloads to [WeightEntry].
abstract final class ApiWeightMapper {
  static List<WeightEntry> entriesFromResponse(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final rawData = json['data'];
    if (rawData is List) {
      return _entriesFromMaps(rawData, fallbackDate: fallbackDate);
    }

    final data = _unwrapData(json);
    final single = entryFromApiJson(data, fallbackDate: fallbackDate);
    if (single != null &&
        (data.containsKey('weightEntry') ||
            data.containsKey('weight') ||
            data.containsKey('weightKg') ||
            data.containsKey('recordedAt'))) {
      return [single];
    }

    final nested = data['weightEntry'] ?? data['entry'];
    if (nested is Map) {
      final parsed = entryFromApiJson(
        Map<String, dynamic>.from(nested),
        fallbackDate: fallbackDate,
      );
      if (parsed != null) return [parsed];
    }

    final items = _readEntryMaps(data);
    return _entriesFromMaps(items, fallbackDate: fallbackDate);
  }

  static WeightLogResponse logResponseFromJson(Map<String, dynamic> json) {
    final data = _unwrapData(json);
    final nested = data['weightEntry'] ?? data['entry'];
    final entry = nested is Map
        ? entryFromApiJson(Map<String, dynamic>.from(nested))
        : entryFromApiJson(data);

    return WeightLogResponse(
      entry: entry,
      profileUpdated: data['profileUpdated'] == true,
      nutritionPlanRegenerated: data['nutritionPlanRegenerated'] == true,
    );
  }

  static List<WeightEntry> _entriesFromMaps(
    Iterable<dynamic> items, {
    DateTime? fallbackDate,
  }) {
    return items
        .whereType<Map>()
        .map(
          (item) => entryFromApiJson(
            Map<String, dynamic>.from(item),
            fallbackDate: fallbackDate,
          ),
        )
        .whereType<WeightEntry>()
        .toList();
  }

  static WeightEntry? entryFromApiJson(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final nested = json['weightEntry'] ?? json['entry'];
    if (nested is Map) {
      return entryFromApiJson(
        Map<String, dynamic>.from(nested),
        fallbackDate: fallbackDate,
      );
    }

    final kg = _readDouble(json, const ['weightKg', 'weight_kg']) ??
        _readDouble(json, const ['weight', 'value']);
    if (kg == null || kg <= 0) return null;

    final date = _readDate(json['recordedAt']) ??
        _readDate(json['recorded_at']) ??
        _readDate(json['date']) ??
        fallbackDate;
    if (date == null) return null;

    return WeightEntry(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      date: MealEntry.normalizeDate(date),
      kg: kg,
    );
  }

  static List<dynamic> _readEntryMaps(Map<String, dynamic> data) {
    final items = data['entries'] ??
        data['weightEntries'] ??
        data['weight_entries'] ??
        data['weightLogs'] ??
        data['weight_logs'] ??
        data['history'] ??
        data['items'] ??
        data['logs'];
    if (items is List) return items;

    if (data.containsKey('weight') ||
        data.containsKey('weightKg') ||
        data.containsKey('recordedAt')) {
      return [data];
    }

    return const [];
  }

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;

    final trimmed = value.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return MealEntry.normalizeDate(MealEntry.dateFromKey(trimmed));
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return null;

    final normalized = MealEntry.normalizeDate(parsed);
    final today = MealEntry.normalizeDate(DateTime.now());
    if (normalized.isAfter(today)) return today;
    return normalized;
  }
}
