import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';

/// Standalone rounded chip with optional checkmark — matches Weekly Progress filters.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontSize = 13,
    this.expanded = false,
    this.showCheck = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;
  final bool expanded;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final showLeadingCheck = showCheck && selected && !expanded;

    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: expanded ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.onPrimary : AppColors.textPrimary,
      ),
    );

    final Widget content;
    if (expanded) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        child: labelText,
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLeadingCheck) ...[
            Icon(
              Icons.check,
              size: r.sp(16),
              color: AppColors.onPrimary,
            ),
            SizedBox(width: r.sp(4)),
          ],
          labelText,
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: expanded ? double.infinity : null,
          alignment: expanded ? Alignment.center : null,
          padding: EdgeInsets.symmetric(
            horizontal: r.sp(expanded ? 6 : 14),
            vertical: r.sp(8),
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(r.sp(20)),
            border: Border.all(
              color: AppColors.primaryDark,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}
