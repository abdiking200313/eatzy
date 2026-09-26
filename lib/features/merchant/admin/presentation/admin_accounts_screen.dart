import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/tailwind.dart';
import '../models/admin_account.dart';
import 'admin_accounts_controller.dart';

/// Admin-only "Accounts" screen (requested directly by the app owner,
/// 2026-09-18, replacing hand-editing `profiles.role` in the Supabase SQL
/// editor): a searchable, paginated list of every account with its name,
/// email, and a role dropdown. Picking a different role asks for
/// confirmation, then saves. It is the only thing an admin sees in
/// [MerchantShell] -- but the actual authorization is enforced server-side
/// by the `admin_list_profiles` / `admin_set_profile_role` RPCs (see
/// `supabase/migrations/20260922000000_add_admin_list_profiles_rpc.sql`),
/// not by this screen being hard to reach.
class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key, this.controller, this.currentUserId});

  /// Overridable for tests; defaults to a real Supabase-backed controller.
  final AdminAccountsController? controller;

  /// The signed-in admin's own `profiles.id`. Their row's dropdown is
  /// disabled so an admin can't strand themselves by demoting the account
  /// they are using. Defaults to the current Supabase session's user id.
  final String? currentUserId;

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  static const _roles = ['customer', 'merchant', 'admin'];
  static const _searchDebounce = Duration(milliseconds: 350);
  static const _loadMoreThreshold = 240.0;

  late final AdminAccountsController _controller =
      widget.controller ??
      AdminAccountsController.supabase(Supabase.instance.client);
  late final bool _ownsController = widget.controller == null;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  String? get _currentUserId =>
      widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      _searchDebounce,
      () => unawaited(_controller.load(value)),
    );
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      unawaited(_controller.loadMore());
    }
  }

  Future<void> _confirmRoleChange(AdminAccount account, String newRole) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Change ${account.displayName}\'s role?'),
        content: Text(
          newRole == 'admin'
              ? '${account.displayName} will be able to manage every '
                    "account's role, including granting or removing other "
                    'admins.'
              : 'This changes ${account.displayName} from '
                    '${account.role} to $newRole.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final succeeded = await _controller.setRole(account.id, newRole);
    if (!mounted) return;
    final message = succeeded
        ? '${account.displayName} is now $newRole.'
        : _controller.saveError ?? 'The role could not be changed.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TwSpacing.screenX,
            TwSpacing.x4,
            TwSpacing.screenX,
            TwSpacing.x2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Accounts', style: textTheme.titleLarge),
              const SizedBox(height: TwSpacing.x1),
              Text(
                'Change what each account can do. Customers shop, merchants '
                'run a store, admins manage accounts.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: TwSpacing.x3),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Search by name or email',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _buildBody(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final controller = _controller;
    final accounts = controller.accounts;

    if (controller.isLoading && accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TwSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: TwSpacing.x3),
              OutlinedButton(
                onPressed: () => unawaited(controller.load(controller.query)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (accounts.isEmpty) {
      return Center(
        child: Text(
          controller.query.isEmpty
              ? 'No accounts yet.'
              : 'No accounts match "${controller.query}".',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final showFooter =
        controller.hasMore ||
        controller.isLoadingMore ||
        controller.loadMoreError != null;

    return Column(
      children: [
        if (controller.isLoading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              TwSpacing.screenX,
              TwSpacing.x2,
              TwSpacing.screenX,
              TwSpacing.x4,
            ),
            itemCount: accounts.length + (showFooter ? 1 : 0),
            itemBuilder: (context, index) => index < accounts.length
                ? _buildAccountCard(context, accounts[index])
                : _buildFooter(context),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final controller = _controller;
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: TwSpacing.x4),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TwSpacing.x2),
      child: Column(
        children: [
          if (controller.loadMoreError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: TwSpacing.x1),
              child: Text(
                controller.loadMoreError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => unawaited(controller.loadMore()),
            child: Text(
              controller.loadMoreError != null ? 'Try again' : 'Load more',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, AdminAccount account) {
    final textTheme = Theme.of(context).textTheme;
    final isSelf = account.id == _currentUserId;
    final isSaving = _controller.savingId == account.id;
    final roles = _roles.contains(account.role)
        ? _roles
        : [..._roles, account.role];

    return Card(
      margin: const EdgeInsets.only(bottom: TwSpacing.x3),
      child: Padding(
        padding: const EdgeInsets.all(TwSpacing.x4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.displayName,
                          style: textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: TwSpacing.x2),
                        Text('You', style: textTheme.labelMedium),
                      ],
                    ],
                  ),
                  if (account.email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      account.email,
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: TwSpacing.x3),
            if (isSaving)
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              DropdownButton<String>(
                key: ValueKey('role-${account.id}'),
                value: account.role,
                items: [
                  for (final role in roles)
                    DropdownMenuItem(value: role, child: Text(_label(role))),
                ],
                // Controlled by `account.role`, so cancelling the dialog
                // needs no revert: the dropdown never moved.
                onChanged: isSelf || _controller.isSaving
                    ? null
                    : (value) {
                        if (value == null || value == account.role) return;
                        unawaited(_confirmRoleChange(account, value));
                      },
              ),
          ],
        ),
      ),
    );
  }

  static String _label(String role) =>
      role.isEmpty ? role : '${role[0].toUpperCase()}${role.substring(1)}';
}
