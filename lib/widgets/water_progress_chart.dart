import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_water_intake.dart';
import '../theme/app_colors.dart';

class WaterProgressChart extends StatelessWidget {
  const WaterProgressChart({
    super.key,
    required this.days,
    required this.waterGoalMl,
    this.chartHeight = 160,
  });

  final List<DailyWaterIntake> days;
  final int waterGoalMl;
  final double chartHeight;

  static const Color _waterBlue = Color(0xFF007AFF);
  static const double _dayLabelHeight = 22;
  static const double _valueLabelHeight = 18;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final values = days.map((d) => d.totalMl).toList();
    final maxValue = _maxChartValue(values);
    final total = values.fold<int>(0, (sum, v) => sum + v);
    final avg = values.isEmpty ? 0.0 : total / values.length;
    final daysOnGoal = days.where((d) => d.goalMet(waterGoalMl)).length;
    final isSingleDay = days.length == 1;
    final day = days.first;
    final barAreaHeight = chartHeight - _dayLabelHeight;
    // Reserve top space for value labels so bars + goal share one scale.
    final plotHeight = barAreaHeight - _valueLabelHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: chartHeight,
          child: Column(
            children: [
              SizedBox(
                height: barAreaHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Horizontal grid lines
                    ...List.generate(3, (i) {
                      final t = (i + 1) / 4;
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: barAreaHeight * t,
                        child: Container(
                          height: 1,
                          color: AppColors.border.withValues(alpha: 0.55),
                        ),
                      );
                    }),
                    // Baseline
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 1.5,
                        color: AppColors.border,
                      ),
                    ),
                    // Bars — use 7-day slot width so Today/Yesterday match week bars
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final slotWidth = _barSlotWidth(
                            constraints.maxWidth,
                            days.length,
                          );
                          final horizontalPad = _barHorizontalPad(days.length);

                          return Row(
                            mainAxisAlignment: days.length < 7
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(days.length, (index) {
                              final intake = days[index];
                              final value = values[index];
                              final metGoal = intake.goalMet(waterGoalMl);
                              final showValueLabel =
                                  _showDayLabel(index, days.length);
                              final hasValue = intake.hasData &&
                                  value > 0 &&
                                  showValueLabel;
                              final barHeight = maxValue > 0
                                  ? (value / maxValue * plotHeight).clamp(
                                      intake.hasData ? 6.0 : 3.0,
                                      plotHeight,
                                    )
                                  : 3.0;

                              return SizedBox(
                                width: slotWidth,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPad,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      SizedBox(
                                        height: _valueLabelHeight,
                                        child: hasValue
                                            ? Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: Text(
                                                  _compactMl(value),
                                                  style: TextStyle(
                                                    fontSize: days.length > 14
                                                        ? 8
                                                        : 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: metGoal
                                                        ? AppColors.primary
                                                        : AppColors
                                                            .textSecondary,
                                                    height: 1,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              )
                                            : null,
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        width: double.infinity,
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: _barColor(intake, metGoal),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _dayLabelHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slotWidth = _barSlotWidth(
                      constraints.maxWidth,
                      days.length,
                    );
                    final horizontalPad = _barHorizontalPad(days.length);

                    return Row(
                      mainAxisAlignment: days.length < 7
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(days.length, (index) {
                        final intake = days[index];
                        final showLabel = _showDayLabel(index, days.length);

                        return SizedBox(
                          width: slotWidth,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPad,
                            ),
                            child: showLabel
                                ? Text(
                                    _formatDayLabel(
                                      intake.date,
                                      days.length,
                                      index,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: days.length > 14 ? 9 : 11,
                                      fontWeight: _isToday(intake.date)
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: _isToday(intake.date)
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isSingleDay)
          _GoalStatusCard(
            intake: day,
            waterGoalMl: waterGoalMl,
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Avg: ${formatWaterMl(avg.round())} / day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  'On goal: $daysOnGoal/${days.length} days',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        daysOnGoal > 0 ? FontWeight.w700 : FontWeight.w500,
                    color: daysOnGoal > 0
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  double _maxChartValue(List<int> values) {
    var max = values.fold<int>(0, (a, b) => a > b ? a : b);
    if (waterGoalMl > max) max = waterGoalMl;
    return max > 0 ? max.toDouble() * 1.15 : 1;
  }

  /// Keep Today/Yesterday bars the same width as a 7-day bar.
  static double _barSlotWidth(double totalWidth, int dayCount) {
    final slots = dayCount < 7 ? 7 : dayCount;
    return totalWidth / slots;
  }

  static double _barHorizontalPad(int dayCount) {
    if (dayCount > 14) return 2.0;
    if (dayCount > 7) return 4.0;
    return 5.0;
  }

  static String _compactMl(int ml) {
    if (ml < 1000) return '$ml';
    final liters = ml / 1000;
    return liters == liters.roundToDouble()
        ? '${liters.round()}L'
        : '${liters.toStringAsFixed(1)}L';
  }

  Color _barColor(DailyWaterIntake intake, bool metGoal) {
    if (!intake.hasData) return AppColors.border;
    return metGoal ? AppColors.primary : _waterBlue;
  }

  bool _showDayLabel(int index, int count) {
    if (count <= 7) return true;
    if (count == 30) return index % 5 == 0 || index == count - 1;
    return true;
  }

  String _formatDayLabel(DateTime date, int count, int index) {
    if (count == 1) return DateFormat('EEE, MMM d').format(date);
    if (count <= 7) return DateFormat('E').format(date);
    if (count == 30) {
      if (index % 5 == 0 || index == count - 1) {
        return DateFormat('d').format(date);
      }
      return '';
    }
    return DateFormat('E').format(date);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _GoalStatusCard extends StatelessWidget {
  const _GoalStatusCard({
    required this.intake,
    required this.waterGoalMl,
  });

  final DailyWaterIntake intake;
  final int waterGoalMl;

  @override
  Widget build(BuildContext context) {
    final met = intake.goalMet(waterGoalMl);
    final goalGlasses = waterGoalMl > 0
        ? (waterGoalMl / DailyWaterIntake.mlPerGlass).round().clamp(1, 100)
        : 8;
    final glasses = intake.glasses;
    final remainingGlasses = (goalGlasses - glasses).clamp(0, goalGlasses);
    final overGlasses = glasses > goalGlasses ? glasses - goalGlasses : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: met
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: met
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.water_drop_outlined,
            color: met ? AppColors.primary : WaterProgressChart._waterBlue,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  met
                      ? overGlasses > 0
                          ? 'Goal achieved · +$overGlasses extra glass'
                              '${overGlasses == 1 ? '' : 'es'}'
                          : 'Daily goal achieved!'
                      : '$remainingGlasses glass'
                          '${remainingGlasses == 1 ? '' : 'es'} to goal',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: met ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$glasses of $goalGlasses glasses · ${formatWaterMl(intake.totalMl)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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
