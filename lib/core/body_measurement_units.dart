/// Converts body measurements between metric and imperial units.
abstract final class BodyMeasurementUnits {
  static const kgToLb = 2.2046226218;
  static const cmPerInch = 2.54;

  static int cmFromFeetInches(int feet, int inches) {
    final totalInches = (feet * 12 + inches).clamp(0, 120);
    return (totalInches * cmPerInch).round();
  }

  static ({int feet, int inches}) feetInchesFromCm(int cm) {
    final totalInches = (cm / cmPerInch).round().clamp(0, 120);
    return (feet: totalInches ~/ 12, inches: totalInches % 12);
  }

  static int kgFromLbs(double lbs) => (lbs / kgToLb).round();

  static int lbsFromKg(int kg) => (kg * kgToLb).round();

  static bool isValidCm(int cm) => cm >= 100 && cm <= 250;

  static bool isValidKg(int kg) => kg >= 30 && kg <= 300;

  static bool isValidLbs(int lbs) => lbs >= 66 && lbs <= 661;

  static bool isValidFeetInches(int feet, int inches) {
    if (feet < 3 || feet > 8) return false;
    if (inches < 0 || inches > 11) return false;
    return isValidCm(cmFromFeetInches(feet, inches));
  }
}
