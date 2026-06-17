enum NutritionTrendMetric {

  calories,

  protein,

  carbs,

  fat,

}



extension NutritionTrendMetricLabel on NutritionTrendMetric {

  String get label => switch (this) {

        NutritionTrendMetric.calories => 'Calories',

        NutritionTrendMetric.protein => 'Protein',

        NutritionTrendMetric.carbs => 'Carbs',

        NutritionTrendMetric.fat => 'Fat',

      };



  String get unit => switch (this) {

        NutritionTrendMetric.calories => 'kcal',

        NutritionTrendMetric.protein => 'g',

        NutritionTrendMetric.carbs => 'g',

        NutritionTrendMetric.fat => 'g',

      };

}

