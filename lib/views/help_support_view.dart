import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class HelpSupportView extends StatefulWidget {
  const HelpSupportView({super.key});

  @override
  State<HelpSupportView> createState() => _HelpSupportViewState();
}

class _HelpSupportViewState extends State<HelpSupportView> {
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
          'Calorie AI looks up nutrition data from Open Food Facts and lets '
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
                              : AppColors.border,
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
              subtitle: 'support@calorieai.app',
              detail: 'We typically reply within 24 hours',
              actionLabel: 'Copy Email',
              onAction: () => _copyToClipboard(
                context,
                'support@calorieai.app',
                'Email copied to clipboard',
              ),
            ),
            SizedBox(height: r.scale(10)),
            _ContactCard(
              icon: Icons.bug_report_outlined,
              title: 'Report a Problem',
              subtitle: 'Found a bug or issue?',
              detail: 'Help us improve Calorie AI',
              actionLabel: 'Send Report',
              onAction: () => _showMessage(
                context,
                'Thank you! Bug report form coming soon.',
              ),
            ),
            SizedBox(height: r.scale(16)),
            Center(
              child: Text(
                'Calorie AI v1.0.0',
                style: TextStyle(
                  fontSize: r.scale(12),
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    _showMessage(context, message);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
        color: AppColors.surfaceOf(context),
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
                    fontSize: 12,
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
