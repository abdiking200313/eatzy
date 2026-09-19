import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/shared/presentation/loadable_state_mixin.dart';
import '../data/admin_accounts_repository.dart';
import '../models/admin_account.dart';

/// `ChangeNotifier` controller for the admin-only "Accounts" screen
/// (requested directly by the app owner, 2026-09-18), following this repo's
/// existing pattern (e.g. `MerchantStoreController`): a `ChangeNotifier`
/// with an injected Supabase-backed repository, not a new state-management
/// framework. [SavableState] backs the role change.
///
/// The list's loading state is tracked here rather than with
/// [LoadableState]: search results arrive out of order as the admin types,
/// and [LoadableState.runLoad] would let a stale, slower response clear
/// `isLoading` (or set an error) while a newer search is still in flight.
class AdminAccountsController extends ChangeNotifier with SavableState {
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

  /// Accounts fetched per page.
  static const pageSize = 25;

  final AdminAccountsRepository _repository;

  final List<AdminAccount> _accounts = [];
  String _query = '';
  bool _hasMore = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _loadError;
  String? _loadMoreError;
  String? _savingId;

  /// Bumped by every [load]; a response tagged with an older id is discarded.
  int _generation = 0;

  /// The accounts loaded so far for the current [query], newest first.
  List<AdminAccount> get accounts => List.unmodifiable(_accounts);

  /// The trimmed search text the current [accounts] were loaded for.
  String get query => _query;

  /// Whether another page is available from [loadMore].
  bool get hasMore => _hasMore;

  /// Whether a first-page [load] is in flight.
  bool get isLoading => _isLoading;

  /// Whether a [loadMore] page fetch is in flight.
  bool get isLoadingMore => _isLoadingMore;

  /// Why the last [load] failed, or `null`.
  String? get loadError => _loadError;

  /// Why the last [loadMore] failed, or `null`.
  String? get loadMoreError => _loadMoreError;

  /// The id of the account whose role change is in flight, or `null`.
  String? get savingId => _savingId;

  /// Loads the first page of accounts matching [query] (all accounts when
  /// empty), replacing whatever was loaded before. Any older in-flight
  /// [load]/[loadMore] response is discarded.
  Future<void> load([String query = '']) async {
    final generation = ++_generation;
    _query = query.trim();
    _isLoading = true;
    _isLoadingMore = false;
    _loadError = null;
    _loadMoreError = null;
    notifyListeners();

    try {
      final rows = await _repository.listAccounts(
        search: _query,
        limit: pageSize + 1,
        offset: 0,
      );
      if (generation != _generation) return;
      _accounts
        ..clear()
        ..addAll(rows.take(pageSize));
      _hasMore = rows.length > pageSize;
    } on Object catch (error, stackTrace) {
      if (generation != _generation) return;
      debugPrint('AdminAccountsController.load failed: $error\n$stackTrace');
      _accounts.clear();
      _hasMore = false;
      _loadError = error is AdminAccountsException
          ? error.message
          : 'The accounts could not be loaded. Please try again.';
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Appends the next page for the current [query]. No-op when there is
  /// nothing more to load or a fetch is already running.
  Future<void> loadMore() async {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    final generation = _generation;
    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final rows = await _repository.listAccounts(
        search: _query,
        limit: pageSize + 1,
        offset: _accounts.length,
      );
      if (generation != _generation) return;
      _accounts.addAll(rows.take(pageSize));
      _hasMore = rows.length > pageSize;
    } on Object catch (error, stackTrace) {
      if (generation != _generation) return;
      debugPrint(
        'AdminAccountsController.loadMore failed: $error\n$stackTrace',
      );
      _loadMoreError = error is AdminAccountsException
          ? error.message
          : 'More accounts could not be loaded. Please try again.';
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Sets account [profileId]'s role to [newRole]. Returns `false` (no-op)
  /// if that account isn't currently loaded, or if the server rejects the
  /// change (see [saveError]); on success the loaded account reflects the
  /// new role without a re-fetch.
  Future<bool> setRole(String profileId, String newRole) async {
    if (!_accounts.any((account) => account.id == profileId)) return false;
    _savingId = profileId;
    final succeeded = await runSave(
      mutate: () async {
        await _repository.setRole(profileId: profileId, newRole: newRole);
        final index = _accounts.indexWhere((a) => a.id == profileId);
        if (index >= 0) {
          _accounts[index] = _accounts[index].copyWith(role: newRole);
        }
      },
      onError: (error, stackTrace) {
        debugPrint(
          'AdminAccountsController.setRole failed: $error\n$stackTrace',
        );
        if (error is AdminAccountsException) return error.message;
        return 'The role could not be changed. Please try again.';
      },
    );
    _savingId = null;
    notifyListeners();
    return succeeded;
  }
}
