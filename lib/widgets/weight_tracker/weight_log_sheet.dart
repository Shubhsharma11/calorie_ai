import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../controllers/tracker_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/app_snackbar.dart';
import '../../core/responsive.dart';
import '../../models/meal_entry.dart';
import '../../theme/app_colors.dart';
import '../weight_ruler_slider.dart';

const double _logWeightMinKg = 40;
const double _logWeightMaxKg = 150;

Future<void> showWeightLogSheet(
  BuildContext context, {
  required double initialWeight,
  DateTime? date,
}) {
  var draftWeight = initialWeight.clamp(_logWeightMinKg, _logWeightMaxKg);
  var logDate = MealEntry.normalizeDate(date ?? DateTime.now());

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final r = context.responsive;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          void setWeight(double value) {
            setSheetState(
              () => draftWeight = value.clamp(_logWeightMinKg, _logWeightMaxKg),
            );
          }

          Future<void> pickLogDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: logDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
              helpText: 'Select log date',
            );
            if (picked == null || !context.mounted) return;

            final controller = Get.find<TrackerController>();
            final normalized = MealEntry.normalizeDate(picked);
            final resolved = await controller.resolveWeightForDate(
              normalized,
              draftWeight,
            );
            if (!context.mounted) return;

            setSheetState(() {
              logDate = normalized;
              draftWeight = resolved;
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + r.scale(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Log New Weight',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: r.scale(18)),
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: pickLogDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              intl.DateFormat('EEE, MMM d, yyyy').format(logDate),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: r.scale(16)),
                  Row(
                    children: [
                      _CircleStepButton(
                        icon: Icons.remove,
                        onPressed: draftWeight > _logWeightMinKg
                            ? () => setWeight(draftWeight - 0.5)
                            : null,
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              draftWeight.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: r.scale(44, tablet: 48),
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'kg',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CircleStepButton(
                        icon: Icons.add,
                        onPressed: draftWeight < _logWeightMaxKg
                            ? () => setWeight(draftWeight + 0.5)
                            : null,
                      ),
                    ],
                  ),
                  SizedBox(height: r.scale(20)),
                  WeightRulerSlider(
                    value: draftWeight,
                    min: _logWeightMinKg,
                    max: _logWeightMaxKg,
                    onChanged: setWeight,
                  ),
                  SizedBox(height: r.scale(20)),
                  ElevatedButton(
                    onPressed: () async {
                      final controller = Get.find<TrackerController>();
                      final userController = Get.find<UserController>();
                      final baseline =
                          userController.captureProfileSyncSnapshot();

                      final outcome = await controller.logCurrentWeight(
                        date: logDate,
                        weightKg: draftWeight,
                      );

                      final today = MealEntry.normalizeDate(DateTime.now());
                      final isToday = logDate == today;
                      String? profileSyncError;
                      if (isToday &&
                          outcome.status == WeightLogStatus.savedAndSynced &&
                          !outcome.profileUpdated) {
                        profileSyncError = await userController
                            .patchPersonalDetailsIfChanged(baseline);
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      switch (outcome.status) {
                        case WeightLogStatus.savedAndSynced:
                          if (profileSyncError != null) {
                            AppSnackbar.info(
                              'Weight saved, but profile sync needs another try.',
                              title: 'Weight saved',
                            );
                          } else {
                            AppSnackbar.success('Weight saved.');
                          }
                        case WeightLogStatus.failed:
                          AppSnackbar.error(
                            controller.weightApiErrorMessage.value ??
                                'Weight could not be saved. Please try again.',
                            title: 'Save failed',
                          );
                        case WeightLogStatus.unchanged:
                          AppSnackbar.info(
                            'Weight is already logged for this date.',
                            title: 'Already logged',
                          );
                      }
                    },
                    child: const Text('Save Weight'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _CircleStepButton extends StatelessWidget {
  const _CircleStepButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: onPressed == null
                ? AppColors.textSecondary.withValues(alpha: 0.4)
                : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
