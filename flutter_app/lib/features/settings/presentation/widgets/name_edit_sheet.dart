import 'package:flutter/material.dart';

import '../../../profile/models/customer_profile.dart';
import '../../../profile/presentation/profile_edit_controller.dart';
import 'edit_field_sheet.dart';

/// The "Edit name" bottom sheet shown from Settings → Account → Name.
///
/// A thin [EditFieldSheet] configuration: first/last name fields prefilled
/// from [profile], saved through [controller]'s `updateName`. Kept as its
/// own widget purely to keep this field-specific wiring out of
/// `SettingsScreen`'s build method — [EditFieldSheet] itself still owns the
/// text controllers (see its doc comment) so there's no change to that
/// dispose-during-close-animation fix.
class NameEditSheet extends StatelessWidget {
  const NameEditSheet({
    super.key,
    required this.profile,
    required this.controller,
  });

  final CustomerProfile? profile;
  final ProfileEditController controller;

  @override
  Widget build(BuildContext context) {
    return EditFieldSheet(
      title: 'Edit name',
      controller: controller,
      fields: [
        EditFieldSpec(
          initialValue: profile?.firstName ?? '',
          label: 'First name',
          textCapitalization: TextCapitalization.words,
          prefixIcon: Icons.person_outline,
          errorMessages: const ['Enter your first name.'],
        ),
        EditFieldSpec(
          initialValue: profile?.lastName ?? '',
          label: 'Last name',
          textCapitalization: TextCapitalization.words,
          prefixIcon: Icons.person_outline,
          errorMessages: const ['Enter your last name.'],
        ),
      ],
      onSave: (values) =>
          controller.updateName(firstName: values[0], lastName: values[1]),
    );
  }
}
