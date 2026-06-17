import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_water_intake.dart';
import '../theme/app_colors.dart';

class WaterProgressChart extends StatelessWidget {
  const WaterProgressChart({
    super.key,
    required this.days,
    required this.waterGoal,
    this.chartHeight = 160,
  });

  final List<DailyWaterIntake> days;
  final int waterGoal;
  final double chartHeight;

  static const Color _waterBlue = Color(0xFF007AFF);
  static const double _dayLabelHeight = 20;
  static const double _valueLabelHeight = 18;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final values = days.map((d) => d.glasses).toList();
    final maxValue = _maxChartValue(values);
    final total = values.fold<int>(0, (sum, v) => sum + v);
    final avg = values.isEmpty ? 0.0 : total / values.length;
    final daysOnGoal = days.where((d) => d.goalMet(waterGoal)).length;
    final isSingleDay = days.length == 1;
    final day = days.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: chartHeight,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barAreaHeight = constraints.maxHeight;

                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        if (waterGoal > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: (waterGoal / maxValue * barAreaHeight)
                                .clamp(0.0, barAreaHeight - 1),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1.5,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Goal',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Positioned.fill(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children:
                                List.generate(days.length, (index) {
                              final intake = days[index];
                              final value = values[index];
                              final metGoal = intake.goalMet(waterGoal);
                              final showValueLabel =
                                  _showDayLabel(index, days.length);
                              final hasValueLabel = intake.hasData &&
                                  value > 0 &&
                                  showValueLabel;
                              final labelSpace =
                                  hasValueLabel ? _valueLabelHeight : 0.0;
                              final availableBarHeight =
                                  barAreaHeight - labelSpace;
                              final barHeight = maxValue > 0
                                  ? (value / maxValue * availableBarHeight)
                                      .clamp(
                                      intake.hasData ? 4.0 : 2.0,
                                      availableBarHeight,
                                    )
                                  : 2.0;

                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSingleDay
                                        ? 48
                                        : (days.length > 14 ? 1 : 3),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (hasValueLabel)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (metGoal) ...[
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 10,
                                                  color: AppColors.primary,
                                                ),
                                                const SizedBox(width: 2),
                                              ],
                                              Text(
                                                '$value',
                                                style: TextStyle(
                                                  fontSize: days.length > 14
                                                      ? 8
                                                      : 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: metGoal
                                                      ? AppColors.primary
                                                      : AppColors
                                                          .textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: _barColor(intake, metGoal),
                                          borderRadius: BorderRadius.circular(
                                            isSingleDay ? 10 : 6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(
                height: _dayLabelHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(days.length, (index) {
                    final intake = days[index];
                    final showLabel = _showDayLabel(index, days.length);

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              isSingleDay ? 48 : (days.length > 14 ? 1 : 3),
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
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isSingleDay)
          _GoalStatusCard(
            intake: day,
            waterGoal: waterGoal,
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Avg: ${avg.toStringAsFixed(1)} glasses',
                  style: TextStyle(
                    fontSize: 13,
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
                        daysOnGoal > 0 ? FontWeight.w600 : FontWeight.normal,
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
    if (waterGoal > max) max = waterGoal;
    return max > 0 ? max.toDouble() : 1;
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
    required this.waterGoal,
  });

  final DailyWaterIntake intake;
  final int waterGoal;

  @override
  Widget build(BuildContext context) {
    final met = intake.goalMet(waterGoal);
    final remaining = (waterGoal - intake.glasses).clamp(0, waterGoal);

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
                  met ? 'Daily goal achieved!' : '$remaining glasses to goal',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: met ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${intake.glasses} of $waterGoal glasses',
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
