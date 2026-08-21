import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

Future<void> showTermsOfServiceDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Terms of Service',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      content: const SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: _TermsOfServiceContent(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _TermsOfServiceContent extends StatelessWidget {
  const _TermsOfServiceContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last Updated: August 7, 2026',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome to MyCaloriePal. By using this app, you agree to these Terms of Service.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        _termsTitle('1. About MyCaloriePal'),
        _termsText(
          'MyCaloriePal helps you track your meals, calories, water intake, exercise, weight progress, and personal health goals.',
        ),
        _termsTitle('2. Health Disclaimer'),
        _termsText(
          'MyCaloriePal is designed for general health and wellness purposes only. It does not provide medical advice, diagnosis, or treatment.\n\nCalorie information, food details, and AI suggestions may not always be completely accurate. Please consult a healthcare professional before making important health or diet decisions.',
        ),
        _termsTitle('3. Your Account'),
        _termsText(
          'You are responsible for providing accurate information while creating your account and keeping your account details secure.',
        ),
        _termsTitle('4. Your Information'),
        _termsText(
          'You are responsible for the information you enter into MyCaloriePal. Your information is handled according to our Privacy Policy.',
        ),
        _termsTitle('5. Notifications'),
        _termsText(
          'MyCaloriePal may send reminders for meals, water intake, progress updates, and other activities.\n\nNotifications may sometimes be delayed due to device settings, internet connection, or system limitations.',
        ),
        _termsTitle('6. Using the App'),
        _termsText(
          'You agree not to misuse the app, attempt unauthorized access, harm the service, or use MyCaloriePal for illegal activities.',
        ),
        _termsTitle('7. App Updates'),
        _termsText(
          'We may update, modify, or remove features from MyCaloriePal to improve your experience.',
        ),
        _termsTitle('8. Account Deletion'),
        _termsText(
          'You can delete your account from the app settings. Some information may be retained when required by law or for legitimate business purposes.',
        ),
        _termsTitle('9. Changes to Terms'),
        _termsText(
          'We may update these Terms of Service from time to time. Continued use of MyCaloriePal means you accept the updated terms.',
        ),
        _termsTitle('10. Contact Us'),
        _termsText(
          'If you have any questions regarding these Terms, please contact us at:',
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openEmail,
          child: Text(
            'support@srhsoftwares.com',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'By using MyCaloriePal, you agree to these Terms of Service.',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  static Widget _termsTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget _termsText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  static Future<void> _openEmail() async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'support@srhsoftwares.com',
      query: 'subject=MyCaloriePal Support',
    );

    final opened = await launchUrl(
      emailUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      Get.snackbar(
        'Email app not found',
        'Please email us at support@srhsoftwares.com',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
