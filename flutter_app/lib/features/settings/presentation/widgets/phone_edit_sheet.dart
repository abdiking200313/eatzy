import 'package:flutter/material.dart';

import '../../../profile/models/customer_profile.dart';
import '../../../profile/presentation/profile_edit_controller.dart';
import 'edit_field_sheet.dart';

/// The "Edit phone number" bottom sheet shown from Settings → Account →
/// Phone Number. See [NameEditSheet]'s doc comment for why this is split
/// out as its own thin [EditFieldSheet] configuration.
class PhoneEditSheet extends StatelessWidget {
  const PhoneEditSheet({
    super.key,
    required this.profile,
    required this.controller,
  });

  final CustomerProfile? profile;
  final ProfileEditController controller;

  @override
  Widget build(BuildContext context) {
    return EditFieldSheet(
      title: 'Edit phone number',
      controller: controller,
      fields: [
        EditFieldSpec(
          initialValue: profile?.phone ?? '',
          label: 'Phone number',
          hintText: '+252 …',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          errorMessages: const [
            'Enter your phone number.',
            'Please enter a valid phone number.',
          ],
        ),
      ],
      onSave: (values) => controller.updatePhone(values[0]),
    );
  }
}
