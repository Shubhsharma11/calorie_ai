import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/tracker_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/responsive.dart';
import '../models/daily_water_intake.dart';
import '../models/water_period.dart';
import '../theme/app_colors.dart';
import '../widgets/period_selector.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';
import '../widgets/water_progress_chart.dart';

class WaterTrackerView extends GetView<TrackerController> {
  const WaterTrackerView({super.key});

  static const _waterBlue = Color(0xFF007AFF);

  double _chartHeightFor(WaterPeriod period, Responsive r) => switch (period) {
        WaterPeriod.month => r.scale(130, tablet: 150, desktop: 170),
        WaterPeriod.week => r.scale(150, tablet: 170, desktop: 190),
        WaterPeriod.today || WaterPeriod.yesterday =>
          r.scale(140, tablet: 160, desktop: 180),
      };

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: const AppAppBar(title: 'Water Tracker'),
      body: ResponsivePage(
        scrollable: true,
        child: Obx(() {
          if (Get.isRegistered<SettingsController>()) {
            Get.find<SettingsController>().waterGoalMl.value;
          }
          final waterMl = controller.waterMl;
          final goalMl = TrackerController.waterGoalMl;
          final glasses = controller.waterGlasses;
          final overMl = controller.waterMlOverGoal;
          final period = controller.waterPeriod.value;
          final _ = controller.waterByDate.length;
          final chartHeight = _chartHeightFor(period, r);
          final goalGlasses = goalMl ~/ TrackerController.mlPerGlass;
          final filledGlasses = waterMl ~/ TrackerController.mlPerGlass;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Track your daily water intake easily.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$waterMl ml',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'of ${formatWaterMl(goalMl)} today · ≈ $glasses glass${glasses == 1 ? '' : 'es'}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              if (overMl > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '+$overMl ml over daily goal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _waterBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: controller.waterProgress,
                  minHeight: 14,
                  backgroundColor: AppColors.surface,
                  color: controller.isWaterGoalComplete
                      ? AppColors.primary
                      : _waterBlue,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _QuickAddButton(
                      label: '+250 ml',
                      onTap: () => controller.addWaterMl(250),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAddButton(
                      label: '+500 ml',
                      onTap: () => controller.addWaterMl(500),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAddButton(
                      label: 'Custom',
                      icon: Icons.tune_rounded,
                      onTap: () => _showCustomAmountSheet(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed:
                    waterMl > 0 ? () => controller.removeWaterMl(250) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: const Text('Remove 250 ml'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hydration History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              PeriodSelector(
                values: WaterPeriod.values,
                selected: period,
                labelFor: controller.periodLabelFor,
                onChanged: controller.setWaterPeriod,
                fontSize: 11,
              ),
              const SizedBox(height: 16),
              WaterProgressChart(
                days: controller.activeWaterDays,
                waterGoalMl: goalMl,
                chartHeight: chartHeight,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ...List.generate(goalGlasses, (i) {
                    final filled = i < filledGlasses;
                    return Icon(
                      filled ? Icons.local_drink : Icons.local_drink_outlined,
                      size: 40,
                      color: filled
                          ? (controller.isWaterGoalComplete
                              ? AppColors.primary
                              : _waterBlue)
                          : AppColors.border,
                    );
                  }),
                  ...List.generate(
                    (filledGlasses - goalGlasses).clamp(0, 24),
                    (_) => const Icon(
                      Icons.local_drink,
                      size: 40,
                      color: _waterBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1 glass = ${TrackerController.mlPerGlass} ml',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          );
        }),
      ),
    );
  }

  void _showCustomAmountSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _CustomWaterAmountSheet(
        onAdd: (ml) => controller.addWaterMl(ml),
      ),
    );
  }
}

class _CustomWaterAmountSheet extends StatefulWidget {
  const _CustomWaterAmountSheet({required this.onAdd});

  final ValueChanged<int> onAdd;

  static const _presets = [100, 150, 200, 300, 330, 500, 750, 1000];

  @override
  State<_CustomWaterAmountSheet> createState() =>
      _CustomWaterAmountSheetState();
}

class _CustomWaterAmountSheetState extends State<_CustomWaterAmountSheet> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit(int ml) {
    if (ml <= 0) return;
    FocusScope.of(context).unfocus();
    widget.onAdd(ml);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add custom amount',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _CustomWaterAmountSheet._presets
                .map(
                  (ml) => ActionChip(
                    label: Text('$ml ml'),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: AppColors.border),
                    onPressed: () => _submit(ml),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Amount in ml',
                    suffixText: 'ml',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (value) {
                    final ml = int.tryParse(value.trim()) ?? 0;
                    _submit(ml);
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  final ml = int.tryParse(_textController.text.trim()) ?? 0;
                  _submit(ml);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: WaterTrackerView._waterBlue.withValues(alpha: 0.12),
        foregroundColor: WaterTrackerView._waterBlue,
      ),
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            )
          : Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
    );
  }
}
