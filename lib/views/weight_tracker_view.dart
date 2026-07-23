import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../controllers/tracker_controller.dart'
    show TrackerController, WeightDeleteStatus;
import '../controllers/settings_controller.dart';
import '../core/app_snackbar.dart';
import '../core/weight_chart_data.dart';
import '../models/meal_entry.dart';
import '../models/weight_entry.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/weight_tracker/weight_log_sheet.dart';
import '../theme/app_colors.dart';

class WeightTrackerView extends GetView<TrackerController> {
  const WeightTrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    return _WeightTrackerBody(controller: controller);
  }
}

class _WeightTrackerBody extends StatefulWidget {
  const _WeightTrackerBody({
    required this.controller,
  });

  final TrackerController controller;

  @override
  State<_WeightTrackerBody> createState() => _WeightTrackerBodyState();
}

class _WeightTrackerBodyState extends State<_WeightTrackerBody> {
  WeightChartPeriod _chartPeriod = WeightChartPeriod.week;
  WeightChartCustomRange? _customChartRange;

  @override
  void initState() {
    super.initState();
    widget.controller.setWeightChartPeriod(
      _chartPeriod,
      customRange: _customChartRange,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.refreshWeightForChartPeriod());
    });
  }

  Future<void> _onChartPeriodChanged(
    BuildContext context,
    WeightChartPeriod period,
  ) async {
    if (period == WeightChartPeriod.custom) {
      final range = await _pickCustomChartRange(context);
      if (range == null || !mounted) return;
      setState(() {
        _chartPeriod = WeightChartPeriod.custom;
        _customChartRange = range;
      });
      widget.controller.setWeightChartPeriod(
        _chartPeriod,
        customRange: _customChartRange,
      );
      await widget.controller.refreshWeightForChartPeriod(
        period: _chartPeriod,
        customRange: _customChartRange,
      );
      return;
    }

    setState(() => _chartPeriod = period);
    widget.controller.setWeightChartPeriod(_chartPeriod);
    await widget.controller.refreshWeightForChartPeriod(period: _chartPeriod);
  }

  Future<WeightChartCustomRange?> _pickCustomChartRange(
    BuildContext context,
  ) async {
    final now = DateTime.now();
    final initial = _customChartRange ??
        WeightChartCustomRange(
          start: now.subtract(const Duration(days: 29)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: initial.start,
        end: initial.end,
      ),
      helpText: 'Select chart date range',
    );
    if (picked == null) return null;

    return WeightChartCustomRange(
      start: MealEntry.normalizeDate(picked.start),
      end: MealEntry.normalizeDate(picked.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Weight Tracker',
      ),
      body: SafeArea(
        child: Obx(() {
          controller.weightRevision.value;
          final weight = controller.currentWeight.value;
          final entries = controller.recentWeightEntries;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WeightChartCard(
                  currentWeight: weight,
                  period: _chartPeriod,
                  customRange: _customChartRange,
                  onPeriodChanged: (period) =>
                      _onChartPeriodChanged(context, period),
                ),
                const SizedBox(height: 10),
                _RecentWeightRecordsCard(entries: entries),
              ],
            ),
          );
        }),
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          unawaited(
            showWeightLogSheet(
              context,
              initialWeight: controller.currentWeight.value,
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Weight',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
      ),
    );
  }
}

class _WeightChartCard extends StatelessWidget {
  const _WeightChartCard({
    required this.currentWeight,
    required this.period,
    required this.customRange,
    required this.onPeriodChanged,
  });

  final double currentWeight;
  final WeightChartPeriod period;
  final WeightChartCustomRange? customRange;
  final ValueChanged<WeightChartPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final tracker = Get.find<TrackerController>();

    return Obx(() {
      tracker.weightRevision.value;
      final entries = tracker.recentWeightEntries;
      final useMetricUnits = Get.isRegistered<SettingsController>()
          ? Get.find<SettingsController>().useMetricUnits.value
          : true;
      final chartData = WeightChartData.build(
        entries: entries,
        period: period,
        useMetricUnits: useMetricUnits,
        customRange: customRange,
      );
      final displayWeight = WeightChartData.toDisplayWeight(
        currentWeight,
        useMetricUnits,
      );
      final unit = chartData.unitLabel;

      return Container(
        decoration: _cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Current Weight',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${displayWeight.toStringAsFixed(2)} $unit',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chart',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showAllEntries(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'View All',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (chartData.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      chartData.subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _WeightPeriodToggle(
                    selected: period,
                    onChanged: onPeriodChanged,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: chartData.isEmpty
                        ? _WeightChartEmptyState(
                            hasAnyEntries: entries.isNotEmpty,
                            suggestedPeriod: chartData.suggestedPeriod,
                            onSwitchPeriod: chartData.suggestedPeriod == null
                                ? null
                                : () => onPeriodChanged(
                                      chartData.suggestedPeriod!,
                                    ),
                          )
                        : CustomPaint(
                            key: ValueKey(
                              '${tracker.weightRevision.value}_'
                              '${period.name}_'
                              '${chartData.points.map((p) => '${p.date.toIso8601String()}:${p.kg}').join('|')}',
                            ),
                            painter: _WeightLineChartPainter(
                              chartData: chartData,
                            ),
                            size: Size.infinite,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showAllEntries(BuildContext context) {
    final tracker = Get.find<TrackerController>();
    if (tracker.weightEntries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No weight entries yet')));
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Obx(() {
            tracker.weightRevision.value;
            final visibleEntries = tracker.recentWeightEntries.reversed.toList();

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSheetHeader(
                    title: 'Weight Entries',
                    onBack: () => Navigator.pop(sheetContext),
                  ),
                  const SizedBox(height: 8),
                  if (visibleEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No weight entries yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: visibleEntries.length,
                        separatorBuilder: (context, index) =>
                            Divider(color: AppColors.border),
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          return Dismissible(
                            key: ValueKey(
                              entry.id ??
                                  '${entry.date.toIso8601String()}_${entry.kg}',
                            ),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppColors.error.withValues(alpha: 0.12),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                              ),
                            ),
                            confirmDismiss: (_) => _confirmDeleteWeightEntry(
                              sheetContext,
                              tracker,
                              entry,
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: SizedBox(
                                width: 42,
                                height: 42,
                                child: SvgPicture.asset(
                                  'assets/image/gym.svg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              title: Text(
                                '${entry.kg.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                intl.DateFormat(
                                  'EEE, MMM d, yyyy',
                                ).format(entry.date),
                              ),
                              trailing: IconButton(
                                tooltip: 'Delete entry',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _confirmDeleteWeightEntry(
                                  sheetContext,
                                  tracker,
                                  entry,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _RecentWeightRecordsCard extends StatelessWidget {
  const _RecentWeightRecordsCard({
    required this.entries,
  });

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final visibleEntries = entries.reversed.take(6).toList();

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Text(
              'Recent Records',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                if (visibleEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'No weight entries yet',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ...List.generate(visibleEntries.length, (index) {
                    final entry = visibleEntries[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == visibleEntries.length - 1 ? 0 : 10,
                      ),
                      child: _RecentWeightRecordTile(
                        entry: entry,
                        previousEntry: index + 1 < visibleEntries.length
                            ? visibleEntries[index + 1]
                            : null,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentWeightRecordTile extends StatelessWidget {
  const _RecentWeightRecordTile({
    required this.entry,
    required this.previousEntry,
  });

  final WeightEntry entry;
  final WeightEntry? previousEntry;

  @override
  Widget build(BuildContext context) {
    final change = previousEntry == null ? null : entry.kg - previousEntry!.kg;
    final showChange = change != null && change.abs() >= 0.05;
    final isGain = (change ?? 0) > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.kg.toStringAsFixed(2)}kg',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  intl.DateFormat('MMM d, yyyy').format(entry.date),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (showChange)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGain
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 18,
                    color: isGain ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${isGain ? '+' : '-'}${change.abs().toStringAsFixed(1)}kg',
                    style: TextStyle(
                      color: isGain ? AppColors.error : AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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

class _WeightPeriodToggle extends StatelessWidget {
  const _WeightPeriodToggle({
    required this.selected,
    required this.onChanged,
  });

  final WeightChartPeriod selected;
  final ValueChanged<WeightChartPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: WeightChartPeriod.values.map((period) {
          final isSelected = period == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(period),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    period.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WeightChartEmptyState extends StatelessWidget {
  const _WeightChartEmptyState({
    required this.hasAnyEntries,
    required this.suggestedPeriod,
    required this.onSwitchPeriod,
  });

  final bool hasAnyEntries;
  final WeightChartPeriod? suggestedPeriod;
  final VoidCallback? onSwitchPeriod;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 36,
              color: AppColors.textSecondary.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 10),
            Text(
              hasAnyEntries
                  ? 'No logs in this date range'
                  : 'No weight entries yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasAnyEntries
                  ? 'Try a wider range or log weight for today.'
                  : 'Log your first weight to start tracking progress.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (suggestedPeriod != null && onSwitchPeriod != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSwitchPeriod,
                child: Text('Switch to ${suggestedPeriod!.label}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDeleteWeightEntry(
  BuildContext context,
  TrackerController tracker,
  WeightEntry entry,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete weight entry?'),
      content: Text(
        'Remove ${entry.kg.toStringAsFixed(1)} kg logged on '
        '${intl.DateFormat('MMM d, yyyy').format(entry.date)}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            'Delete',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  final outcome = await tracker.deleteWeightEntry(entry);
  if (!context.mounted) return false;

  switch (outcome.status) {
    case WeightDeleteStatus.deleted:
      AppSnackbar.success('Weight entry deleted.');
      if (tracker.weightEntries.isEmpty) {
        Navigator.pop(context);
      }
      return true;
    case WeightDeleteStatus.failed:
      AppSnackbar.error(
        outcome.message ?? 'Weight entry could not be deleted.',
        title: 'Delete failed',
      );
      return false;
    case WeightDeleteStatus.missingId:
      AppSnackbar.error(
        outcome.message ?? 'This entry cannot be deleted.',
        title: 'Delete failed',
      );
      return false;
  }
}

class _WeightLineChartPainter extends CustomPainter {
  const _WeightLineChartPainter({required this.chartData});

  final WeightChartData chartData;

  @override
  void paint(Canvas canvas, Size size) {
    final points = chartData.points;
    if (points.isEmpty) return;

    const horizontalPadding = 4.0;
    const verticalPadding = 16.0;
    final chartWidth = size.width - horizontalPadding * 2;
    final chartHeight = size.height - verticalPadding * 2;
    final minValue = chartData.minY;
    final maxValue = chartData.maxY;
    final range = (maxValue - minValue).abs() < 0.1 ? 1.0 : maxValue - minValue;
    final baselineY = verticalPadding + chartHeight;

    final plottedPoints = <Offset>[];
    for (final point in points) {
      final x = horizontalPadding + chartWidth * point.xFraction;
      final normalized = (point.displayWeight - minValue) / range;
      final y = verticalPadding + chartHeight - normalized * chartHeight;
      plottedPoints.add(
        Offset(x, y.clamp(verticalPadding + 4, baselineY - 4)),
      );
    }

    if (plottedPoints.length == 1) {
      final point = plottedPoints.first;
      final flatPath = Path()
        ..moveTo(horizontalPadding, point.dy)
        ..lineTo(horizontalPadding + chartWidth, point.dy);
      _drawArea(canvas, flatPath, baselineY, plottedPoints);
      canvas.drawPath(
        flatPath,
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final linePath = _buildSmoothPath(plottedPoints);
    _drawArea(canvas, linePath, baselineY, plottedPoints);

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);
  }

  void _drawArea(
    Canvas canvas,
    Path linePath,
    double baselineY,
    List<Offset> points,
  ) {
    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, baselineY)
      ..lineTo(points.first.dx, baselineY)
      ..close();

    final bounds = areaPath.getBounds();
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.28),
          AppColors.primary.withValues(alpha: 0.04),
          AppColors.primary.withValues(alpha: 0),
        ],
        stops: const [0, 0.65, 1],
      ).createShader(bounds);
    canvas.drawPath(areaPath, areaPaint);
  }

  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _WeightLineChartPainter oldDelegate) {
    if (oldDelegate.chartData.period != chartData.period) return true;
    if (oldDelegate.chartData.useMetricUnits != chartData.useMetricUnits) {
      return true;
    }
    if (oldDelegate.chartData.usesFallbackWindow !=
        chartData.usesFallbackWindow) {
      return true;
    }

    final oldPoints = oldDelegate.chartData.points;
    final newPoints = chartData.points;
    if (oldPoints.length != newPoints.length) return true;

    for (var i = 0; i < oldPoints.length; i++) {
      if (oldPoints[i].date != newPoints[i].date ||
          oldPoints[i].kg != newPoints[i].kg) {
        return true;
      }
    }

    return oldDelegate.chartData.minY != chartData.minY ||
        oldDelegate.chartData.maxY != chartData.maxY;
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowColor,
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}
