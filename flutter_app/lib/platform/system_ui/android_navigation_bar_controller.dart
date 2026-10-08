import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps Android's system navigation bar hidden while Zivo is active.
///
/// A swipe from the bottom edge can still reveal the bar temporarily. Android
/// also forces the bar to appear with the keyboard, so it is hidden again
/// after text entry finishes.
class AndroidNavigationBarController extends WidgetsBindingObserver {
  AndroidNavigationBarController();

  static const MethodChannel _channel = MethodChannel('zivo/system_ui');
  static const Duration _keyboardRestoreDelay = Duration(milliseconds: 1100);

  Timer? _restoreTimer;
  bool _keyboardWasVisible = false;
  bool _started = false;

  void start() {
    if (_started || !_isAndroid) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(hide());
  }

  void dispose() {
    if (!_started) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _restoreTimer?.cancel();
    _started = false;
  }

  Future<void> hide() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('hideNavigationBar');
    } on MissingPluginException {
      // Keeps widget tests and non-Android embedders safe.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(hide());
    }
  }

  @override
  void didChangeMetrics() {
    final keyboardIsVisible = WidgetsBinding.instance.platformDispatcher.views
        .any((view) => view.viewInsets.bottom > 0);

    if (_keyboardWasVisible && !keyboardIsVisible) {
      _restoreTimer?.cancel();
      _restoreTimer = Timer(_keyboardRestoreDelay, () {
        unawaited(hide());
      });
    }
    _keyboardWasVisible = keyboardIsVisible;
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
