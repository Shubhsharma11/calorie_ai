import 'meal_entry.dart';
import 'water_log_entry.dart';

/// Maps backend water payloads to [WaterLogEntry] and daily totals.
abstract final class ApiWaterMapper {
  static List<WaterLogEntry> entriesFromResponse(
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
        (data.containsKey('waterEntry') ||
            data.containsKey('quantity') ||
            data.containsKey('amountMl') ||
            data.containsKey('recordedAt'))) {
      return [single];
    }

    final nested = data['waterEntry'] ?? data['entry'];
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

  static WaterFetchResult fetchResultFromResponse(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final data = _unwrapData(json);
    final entries = entriesFromResponse(json, fallbackDate: fallbackDate);
    final totals = <DateTime, int>{};

    for (final entry in entries) {
      final day = entry.normalizedDate;
      totals[day] = (totals[day] ?? 0) + entry.amountMl;
    } 

    final dailyTotalMl = _readMl(
      data['dailyTotalMl'] ??
          data['daily_total_ml'] ??
          data['totalMl'] ??
          data['total_ml'],
    );
    final dateKey =
        _readDate(data['date']) ?? _readDate(data['day']) ?? fallbackDate;
    if (dailyTotalMl != null && dateKey != null) {
      totals[MealEntry.normalizeDate(dateKey)] = dailyTotalMl;
    }

    return WaterFetchResult(entries: entries, dailyTotalsMl: totals);
  }

  static Map<DateTime, int> dailyTotalsFromResponse(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) =>
      fetchResultFromResponse(json, fallbackDate: fallbackDate).dailyTotalsMl;

  static WaterLogResponse logResponseFromJson(Map<String, dynamic> json) {
    final data = _unwrapData(json);
    final nested = data['waterEntry'] ?? data['entry'];
    final entry = nested is Map
        ? entryFromApiJson(Map<String, dynamic>.from(nested))
        : entryFromApiJson(data);
    final dailyTotalMl = _readMl(
      data['dailyTotalMl'] ??
          data['daily_total_ml'] ??
          data['totalMl'] ??
          data['total_ml'],
    );

    return WaterLogResponse(entry: entry, dailyTotalMl: dailyTotalMl);
  }

  static List<WaterLogEntry> _entriesFromMaps(
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
        .whereType<WaterLogEntry>()
        .toList();
  }

  static WaterLogEntry? entryFromApiJson(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final nested = json['waterEntry'] ?? json['entry'];
    if (nested is Map) {
      return entryFromApiJson(
        Map<String, dynamic>.from(nested),
        fallbackDate: fallbackDate,
      );
    }

    final amountMl = _readMl(json) ??
        _quantityToMl(
          _readDouble(json, const ['quantity', 'amount', 'value']),
          json['unit']?.toString(),
        );
    if (amountMl == null || amountMl <= 0) return null;

    final date = _readDate(json['recordedAt']) ??
        _readDate(json['recorded_at']) ??
        _readDate(json['date']) ??
        fallbackDate;
    if (date == null) return null;

    return WaterLogEntry(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      date: MealEntry.normalizeDate(date),
      amountMl: amountMl,
    );
  }

  static List<dynamic> _readEntryMaps(Map<String, dynamic> data) {
    final items = data['entries'] ??
        data['waterEntries'] ??
        data['water_entries'] ??
        data['waterLogs'] ??
        data['water_logs'] ??
        data['history'] ??
        data['items'] ??
        data['logs'];
    if (items is List) return items;

    if (data.containsKey('quantity') ||
        data.containsKey('amountMl') ||
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

  static int? _readMl(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    if (value is Map) {
      return _readMl(value['totalMl'] ?? value['total_ml'] ?? value['amountMl']);
    }
    return null;
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

  static int? _quantityToMl(double? quantity, String? unit) {
    if (quantity == null || quantity <= 0) return null;
    final normalized = unit?.trim().toLowerCase();
    return switch (normalized) {
      'ml' || 'milliliter' || 'milliliters' => quantity.round(),
      'l' || 'liter' || 'liters' || 'litre' || 'litres' =>
        (quantity * 1000).round(),
      'glass' || 'glasses' => (quantity * 250).round(),
      _ => (quantity * 1000).round(),
    };
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

  /// Converts millilitres to API request fields.
  static Map<String, dynamic> requestBodyFromMl(
    int ml, {
    DateTime? date,
  }) {
    final body = <String, dynamic>{
      'quantity': ml,
      'unit': 'ml',
    };
    if (date != null) {
      body['date'] = MealEntry.dateToKey(date);
    }
    return body;
  }
}
