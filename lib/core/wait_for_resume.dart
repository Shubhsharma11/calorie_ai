import 'dart:async';

import 'package:flutter/widgets.dart';

bool get isAppResumed {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}

/// Waits until the Flutter activity is [AppLifecycleState.resumed].
///
/// Native camera/gallery pushes our activity to the background. Updating
/// GetX / decoding images before the SurfaceView is valid can destroy the
/// engine (lost connection / crash) on Android.
///
/// [pickImage] often completes *after* [AppLifecycleState.resumed], so even
/// when we are already resumed we still wait extra frames for the surface.
///
/// Returns false if the app never came back (timeout or still paused).
Future<bool> waitForAppResumed({
  Duration extraDelay = const Duration(milliseconds: 400),
  Duration timeout = const Duration(seconds: 20),
  int extraFrames = 3,
}) async {
  final binding = WidgetsBinding.instance;
  final state = binding.lifecycleState;
  if (state != null && state != AppLifecycleState.resumed) {
    final resumed = Completer<void>();
    final observer = _ResumeObserver(() {
      if (!resumed.isCompleted) resumed.complete();
    });
    binding.addObserver(observer);
    try {
      await resumed.future.timeout(timeout);
    } on TimeoutException {
      return false;
    } finally {
      binding.removeObserver(observer);
    }
  }

  for (var i = 0; i < extraFrames; i++) {
    binding.scheduleFrame();
    await binding.endOfFrame;
  }
  if (extraDelay > Duration.zero) {
    await Future<void>.delayed(extraDelay);
  }
  return isAppResumed;
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResumed);

  final VoidCallback _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }
}
