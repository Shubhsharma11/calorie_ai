import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../theme/app_colors.dart';

const _dontSuggestReasons = [
  "I don't like this food",
  "I've had this recently",
  "I don't have these ingredients",
  'Too spicy',
  'Too heavy',
  "I don't eat this type of food",
  'Other',
];

/// Returns selected reason (or null if cancelled). Empty string = confirmed without reason.
Future<String?> showDontSuggestReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      AppColors.syncFromContext(sheetContext);
      return const _DontSuggestReasonSheet();
    },
  );
}

Future<bool> showDontSuggestConfirmDialog(BuildContext context) async {
  AppColors.syncFromContext(context);
  final r = context.responsive;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.scale(22)),
        ),
        insetPadding: EdgeInsets.symmetric(horizontal: r.scale(28)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            r.scale(20),
            r.scale(22),
            r.scale(20),
            r.scale(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.scale(56),
                height: r.scale(56),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.do_not_disturb_on_rounded,
                  size: r.scale(30),
                  color: AppColors.primaryDark,
                ),
              ),
              SizedBox(height: r.scale(14)),
              Text(
                "Don't suggest this meal again?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.scale(18),
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: r.scale(8)),
              Text(
                "We'll avoid showing this meal in your future meal plans. "
                'You can always change this from your preferences.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.scale(13),
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: r.scale(18)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: r.scale(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    "Yes, don't suggest",
                    style: TextStyle(
                      fontSize: r.scale(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: r.scale(14),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result == true;
}

class _DontSuggestReasonSheet extends StatefulWidget {
  const _DontSuggestReasonSheet();

  @override
  State<_DontSuggestReasonSheet> createState() =>
      _DontSuggestReasonSheetState();
}

class _DontSuggestReasonSheetState extends State<_DontSuggestReasonSheet> {
  String? _selected = _dontSuggestReasons.first;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.scale(24))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: r.scale(10)),
            Container(
              width: r.scale(40),
              height: r.scale(4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                r.scale(18),
                r.scale(14),
                r.scale(8),
                r.scale(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Why don't you want this meal?",
                      style: TextStyle(
                        fontSize: r.scale(18),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.scale(18)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose the reason (optional).',
                  style: TextStyle(
                    fontSize: r.scale(13),
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(height: r.scale(8)),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: r.scale(10)),
                itemCount: _dontSuggestReasons.length,
                itemBuilder: (context, index) {
                  final reason = _dontSuggestReasons[index];
                  final selected = _selected == reason;
                  return ListTile(
                    onTap: () => setState(() => _selected = reason),
                    title: Text(
                      reason,
                      style: TextStyle(
                        fontSize: r.scale(15),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: selected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: r.scale(22),
                          )
                        : Icon(
                            Icons.circle_outlined,
                            color: AppColors.border,
                            size: r.scale(22),
                          ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                r.scale(18),
                r.scale(8),
                r.scale(18),
                r.scale(8),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected ?? ''),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: r.scale(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: r.scale(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_selected ?? ''),
              child: Text(
                "Don't suggest this meal again",
                style: TextStyle(
                  fontSize: r.scale(13),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            SizedBox(height: r.scale(8)),
          ],
        ),
      ),
    );
  }
}
