import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/dashboard_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_coach_marks.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class HelpSupportView extends StatefulWidget {
  const HelpSupportView({super.key});

  @override
  State<HelpSupportView> createState() => _HelpSupportViewState();
}

class _HelpSupportViewState extends State<HelpSupportView> {
  static const _supportEmail = 'support@fitbuddyai.com';
  static const _appVersion = '1.0.0';

  int? _expandedIndex;

  static const _faqs = [
    (
      question: 'How do I log my meals?',
      answer:
          'Tap Add Food on the Home or Diary tab, search for a food item, '
          'select your portion size, and save it to your daily log. You can '
          'also use the Scan tab to log packaged foods by barcode.',
    ),
    (
      question: 'How is my daily calorie goal calculated?',
      answer:
          'Your goal is estimated from your age, height, weight, gender, '
          'activity level, and fitness goal (lose, maintain, or gain weight). '
          'Update these in your Health Profile on the Profile tab.',
    ),
    (
      question: 'Can I track water intake?',
      answer:
          'Yes. Use the Water Intake banner on Home or open Water Tracker '
          'from Profile or Stats. Log water in ml with quick-add buttons '
          '(+250 ml, +500 ml, or a custom amount) and track progress toward '
          'your daily goal, which you can change in Settings.',
    ),
    (
      question: 'How does food scanning work?',
      answer:
          'Open the Scan tab and point your camera at a product barcode. '
          'FitBuddy AI looks up nutrition data from Open Food Facts and lets '
          'you add it to your log.',
    ),
    (
      question: 'Why can\'t I find a food in search?',
      answer:
          'Search uses a curated Indian foods database. If your item is not '
          'listed, try a similar dish or use barcode scan for packaged products.',
    ),
    (
      question: 'How do I change my weight or goals?',
      answer:
          'Go to Profile → Health Profile and update My Goals, Personal '
          'Details, or Activity Level. Your calorie and macro targets will '
          'recalculate automatically.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      appBar: const AppAppBar(title: 'Help & Support'),
      body: ResponsivePage(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How can we help?',
              style: TextStyle(
                fontSize: r.scale(22, tablet: 24),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            SizedBox(height: r.scale(8)),
            Text(
              'Find answers below or reach out to our support team.',
              style: TextStyle(
                fontSize: r.scale(14),
                color: AppColors.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
            SizedBox(height: r.scale(24)),
            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: TextStyle(
                fontSize: r.scale(12),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(height: r.scale(12)),
            ...List.generate(_faqs.length, (index) {
              final faq = _faqs[index];
              final isExpanded = _expandedIndex == index;

              return Padding(
                padding: EdgeInsets.only(bottom: r.scale(8)),
                child: Material(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => setState(
                      () => _expandedIndex = isExpanded ? null : index,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isExpanded
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.borderOf(context),
                        ),
                      ),
                      padding: EdgeInsets.all(r.scale(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  faq.question,
                                  style: TextStyle(
                                    fontSize: r.scale(15),
                                    fontWeight: FontWeight.w600,
                                    color: isExpanded
                                        ? AppColors.primary
                                        : AppColors.textPrimaryOf(context),
                                  ),
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: isExpanded
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ],
                          ),
                          if (isExpanded) ...[
                            SizedBox(height: r.scale(12)),
                            Text(
                              faq.answer,
                              style: TextStyle(
                                fontSize: r.scale(14),
                                color: AppColors.textSecondaryOf(context),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: r.scale(24)),
            Text(
              'APP TOUR',
              style: TextStyle(
                fontSize: r.scale(12),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(height: r.scale(12)),
            _ContactCard(
              icon: Icons.tour_outlined,
              title: 'Replay app tour',
              subtitle: 'Highlight Home and navigation features',
              detail: 'Takes about a minute',
              actionLabel: 'Start tour',
              onAction: () => _replayTour(context),
            ),
            SizedBox(height: r.scale(24)),
            Text(
              'CONTACT US',
              style: TextStyle(
                fontSize: r.scale(12),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(height: r.scale(12)),
            _ContactCard(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: _supportEmail,
              detail: 'We typically reply within 24 hours',
              actionLabel: 'Send Email',
              onAction: () => _openSupportEmail(
                subject: 'FitBuddy AI Support',
                body: _supportEmailBody(),
              ),
            ),
            SizedBox(height: r.scale(10)),
            _ContactCard(
              icon: Icons.bug_report_outlined,
              title: 'Report a Problem',
              subtitle: 'Found a bug or issue?',
              detail: 'Help us improve FitBuddy AI',
              actionLabel: 'Send Report',
              onAction: _reportProblem,
            ),
            SizedBox(height: r.scale(16)),
            Center(
              child: Text(
                'FitBuddy AI v$_appVersion',
                style: TextStyle(
                  fontSize: r.scale(12),
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            SizedBox(
              height: MediaQuery.viewPaddingOf(context).bottom + r.scale(16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replayTour(BuildContext context) async {
    final userId = Get.isRegistered<UserController>()
        ? Get.find<UserController>().userId.trim()
        : '';

    final storage = LocalStorageService(
      null,
      userId.isEmpty ? null : userId,
    );

    // Tour highlights Home/nav targets under MainView — leave Help without
    // wiping the whole stack (offAllNamed felt like the app closed).
    if (Get.currentRoute == AppRoutes.helpSupport) {
      Get.back();
    } else {
      Get.until(
        (route) =>
            route.settings.name == AppRoutes.main || route.isFirst,
      );
    }

    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().resetToHomeTab();
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().scrollHomeToTop();
    }

    // Let the Help route finish popping so Home targets are layout-ready.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    await WidgetsBinding.instance.endOfFrame;

    if (AppCoachMarks.replayHandler == null) {
      AppSnackbar.info(
        'Open Home first, then try the tour again.',
        title: 'Tour unavailable',
      );
      return;
    }

    await AppCoachMarks.replay(storage);
  }

  Future<void> _reportProblem() async {
    await _openSupportEmail(
      subject: 'FitBuddy AI Bug Report',
      body: _bugReportBody(),
    );
  }

  String _supportEmailBody() {
    final user = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : null;
    final name = user?.user.name.trim() ?? '';
    final email = user?.user.email.trim() ?? '';

    return [
      'Hi FitBuddy team,',
      '',
      'I need help with:',
      '',
      '',
      '—',
      if (name.isNotEmpty) 'Name: $name',
      if (email.isNotEmpty) 'Account: $email',
      'App: FitBuddy AI v$_appVersion',
      'Platform: ${Platform.operatingSystem}',
    ].join('\n');
  }

  String _bugReportBody() {
    final user = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : null;
    final name = user?.user.name.trim() ?? '';
    final email = user?.user.email.trim() ?? '';
    final userId = user?.userId.trim() ?? '';

    return [
      'Hi FitBuddy team,',
      '',
      'What happened:',
      '',
      '',
      'Steps to reproduce:',
      '1. ',
      '2. ',
      '3. ',
      '',
      'Expected result:',
      '',
      '',
      '— Device info (please leave) —',
      if (name.isNotEmpty) 'Name: $name',
      if (email.isNotEmpty) 'Account: $email',
      if (userId.isNotEmpty) 'User ID: $userId',
      'App: FitBuddy AI v$_appVersion',
      'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    ].join('\n');
  }

  Future<void> _openSupportEmail({
    required String subject,
    required String body,
  }) async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: _encodeQuery({
          'subject': subject,
          'body': body,
        }),
      );

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        await Clipboard.setData(ClipboardData(text: _supportEmail));
        AppSnackbar.info(
          'Could not open email. Address copied: $_supportEmail',
          title: 'Email app unavailable',
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _supportEmail));
      AppSnackbar.info(
        'Could not open email. Address copied: $_supportEmail',
        title: 'Email app unavailable',
      );
    }
  }

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          SizedBox(width: r.scale(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: r.scale(15),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: r.scale(2)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: r.scale(14),
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: r.scale(4)),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: r.scale(12),
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                SizedBox(height: r.scale(10)),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(
                    actionLabel,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
