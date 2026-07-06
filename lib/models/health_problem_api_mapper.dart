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
