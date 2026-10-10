/**
 * Ports the three thin `EditFieldSheet` configurations from
 * `flutter_app/lib/features/settings/presentation/widgets/`
 * (`name_edit_sheet.dart`, `phone_edit_sheet.dart`, `email_edit_sheet.dart`;
 * issue #400 / P8-04). Field labels, hints, and the error messages each
 * field claims are copied verbatim -- `EditFieldSheet` places an error under
 * a field by matching these exact strings.
 */
import type { CustomerProfile } from '@/features/profile/api/customer-profile';
import type { ProfileEditController, ProfileEditResult } from '@/features/profile/profile-edit-controller';

import { EditFieldSheet } from './edit-field-sheet';

type ProfileSheetProps = {
  profile: CustomerProfile | null;
  controller: ProfileEditController;
  onSaved: (result: ProfileEditResult) => void;
};

/** Settings → Account → Name. */
export function NameEditSheet({ profile, controller, onSaved }: ProfileSheetProps) {
  return (
    <EditFieldSheet
      title="Edit name"
      controller={controller}
      onSaved={onSaved}
      fields={[
        {
          initialValue: profile?.firstName ?? '',
          label: 'First name',
          autoCapitalize: 'words',
          prefixIcon: 'person-outline',
          errorMessages: ['Enter your first name.'],
        },
        {
          initialValue: profile?.lastName ?? '',
          label: 'Last name',
          autoCapitalize: 'words',
          prefixIcon: 'person-outline',
          errorMessages: ['Enter your last name.'],
        },
      ]}
      onSave={([firstName = '', lastName = '']) => controller.updateName({ firstName, lastName })}
    />
  );
}

/** Settings → Account → Phone Number. */
export function PhoneEditSheet({ profile, controller, onSaved }: ProfileSheetProps) {
  return (
    <EditFieldSheet
      title="Edit phone number"
      controller={controller}
      onSaved={onSaved}
      fields={[
        {
          initialValue: profile?.phone ?? '',
          label: 'Phone number',
          hintText: '+252 …',
          keyboardType: 'phone-pad',
          prefixIcon: 'phone',
          errorMessages: ['Enter your phone number.', 'Please enter a valid phone number.'],
        },
      ]}
      onSave={([phone = '']) => controller.updatePhone(phone)}
    />
  );
}

type EmailSheetProps = {
  email: string | null;
  controller: ProfileEditController;
  onSaved: (result: ProfileEditResult) => void;
};

/**
 * Settings → Account → Email Address. A successful save only means
 * Supabase accepted the change request -- the caller tells the user to
 * check their inbox.
 */
export function EmailEditSheet({ email, controller, onSaved }: EmailSheetProps) {
  return (
    <EditFieldSheet
      title="Edit email address"
      controller={controller}
      onSaved={onSaved}
      helperText="We'll send a confirmation link to your new email address. The change only applies once you confirm it."
      fields={[
        {
          initialValue: email ?? '',
          label: 'Email address',
          keyboardType: 'email-address',
          autoCapitalize: 'none',
          prefixIcon: 'mail-outline',
          errorMessages: [
            'Enter your email address.',
            'Please enter a valid email address.',
            "That's already your email address.",
          ],
        },
      ]}
      onSave={([newEmail = '']) => controller.updateEmail(newEmail)}
    />
  );
}
