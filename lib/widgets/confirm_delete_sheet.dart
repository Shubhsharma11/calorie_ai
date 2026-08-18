import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';

/// Shared confirm-delete bottom sheet used across diary / tracker rows.
Future<bool> showConfirmDeleteSheet({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Delete',
  IconData icon = Icons.delete_outline_rounded,
}) async {
  if (!context.mounted) return false;

  final result = await showAppBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      final r = sheetContext.responsive;

      return AppSheetScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.scale(56),
              height: r.scale(56),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.error, size: r.scale(28)),
            ),
            SizedBox(height: r.scale(16)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: r.scale(20),
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            SizedBox(height: r.scale(8)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.scale(14),
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: r.scale(22)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(
                        sheetContext,
                        rootNavigator: true,
                      ).pop(false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border),
                      minimumSize: Size.fromHeight(r.scale(48)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.scale(14)),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.scale(15),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: r.scale(10)),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(sheetContext, rootNavigator: true).pop(true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: Size.fromHeight(r.scale(48)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.scale(14)),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.scale(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  return result == true;
}
