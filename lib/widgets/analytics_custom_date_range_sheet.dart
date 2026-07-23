import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/analytics_controller.dart';
import '../theme/app_colors.dart';

/// Opens the Analytics custom date-range sheet.
/// Returns `true` when the user applies a range.
Future<bool> showAnalyticsCustomDateRangeSheet(BuildContext context) async {
  final controller = Get.find<AnalyticsController>();
  final applied = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AnalyticsCustomDateRangeSheet(
      initialStart: controller.customStartDate.value,
      initialEnd: controller.customEndDate.value,
    ),
  );
  return applied == true;
}

class _AnalyticsCustomDateRangeSheet extends StatefulWidget {
  const _AnalyticsCustomDateRangeSheet({
    required this.initialStart,
    required this.initialEnd,
  });

  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_AnalyticsCustomDateRangeSheet> createState() =>
      _AnalyticsCustomDateRangeSheetState();
}

class _AnalyticsCustomDateRangeSheetState
    extends State<_AnalyticsCustomDateRangeSheet> {
  late DateTime _start;
  late DateTime _end;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _earliest => _today.subtract(const Duration(days: 365 * 2));

  @override
  void initState() {
    super.initState();
    _start = DateTime(
      widget.initialStart.year,
      widget.initialStart.month,
      widget.initialStart.day,
    );
    _end = DateTime(
      widget.initialEnd.year,
      widget.initialEnd.month,
      widget.initialEnd.day,
    );
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start.isAfter(_end) ? _end : _start,
      firstDate: _earliest,
      lastDate: _end.isAfter(_today) ? _today : _end,
      helpText: 'Start date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(picked.year, picked.month, picked.day);
      if (_end.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start.isBefore(_earliest) ? _earliest : _start,
      lastDate: _today,
      helpText: 'End date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _end = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _reset() {
    setState(() {
      _start = _today.subtract(const Duration(days: 29));
      _end = _today;
    });
  }

  void _apply() {
    Get.find<AnalyticsController>().applyCustomRange(_start, _end);
    Navigator.of(context).pop(true);
  }

  String _format(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Custom date range',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              'Choose any start and end date to view your nutrition chart.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _DateRow(
              label: 'Start date',
              value: _format(_start),
              onTap: _pickStart,
            ),
            const SizedBox(height: 12),
            _DateRow(
              label: 'End date',
              value: _format(_end),
              onTap: _pickEnd,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: AppColors.iconAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
