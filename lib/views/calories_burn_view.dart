import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_type.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class CaloriesBurnView extends GetView<TrackerController> {
  const CaloriesBurnView({super.key});

  static const _burnOrange = Color(0xFFFF9500);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppBar(title: const Text('Calories Burn')),
      body: ResponsivePage(
        scrollable: true,
        child: Obx(() {
          final burned = controller.todayCaloriesBurned;
          final steps = controller.todaySteps;
          final stepsCalories = controller.stepsCalories;
          final exercises = controller.todayExercises;
          final exerciseCalories = exercises.fold(
            0,
            (sum, e) => sum + e.calories,
          );
          final exerciseMinutes = controller.todayExerciseMinutes;
          final stepsProgress = controller.stepsProgress;
          final isAutoTracking = controller.isStepTrackingActive.value;
          final trackingMessage = controller.stepTrackingMessage.value;
          final needsHealthConnectInstall =
              controller.needsHealthConnectInstall.value;
          final _ = controller.activityRevision.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Track steps via Health Connect and log exercise to see calories burned.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$burned',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.scale(48, tablet: 52),
                  fontWeight: FontWeight.bold,
                  color: _burnOrange,
                ),
              ),
              Text(
                'kcal burned today',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'From steps',
                      value: '$stepsCalories kcal',
                      subtitle: '$steps steps',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      label: 'From exercise',
                      value: '$exerciseCalories kcal',
                      subtitle: '$exerciseMinutes min',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Steps',
                style: TextStyle(
                  fontSize: r.scale(18),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAutoTracking
                    ? 'Auto-detected from your device'
                    : 'Enable motion access below to count steps',
                style: TextStyle(
                  fontSize: r.scale(13),
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$steps / ${TrackerController.stepsGoal}',
                style: TextStyle(
                  fontSize: r.scale(15),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: stepsProgress,
                  minHeight: 12,
                  backgroundColor: AppColors.surface,
                  color: controller.isStepsGoalComplete
                      ? AppColors.primary
                      : const Color(0xFF007AFF),
                ),
              ),
              const SizedBox(height: 12),
              _StepTrackingStatus(
                isActive: isAutoTracking,
                message: trackingMessage,
                onEnable: controller.syncActivity,
                onInstallHealthConnect: needsHealthConnectInstall
                    ? controller.installHealthConnect
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Exercise',
                    style: TextStyle(
                      fontSize: r.scale(18),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showAddExerciseSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (exercises.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No workouts logged today.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                )
              else
                ...exercises.map(
                  (entry) => _ExerciseRow(
                    entry: entry,
                    onRemove: () => controller.removeExercise(entry.id),
                  ),
                ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Log Exercise',
                onPressed: () => _showAddExerciseSheet(context),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          );
        }),
      ),
    );
  }

  void _showAddExerciseSheet(
    BuildContext context, {
    ExerciseType initialType = ExerciseType.gymModerate,
  }) {
    var selected = initialType;
    var duration = 30;
    var intensity = ExerciseIntensity.normal;

    final weightKg = Get.isRegistered<UserController>()
        ? Get.find<UserController>().user.weightKg.toDouble()
        : 70.0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bottom = MediaQuery.paddingOf(context).bottom;
            final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
            final estimated = ExerciseType.estimateCalories(
              type: selected,
              weightKg: weightKg,
              durationMinutes: duration,
              intensity: intensity,
            );

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
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
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Log Exercise',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick activity type — gym workouts use different burn rates.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final category in ExerciseCategory.values) ...[
                              Text(
                                category.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...ExerciseType.forCategory(category).map((type) {
                                final isSelected = selected == type;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                    ),
                                    tileColor: isSelected
                                        ? AppColors.selectionFill
                                        : AppColors.surface,
                                    leading: Icon(
                                      type.icon,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    title: Text(
                                      type.label,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'MET ${type.met.toStringAsFixed(1)} · ${type.intensityHint}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: isSelected
                                        ? Icon(
                                            Icons.check_circle,
                                            color: AppColors.primary,
                                          )
                                        : null,
                                    onTap: () =>
                                        setState(() => selected = type),
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              'EFFORT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<ExerciseIntensity>(
                              segments: ExerciseIntensity.values
                                  .map(
                                    (level) => ButtonSegment(
                                      value: level,
                                      label: Text(level.label),
                                    ),
                                  )
                                  .toList(),
                              selected: {intensity},
                              onSelectionChanged: (values) => setState(
                                () => intensity = values.first,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text(
                                  'Duration',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                Text(
                                  '$duration min',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: duration.toDouble(),
                              min: 5,
                              max: 120,
                              divisions: 23,
                              activeColor: AppColors.primary,
                              onChanged: (v) =>
                                  setState(() => duration = v.round()),
                            ),
                            Text(
                              'Estimated burn: $estimated kcal',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Save',
                      onPressed: () async {
                        await controller.addExercise(
                          type: selected,
                          durationMinutes: duration,
                          intensity: intensity,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
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
}

class _StepTrackingStatus extends StatelessWidget {
  const _StepTrackingStatus({
    required this.isActive,
    required this.message,
    required this.onEnable,
    this.onInstallHealthConnect,
  });

  final bool isActive;
  final String? message;
  final VoidCallback onEnable;
  final VoidCallback? onInstallHealthConnect;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    final icon = isActive ? Icons.favorite_rounded : Icons.favorite_border_rounded;
    final text = message ??
        (isActive
            ? 'Steps sync from Health Connect.'
            : 'Connect Health Connect to track steps automatically.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          if (!isActive)
            TextButton(
              onPressed: onInstallHealthConnect ?? onEnable,
              child: Text(onInstallHealthConnect != null ? 'Install' : 'Connect'),
            ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.entry, required this.onRemove});

  final ExerciseEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final type =
        ExerciseType.fromId(entry.typeId) ?? ExerciseType.fromLabel(entry.name);
    final effort = entry.intensityLabel;
    final subtitle = [
      '${entry.durationMinutes} min',
      if (effort != null) '$effort effort',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            type?.icon ?? Icons.fitness_center_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.calories} kcal',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: CaloriesBurnView._burnOrange,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
