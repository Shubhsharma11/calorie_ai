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
          final period = controller.waterPeriod.value;
          final _ = controller.waterByDate.length;
          final chartHeight = _chartHeightFor(period, r);
          final goalGlasses = goalMl > 0
              ? (goalMl / TrackerController.mlPerGlass).round().clamp(1, 100)
              : 8;
          final overGlasses =
              glasses > goalGlasses ? glasses - goalGlasses : 0;
          final glassWord = glasses == 1 ? 'glass' : 'glasses';

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
                '$glasses',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                glassWord,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'of $goalGlasses glasses today · ${formatWaterMl(waterMl)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              if (overGlasses > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '+$overGlasses extra glass${overGlasses == 1 ? '' : 'es'}',
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
                      label: '+1 glass',
                      onTap: controller.addWater,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAddButton(
                      label: '+2 glasses',
                      onTap: () => controller.addWaterMl(
                        TrackerController.mlPerGlass * 2,
                      ),
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
              const SizedBox(height: 12),
              Center(
                child: FilledButton.tonal(
                  onPressed: waterMl > 0 ? controller.removeWater : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: const Color(0xFFFFE8E6),
                    foregroundColor: const Color(0xFFC45C54),
                    disabledBackgroundColor:
                        AppColors.surface.withValues(alpha: 0.7),
                    disabledForegroundColor:
                        AppColors.textSecondary.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_rounded, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Remove 1 glass',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
      useSafeArea: false,
      showDragHandle: true,
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
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _submit(int ml) {
    if (ml <= 0) return;
    // Pop first so the sheet doesn't drop onto the system bar while
    // the keyboard is still animating away.
    widget.onAdd(ml);
    if (mounted) Navigator.of(context).pop();
  }

  void _onDone(String value) {
    final ml = int.tryParse(value.trim()) ?? 0;
    if (ml > 0) {
      _submit(ml);
      return;
    }
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // Keep clear of home indicator / nav bar when the keyboard is closed.
    final bottomPad = keyboard > 0
        ? keyboard + 12
        : media.padding.bottom + 20;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add water',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Quick glasses or enter an exact amount in ml.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final glasses in const [1, 2, 3, 4])
                ActionChip(
                  label: Text(
                    glasses == 1 ? '+1 glass' : '+$glasses glasses',
                  ),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: AppColors.border),
                  onPressed: () =>
                      _submit(glasses * TrackerController.mlPerGlass),
                ),
              ..._CustomWaterAmountSheet._presets.map(
                (ml) => ActionChip(
                  label: Text('$ml ml'),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: AppColors.border),
                  onPressed: () => _submit(ml),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                    signed: false,
                  ),
                  textInputAction: TextInputAction.done,
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
                  onSubmitted: _onDone,
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
