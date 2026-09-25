import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/activity_level.dart';
import '../models/diet_plan_interest.dart';
import '../models/diet_type.dart';
import '../models/goal_type.dart';
import '../models/lifestyle_habits.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/privacy_policy_dialog.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_photo_sheet.dart';
import '../widgets/terms_of_service_dialog.dart';
import 'food_profile_form_view.dart';
import 'health_form_view.dart';
import 'lifestyle_form_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _scrollController = ScrollController();

  static const _elevateAfter = 6.0;
  static const _proteinColor = Color(0xFF4C8DFF);
  static const _carbsColor = Color(0xFFF5A623);
  static const _fatColor = Color(0xFFE85D9A);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);

    final r = context.responsive;
    final horizontalPadding = r.scale(20, tablet: 28, desktop: 32);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPad = r.scale(110) + bottomInset;

    return ColoredBox(
      color: AppColors.background,
      child: GetBuilder<UserController>(
        builder: (ctrl) {
          final isAppleProfile = Platform.isIOS && ctrl.authProvider == 'apple';
          final user = ctrl.user;
          final signingOut = ctrl.isLoggingOut || ctrl.isDeletingAccount;
          // Only show the settling skeleton on first load — never replace an
          // already-rendered profile during pull-to-refresh.
          final profileSettling = !signingOut &&
              ctrl.isLoggedIn &&
              !user.hasProfileBasics &&
              ctrl.isLoadingProfile;

          if (profileSettling) {
            return _ProfileSettlingState(
              horizontalPadding: horizontalPadding,
              bottomPad: bottomPad,
            );
          }

          if (!ctrl.isLoggedIn && !signingOut && !user.hasProfileBasics) {
            return ColoredBox(color: AppColors.background);
          }

          if (!user.hasProfileBasics) {
            return ColoredBox(color: AppColors.background);
          }

          ctrl.ensureNutritionPlanBaseline();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedBuilder(
                animation: _scrollController,
                builder: (context, _) {
                  final offset = _scrollController.hasClients
                      ? _scrollController.offset
                      : 0.0;
                  final elevated = offset > _elevateAfter;
                  return _ProfilePinnedTitle(
                    horizontalPadding: horizontalPadding,
                    elevated: elevated,
                  );
                },
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    await ctrl.fetchProfile(force: true);
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      r.scale(4),
                      horizontalPadding,
                      bottomPad,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileIdentityRow(
                          user: user,
                          isAppleProfile: isAppleProfile,
                          isUploadingAvatar: ctrl.isUploadingAvatar,
                          onAvatarTap: () {
                            if (isAppleProfile && user.hasProfilePhoto) {
                              showProfilePhotoViewer(
                                context: context,
                                user: user,
                              );
                              return;
                            }
                            ctrl.showProfilePhotoOptions(context);
                          },
                          onEditTap: () => showEditProfileBottomSheet(
                            context: context,
                            controller: ctrl,
                          ),
                        ),
                        if (ctrl.needsNutritionPlanRefresh) ...[
                          SizedBox(height: r.scale(14)),
                          _UpdatePlanBanner(
                            isLoading: ctrl.isRefreshingNutritionPlan,
                            onUpdate: () => _updatePlan(ctrl),
                          ),
                        ],
                        SizedBox(height: r.scale(16)),
                        _MyDietPlanCard(
                          user: user,
                          proteinColor: _proteinColor,
                          carbsColor: _carbsColor,
                          fatColor: _fatColor,
                        ),
                        SizedBox(height: r.scale(14)),
                        _BodyGoalCard(
                          user: user,
                          onEdit: () => _editBodyOrGoal(context),
                        ),
                        SizedBox(height: r.scale(14)),
                        _FoodProfileCard(
                          user: user,
                          onEdit: () => Get.to(() => const FoodProfileFormView()),
                          onAddFood: () =>
                              Get.to(() => const FoodProfileFormView()),
                          onDietType: () =>
                              Get.to(() => const FoodProfileFormView()),
                          onFoodRegion: () =>
                              Get.to(() => const FoodProfileFormView()),
                          onPlanInterest: () =>
                              Get.to(() => const FoodProfileFormView()),
                          onAllergies: () =>
                              Get.to(() => const FoodProfileFormView()),
                          onDontEat: () =>
                              Get.to(() => const FoodProfileFormView()),
                        ),
                        SizedBox(height: r.scale(14)),
                        _LifestyleCard(
                          user: user,
                          onEdit: () => Get.to(() => const LifestyleFormView()),
                          onActivity: () =>
                              Get.to(() => const LifestyleFormView()),
                          onEatingHabits: () =>
                              Get.to(() => const LifestyleFormView()),
                          onCookingSkills: () =>
                              Get.to(() => const LifestyleFormView()),
                        ),
                        SizedBox(height: r.scale(14)),
                        _HealthCard(
                          user: user,
                          onEdit: () => Get.to(() => const HealthFormView()),
                          onConditions: () =>
                              Get.to(() => const HealthFormView()),
                          onMedications: () =>
                              Get.to(() => const HealthFormView()),
                        ),
                        SizedBox(height: r.scale(14)),
                        _LinksCard(
                          icon: Icons.support_agent_outlined,
                          title: 'Support',
                          rows: [
                            _LinkRowData(
                              icon: Icons.headset_mic_outlined,
                              title: 'Help center',
                              onTap: () => Get.toNamed(AppRoutes.helpSupport),
                            ),
                            _LinkRowData(
                              icon: Icons.shield_outlined,
                              title: 'Privacy Policy',
                              onTap: openPrivacyPolicy,
                            ),
                            _LinkRowData(
                              icon: Icons.description_outlined,
                              title: 'Terms & Service',
                              onTap: openTermsOfService,
                            ),
                          ],
                        ),
                        SizedBox(height: r.scale(14)),
                        _LinksCard(
                          icon: Icons.settings_outlined,
                          title: 'App',
                          rows: [
                            _LinkRowData(
                              icon: Icons.settings_outlined,
                              title: 'Settings',
                              onTap: () => Get.toNamed(AppRoutes.settings),
                            ),
                            _LinkRowData(
                              icon: Icons.card_giftcard_outlined,
                              title: 'Invite Friends',
                              onTap: () => Get.toNamed(AppRoutes.inviteFriends),
                            ),
                            _LinkRowData(
                              icon: Icons.share_outlined,
                              title: 'Share App',
                              onTap: _shareApp,
                            ),
                          ],
                        ),
                        SizedBox(height: r.scale(14)),
                        _AccountActionsCard(
                          loggingOut: ctrl.isLoggingOut,
                          deleting: ctrl.isDeletingAccount,
                          onLogout: ctrl.isLoggingOut
                              ? null
                              : () => _confirmLogout(context, ctrl),
                          onDelete: ctrl.isDeletingAccount || ctrl.isLoggingOut
                              ? null
                              : () => _confirmDeleteAccount(context, ctrl),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updatePlan(UserController ctrl) async {
    final error = await ctrl.refreshNutritionPlanFromProfile();
    if (error != null) {
      AppSnackbar.error(error, title: 'Plan update failed');
      return;
    }
    AppSnackbar.success('Your plan is up to date.');
  }

  Future<void> _editBodyOrGoal(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Edit body & goal'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              Get.toNamed(
                AppRoutes.personalInformation,
                arguments: RouteArgs.fromProfileMap,
              );
            },
            child: const Text('Body details'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              Get.toNamed(
                AppRoutes.myGoals,
                arguments: RouteArgs.fromProfileMap,
              );
            },
            child: const Text('Goal & target'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _shareApp() async {
    const message = 'Check out MyCaloriePal — your smart nutrition tracker!';
    await SharePlus.instance.share(
      ShareParams(text: message, title: 'Share MyCaloriePal'),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    UserController ctrl,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !ctrl.isDeletingAccount,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This permanently deletes your MyCaloriePal account and all app data. '
          'You will need to create a new account to use the app again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ctrl.performDeleteAccount();
    }
  }

  Future<void> _confirmLogout(BuildContext context, UserController ctrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !ctrl.isLoggingOut,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ctrl.performLogout();
    }
  }
}

// ─── Shared copy helpers ─────────────────────────────────────────────────────

String _optionLabel(List<HabitOption> options, String? value) {
  if (value == null || value.isEmpty) return '—';
  for (final option in options) {
    if (option.value == value) return option.label;
  }
  return value;
}

String _foodPreferenceLabel(String value) {
  for (final option in LifestyleHabitOptions.foodPreferences) {
    if (option.value == value) return option.label;
  }
  return value.replaceAll('_', ' ');
}

String _livingAreaLabel(UserModel user) {
  final region = LifestyleHabitOptions.livingRegionByValue(user.livingArea);
  if (region == null) return '—';
  final stateValue = user.livingState;
  if (stateValue == null || stateValue.isEmpty) return region.label;
  for (final state in region.states) {
    if (state.value == stateValue) {
      return '${region.label} · ${state.label}';
    }
  }
  return region.label;
}

List<String> _avoidChips(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const [];
  final lower = text.toLowerCase();
  if (lower.contains('nothing') || lower == 'none') return const [];
  final chips = <String>[];
  for (final option in LifestyleHabitOptions.foodsToAvoid) {
    if (option.value == 'none') continue;
    if (lower.contains(option.label.toLowerCase()) ||
        lower.contains(option.value.replaceAll('_', ' '))) {
      chips.add(option.label);
    }
  }
  if (chips.isNotEmpty) return chips;
  return text
      .split(RegExp(r'[,;]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _formatKgAmount(double kg) {
  final rounded = kg.roundToDouble();
  if ((kg - rounded).abs() < 0.05) return '${rounded.toInt()}';
  return kg.toStringAsFixed(1);
}

String _goalActionLabel(UserModel user) {
  final goal = user.pinnedGoalType ?? user.goal ?? GoalType.maintainWeight;
  final current = user.weightKg?.toDouble() ?? 0;
  final target = user.goalWeightKg;
  final delta = (target - current).abs();

  return switch (goal) {
    GoalType.loseWeight => 'Lose ${_formatKgAmount(delta)} kg',
    GoalType.gainWeight => 'Gain ${_formatKgAmount(delta)} kg',
    GoalType.maintainWeight => 'Maintain weight',
  };
}

String _goalDateLabel(UserModel user) {
  return DateFormat('MMM yyyy').format(user.targetDate);
}

String _goalTimeLeftLabel(UserModel user) {
  final today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final daysLeft = user.targetDate.difference(today).inDays;
  if (daysLeft <= 0) return 'Target date reached';
  if (daysLeft == 1) return '1 day left';
  if (daysLeft < 14) return '$daysLeft days left';
  if (daysLeft < 60) {
    final weeks = (daysLeft / 7).round().clamp(1, 8);
    return weeks == 1 ? '1 week left' : '$weeks weeks left';
  }
  final months = (daysLeft / 30.44).round().clamp(1, 36);
  return months == 1 ? '1 month left' : '$months months left';
}

String _goalSubline(UserModel user) {
  final goal = user.pinnedGoalType ?? user.goal ?? GoalType.maintainWeight;
  final current = user.weightKg;
  final target = user.goalWeightKg;
  final timeLeft = _goalTimeLeftLabel(user);

  if (goal == GoalType.maintainWeight || current == null) {
    return timeLeft;
  }

  return '${_formatKgAmount(current.toDouble())} → '
      '${_formatKgAmount(target)} kg · $timeLeft';
}

String? _paceWarning(UserModel user) {
  final goal = user.pinnedGoalType ?? user.goal;
  final current = user.weightKg?.toDouble();
  if (goal == null ||
      goal == GoalType.maintainWeight ||
      current == null ||
      current <= 0) {
    return null;
  }

  final today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final days = user.targetDate.difference(today).inDays.clamp(1, 730);
  final weeks = days / 7.0;
  final delta = (user.goalWeightKg - current).abs();
  if (delta < 0.5) return null;

  final perWeek = delta / weeks;
  if (perWeek <= 1.05) return null;

  final verb = goal == GoalType.loseWeight ? 'Losing' : 'Gaining';
  final dateLabel = DateFormat('MMM yyyy').format(user.targetDate);
  return '$verb ${_formatKgAmount(delta)} kg by $dateLabel '
      'is about ${perWeek.toStringAsFixed(1)} kg a week — faster than the '
      'usual safe pace (0.5–1 kg). Consider a later date.';
}

// ─── Chrome ──────────────────────────────────────────────────────────────────

class _ProfilePinnedTitle extends StatelessWidget {
  const _ProfilePinnedTitle({
    required this.horizontalPadding,
    required this.elevated,
  });

  final double horizontalPadding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        r.scale(8),
        horizontalPadding,
        r.scale(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: elevated
                ? AppColors.border.withValues(alpha: isDark ? 0.9 : 0.75)
                : Colors.transparent,
            width: 1,
          ),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        'Profile',
        style: TextStyle(
          fontSize: r.scale(28, tablet: 30),
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.4,
          height: 1.15,
        ),
      ),
    );
  }
}

class _ProfileIdentityRow extends StatelessWidget {
  const _ProfileIdentityRow({
    required this.user,
    required this.onAvatarTap,
    required this.onEditTap,
    this.isAppleProfile = false,
    this.isUploadingAvatar = false,
  });

  final UserModel user;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;
  final bool isAppleProfile;
  final bool isUploadingAvatar;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final avatarRadius = r.scale(34, tablet: 38);
    final displayName = user.name.trim();
    final nameLabel = displayName.isEmpty ? 'MyCaloriePal' : displayName;
    final emailLabel = user.email.trim().isEmpty ? '—' : user.email.trim();

    return Row(
      children: [
        ProfileAvatar(
          user: user,
          onTap: onAvatarTap,
          radius: avatarRadius,
          isUploading: isUploadingAvatar,
          showEditBadge: true,
          onEditBadgeTap: onEditTap,
          tooltip: isAppleProfile && user.hasProfilePhoto
              ? 'View photo'
              : 'Profile photo',
        ),
        SizedBox(width: r.scale(14)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nameLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(18, tablet: 20),
                  fontWeight: FontWeight.w800,
                  color: displayName.isEmpty
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              SizedBox(height: r.scale(4)),
              Text(
                emailLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(13, tablet: 14),
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpdatePlanBanner extends StatelessWidget {
  const _UpdatePlanBanner({
    required this.isLoading,
    required this.onUpdate,
  });

  final bool isLoading;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.fromLTRB(
        r.scale(14),
        r.scale(12),
        r.scale(10),
        r.scale(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'You changed something. Refresh your plan to match.',
              style: TextStyle(
                fontSize: r.scale(13),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
          SizedBox(width: r.scale(8)),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: isLoading ? null : onUpdate,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(12),
                  vertical: r.scale(8),
                ),
                child: isLoading
                    ? SizedBox(
                        width: r.scale(16),
                        height: r.scale(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.warning,
                        ),
                      )
                    : Text(
                        'Update plan',
                        style: TextStyle(
                          fontSize: r.scale(12),
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Diet plan hero card ─────────────────────────────────────────────────────

class _MyDietPlanCard extends StatelessWidget {
  const _MyDietPlanCard({
    required this.user,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
  });

  final UserModel user;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;

  void _openGoals() {
    Get.toNamed(
      AppRoutes.myGoals,
      arguments: RouteArgs.fromProfileMap,
    );
  }

  void _openCalories() {
    Get.toNamed(
      AppRoutes.dailyCalorieGoal,
      arguments: RouteArgs.fromProfileMap,
    );
  }

  void _openFoodProfile() {
    Get.to(() => const FoodProfileFormView());
  }

  void _openNutritionPlan() {
    Get.toNamed(AppRoutes.aiNutritionPlan);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final calories = user.dailyCalorieGoal;
    final protein = user.proteinGoalG;
    final carbs = user.carbsGoalG;
    final fat = user.fatGoalG;
    // Ratio by calorie contribution (protein×4, carbs×4, fat×9).
    final proteinCal = (protein * 4).clamp(0, 100000).toDouble();
    final carbsCal = (carbs * 4).clamp(0, 100000).toDouble();
    final fatCal = (fat * 9).clamp(0, 100000).toDouble();
    final macroTotal = proteinCal + carbsCal + fatCal;
    final meals = user.mealsPerDay ?? 3;
    final perMeal = calories > 0 && meals > 0
        ? (calories / meals).round()
        : 0;
    final interest = user.dietPlanInterest?.title;
    final calorieLabel = calories > 0
        ? NumberFormat('#,###').format(calories)
        : '—';

    final proteinShare = macroTotal > 0 ? proteinCal / macroTotal : 0.3;
    final carbsShare = macroTotal > 0 ? carbsCal / macroTotal : 0.4;
    final fatShare = macroTotal > 0 ? fatCal / macroTotal : 0.3;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(r.scale(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'MY DIET PLAN',
                    style: TextStyle(
                      fontSize: r.scale(11),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.85,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (interest != null)
                    _PlanInterestChip(
                      label: interest,
                      onTap: _openFoodProfile,
                    ),
                ],
              ),
              SizedBox(height: r.scale(14)),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openGoals,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: r.scale(2)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _goalActionLabel(user),
                          style: TextStyle(
                            fontSize: r.scale(22, tablet: 24),
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.15,
                            letterSpacing: -0.35,
                          ),
                        ),
                        SizedBox(height: r.scale(4)),
                        Text(
                          'by ${_goalDateLabel(user)}',
                          style: TextStyle(
                            fontSize: r.scale(14, tablet: 15),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            height: 1.2,
                            letterSpacing: -0.1,
                          ),
                        ),
                        SizedBox(height: r.scale(8)),
                        Text(
                          _goalSubline(user),
                          style: TextStyle(
                            fontSize: r.scale(13),
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.scale(16)),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openCalories,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: r.scale(2)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          calorieLabel,
                          style: TextStyle(
                            fontSize: r.scale(34, tablet: 36),
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.8,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(width: r.scale(8)),
                        Padding(
                          padding: EdgeInsets.only(bottom: r.scale(5)),
                          child: Text(
                            'kcal / day',
                            style: TextStyle(
                              fontSize: r.scale(14),
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.scale(18)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openNutritionPlan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MacroRatioBar(
                      proteinShare: proteinShare,
                      carbsShare: carbsShare,
                      fatShare: fatShare,
                      proteinColor: proteinColor,
                      carbsColor: carbsColor,
                      fatColor: fatColor,
                    ),
                    SizedBox(height: r.scale(12)),
                    Row(
                      children: [
                        Expanded(
                          child: _MacroLegendDot(
                            color: proteinColor,
                            label: 'Protein $protein g',
                          ),
                        ),
                        Expanded(
                          child: _MacroLegendDot(
                            color: carbsColor,
                            label: 'Carbs $carbs g',
                          ),
                        ),
                        Expanded(
                          child: _MacroLegendDot(
                            color: fatColor,
                            label: 'Fat $fat g',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.scale(16)),
              Row(
                children: [
                  Expanded(
                    child: _PlanStatTile(
                      value: meals > 0 ? '$meals' : '—',
                      label: 'meals',
                      onTap: _openFoodProfile,
                    ),
                  ),
                  SizedBox(width: r.scale(8)),
                  Expanded(
                    child: _PlanStatTile(
                      value: perMeal > 0 ? '~$perMeal' : '—',
                      label: 'kcal each',
                      onTap: _openCalories,
                    ),
                  ),
                  SizedBox(width: r.scale(8)),
                  Expanded(
                    child: _PlanStatTile(
                      value: user.dietType?.shortPlanLabel ?? '—',
                      label: 'diet type',
                      onTap: _openFoodProfile,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanInterestChip extends StatelessWidget {
  const _PlanInterestChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Material(
      color: AppColors.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(10),
            vertical: r.scale(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.scale(11),
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// Straight macro bar: blue / orange / pink pills with thin gaps (mock style).
class _MacroRatioBar extends StatelessWidget {
  const _MacroRatioBar({
    required this.proteinShare,
    required this.carbsShare,
    required this.fatShare,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
  });

  final double proteinShare;
  final double carbsShare;
  final double fatShare;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final height = r.scale(12);
    final gap = r.scale(3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= gap * 2) {
          return SizedBox(width: double.infinity, height: height);
        }

        final shares = <double>[
          proteinShare.clamp(0.0, 1.0),
          carbsShare.clamp(0.0, 1.0),
          fatShare.clamp(0.0, 1.0),
        ];
        final shareSum = shares.fold<double>(0, (a, b) => a + b);
        final normalized = shareSum > 0
            ? shares.map((s) => s / shareSum).toList()
            : const [0.3, 0.4, 0.3];

        final colors = [proteinColor, carbsColor, fatColor];
        final usable = width - gap * 2;
        final segmentWidths = normalized.map((s) => usable * s).toList();

        return SizedBox(
          width: width,
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < segmentWidths.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                SizedBox(
                  width: segmentWidths[i],
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors[i],
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MacroLegendDot extends StatelessWidget {
  const _MacroLegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Row(
      children: [
        Container(
          width: r.scale(8),
          height: r.scale(8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: r.scale(5)),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(11),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanStatTile extends StatelessWidget {
  const _PlanStatTile({
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(8),
            vertical: r.scale(12),
          ),
          child: Column(
            children: [
              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(18),
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              SizedBox(height: r.scale(2)),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(11),
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section cards ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.fromLTRB(
        r.scale(16),
        r.scale(14),
        r.scale(14),
        r.scale(16),
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: r.scale(20)),
              SizedBox(width: r.scale(8)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: r.scale(16),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: r.scale(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: r.scale(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(12)),
          child,
        ],
      ),
    );
  }
}

class _BodyGoalCard extends StatelessWidget {
  const _BodyGoalCard({required this.user, required this.onEdit});

  final UserModel user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final bmi = user.bmi;
    final goal = user.pinnedGoalType ?? user.goal;
    final pace = _paceWarning(user);

    return _SectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Body & goal',
      actionLabel: 'Edit',
      onAction: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  value: user.weightKg != null ? '${user.weightKg} kg' : '—',
                  label: 'now',
                ),
              ),
              SizedBox(width: r.scale(8)),
              Expanded(
                child: _MetricBox(
                  value: user.heightCm != null ? '${user.heightCm} cm' : '—',
                  label: 'height',
                ),
              ),
              SizedBox(width: r.scale(8)),
              Expanded(
                child: _MetricBox(
                  value: user.age != null ? '${user.age} yrs' : '—',
                  label: 'age',
                ),
              ),
              SizedBox(width: r.scale(8)),
              Expanded(
                child: _MetricBox(
                  value: bmi != null ? bmi.toStringAsFixed(1) : '—',
                  label: 'BMI',
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(14)),
          _DetailRow(label: 'Gender', value: user.gender?.trim().isNotEmpty == true
              ? user.gender!
              : '—'),
          _DetailRow(
            label: 'Goal',
            value: goal == null
                ? '—'
                : '${goal.title} · ${user.goalWeightKg.round()} kg',
          ),
          _DetailRow(
            label: 'Target date',
            value: DateFormat('d MMM yyyy').format(user.targetDate),
          ),
          if (pace != null) ...[
            SizedBox(height: r.scale(10)),
            Text(
              pace,
              style: TextStyle(
                fontSize: r.scale(12),
                height: 1.4,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(6),
        vertical: r.scale(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(13),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: r.scale(2)),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(10),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final row = Padding(
      padding: EdgeInsets.only(bottom: r.scale(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.scale(110),
            child: Text(
              label,
              style: TextStyle(
                fontSize: r.scale(13),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: r.scale(13),
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: row,
      ),
    );
  }
}

class _FoodProfileCard extends StatelessWidget {
  const _FoodProfileCard({
    required this.user,
    required this.onEdit,
    required this.onAddFood,
    required this.onDietType,
    required this.onFoodRegion,
    required this.onPlanInterest,
    required this.onAllergies,
    required this.onDontEat,
  });

  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onAddFood;
  final VoidCallback onDietType;
  final VoidCallback onFoodRegion;
  final VoidCallback onPlanInterest;
  final VoidCallback onAllergies;
  final VoidCallback onDontEat;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final allergies = user.foodAllergies
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) {
          final lower = e.toLowerCase();
          return lower != 'none' && !lower.contains('prefer not');
        })
        .toList();
    final avoid = _avoidChips(user.foodsToAvoid);
    final likes = user.foodPreferences.map(_foodPreferenceLabel).toList();

    return _SectionCard(
      icon: Icons.eco_outlined,
      title: 'Food profile',
      actionLabel: 'Edit',
      onAction: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailRow(
            label: 'Diet type',
            value: user.dietType?.title ?? '—',
            onTap: onDietType,
          ),
          _DetailRow(
            label: 'Food region',
            value: _livingAreaLabel(user),
            onTap: onFoodRegion,
          ),
          _DetailRow(
            label: 'Plan interest',
            value: user.dietPlanInterest?.title ?? '—',
            onTap: onPlanInterest,
          ),
          SizedBox(height: r.scale(6)),
          _ChipSection(
            title: 'ALLERGIES & INTOLERANCES',
            chips: allergies,
            emptyLabel: 'None listed',
            tone: _ChipTone.warning,
            onSectionTap: onAllergies,
          ),
          SizedBox(height: r.scale(12)),
          _ChipSection(
            title: "DON'T EAT",
            chips: avoid,
            emptyLabel: 'Nothing excluded',
            tone: _ChipTone.danger,
            onSectionTap: onDontEat,
          ),
          SizedBox(height: r.scale(12)),
          _ChipSection(
            title: 'FOODS I LIKE',
            chips: likes,
            emptyLabel: 'Add foods you enjoy',
            tone: _ChipTone.primary,
            trailingAdd: true,
            onAdd: onAddFood,
            onSectionTap: onAddFood,
          ),
          SizedBox(height: r.scale(12)),
          Text(
            'Allergies are treated as strict rules for meal suggestions. '
            '“Don’t eat” and likes are preferences we try to respect.',
            style: TextStyle(
              fontSize: r.scale(11),
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChipTone { warning, danger, primary }

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.chips,
    required this.emptyLabel,
    required this.tone,
    this.trailingAdd = false,
    this.onAdd,
    this.onSectionTap,
  });

  final String title;
  final List<String> chips;
  final String emptyLabel;
  final _ChipTone tone;
  final bool trailingAdd;
  final VoidCallback? onAdd;
  final VoidCallback? onSectionTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final (bg, fg) = switch (tone) {
      _ChipTone.warning => (
        AppColors.warning.withValues(alpha: 0.18),
        AppColors.warning,
      ),
      _ChipTone.danger => (
        AppColors.error.withValues(alpha: 0.14),
        AppColors.error,
      ),
      _ChipTone.primary => (
        AppColors.primary.withValues(alpha: 0.14),
        AppColors.primaryDark,
      ),
    };

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: r.scale(10),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: r.scale(8)),
        Wrap(
          spacing: r.scale(8),
          runSpacing: r.scale(8),
          children: [
            if (chips.isEmpty)
              Text(
                emptyLabel,
                style: TextStyle(
                  fontSize: r.scale(12),
                  color: AppColors.textSecondary,
                ),
              ),
            for (final chip in chips)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(10),
                  vertical: r.scale(6),
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    fontSize: r.scale(12),
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            if (trailingAdd)
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.scale(10),
                      vertical: r.scale(6),
                    ),
                    child: Text(
                      '+ Add',
                      style: TextStyle(
                        fontSize: r.scale(12),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    if (onSectionTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSectionTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: r.scale(2)),
          child: body,
        ),
      ),
    );
  }
}

class _LifestyleCard extends StatelessWidget {
  const _LifestyleCard({
    required this.user,
    required this.onEdit,
    required this.onActivity,
    required this.onEatingHabits,
    required this.onCookingSkills,
  });

  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onActivity;
  final VoidCallback onEatingHabits;
  final VoidCallback onCookingSkills;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.directions_walk_rounded,
      title: 'Lifestyle',
      actionLabel: 'Edit',
      onAction: onEdit,
      child: Column(
        children: [
          _DetailRow(
            label: 'Activity level',
            value: user.activityLevel?.title ?? '—',
            onTap: onActivity,
          ),
          _DetailRow(
            label: 'Eating habits',
            value: _optionLabel(
              LifestyleHabitOptions.eatingHabits,
              user.eatingHabits,
            ),
            onTap: onEatingHabits,
          ),
          _DetailRow(
            label: 'Cooking skills',
            value: _optionLabel(
              LifestyleHabitOptions.cookingSkills,
              user.cookingSkills,
            ),
            onTap: onCookingSkills,
          ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.user,
    required this.onEdit,
    required this.onConditions,
    required this.onMedications,
  });

  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onConditions;
  final VoidCallback onMedications;

  String get _conditionsValue {
    final concerns = user.healthConcerns;
    if (concerns.isEmpty) return '—';
    if (concerns.every((c) => c.isNone)) return 'None';
    final labels = concerns
        .where((c) => !c.isNone)
        .map((c) => c.category)
        .where((c) => c.isNotEmpty)
        .toList();
    if (labels.isEmpty) return 'None';
    if (labels.length <= 2) return labels.join(', ');
    return '${labels.length} conditions';
  }

  String get _medicationsValue {
    final meds = user.medications;
    if (meds.isEmpty) return '—';
    if (meds.length == 1 && meds.first.toLowerCase() == 'no') return 'None';
    final labels = <String>[];
    for (final value in meds) {
      var found = false;
      for (final option in LifestyleHabitOptions.medications) {
        if (option.value == value) {
          labels.add(option.label);
          found = true;
          break;
        }
      }
      if (!found) labels.add(value);
    }
    if (labels.length <= 2) return labels.join(', ');
    return '${labels.length} selected';
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.favorite_outline_rounded,
      title: 'Health & medications',
      actionLabel: 'Edit',
      onAction: onEdit,
      child: Column(
        children: [
          _DetailRow(
            label: 'Conditions',
            value: _conditionsValue,
            onTap: onConditions,
          ),
          _DetailRow(
            label: 'Medications',
            value: _medicationsValue,
            onTap: onMedications,
          ),
        ],
      ),
    );
  }
}

// ─── Menu / actions (same card chrome as Body / Food / Lifestyle) ─────────────

class _LinkRowData {
  const _LinkRowData({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

class _LinksCard extends StatelessWidget {
  const _LinksCard({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<_LinkRowData> rows;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.fromLTRB(
        r.scale(16),
        r.scale(14),
        r.scale(8),
        r.scale(8),
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: r.scale(20)),
              SizedBox(width: r.scale(8)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: r.scale(16),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(6)),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border.withValues(alpha: 0.45),
              ),
            _LinkTile(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.row});

  final _LinkRowData row;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: row.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: r.scale(12),
            horizontal: r.scale(4),
          ),
          child: Row(
            children: [
              Icon(row.icon, color: AppColors.primary, size: r.scale(20)),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Text(
                  row.title,
                  style: TextStyle(
                    fontSize: r.scale(14),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: r.scale(22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountActionsCard extends StatelessWidget {
  const _AccountActionsCard({
    required this.loggingOut,
    required this.deleting,
    required this.onLogout,
    required this.onDelete,
  });

  final bool loggingOut;
  final bool deleting;
  final VoidCallback? onLogout;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.symmetric(vertical: r.scale(4)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _AccountActionTile(
            label: 'Log Out',
            color: AppColors.textPrimary,
            onTap: onLogout,
            isLoading: loggingOut,
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: r.scale(16),
            endIndent: r.scale(16),
            color: AppColors.border.withValues(alpha: 0.45),
          ),
          _AccountActionTile(
            label: 'Delete Account',
            color: AppColors.error,
            onTap: onDelete,
            isLoading: deleting,
          ),
        ],
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: r.scale(14)),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: r.scale(18),
                      height: r.scale(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: r.scale(15),
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSettlingState extends StatelessWidget {
  const _ProfileSettlingState({
    required this.horizontalPadding,
    required this.bottomPad,
  });

  final double horizontalPadding;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfilePinnedTitle(
          horizontalPadding: horizontalPadding,
          elevated: false,
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              r.scale(8),
              horizontalPadding,
              bottomPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SizedBox(
                    width: r.scale(28),
                    height: r.scale(28),
                    child: const CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
                SizedBox(height: r.scale(16)),
                Text(
                  'Loading your profile…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(14),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: r.scale(24)),
                _PulseBlock(height: r.scale(180)),
                SizedBox(height: r.scale(12)),
                _PulseBlock(height: r.scale(140)),
                SizedBox(height: r.scale(12)),
                _PulseBlock(height: r.scale(160)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseBlock extends StatelessWidget {
  const _PulseBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
    );
  }
}
