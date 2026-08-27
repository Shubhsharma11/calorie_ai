import 'package:url_launcher/url_launcher.dart';

import '../core/app_snackbar.dart';

const termsOfServiceUrl = 'https://mycaloriepal.com/terms';

/// Opens the hosted Terms of Service in an in-app browser
/// (Safari View Controller / Chrome Custom Tabs), with a system-browser fallback.
Future<void> openTermsOfService() async {
  final uri = Uri.parse(termsOfServiceUrl);

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
      'Could not open the terms of service. Please try again.',
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
      'Could not open the terms of service. Please try again.',
      title: 'Unable to open link',
    );
  }
}
