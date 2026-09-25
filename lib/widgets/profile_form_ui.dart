import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'primary_button.dart';

/// Section header used by profile edit form screens (Personal Information style).
class ProfileFormSectionLabel extends StatelessWidget {
  const ProfileFormSectionLabel({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        Container(
          width: 3,
          height: r.scale(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: r.scale(8)),
        Text(
          title,
          style: TextStyle(
            fontSize: r.scale(12, tablet: 13),
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryOf(context),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// Tappable label + value chip row used by profile edit form screens.
class ProfileFormInfoRow extends StatelessWidget {
  const ProfileFormInfoRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.wideValue = false,
  });

  final String label;
  final String subtitle;
  final String value;
  final bool wideValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.scale(16),
                  r.scale(14),
                  r.scale(wideValue ? 156 : 116),
                  r.scale(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.scale(15, tablet: 16),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: r.scale(12, tablet: 13),
                        color: AppColors.textSecondaryOf(context),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: r.scale(12),
                top: r.scale(12),
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: r.scale(wideValue ? 108 : 84),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.scale(wideValue ? 12 : 14),
                    vertical: r.scale(9),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: r.scale(wideValue ? 124 : 80),
                        ),
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: r.scale(13, tablet: 14),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryOf(
                              context,
                            ).withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                      SizedBox(width: r.scale(4)),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: r.scale(18),
                        color: AppColors.textSecondaryOf(
                          context,
                        ).withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileFormOption {
  const ProfileFormOption({
    required this.value,
    required this.label,
    this.emoji,
  });

  final String value;
  final String label;
  final String? emoji;
}

/// Multi-select sheet with Done — returns the selected values (or null if cancelled).
Future<List<String>?> showProfileMultiSelectSheet({
  required BuildContext context,
  required String title,
  required List<ProfileFormOption> options,
  required Set<String> initiallySelected,
  String? exclusiveValue,
  List<String> exclusiveValues = const [],
}) {
  final exclusive = <String>{
    ?exclusiveValue,
    ...exclusiveValues,
  };

  return showAppBottomSheet<List<String>>(
    context: context,
    builder: (sheetContext) {
      final selected = Set<String>.from(initiallySelected);
      final r = sheetContext.responsive;

      return StatefulBuilder(
        builder: (context, setModalState) {
          void toggle(String value) {
            HapticFeedback.selectionClick();
            setModalState(() {
              if (exclusive.contains(value)) {
                selected
                  ..clear()
                  ..add(value);
                return;
              }
              selected.removeAll(exclusive);
              if (!selected.remove(value)) selected.add(value);
            });
          }

          return AppSheetScaffold(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: r.scale(18),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(8)),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.border.withValues(alpha: 0.7),
                    ),
                    itemBuilder: (_, index) {
                      final option = options[index];
                      final isSelected = selected.contains(option.value);
                      return ListTile(
                        onTap: () => toggle(option.value),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: r.scale(4),
                        ),
                        leading: option.emoji == null
                            ? null
                            : Text(
                                option.emoji!,
                                style: TextStyle(fontSize: r.scale(20)),
                              ),
                        title: Text(
                          option.label,
                          style: TextStyle(
                            fontSize: r.scale(15),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary.withValues(alpha: 0.45),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: r.scale(12)),
                PrimaryButton(
                  label: 'Done',
                  onPressed: () {
                    Navigator.pop(
                      sheetContext,
                      selected.toList()..sort(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Sticky save footer used by profile form screens.
class ProfileFormSaveBar extends StatelessWidget {
  const ProfileFormSaveBar({
    super.key,
    required this.isLoading,
    required this.onSave,
  });

  final bool isLoading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.45)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        r.scale(20, tablet: 28),
        r.scale(12),
        r.scale(20, tablet: 28),
        r.scale(12) + MediaQuery.paddingOf(context).bottom,
      ),
      child: PrimaryButton(
        label: 'Save Changes',
        isLoading: isLoading,
        onPressed: onSave,
      ),
    );
  }
}
