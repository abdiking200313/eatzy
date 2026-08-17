import 'package:flutter/foundation.dart';

/// A reusable "track loading/error state around an async fetch" shell for
/// [ChangeNotifier]-based controllers.
///
/// Mix this in to get [isLoading] / [loadError] state plus [runLoad], which
/// wraps a fetch call with the boilerplate that would otherwise be
/// duplicated across controllers: set loading, clear the previous error,
/// notify listeners; await the fetch; on error, record a caller-supplied
/// message; then reset loading and notify listeners again.
mixin LoadableState on ChangeNotifier {
  bool _isLoading = false;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  /// Runs [fetch], managing [isLoading] and [loadError] around it and
  /// notifying listeners both before and after.
  ///
  /// If [fetch] throws, [onError] is called with the error and stack trace
  /// to produce the message stored in [loadError].
  Future<void> runLoad({
    required Future<void> Function() fetch,
    required String Function(Object error, StackTrace stackTrace) onError,
  }) async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      await fetch();
    } on Object catch (error, stackTrace) {
      _loadError = onError(error, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
