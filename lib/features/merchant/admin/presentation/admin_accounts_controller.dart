import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/shared/presentation/loadable_state_mixin.dart';
import '../data/admin_accounts_repository.dart';
import '../models/admin_account_lookup.dart';

/// `ChangeNotifier` controller for the admin-only "promote an account"
/// screen (requested directly by the app owner, 2026-09-18), following this
/// repo's existing pattern (e.g. `MerchantStoreController`): a
/// `ChangeNotifier` with an injected Supabase-backed repository, not a new
/// state-management framework. [LoadableState] backs the email lookup,
/// [SavableState] backs the role change.
class AdminAccountsController extends ChangeNotifier
    with LoadableState, SavableState {
  // `repository` is a named parameter tests construct directly (e.g.
  // `AdminAccountsController(repository: FakeAdminAccountsRepository())`);
  // an initializing formal would force the external name to the private
  // `_repository`.
  AdminAccountsController({required AdminAccountsRepository repository})
    // ignore: prefer_initializing_formals
    : _repository = repository;

  factory AdminAccountsController.supabase(SupabaseClient client) =>
      AdminAccountsController(
        repository: SupabaseAdminAccountsRepository(client: client),
      );

  final AdminAccountsRepository _repository;

  AdminAccountLookup? _result;

  /// The most recent lookup's match, or `null` if the lookup found nothing,
  /// hasn't run yet, or failed. Distinguished from "not searched yet" by
  /// [loadError] and [isLoading] rather than a separate flag: a search that
  /// completed with no match has `loadError == null`, `isLoading == false`,
  /// and `result == null`, which the screen renders as "no account found".
  AdminAccountLookup? get result => _result;

  /// Whether a lookup has completed (successfully or not) at least once,
  /// so the screen can distinguish its initial "search for an account"
  /// prompt from a completed search that found nothing.
  bool get hasSearched => _hasSearched;
  bool _hasSearched = false;

  /// Looks up the account signed up with [email]. On success, [result]
  /// holds the match (or `null` if none exists) and [hasSearched] becomes
  /// `true`. On failure, [result] is cleared and [loadError] carries the
  /// reason (see [AdminAccountsException]).
  Future<void> lookup(String email) async {
    await runLoad(
      fetch: () async {
        _result = null;
        _hasSearched = false;
        _result = await _repository.lookupByEmail(email);
        _hasSearched = true;
      },
      onError: (error, stackTrace) {
        debugPrint(
          'AdminAccountsController.lookup failed: $error\n$stackTrace',
        );
        if (error is AdminAccountsException || error is FormatException) {
          return error.toString();
        }
        return 'The lookup could not be completed. Please try again.';
      },
    );
  }

  /// Sets the currently-looked-up account's role to [newRole]. Returns
  /// `false` immediately (no-op) if no account is currently loaded. On
  /// success, [result] reflects the new role so the screen updates without
  /// a re-lookup.
  Future<bool> setRole(String newRole) {
    final current = _result;
    if (current == null) return Future.value(false);
    return runSave(
      mutate: () async {
        await _repository.setRole(profileId: current.id, newRole: newRole);
        _result = AdminAccountLookup(
          id: current.id,
          firstName: current.firstName,
          lastName: current.lastName,
          role: newRole,
        );
      },
      onError: (error, stackTrace) {
        debugPrint(
          'AdminAccountsController.setRole failed: $error\n$stackTrace',
        );
        if (error is AdminAccountsException) return error.message;
        return 'The role could not be changed. Please try again.';
      },
    );
  }

  /// Clears the current search result, e.g. so the screen can start a fresh
  /// lookup after handling the previous one.
  void clear() {
    if (_result == null && !_hasSearched) return;
    _result = null;
    _hasSearched = false;
    notifyListeners();
  }
}
