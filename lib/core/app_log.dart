import 'package:flutter/foundation.dart';

/// Always-visible debug banners for Logcat / Debug Console.
///
/// Filter Android Logcat by: `MyCaloriePal` or `flutter`
void appLog(String message) {
  if (!kDebugMode) return;
  // ignore: avoid_print — intentional so logs show when debugPrint is filtered out
  print('[MyCaloriePal] $message');
}
