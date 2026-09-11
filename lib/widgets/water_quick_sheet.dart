import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/tracker_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'onboarding_step_scaffold.dart';

enum _WaterSheetTab { add, settings }

Future<void> showWaterQuickSheet(
  BuildContext context, {
  DateTime? date,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) => _WaterQuickSheet(date: date),
  );
}

class _WaterQuickSheet extends StatefulWidget {
  const _WaterQuickSheet({this.date});

  final DateTime? date;

  @override
  State<_WaterQuickSheet> createState() => _WaterQuickSheetState();
}

class _WaterQuickSheetState extends State<_WaterQuickSheet> {
  _WaterSheetTab _tab = _WaterSheetTab.add;
  late final TextEditingController _customGlassCtrl;

  TrackerController get _tracker => Get.find<TrackerController>();
  SettingsController get _settings => Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    _customGlassCtrl = TextEditingController(
      text: _settings.displayFromMl(_settings.effectiveGlassMl).round().toString(),
    );
  }

  @override
  void dispose() {
    _customGlassCtrl.dispose();
    super.dispose();
  }

  DateTime get _logDate => widget.date ?? DateTime.now();

  void _addMl(int ml) {
    if (ml <= 0) return;
    HapticFeedback.lightImpact();
    _tracker.addWaterMl(ml, date: _logDate);
    Navigator.of(context).maybePop();
  }

  Future<void> _setGlassFromField() async {
    final raw = double.tryParse(_customGlassCtrl.text.trim());
    if (raw == null || raw <= 0) return;
    final ml = _settings.mlFromDisplay(raw).clamp(50, 1000);
    await _settings.setWaterGlassMl(ml);
    if (!mounted) return;
    setState(() {
      _customGlassCtrl.text =
          _settings.displayFromMl(ml).round().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    const waterBlue = Color(0xFF4AA3DF);

    return AppSheetScaffold(
      child: Obx(() {
        final waterMl = _tracker.waterForDate(_logDate);
        final glassMl = _settings.effectiveGlassMl;
        final goalMl = _settings.waterGoalMl.value;
        final glasses = (waterMl / glassMl).floor();
        final goalGlasses =
            goalMl > 0 ? (goalMl / glassMl).round().clamp(1, 100) : 8;
        final useMl = _settings.waterUseMl.value;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Water',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.scale(20, tablet: 22),
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              SizedBox(height: r.scale(14)),
              _SheetTabs(
                addSelected: _tab == _WaterSheetTab.add,
                onAdd: () => setState(() => _tab = _WaterSheetTab.add),
                onSettings: () =>
                    setState(() => _tab = _WaterSheetTab.settings),
              ),
              SizedBox(height: r.scale(18)),
              if (_tab == _WaterSheetTab.add)
                _AddWaterPane(
                  waterMl: waterMl,
                  glasses: glasses,
                  goalGlasses: goalGlasses,
                  glassMl: glassMl,
                  color: waterBlue,
                  formatAmount: _settings.formatWaterAmount,
                  onAddGlass: () => _addMl(glassMl),
                  onAddMl: _addMl,
                )
              else
                _WaterSettingsPane(
                  useMl: useMl,
                  glassMl: glassMl,
                  customCtrl: _customGlassCtrl,
                  formatAmount: _settings.formatWaterAmount,
                  unitLabel: _settings.waterUnitLabel,
                  onUnitChanged: (useMlValue) async {
                    await _settings.setWaterUseMl(useMlValue);
                    if (!mounted) return;
                    setState(() {
                      _customGlassCtrl.text = _settings
                          .displayFromMl(_settings.effectiveGlassMl)
                          .round()
                          .toString();
                    });
                  },
                  onSelectGlass: (ml) async {
                    await _settings.setWaterGlassMl(ml);
                    if (!mounted) return;
                    setState(() {
                      _customGlassCtrl.text =
                          _settings.displayFromMl(ml).round().toString();
                    });
                  },
                  onSaveCustom: _setGlassFromField,
                ),
              SizedBox(height: r.scale(8)),
            ],
          ),
        );
      }),
    );
  }
}

class _SheetTabs extends StatelessWidget {
  const _SheetTabs({
    required this.addSelected,
    required this.onAdd,
    required this.onSettings,
  });

  final bool addSelected;
  final VoidCallback onAdd;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              context,
              label: 'Add water',
              selected: addSelected,
              onTap: onAdd,
              r: r,
            ),
          ),
          Expanded(
            child: _tabButton(
              context,
              label: 'Settings',
              selected: !addSelected,
              onTap: onSettings,
              r: r,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Responsive r,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(vertical: r.scale(12)),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.4,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.scale(14, tablet: 15),
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.primary
                  : AppColors.textPrimaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddWaterPane extends StatelessWidget {
  const _AddWaterPane({
    required this.waterMl,
    required this.glasses,
    required this.goalGlasses,
    required this.glassMl,
    required this.color,
    required this.formatAmount,
    required this.onAddGlass,
    required this.onAddMl,
  });

  final int waterMl;
  final int glasses;
  final int goalGlasses;
  final int glassMl;
  final Color color;
  final String Function(int ml) formatAmount;
  final VoidCallback onAddGlass;
  final ValueChanged<int> onAddMl;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final quickAmounts = <int>{
      (glassMl * 0.5).round().clamp(50, 1000),
      glassMl,
      (glassMl * 2).clamp(50, 1000),
      500,
    }.toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(r.scale(14)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.water_drop_rounded, color: color, size: r.scale(28)),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$glasses / $goalGlasses glasses',
                      style: TextStyle(
                        fontSize: r.scale(16, tablet: 17),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      formatAmount(waterMl),
                      style: TextStyle(
                        fontSize: r.scale(13, tablet: 14),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.scale(16)),
        SizedBox(
          height: r.scale(54),
          child: FilledButton.icon(
            onPressed: onAddGlass,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'Add 1 glass (${formatAmount(glassMl)})',
              style: TextStyle(
                fontSize: r.scale(15, tablet: 16),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(height: r.scale(14)),
        Text(
          'Quick add',
          style: TextStyle(
            fontSize: r.scale(13, tablet: 14),
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        SizedBox(height: r.scale(10)),
        Wrap(
          spacing: r.scale(10),
          runSpacing: r.scale(10),
          children: [
            for (final ml in quickAmounts)
              _QuickChip(
                label: '+ ${formatAmount(ml)}',
                onTap: () => onAddMl(ml),
              ),
          ],
        ),
      ],
    );
  }
}

class _WaterSettingsPane extends StatelessWidget {
  const _WaterSettingsPane({
    required this.useMl,
    required this.glassMl,
    required this.customCtrl,
    required this.formatAmount,
    required this.unitLabel,
    required this.onUnitChanged,
    required this.onSelectGlass,
    required this.onSaveCustom,
  });

  final bool useMl;
  final int glassMl;
  final TextEditingController customCtrl;
  final String Function(int ml) formatAmount;
  final String unitLabel;
  final ValueChanged<bool> onUnitChanged;
  final ValueChanged<int> onSelectGlass;
  final VoidCallback onSaveCustom;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Unit',
          style: TextStyle(
            fontSize: r.scale(13, tablet: 14),
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        SizedBox(height: r.scale(10)),
        OnboardingUnitToggle(
          left: 'ml',
          right: 'oz',
          leftSelected: useMl,
          onLeft: () => onUnitChanged(true),
          onRight: () => onUnitChanged(false),
        ),
        SizedBox(height: r.scale(20)),
        Text(
          'Glass size',
          style: TextStyle(
            fontSize: r.scale(13, tablet: 14),
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        SizedBox(height: r.scale(4)),
        Text(
          'Used when you add or remove one glass',
          style: TextStyle(
            fontSize: r.scale(12, tablet: 13),
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        SizedBox(height: r.scale(12)),
        Wrap(
          spacing: r.scale(10),
          runSpacing: r.scale(10),
          children: [
            for (final ml in SettingsController.waterGlassMlOptions)
              _QuickChip(
                label: formatAmount(ml),
                selected: glassMl == ml,
                onTap: () => onSelectGlass(ml),
              ),
          ],
        ),
        SizedBox(height: r.scale(16)),
        Text(
          'Custom glass ($unitLabel)',
          style: TextStyle(
            fontSize: r.scale(13, tablet: 14),
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        SizedBox(height: r.scale(10)),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardOf(context),
                  hintText: useMl ? 'e.g. 300' : 'e.g. 10',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: r.scale(14),
                    vertical: r.scale(14),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.borderOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.borderOf(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: r.scale(10)),
            SizedBox(
              height: r.scale(52),
              child: FilledButton(
                onPressed: onSaveCustom,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final mint = AppColors.primary.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(14),
            vertical: r.scale(10),
          ),
          decoration: BoxDecoration(
            color: selected ? mint : AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderOf(context),
              width: selected ? 1.6 : 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.scale(13, tablet: 14),
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.primary
                  : AppColors.textPrimaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}
