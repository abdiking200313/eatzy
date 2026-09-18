import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/theme.dart';
import '../models/admin_account_lookup.dart';
import 'admin_accounts_controller.dart';

/// Admin-only "promote an account" screen (requested directly by the app
/// owner, 2026-09-18, replacing hand-editing `profiles.role` in the
/// Supabase SQL editor): search for an account by its sign-up email, then
/// change its role. Only reachable from [MerchantShell]'s "Accounts"
/// destination, which only appears for a signed-in `admin` account --- but
/// the actual authorization is enforced server-side by the
/// `admin_lookup_profile_by_email` / `admin_set_profile_role` RPCs (see
/// `supabase/migrations/20260921020000_add_admin_role_management_rpcs.sql`),
/// not by this screen being hard to reach.
class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key, this.controller});

  /// Overridable for tests; defaults to a real Supabase-backed controller.
  final AdminAccountsController? controller;

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  late final AdminAccountsController _controller =
      widget.controller ??
      AdminAccountsController.supabase(Supabase.instance.client);
  late final bool _ownsController = widget.controller == null;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _emailController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // Keep the role picker's selection in sync with whichever account is
    // currently loaded, so switching to a new search (or a just-applied
    // change) doesn't leave a stale selection from a previous account.
    setState(() => _selectedRole = _controller.result?.role);
  }

  Future<void> _search() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    FocusScope.of(context).unfocus();
    await _controller.lookup(_emailController.text);
  }

  Future<void> _applyRoleChange(
    AdminAccountLookup account,
    String newRole,
  ) async {
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

    final succeeded = await _controller.setRole(newRole);
    if (succeeded && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.displayName} is now $newRole.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Change account roles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Search for an account by email, then grant or remove '
            'merchant/admin access.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Account email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter an email address.'
                        : null,
                    onFieldSubmitted: (_) => unawaited(_search()),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _controller.isLoading
                      ? null
                      : () => unawaited(_search()),
                  child: _controller.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          if (_controller.loadError != null) ...[
            const SizedBox(height: 12),
            Text(
              _controller.loadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_controller.hasSearched && _controller.loadError == null) ...[
            const SizedBox(height: 20),
            _buildResult(context),
          ],
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final account = _controller.result;
    if (account == null) {
      return Text(
        'No account found for that email.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final selectedRole = _selectedRole ?? account.role;
    final hasChange = selectedRole != account.role;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Current role: ${account.role}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'customer', label: Text('Customer')),
                ButtonSegment(value: 'merchant', label: Text('Merchant')),
                ButtonSegment(value: 'admin', label: Text('Admin')),
              ],
              selected: {selectedRole},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedRole = selection.first),
            ),
            if (_controller.saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                _controller.saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: hasChange && selectedRole == 'admin'
                  ? FilledButton.styleFrom(backgroundColor: TwColors.error)
                  : null,
              onPressed: !hasChange || _controller.isSaving
                  ? null
                  : () => unawaited(_applyRoleChange(account, selectedRole)),
              child: _controller.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply role change'),
            ),
          ],
        ),
      ),
    );
  }
}
