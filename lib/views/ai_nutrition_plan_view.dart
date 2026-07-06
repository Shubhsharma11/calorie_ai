import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_page.dart';

class AiNutritionPlanView extends StatelessWidget {
  const AiNutritionPlanView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Get.find<UserController>().user;
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsivePage(
          scrollable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PlanTopBar(),
              SizedBox(height: r.scale(14)),
              _PlanSummaryCard(
                calories: user.dailyCalorieGoal,
                protein: user.proteinGoalG,
                carbs: user.carbsGoalG,
                fat: user.fatGoalG,
              ),
              SizedBox(height: r.scale(16)),
              const _SectionHeader(title: 'Meal Plan'),
              SizedBox(height: r.scale(9)),
              ..._mealPlans.map(
                (meal) => Padding(
                  padding: EdgeInsets.only(bottom: r.scale(10)),
                  child: _MealPlanCard(meal: meal),
                ),
              ),
              SizedBox(height: r.scale(4)),
              const _FoodsToAvoidCard(),
              SizedBox(height: r.scale(12)),
              const _AiTipsCard(),
              SizedBox(height: r.scale(14)),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: Get.back,
                  icon: const Icon(Icons.fact_check_rounded, size: 19),
                  label: const Text('Save My Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.scale(10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: r.scale(13),
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: r.scale(5)),
                  Text(
                    'Your plan is private and secure',
                    style: TextStyle(
                      fontSize: r.scale(12),
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.scale(12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTopBar extends StatelessWidget {
  const _PlanTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundActionButton(icon: Icons.arrow_back_rounded, onTap: Get.back),
        const Spacer(),
        Text(
          'AI Nutrition Plan',
          style: TextStyle(
            fontSize: context.responsive.scale(18, tablet: 20),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        _RoundActionButton(icon: Icons.ios_share_rounded, onTap: () {}),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 21, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(r.scale(14)),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Daily Nutrition Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.scale(16, tablet: 17),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: r.scale(4)),
                      Text(
                        'Based on your profile and goal',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: r.scale(12, tablet: 13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const _ClipboardAppleIllustration(),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.scale(10),
              vertical: r.scale(13),
            ),
            child: Row(
              children: [
                _MacroPlanStat(value: '$calories', label: 'Calories / day'),
                _MacroPlanStat(value: '${protein}g', label: 'Protein'),
                _MacroPlanStat(value: '${carbs}g', label: 'Carbs'),
                _MacroPlanStat(value: '${fat}g', label: 'Fat'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipboardAppleIllustration extends StatelessWidget {
  const _ClipboardAppleIllustration();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      width: r.scale(78),
      height: r.scale(58),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 8,
            child: Icon(
              Icons.eco_rounded,
              color: Colors.white.withValues(alpha: 0.16),
              size: r.scale(58),
            ),
          ),
          Container(
            width: r.scale(43),
            height: r.scale(54),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: r.scale(9),
                        color: AppColors.primary,
                      ),
                      SizedBox(width: r.scale(3)),
                      Container(
                        width: r.scale(17),
                        height: r.scale(3),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: r.scale(2),
            bottom: r.scale(2),
            child: Icon(
              Icons.apple_rounded,
              color: AppColors.error,
              size: r.scale(31),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroPlanStat extends StatelessWidget {
  const _MacroPlanStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(18, tablet: 20),
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: r.scale(2)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(10, tablet: 11),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        Container(
          width: 4,
          height: r.scale(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        SizedBox(width: r.scale(9)),
        Text(
          title,
          style: TextStyle(
            fontSize: r.scale(15, tablet: 16),
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MealPlanCard extends StatelessWidget {
  const _MealPlanCard({required this.meal});

  final _MealPlan meal;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(11)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(meal.icon, color: meal.color, size: r.scale(18)),
                    SizedBox(width: r.scale(6)),
                    Text(
                      meal.title,
                      style: TextStyle(
                        color: meal.color,
                        fontWeight: FontWeight.w900,
                        fontSize: r.scale(14, tablet: 15),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.scale(8)),
                ...meal.items.map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: r.scale(3)),
                    child: Text(
                      '- $item',
                      style: TextStyle(
                        fontSize: r.scale(12, tablet: 13),
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.scale(8)),
          _FoodPlate(meal: meal),
          SizedBox(width: r.scale(8)),
          _KcalBadge(kcal: meal.kcal, color: meal.color),
        ],
      ),
    );
  }
}

class _FoodPlate extends StatelessWidget {
  const _FoodPlate({required this.meal});

  final _MealPlan meal;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      width: r.scale(62, tablet: 70),
      height: r.scale(62, tablet: 70),
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: r.scale(50, tablet: 56),
          height: r.scale(50, tablet: 56),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              ...meal.plateItems.map(
                (item) => Positioned(
                  left: r.scale(item.left),
                  top: r.scale(item.top),
                  child: Container(
                    width: r.scale(item.size),
                    height: r.scale(item.size),
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KcalBadge extends StatelessWidget {
  const _KcalBadge({required this.kcal, required this.color});

  final int kcal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      width: r.scale(54, tablet: 60),
      padding: EdgeInsets.symmetric(vertical: r.scale(11)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            '$kcal',
            style: TextStyle(
              color: color,
              fontSize: r.scale(17, tablet: 18),
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          SizedBox(height: r.scale(3)),
          Text(
            'kcal',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: r.scale(10),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodsToAvoidCard extends StatelessWidget {
  const _FoodsToAvoidCard();

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      icon: Icons.do_not_disturb_on_rounded,
      iconColor: AppColors.error,
      title: 'Foods to Avoid',
      subtitle: 'Based on your health conditions',
      backgroundColor: const Color(0xFFFFF0F0),
      trailing: const _AvoidIllustration(),
      children: const [
        _AvoidFood(label: 'Sugary Drinks'),
        _AvoidFood(label: 'Refined Sugar'),
        _AvoidFood(label: 'White Bread'),
        _AvoidFood(label: 'Packaged Juice'),
      ],
    );
  }
}

class _AvoidIllustration extends StatelessWidget {
  const _AvoidIllustration();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Icon(
      Icons.do_not_disturb_alt_rounded,
      color: AppColors.error.withValues(alpha: 0.18),
      size: r.scale(62),
    );
  }
}

class _AiTipsCard extends StatelessWidget {
  const _AiTipsCard();

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      icon: Icons.lightbulb_rounded,
      iconColor: const Color(0xFF007AFF),
      title: 'AI Tips for You',
      backgroundColor: const Color(0xFFEFF7FF),
      trailing: const _WaterBottleIllustration(),
      children: const [
        _TipLine(text: 'Drink 3L water daily'),
        _TipLine(text: 'Walk 8,000 steps every day'),
        _TipLine(text: 'Sleep 7-8 hours'),
        _TipLine(text: 'Eat protein in every meal'),
        _TipLine(text: 'Avoid late-night snacking'),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.backgroundColor,
    required this.children,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color backgroundColor;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(13)),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: r.scale(18)),
                    SizedBox(width: r.scale(7)),
                    Text(
                      title,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: r.scale(14, tablet: 15),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  SizedBox(height: r.scale(2)),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: r.scale(10, tablet: 11),
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: r.scale(10)),
                Wrap(
                  spacing: r.scale(14),
                  runSpacing: r.scale(7),
                  children: children,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: r.scale(10)), trailing!],
        ],
      ),
    );
  }
}

class _AvoidFood extends StatelessWidget {
  const _AvoidFood({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      width: r.scale(122, tablet: 140),
      child: Row(
        children: [
          Icon(Icons.cancel_rounded, color: AppColors.error, size: r.scale(15)),
          SizedBox(width: r.scale(6)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: r.scale(11, tablet: 12),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      width: r.scale(180, tablet: 220),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: const Color(0xFF007AFF),
            size: r.scale(15),
          ),
          SizedBox(width: r.scale(6)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: r.scale(12, tablet: 13),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterBottleIllustration extends StatelessWidget {
  const _WaterBottleIllustration();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      width: r.scale(72),
      height: r.scale(96),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Icon(
              Icons.eco_rounded,
              color: AppColors.primary.withValues(alpha: 0.25),
              size: r.scale(54),
            ),
          ),
          Positioned(
            right: 0,
            bottom: r.scale(6),
            child: Icon(
              Icons.eco_rounded,
              color: AppColors.primary.withValues(alpha: 0.22),
              size: r.scale(48),
            ),
          ),
          Icon(
            Icons.water_drop_rounded,
            color: const Color(0xFF8EC5FF),
            size: r.scale(72),
          ),
        ],
      ),
    );
  }
}

const _mealPlans = [
  _MealPlan(
    title: 'Breakfast',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFFFFB800),
    kcal: 450,
    items: ['Oats with milk', '2 Boiled eggs', '1 Banana'],
    plateItems: [
      _PlateItem(Color(0xFFFFF3C4), 5, 5, 19),
      _PlateItem(Color(0xFFFFD44D), 11, 11, 10),
      _PlateItem(Color(0xFFF6E7B6), 28, 4, 15),
      _PlateItem(Color(0xFFFFF3C4), 27, 26, 18),
      _PlateItem(Color(0xFFFFD44D), 33, 32, 9),
    ],
  ),
  _MealPlan(
    title: 'Lunch',
    icon: Icons.wb_sunny_outlined,
    color: AppColors.primary,
    kcal: 700,
    items: ['Brown rice', 'Grilled chicken / Paneer', 'Mixed vegetables'],
    plateItems: [
      _PlateItem(Color(0xFFF4E2C4), 4, 8, 22),
      _PlateItem(Color(0xFFC96C2C), 24, 6, 18),
      _PlateItem(Color(0xFFFF9500), 18, 25, 10),
      _PlateItem(Color(0xFF34C759), 30, 28, 12),
      _PlateItem(Color(0xFF8BC34A), 8, 29, 11),
    ],
  ),
  _MealPlan(
    title: 'Dinner',
    icon: Icons.dark_mode_rounded,
    color: Color(0xFF8B5CF6),
    kcal: 650,
    items: ['2 Roti', 'Dal', 'Salad'],
    plateItems: [
      _PlateItem(Color(0xFFE9C68A), 5, 19, 27),
      _PlateItem(Color(0xFFD89744), 27, 6, 18),
      _PlateItem(Color(0xFF34C759), 33, 29, 11),
      _PlateItem(Color(0xFFFF9500), 22, 23, 8),
    ],
  ),
  _MealPlan(
    title: 'Snacks',
    icon: Icons.apple_rounded,
    color: AppColors.error,
    kcal: 350,
    items: ['Apple', 'Almonds (10 pcs)', 'Greek Yogurt'],
    plateItems: [
      _PlateItem(Color(0xFFF7F1E3), 6, 8, 35),
      _PlateItem(Color(0xFF1C1C1E), 12, 9, 8),
      _PlateItem(Color(0xFF283593), 28, 8, 9),
      _PlateItem(Color(0xFFC68B59), 19, 28, 8),
      _PlateItem(Color(0xFFC68B59), 31, 27, 7),
    ],
  ),
];

class _MealPlan {
  const _MealPlan({
    required this.title,
    required this.icon,
    required this.color,
    required this.kcal,
    required this.items,
    required this.plateItems,
  });

  final String title;
  final IconData icon;
  final Color color;
  final int kcal;
  final List<String> items;
  final List<_PlateItem> plateItems;
}

class _PlateItem {
  const _PlateItem(this.color, this.left, this.top, this.size);

  final Color color;
  final double left;
  final double top;
  final double size;
}
