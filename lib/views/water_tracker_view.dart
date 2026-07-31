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

  /// Soft water accent — secondary to brand green, not loud system blue.
  static const _waterAccent = Color(0xFF4AA3DF);

  double _chartHeightFor(WaterPeriod period, Responsive r) => switch (period) {
        WaterPeriod.month => r.scale(130, tablet: 150, desktop: 170),
        WaterPeriod.week => r.scale(150, tablet: 170, desktop: 190),
        WaterPeriod.today || WaterPeriod.yesterday =>
          r.scale(140, tablet: 160, desktop: 180),
      };

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      );

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
          final _ = controller.waterRevision.value;
          final chartHeight = _chartHeightFor(period, r);
          final goalGlasses = goalMl > 0
              ? (goalMl / TrackerController.mlPerGlass).round().clamp(1, 100)
              : 8;
          final overGlasses =
              glasses > goalGlasses ? glasses - goalGlasses : 0;
          final glassWord = glasses == 1 ? 'glass' : 'glasses';
          final progressColor = controller.isWaterGoalComplete
              ? AppColors.primary
              : _waterAccent;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Track your daily water intake easily.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: r.scale(14),
                  height: 1.4,
                ),
              ),
              SizedBox(height: r.scale(18)),
              Container(
                decoration: _cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        r.scale(16),
                        r.scale(20),
                        r.scale(16),
                        r.scale(18),
                      ),
                      color: AppColors.isDark(context)
                          ? AppColors.surface
                          : const Color(0xFFF7FBF8),
                      child: Column(
                        children: [
                          Text(
                            '$glasses',
                            style: TextStyle(
                              fontSize: r.scale(40),
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: r.scale(4)),
                          Text(
                            glassWord,
                            style: TextStyle(
                              fontSize: r.scale(15),
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          SizedBox(height: r.scale(6)),
                          Text(
                            'of $goalGlasses glasses today · ${formatWaterMl(waterMl)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: r.scale(13),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (overGlasses > 0) ...[
                            SizedBox(height: r.scale(6)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.scale(10),
                                vertical: r.scale(4),
                              ),
                              decoration: BoxDecoration(
                                color: _waterAccent.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(r.scale(999)),
                              ),
                              child: Text(
                                '+$overGlasses extra glass${overGlasses == 1 ? '' : 'es'}',
                                style: TextStyle(
                                  color: _waterAccent,
                                  fontSize: r.scale(12),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: r.scale(16)),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(r.scale(999)),
                            child: LinearProgressIndicator(
                              value: controller.waterProgress,
                              minHeight: r.scale(10),
                              backgroundColor: AppColors.isDark(context)
                                  ? AppColors.border
                                  : Colors.white.withValues(alpha: 0.9),
                              color: progressColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        r.scale(12),
                        r.scale(12),
                        r.scale(12),
                        r.scale(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _QuickAddButton(
                                  label: '+1 glass',
                                  onTap: controller.addWater,
                                ),
                              ),
                              SizedBox(width: r.scale(8)),
                              Expanded(
                                child: _QuickAddButton(
                                  label: '+2 glasses',
                                  onTap: () => controller.addWaterMl(
                                    TrackerController.mlPerGlass * 2,
                                  ),
                                ),
                              ),
                              SizedBox(width: r.scale(8)),
                              Expanded(
                                child: _QuickAddButton(
                                  label: 'Custom',
                                  icon: Icons.tune_rounded,
                                  onTap: () =>
                                      _showCustomAmountSheet(context),
                                ),
                              ),
                            ],
                          ),
                          if (waterMl > 0) ...[
                            SizedBox(height: r.scale(8)),
                            _RemoveGlassButton(
                              onTap: controller.removeWater,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.scale(16)),
              Container(
                decoration: _cardDecoration(),
                clipBehavior: Clip.antiAlias,
                padding: EdgeInsets.fromLTRB(
                  r.scale(14),
                  r.scale(14),
                  r.scale(14),
                  r.scale(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Hydration History',
                      style: TextStyle(
                        fontSize: r.scale(16),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.scale(12)),
                    PeriodSelector(
                      values: WaterPeriod.values,
                      selected: period,
                      labelFor: controller.periodLabelFor,
                      onChanged: controller.setWaterPeriod,
                      fontSize: r.scale(11),
                    ),
                    SizedBox(height: r.scale(14)),
                    WaterProgressChart(
                      days: controller.activeWaterDays,
                      waterGoalMl: goalMl,
                      chartHeight: chartHeight,
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.scale(20)),
              Text(
                '1 glass = ${TrackerController.mlPerGlass} ml',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.scale(12),
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
    final bottomPad =
        keyboard > 0 ? keyboard + 12 : media.padding.bottom + 20;
    final r = context.responsive;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add water',
            style: TextStyle(
              fontSize: r.scale(18),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            'Quick glasses or enter an exact amount in ml.',
            style: TextStyle(
              fontSize: r.scale(13),
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: r.scale(16)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final glasses in const [1, 2, 3, 4])
                ActionChip(
                  label: Text(
                    glasses == 1 ? '+1 glass' : '+$glasses glasses',
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.18),
                  ),
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
          SizedBox(height: r.scale(16)),
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RemoveGlassButton extends StatelessWidget {
  const _RemoveGlassButton({required this.onTap});

  final VoidCallback onTap;

  static const _softRemove = Color(0xFFD97878);
  static const _softRemoveFill = Color(0xFFFFF5F5);
  static const _softRemoveBorder = Color(0xFFE8B4B4);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = BorderRadius.circular(r.scale(12));

    return Material(
      color: _softRemoveFill,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(18),
            vertical: r.scale(12),
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: _softRemoveBorder),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.remove_rounded,
                size: r.scale(16),
                color: _softRemove,
              ),
              SizedBox(width: r.scale(6)),
              Text(
                'Remove 1 glass',
                style: TextStyle(
                  fontSize: r.scale(12),
                  fontWeight: FontWeight.w700,
                  color: _softRemove,
                ),
              ),
            ],
          ),
        ),
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
    final r = context.responsive;

    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(r.scale(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.scale(12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.scale(12)),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: r.scale(15),
                      color: AppColors.primaryDark,
                    ),
                    SizedBox(width: r.scale(4)),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.scale(12),
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.scale(12),
                    color: AppColors.primaryDark,
                  ),
                ),
        ),
      ),
    );
  }
}
