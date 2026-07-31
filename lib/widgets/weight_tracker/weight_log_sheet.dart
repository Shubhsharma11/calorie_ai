import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../controllers/tracker_controller.dart';
import '../../core/app_snackbar.dart';
import '../../core/dashboard_actions.dart';
import '../../core/responsive.dart';
import '../../models/meal_entry.dart';
import '../../theme/app_colors.dart';

const double _logWeightMinKg = 30;
const double _logWeightMaxKg = 300;

class _WeightLogSheetResult {
  const _WeightLogSheetResult({
    required this.outcome,
  });

  final WeightLogOutcome outcome;
}

/// Opens the log-weight sheet — date picker + manual kg entry.
///
/// Records weight history only (weight API). Does not patch onboarding
/// or change the user's target weight.
Future<void> showWeightLogSheet(
  BuildContext context, {
  required double initialWeight,
  DateTime? date,
}) async {
  final result = await showModalBottomSheet<_WeightLogSheetResult>(
    context: context,
    useRootNavigator: false,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _ManualWeightLogSheet(
      initialWeight: initialWeight.clamp(_logWeightMinKg, _logWeightMaxKg),
      initialDate: MealEntry.normalizeDate(date ?? DateTime.now()),
    ),
  );

  if (result == null) return;
  await WidgetsBinding.instance.endOfFrame;
  _showWeightLogSnackbar(result);
}

class _ManualWeightLogSheet extends StatefulWidget {
  const _ManualWeightLogSheet({
    required this.initialWeight,
    required this.initialDate,
  });

  final double initialWeight;
  final DateTime initialDate;

  @override
  State<_ManualWeightLogSheet> createState() => _ManualWeightLogSheetState();
}

class _ManualWeightLogSheetState extends State<_ManualWeightLogSheet> {
  late final TextEditingController _weightController = TextEditingController(
    text: widget.initialWeight.toStringAsFixed(1),
  );
  late double _draftWeight = widget.initialWeight;
  late DateTime _logDate = widget.initialDate;
  var _manualWeightError = false;
  var _isSaving = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickLogDate() async {
    final picked = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: _logDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'Select log date',
    );
    if (picked == null || !mounted) return;

    final controller = Get.find<TrackerController>();
    final normalized = MealEntry.normalizeDate(picked);
    final resolved = await controller.resolveWeightForDate(
      normalized,
      _draftWeight,
    );
    if (!mounted) return;

    setState(() {
      _logDate = normalized;
      _draftWeight = resolved.clamp(_logWeightMinKg, _logWeightMaxKg);
      _manualWeightError = false;
      _weightController.text = _draftWeight.toStringAsFixed(1);
    });
  }

  Future<void> _saveWeight() async {
    if (_isSaving || _manualWeightError) return;

    final enteredWeight = double.tryParse(_weightController.text.trim());
    if (enteredWeight == null ||
        enteredWeight < _logWeightMinKg ||
        enteredWeight > _logWeightMaxKg) {
      setState(() => _manualWeightError = true);
      return;
    }

    setState(() => _isSaving = true);
    _draftWeight = enteredWeight;

    final controller = Get.find<TrackerController>();

    // History only — never PATCH onboarding / target weight from this flow.
    final outcome = await controller.logCurrentWeight(
      date: _logDate,
      weightKg: _draftWeight,
    );

    if (!mounted) return;
    Navigator.of(context).pop(_WeightLogSheetResult(outcome: outcome));
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    AppColors.syncFromContext(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Log Weight',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.scale(24),
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: r.scale(12)),
            Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: _isSaving ? null : _pickLogDate,
                  child: Text(
                    formatLogDateLabel(_logDate),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.scale(15),
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: _isSaving ? null : _pickLogDate,
                    tooltip: 'Select date',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    icon: SvgPicture.asset(
                      'assets/image/calendar.svg',
                      width: r.scale(26),
                      height: r.scale(26),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.scale(20)),
            Text(
              'Weight',
              style: TextStyle(
                fontSize: r.scale(13),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: r.scale(8)),
            
            TextField(
              controller: _weightController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,3}(\.\d{0,1})?$'),
                ),
              ],
              style: TextStyle(
                fontSize: r.scale(16),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter weight',
                hintStyle: TextStyle(
                  fontSize: r.scale(16),
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                suffixText: 'kg',
                suffixStyle: TextStyle(
                  fontSize: r.scale(15),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                errorText: _manualWeightError ? 'Enter 30–300 kg' : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: r.scale(14),
                  vertical: r.scale(16),
                ),
              ),
              onChanged: (text) {
                final parsed = double.tryParse(text);
                final isValid =
                    parsed != null &&
                    parsed >= _logWeightMinKg &&
                    parsed <= _logWeightMaxKg;
                setState(() {
                  _manualWeightError = !isValid;
                  if (isValid) _draftWeight = parsed;
                });
              },
              onSubmitted: (_) {
                if (!_isSaving) _saveWeight();
              },
              onTap: () => _weightController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _weightController.text.length,
              ),
            ),
            SizedBox(height: r.scale(20)),
            SizedBox(
              height: r.scale(52),
              child: FilledButton(
                onPressed: _manualWeightError || _isSaving ? null : _saveWeight,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(
                        'Save',
                        style: TextStyle(
                          fontSize: r.scale(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showWeightLogSnackbar(_WeightLogSheetResult result) {
  switch (result.outcome.status) {
    case WeightLogStatus.savedAndSynced:
      AppSnackbar.success('Weight saved.');
    case WeightLogStatus.failed:
      final message = Get.isRegistered<TrackerController>()
          ? Get.find<TrackerController>().weightApiErrorMessage.value
          : null;
      AppSnackbar.error(
        message ?? 'Weight could not be saved. Please try again.',
        title: 'Save failed',
      );
    case WeightLogStatus.unchanged:
      AppSnackbar.info(
        'Weight is already logged for this date.',
        title: 'Already logged',
      );
  }
}
