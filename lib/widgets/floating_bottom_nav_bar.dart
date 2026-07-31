import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/main_controller.dart';
import '../core/app_coach_marks.dart';
import '../theme/app_colors.dart';

class FloatingBottomNavBar extends StatelessWidget {
  const FloatingBottomNavBar({
    super.key,
    required this.onTap,
    required this.items,
    this.coachKeys,
  });

  final ValueChanged<int> onTap;
  final List<({IconData icon, String label})> items;
  final List<GlobalKey?>? coachKeys;

  @override
  Widget build(BuildContext context) {
    // Scaffold often clears MediaQuery.padding for bottomNavigationBar, so
    // SafeArea alone can sit on top of the system gesture / nav bar.
    // Always lift using viewPadding (home indicator / Android nav).
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    final bottomGap = (systemBottom > 0 ? systemBottom : 8.0) + 10;
    final main = Get.find<MainController>();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: SizedBox(
        height: 100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _NavBarShapePainter(
                    isDark: AppColors.isDark(context),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 5,
                child: SizedBox(
                  height: 90,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isCenter = index == items.length ~/ 2;
                      final coachKey =
                          coachKeys != null && index < coachKeys!.length
                              ? coachKeys![index]
                              : null;

                      Widget navItem = Obx(
                        () => _NavItem(
                          icon: item.icon,
                          label: item.label,
                          selected: main.tabIndex.value == index,
                          isCenter: isCenter,
                          onTap: () => onTap(index),
                          compact: coachKey != null,
                        ),
                      );

                      if (coachKey != null) {
                        // Tight target around the visible control — not the
                        // full 90px Expanded cell (that left a huge tip gap).
                        navItem = Align(
                          alignment: Alignment.bottomCenter,
                          child: AppCoachMarks.target(
                            key: coachKey,
                            child: navItem,
                          ),
                        );
                      }

                      return Expanded(child: navItem);
                    }),
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

class _NavBarShapePainter extends CustomPainter {
  _NavBarShapePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    canvas.drawShadow(
      path,
      AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.22),
      16,
      true,
    );
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
      18,
      true,
    );

    final fillColors = isDark
        ? [
            AppColors.darkCard,
            AppColors.darkSurface,
            AppColors.darkBackground,
          ]
        : const [
            Color(0xFFF8FFF7),
            Color(0xFFEFFFF4),
            Color(0xFFEAF8F1),
          ];

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: fillColors,
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);

    final glow = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 0.9,
        colors: [
          AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.11),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, glow);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = isDark
          ? AppColors.darkBorder.withValues(alpha: 0.85)
          : AppColors.onPrimary.withValues(alpha: 0.76);
    canvas.drawPath(path, border);
  }

  Path _buildPath(Size size) {
    const top = 28.0;
    const bumpTop = 1.0;
    const radius = 38.0;
    final centerX = size.width / 2;
    final bumpHalfWidth = size.width * 0.17;

    return Path()
      ..moveTo(radius, top)
      ..lineTo(centerX - bumpHalfWidth, top)
      ..cubicTo(centerX - 45, top, centerX - 46, bumpTop, centerX, bumpTop)
      ..cubicTo(
        centerX + 46,
        bumpTop,
        centerX + 45,
        top,
        centerX + bumpHalfWidth,
        top,
      )
      ..lineTo(size.width - radius, top)
      ..quadraticBezierTo(size.width, top, size.width, top + radius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, top + radius)
      ..quadraticBezierTo(0, top, radius, top)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _NavBarShapePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? null
        : LinearGradient(colors: [AppColors.surface, AppColors.surface]);
    final iconColor = selected ? AppColors.onPrimary : AppColors.textSecondary;
    final shadowColor = selected
        ? AppColors.primary.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            background ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF66E28C),
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
        border: Border.all(
          color: selected
              ? AppColors.onPrimary.withValues(alpha: 0.85)
              : AppColors.border,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: selected ? 20 : 12,
            offset: Offset(0, selected ? 10 : 4),
          ),
          if (selected)
            BoxShadow(
              color: AppColors.onPrimary.withValues(alpha: 0.80),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: selected ? 30 : 28),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isCenter,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isCenter;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.iconAccent;
    final inactiveColor = AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: compact ? null : 90,
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isCenter)
                _CenterAction(icon: Icons.eco_rounded, selected: selected)
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 42,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: selected ? activeColor : inactiveColor,
                  ),
                ),
              SizedBox(height: isCenter ? 4 : 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
              SizedBox(height: isCenter ? 6 : (compact ? 6 : 10)),
            ],
          ),
        ),
      ),
    );
  }
}
