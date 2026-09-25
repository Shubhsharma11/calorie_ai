import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/food_controller.dart';
import '../controllers/nutrition_plan_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../models/diet_type.dart';
import '../models/goal_type.dart';
import '../models/planned_meal.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';
import '../widgets/weekly_meal_plan/dont_suggest_sheets.dart';
import '../widgets/weekly_meal_plan/meal_detail_sheet.dart';
import '../widgets/weekly_meal_plan/swap_meal_sheet.dart';
import '../widgets/weekly_meal_plan/weekly_meal_card.dart';
import 'weekly_meal_more_options_view.dart';

class WeeklyMealPlanView extends StatefulWidget {
  const WeeklyMealPlanView({super.key});

  @override
  State<WeeklyMealPlanView> createState() => _WeeklyMealPlanViewState();
}

class _WeeklyMealPlanViewState extends State<WeeklyMealPlanView> {
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late int _selectedWeekday;

  /// Slot id → replacement meal (keeps slot id / time / status).
  final Map<String, PlannedMeal> _swaps = {};

  /// Slot ids marked logged.
  final Set<String> _loggedIds = {};

  /// Meal names the user never wants again (lowercase).
  final Set<String> _suppressedNames = {};

  /// Slot ids removed after don't-suggest (until auto-replaced).
  final Set<String> _removedSlotIds = {};

  @override
  void initState() {
    super.initState();
    _selectedWeekday = DateTime.now().weekday;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planController = Get.isRegistered<NutritionPlanController>()
          ? Get.find<NutritionPlanController>()
          : Get.put(NutritionPlanController(), permanent: true);
      unawaited(planController.ensureWeeklyPlan());
    });
  }

  NutritionPlanController? get _planController =>
      Get.isRegistered<NutritionPlanController>()
          ? Get.find<NutritionPlanController>()
          : null;

  WeeklyMealPlanData? get _weekly => _planController?.plan.value?.weeklyPlan;

  String _goalLabel(GoalType? goal) {
    return switch (goal) {
      GoalType.loseWeight => 'Fat Loss',
      GoalType.gainWeight => 'Muscle Gain',
      GoalType.maintainWeight => 'Maintenance',
      null => 'Fitness',
    };
  }

  String _formatKcal(int value) => NumberFormat('#,###').format(value);

  List<PlannedMeal> _swapPoolFor(PlannedMeal meal) {
    final weekly = _weekly;
    final fromMeal = meal.alternatives;
    if (fromMeal.isNotEmpty) {
      return fromMeal
          .where(
            (m) =>
                m.name.toLowerCase() != meal.name.toLowerCase() &&
                !_suppressedNames.contains(m.name.toLowerCase()),
          )
          .toList();
    }
    if (weekly == null || weekly.isEmpty) return const [];
    return weekly.swapAlternativesFor(
      meal,
      suppressedNames: _suppressedNames,
    );
  }

  List<PlannedMeal> _moreOptionsPoolFor(PlannedMeal meal) {
    final weekly = _weekly;
    if (weekly == null || weekly.isEmpty) {
      return _swapPoolFor(meal);
    }
    return weekly.moreOptionsFor(
      meal,
      suppressedNames: _suppressedNames,
    );
  }

  /// Slot ids currently posting to the diary API.
  final Set<String> _loggingIds = {};

  DateTime _dateForSelectedWeekday() {
    final weekStart = _weekly?.weekStart;
    final monday = weekStart != null
        ? DateTime(weekStart.year, weekStart.month, weekStart.day)
        : _mondayOf(DateTime.now());
    return monday.add(Duration(days: _selectedWeekday - DateTime.monday));
  }

  static DateTime _mondayOf(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  PlannedMeal _resolve(PlannedMeal meal) {
    var resolved = _swaps[meal.id] ?? meal;
    if (_loggedIds.contains(meal.id)) {
      resolved = resolved.copyWith(status: PlannedMealStatus.completed);
    }
    return resolved;
  }

  List<PlannedMeal> _visibleMeals(List<PlannedMeal> meals) {
    final mealsPerDay = Get.isRegistered<UserController>()
        ? (Get.find<UserController>().user.mealsPerDay ?? 3)
        : 3;
    final visible = meals
        .where((m) => !_removedSlotIds.contains(m.id))
        .map(_resolve)
        .where((m) => !_suppressedNames.contains(m.name.toLowerCase()))
        .toList();
    return MealsPerDayOptions.sortBySlotOrder(
      visible,
      mealsPerDay,
      (m) => m.mealType,
    );
  }

  Future<void> _openSwap(PlannedMeal meal) async {
    final result = await showSwapMealSheet(
      context,
      current: meal,
      alternatives: _swapPoolFor(meal),
      suppressedNames: _suppressedNames,
    );
    if (!mounted || result == null) return;

    if (result.id == kMoreOptionsSentinelId) {
      await _openMoreOptions(meal);
      return;
    }
    _applySwap(meal, result);
  }

  Future<void> _openMoreOptions(PlannedMeal meal) async {
    final picked = await Navigator.of(context).push<PlannedMeal>(
      MaterialPageRoute(
        builder: (_) => WeeklyMealMoreOptionsView(
          current: meal,
          options: _moreOptionsPoolFor(meal),
          suppressedNames: _suppressedNames,
        ),
      ),
    );
    if (!mounted || picked == null) return;
    _applySwap(meal, picked);
  }

  void _applySwap(PlannedMeal slot, PlannedMeal replacement) {
    setState(() {
      _swaps[slot.id] = replacement.copyWith(
        id: slot.id,
        mealType: slot.mealType,
        timeLabel: slot.timeLabel,
        status: _loggedIds.contains(slot.id)
            ? PlannedMealStatus.completed
            : slot.status,
      );
      _removedSlotIds.remove(slot.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Swapped to ${replacement.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logMeal(PlannedMeal meal) async {
    if (_loggedIds.contains(meal.id) || _loggingIds.contains(meal.id)) {
      AppSnackbar.info('This meal is already logged.');
      return;
    }
    if (!Get.isRegistered<FoodController>()) {
      AppSnackbar.error('Food diary is not ready yet. Try again.');
      return;
    }

    setState(() => _loggingIds.add(meal.id));
    final food = Get.find<FoodController>();
    final ok = await food.logPlannedMeal(
      meal,
      date: _dateForSelectedWeekday(),
    );
    if (!mounted) return;
    setState(() => _loggingIds.remove(meal.id));

    if (!ok) return;

    setState(() => _loggedIds.add(meal.id));
    AppSnackbar.success('${meal.name} saved to your diary.');
  }

  Future<void> _dontSuggest(PlannedMeal meal) async {
    final reason = await showDontSuggestReasonSheet(context);
    if (!mounted || reason == null) return;

    final confirmed = await showDontSuggestConfirmDialog(context);
    if (!mounted || !confirmed) return;

    final alts = _swapPoolFor(meal);

    setState(() {
      _suppressedNames.add(meal.name.toLowerCase());
      if (alts.isNotEmpty) {
        _swaps[meal.id] = alts.first.copyWith(
          id: meal.id,
          mealType: meal.mealType,
          timeLabel: meal.timeLabel,
          status: meal.status,
        );
      } else {
        _removedSlotIds.add(meal.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Got it — we won't suggest that meal again"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openDetail(PlannedMeal meal) {
    return showMealDetailSheet(
      context,
      meal: meal,
      onSwap: () => unawaited(_openSwap(meal)),
      onLog: () => unawaited(_logMeal(meal)),
      onDontSuggest: () => unawaited(_dontSuggest(meal)),
    );
  }

  Future<void> _showCardMenu(PlannedMeal meal) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.responsive.scale(20)),
        ),
      ),
      builder: (ctx) {
        final r = ctx.responsive;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: AppColors.primary),
                title: Text('View details', style: TextStyle(fontSize: r.scale(15))),
                onTap: () => Navigator.pop(ctx, 'detail'),
              ),
              if (meal.status != PlannedMealStatus.completed) ...[
                ListTile(
                  leading: Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                  title: Text('Swap meal', style: TextStyle(fontSize: r.scale(15))),
                  onTap: () => Navigator.pop(ctx, 'swap'),
                ),
                ListTile(
                  leading: Icon(Icons.restaurant_rounded, color: AppColors.primary),
                  title: Text('Log this meal', style: TextStyle(fontSize: r.scale(15))),
                  onTap: () => Navigator.pop(ctx, 'log'),
                ),
              ],
              ListTile(
                leading: Icon(
                  Icons.do_not_disturb_on_outlined,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  "Don't suggest again",
                  style: TextStyle(fontSize: r.scale(15)),
                ),
                onTap: () => Navigator.pop(ctx, 'dont'),
              ),
              SizedBox(height: r.scale(8)),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'detail':
        await _openDetail(meal);
      case 'swap':
        await _openSwap(meal);
      case 'log':
        await _logMeal(meal);
      case 'dont':
        await _dontSuggest(meal);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final planController = _planController;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'Your Weekly Meal Plan'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await _planController?.ensureWeeklyPlan();
        },
        child: ResponsivePage(
          scrollable: true,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Builder(
            builder: (context) {
              if (!Get.isRegistered<UserController>()) {
                return const SizedBox.shrink();
              }
              final userController = Get.find<UserController>();
              return Obx(() {
                planController?.revision.value;
                userController.calorieGoalRevision.value;
                final user = userController.user;
                final plan = planController?.plan.value;
                final weekly = plan?.weeklyPlan;
                final hasWeeklyApi = weekly != null && weekly.isNotEmpty;
                final goal = user.pinnedGoalType ?? user.goal;
                final goalLabel = (plan?.goalLabel?.trim().isNotEmpty == true)
                    ? plan!.goalLabel!.trim()
                    : _goalLabel(goal);
                final calories =
                    weekly?.dailyCalorieTarget ??
                    plan?.calories ??
                    user.dailyCalorieGoal;
                final isLoading = planController?.isLoading.value == true;
                final error = planController?.errorMessage.value;
                final completed = planController?.hasCompletedFetch.value == true;

                if (isLoading && !hasWeeklyApi) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: r.scale(80)),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                if (!hasWeeklyApi) {
                  return _ApiEmptyState(
                    message: error ??
                        (completed
                            ? 'No weekly meals in your plan yet.'
                            : 'Unable to load your meal plan.'),
                    onRetry: () => unawaited(
                      planController?.ensureWeeklyPlan() ?? Future.value(),
                    ),
                  );
                }

                final meals = _visibleMeals(
                  weekly.mealsForWeekday(_selectedWeekday),
                );
                final nextMeals = meals
                    .where((m) => m.status == PlannedMealStatus.next)
                    .toList();
                final otherMeals = meals
                    .where((m) => m.status != PlannedMealStatus.next)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: r.scale(4)),
                    _TargetBanner(
                      caloriesLabel:
                          '${_formatKcal(weekly.dailyCalorieTarget ?? calories)} kcal / day target',
                      goalLabel: weekly.goalLabel?.trim().isNotEmpty == true
                          ? weekly.goalLabel!.trim()
                          : goalLabel,
                    ),
                    SizedBox(height: r.scale(14)),
                    _DaySelector(
                      selectedWeekday: _selectedWeekday,
                      labels: _dayLabels,
                      onSelected: (weekday) {
                        setState(() => _selectedWeekday = weekday);
                      },
                    ),
                    SizedBox(height: r.scale(16)),
                    if (meals.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: r.scale(36)),
                        child: Text(
                          'No meals planned for this day yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: r.scale(14),
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      )
                    else ...[
                      if (nextMeals.isNotEmpty) ...[
                        Text(
                          'Next meal',
                          style: TextStyle(
                            fontSize: r.scale(16),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: r.scale(10)),
                        for (final meal in nextMeals) ...[
                          WeeklyMealPlanCard(
                            meal: meal,
                            onSwap: () => unawaited(_openSwap(meal)),
                            onLog: () => unawaited(_logMeal(meal)),
                            onOpenDetail: () => unawaited(_openDetail(meal)),
                            onMenu: () => unawaited(_showCardMenu(meal)),
                          ),
                          SizedBox(height: r.scale(14)),
                        ],
                      ],
                      for (final meal in otherMeals) ...[
                        WeeklyMealPlanCard(
                          meal: meal,
                          compact: meal.status == PlannedMealStatus.completed,
                          onSwap: () => unawaited(_openSwap(meal)),
                          onLog: () => unawaited(_logMeal(meal)),
                          onOpenDetail: () => unawaited(_openDetail(meal)),
                          onMenu: () => unawaited(_showCardMenu(meal)),
                        ),
                        SizedBox(height: r.scale(14)),
                      ],
                    ],
                    SizedBox(
                      height:
                          MediaQuery.viewPaddingOf(context).bottom +
                          r.scale(24),
                    ),
                  ],
                );
              });
            },
          ),
        ),
      ),
    );
  }
}

class _ApiEmptyState extends StatelessWidget {
  const _ApiEmptyState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(24),
        vertical: r.scale(48),
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: r.scale(40),
            color: AppColors.textSecondary,
          ),
          SizedBox(height: r.scale(14)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(15),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            'Pull to refresh or tap retry after your plan is ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(13),
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          SizedBox(height: r.scale(16)),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetBanner extends StatelessWidget {
  const _TargetBanner({required this.caloriesLabel, required this.goalLabel});

  final String caloriesLabel;
  final String goalLabel;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(14),
        vertical: r.scale(14),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/image/Vector.png',
            width: r.scale(40),
            height: r.scale(40),
            fit: BoxFit.contain,
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caloriesLabel,
                  style: TextStyle(
                    fontSize: r.scale(15),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(2)),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: r.scale(12),
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    children: [
                      const TextSpan(text: 'Designed around your '),
                      TextSpan(
                        text: goalLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const TextSpan(text: ' goal'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selectedWeekday,
    required this.labels,
    required this.onSelected,
  });

  final int selectedWeekday;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final chipWidth = r.scale(58);
    final chipHeight = r.scale(42);

    return SizedBox(
      height: chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (context, index) => SizedBox(width: r.scale(8)),
        itemBuilder: (context, i) {
          final selected = selectedWeekday == i + 1;
          return SizedBox(
            width: chipWidth,
            height: chipHeight,
            child: Material(
              color: selected ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(r.scale(12)),
              child: InkWell(
                onTap: () => onSelected(i + 1),
                borderRadius: BorderRadius.circular(r.scale(12)),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.scale(12)),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 0 : 1,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: r.scale(13),
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
