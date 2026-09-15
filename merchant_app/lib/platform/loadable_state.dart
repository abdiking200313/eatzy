import 'package:flutter/foundation.dart';

/// A reusable "track loading/error state around an async fetch" shell for
/// [ChangeNotifier]-based controllers (issue #133).
///
/// This mirrors the root app's `lib/services/shared/presentation/
/// loadable_state_mixin.dart` -- same shape, duplicated rather than shared
/// because the merchant app is an independent Flutter project with its own
/// `pubspec.yaml` (see `AGENTS.md` / issue #133: no cross-project package
/// extraction).
mixin LoadableState on ChangeNotifier {
  bool _isLoading = false;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  /// Runs [fetch], managing [isLoading] and [loadError] around it and
  /// notifying listeners both before and after. If [fetch] throws, [onError]
  /// is called with the error and stack trace to produce the message stored
  /// in [loadError].
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

/// A reusable "track saving/error state around an async mutation" shell,
/// the create/update/delete counterpart of [LoadableState]. Kept separate
/// from [LoadableState] so a screen can distinguish "still loading the
/// initial data" from "a save/delete is in flight" (e.g. to disable just a
/// submit button rather than the whole screen).
mixin SavableState on ChangeNotifier {
  bool _isSaving = false;
  String? _saveError;

  bool get isSaving => _isSaving;
  String? get saveError => _saveError;

  /// Runs [mutate], managing [isSaving] and [saveError] around it. Returns
  /// `true` on success, `false` if [mutate] threw (with [onError] used to
  /// produce the message stored in [saveError]).
  Future<bool> runSave({
    required Future<void> Function() mutate,
    required String Function(Object error, StackTrace stackTrace) onError,
  }) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();

    var succeeded = true;
    try {
      await mutate();
    } on Object catch (error, stackTrace) {
      succeeded = false;
      _saveError = onError(error, stackTrace);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    return succeeded;
  }

  /// Clears a previously-set [saveError] without touching [isSaving], e.g.
  /// when the user dismisses an error banner or edits the form again.
  void clearSaveError() {
    if (_saveError == null) return;
    _saveError = null;
    notifyListeners();
  }
}
