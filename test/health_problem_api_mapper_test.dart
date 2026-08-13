import 'package:calorie_ai/models/health_problem_api_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps UI health concern values to API enums', () {
    expect(
      HealthProblemApiMapper.category('High Cholesterol'),
      'highCholesterol',
    );
    expect(HealthProblemApiMapper.category('Stress / Anxiety'), 'stress');
    expect(HealthProblemApiMapper.duration('1-4 weeks'), 'oneToFourWeeks');
    expect(HealthProblemApiMapper.duration('1-6 months'), 'oneToSixMonths');
    expect(HealthProblemApiMapper.severity('Moderate'), 'moderate');
    expect(HealthProblemApiMapper.medication('No'), 'no');
  });

  test('maps API enums back to UI health concern values', () {
    expect(HealthProblemApiMapper.categoryFromApi('diabetes'), 'Diabetes');
    expect(
      HealthProblemApiMapper.categoryFromApi('bloodPressure'),
      'Blood Pressure',
    );
    expect(
      HealthProblemApiMapper.categoryFromApi('high_cholesterol'),
      'High Cholesterol',
    );
    expect(HealthProblemApiMapper.categoryFromApi('stress'), 'Stress / Anxiety');
    expect(
      HealthProblemApiMapper.durationFromApi('oneToSixMonths'),
      '1-6 months',
    );
    expect(HealthProblemApiMapper.severityFromApi('moderate'), 'Moderate');
    expect(HealthProblemApiMapper.medicationFromApi('yes'), 'Yes');
  });

  test('parseConcerns restores filled health details from API payload', () {
    final concerns = HealthProblemApiMapper.parseConcerns([
      {
        'category': 'diabetes',
        'description': 'Type 2, controlled with diet',
        'duration': 'oneToSixMonths',
        'severity': 'mild',
        'medication': 'yes',
      },
    ]);

    expect(concerns, isNotNull);
    expect(concerns, hasLength(1));
    expect(concerns!.first.category, 'Diabetes');
    expect(concerns.first.description, 'Type 2, controlled with diet');
    expect(concerns.first.duration, '1-6 months');
    expect(concerns.first.severity, 'Mild');
    expect(concerns.first.medication, 'Yes');
  });

  test('parseConcerns treats empty API list as None', () {
    final concerns = HealthProblemApiMapper.parseConcerns(const []);
    expect(concerns, hasLength(1));
    expect(concerns!.first.isNone, isTrue);
  });

  test('parseConcerns returns null when field is missing', () {
    expect(HealthProblemApiMapper.parseConcerns(null), isNull);
  });
}
