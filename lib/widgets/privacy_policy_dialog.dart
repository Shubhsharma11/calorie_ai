import 'package:url_launcher/url_launcher.dart';

import '../core/app_snackbar.dart';

const privacyPolicyUrl = 'https://mycaloriepal.com/privacy';

/// Opens the hosted Privacy Policy in an in-app browser
/// (Safari View Controller / Chrome Custom Tabs), with a system-browser fallback.
Future<void> openPrivacyPolicy() async {
  final uri = Uri.parse(privacyPolicyUrl);

  try {
    final openedInApp = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
    );
    if (openedInApp) return;

    final openedExternally = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (openedExternally) return;

    AppSnackbar.error(
      'Could not open the privacy policy. Please try again.',
      title: 'Unable to open link',
    );
  } catch (_) {
    try {
      final openedExternally = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (openedExternally) return;
    } catch (_) {}

    AppSnackbar.error(
      'Could not open the privacy policy. Please try again.',
      title: 'Unable to open link',
    );
  }
}
