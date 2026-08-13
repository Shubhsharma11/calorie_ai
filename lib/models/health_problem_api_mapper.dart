import 'health_concern.dart';

/// Maps UI health-concern values to backend onboarding API enums.
abstract final class HealthProblemApiMapper {
  static const categoryToApi = <String, String>{
    'Diabetes': 'diabetes',
    'Blood Pressure': 'bloodPressure',
    'Respiratory': 'respiratory',
    'Digestive': 'digestive',
    'Stress / Anxiety': 'stress',
    'Immunity': 'immunity',
    'High Cholesterol': 'highCholesterol',
    'Other': 'other',
    'None': 'none',
  };

  static const durationToApi = <String, String>{
    'Less than a week': 'lessThanOneWeek',
    '1-4 weeks': 'oneToFourWeeks',
    '1-6 months': 'oneToSixMonths',
    'More than 6 months': 'moreThanSixMonths',
  };

  static const severityToApi = <String, String>{
    'Mild': 'mild',
    'Moderate': 'moderate',
    'Severe': 'severe',
  };

  static const medicationToApi = <String, String>{
    'No': 'no',
    'Yes': 'yes',
    'Prefer not to say': 'preferNotToSay',
  };

  static String category(String uiValue) =>
      categoryToApi[uiValue] ?? _toCamelCase(uiValue);

  static String? duration(String? uiValue) =>
      uiValue == null ? null : durationToApi[uiValue] ?? _toCamelCase(uiValue);

  static String? severity(String? uiValue) =>
      uiValue == null ? null : severityToApi[uiValue] ?? uiValue.toLowerCase();

  static String? medication(String? uiValue) =>
      uiValue == null ? null : medicationToApi[uiValue] ?? _toCamelCase(uiValue);

  static String categoryFromApi(String apiValue) =>
      _fromApi(apiValue, categoryToApi);

  static String? durationFromApi(String? apiValue) =>
      apiValue == null ? null : _fromApi(apiValue, durationToApi);

  static String? severityFromApi(String? apiValue) =>
      apiValue == null ? null : _fromApi(apiValue, severityToApi);

  static String? medicationFromApi(String? apiValue) =>
      apiValue == null ? null : _fromApi(apiValue, medicationToApi);

  /// Parses `healthProblems` from a GET/PATCH onboarding payload.
  ///
  /// Returns `null` when the field is absent so callers can leave local
  /// state unchanged. An empty list means the user chose None.
  static List<HealthConcern>? parseConcerns(Object? raw) {
    if (raw == null) return null;

    if (raw is List) {
      if (raw.isEmpty) return [HealthConcern.none()];
      final concerns = <HealthConcern>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final concern = concernFromApi(Map<String, dynamic>.from(item));
        if (concern != null) concerns.add(concern);
      }
      if (concerns.isEmpty) return [HealthConcern.none()];
      if (concerns.every((item) => item.isNone)) {
        return [HealthConcern.none()];
      }
      return concerns.where((item) => !item.isNone).toList();
    }

    if (raw is Map) {
      final concern = concernFromApi(Map<String, dynamic>.from(raw));
      if (concern == null || concern.isNone) return [HealthConcern.none()];
      return [concern];
    }

    return null;
  }

  static HealthConcern? concernFromApi(Map<String, dynamic> json) {
    final categoryRaw = json['category'] as String? ?? '';
    if (categoryRaw.trim().isEmpty) return null;

    final category = categoryFromApi(categoryRaw);
    if (category == HealthConcern.noneCategory) {
      return HealthConcern.none();
    }

    return HealthConcern(
      category: category,
      description: json['description'] as String? ?? '',
      duration: durationFromApi(json['duration'] as String?),
      severity: severityFromApi(json['severity'] as String?),
      medication: medicationFromApi(json['medication'] as String?),
    );
  }

  static String _fromApi(String value, Map<String, String> uiToApi) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (uiToApi.containsKey(trimmed)) return trimmed;

    final normalized = _normalizeKey(trimmed);
    for (final entry in uiToApi.entries) {
      if (_normalizeKey(entry.value) == normalized) return entry.key;
      if (_normalizeKey(entry.key) == normalized) return entry.key;
    }
    return trimmed;
  }

  static String _normalizeKey(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

  static String _toCamelCase(String value) {
    final parts = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return value;

    final first = parts.first.toLowerCase();
    final rest = parts
        .skip(1)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join();
    return '$first$rest';
  }
}
