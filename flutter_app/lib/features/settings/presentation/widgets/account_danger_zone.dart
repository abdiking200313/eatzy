import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';

/// The Settings screen's bottom "Logout" / "Delete Account" actions.
///
/// [onDeleteAccountTap] is expected to own the confirmation dialog itself
/// (as the screen's existing `_confirmDeleteAccount` does) — this widget
/// just renders the two actions.
class AccountDangerZone extends StatelessWidget {
  const AccountDangerZone({
    super.key,
    required this.onLogoutTap,
    required this.onDeleteAccountTap,
  });

  final VoidCallback onLogoutTap;
  final VoidCallback onDeleteAccountTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrimaryButton(
          label: 'Logout',
          onPressed: onLogoutTap,
          color: TwColors.error,
        ),
        const SizedBox(height: TwSpacing.x3_5),
        Center(
          child: TextButton(
            onPressed: onDeleteAccountTap,
            child: const Text(
              'Delete Account',
              style: TextStyle(color: TwColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
