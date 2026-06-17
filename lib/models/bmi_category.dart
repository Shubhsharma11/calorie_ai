enum BmiCategory {
  underweight,
  normal,
  overweight,
  obese,
}

extension BmiCategoryLabel on BmiCategory {
  String get title => switch (this) {
        BmiCategory.underweight => 'Underweight',
        BmiCategory.normal => 'Normal',
        BmiCategory.overweight => 'Overweight',
        BmiCategory.obese => 'Obese',
      };

  String get guidance => switch (this) {
        BmiCategory.underweight =>
          'Focus on gradual, healthy weight gain within a normal BMI range.',
        BmiCategory.normal =>
          'Small, steady changes are recommended to stay within a healthy range.',
        BmiCategory.overweight =>
          'A moderate loss toward the healthy BMI range is recommended.',
        BmiCategory.obese =>
          'A staged loss of about 5–10% body weight is a healthy first milestone.',
      };
}
