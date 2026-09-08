import 'package:url_launcher/url_launcher.dart';

import 'app_snackbar.dart';

/// Opens [url] in an in-app browser, with a system-browser fallback.
Future<void> openExternalUrl(
  String url, {
  String errorMessage = 'Could not open the link. Please try again.',
}) async {
  final uri = Uri.parse(url);

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

    AppSnackbar.error(errorMessage, title: 'Unable to open link');
  } catch (_) {
    try {
      final openedExternally = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (openedExternally) return;
    } catch (_) {}

    AppSnackbar.error(errorMessage, title: 'Unable to open link');
  }
}
