import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';

/// Shared floating card used by log sheets and pickers across the app.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (sheetContext) {
      AppColors.syncFromContext(sheetContext);
      final r = sheetContext.responsive;
      final media = MediaQuery.of(sheetContext);
      final maxHeight = media.size.height * 0.82;
      final bottomPad =
          media.padding.bottom + r.scale(12) + media.viewInsets.bottom;

      return GestureDetector(
        onTap: isDismissible
            ? () => Navigator.of(sheetContext).maybePop()
            : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.fromLTRB(r.scale(12), 0, r.scale(12), bottomPad),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(r.scale(28)),
                  clipBehavior: Clip.antiAlias,
                  child: builder(sheetContext),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

/// Standard inner padding + drag handle for [showAppBottomSheet] content.
class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            r.scale(20),
            r.scale(10),
            r.scale(20),
            r.scale(16),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHandle(),
          SizedBox(height: r.scale(16)),
          Flexible(fit: FlexFit.loose, child: child),
        ],
      ),
    );
  }
}

class AppSheetOption<T> {
  const AppSheetOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// Title + tappable option list inside the shared sheet chrome.
Future<T?> showAppOptionsSheet<T>({
  required BuildContext context,
  required String title,
  required List<AppSheetOption<T>> options,
  T? selected,
  bool useRootNavigator = false,
}) {
  return showAppBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (sheetContext) {
      final r = sheetContext.responsive;

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
                  final isSelected = option.value == selected;
                  return ListTile(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(sheetContext, option.value);
                    },
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: r.scale(4),
                    ),
                    leading: option.icon == null
                        ? null
                        : Icon(
                            option.icon,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
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
                    subtitle: option.subtitle == null
                        ? null
                        : Text(
                            option.subtitle!,
                            style: TextStyle(
                              fontSize: r.scale(12),
                              color: AppColors.textSecondary,
                            ),
                          ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class AppSheetPrimaryButton extends StatelessWidget {
  const AppSheetPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      height: r.scale(52),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: r.scale(16), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  return showAppOptionsSheet<ImageSource>(
    context: context,
    title: 'Add photo',
    options: const [
      AppSheetOption(
        value: ImageSource.gallery,
        label: 'Choose from gallery',
        icon: Icons.photo_library_outlined,
      ),
      AppSheetOption(
        value: ImageSource.camera,
        label: 'Take a photo',
        icon: Icons.photo_camera_outlined,
      ),
    ],
  );
}

Future<String?> showServingUnitSheet({
  required BuildContext context,
  required Map<String, String> units,
  required String selected,
}) {
  return showAppBottomSheet<String>(
    context: context,
    builder: (sheetContext) {
      final r = sheetContext.responsive;

      return AppSheetScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select serving unit',
              style: TextStyle(
                fontSize: r.scale(18),
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: r.scale(14)),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: r.scale(8),
              crossAxisSpacing: r.scale(8),
              childAspectRatio: 2.4,
              children: units.entries.map((entry) {
                final isSelected = entry.key == selected;
                return InkWell(
                  onTap: () => Navigator.pop(sheetContext, entry.key),
                  borderRadius: BorderRadius.circular(r.scale(10)),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(r.scale(10)),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.scale(10.5),
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    },
  );
}
