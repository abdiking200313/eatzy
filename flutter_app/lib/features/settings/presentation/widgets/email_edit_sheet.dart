import 'package:flutter/material.dart';

import '../../../profile/presentation/profile_edit_controller.dart';
import 'edit_field_sheet.dart';

/// The "Edit email address" bottom sheet shown from Settings → Account →
/// Email Address. See [NameEditSheet]'s doc comment for why this is split
/// out as its own thin [EditFieldSheet] configuration.
///
/// A successful save here only means Supabase accepted the change request
/// (see [ProfileEditResult]'s doc comment) — the caller, not this widget,
/// is responsible for telling the user to check their inbox.
class EmailEditSheet extends StatelessWidget {
  const EmailEditSheet({
    super.key,
    required this.email,
    required this.controller,
  });

  final String? email;
  final ProfileEditController controller;

  @override
  Widget build(BuildContext context) {
    return EditFieldSheet(
      title: 'Edit email address',
      controller: controller,
      helperText:
          "We'll send a confirmation link to your new email address. "
          "The change only applies once you confirm it.",
      fields: [
        EditFieldSpec(
          initialValue: email ?? '',
          label: 'Email address',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          errorMessages: const [
            'Enter your email address.',
            'Please enter a valid email address.',
            "That's already your email address.",
          ],
        ),
      ],
      onSave: (values) => controller.updateEmail(values[0]),
    );
  }
}
