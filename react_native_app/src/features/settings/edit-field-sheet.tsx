import type { MaterialIcons } from '@expo/vector-icons';
import { useState } from 'react';
import { Text, View, type KeyboardTypeOptions, type TextInputProps } from 'react-native';

import { AppTextField } from '@/components/app-text-field';
import { GradientActionButton } from '@/components/gradient-action-button';
import {
  useProfileEditState,
  type ProfileEditController,
  type ProfileEditResult,
} from '@/features/profile/profile-edit-controller';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { spacing } from '@/theme/tokens';

/** Mirrors `EditFieldSpec`: one text field rendered inside an {@link EditFieldSheet}. */
export interface EditFieldSpec {
  initialValue?: string;
  label: string;
  hintText?: string;
  keyboardType?: KeyboardTypeOptions;
  autoCapitalize?: TextInputProps['autoCapitalize'];
  prefixIcon?: keyof typeof MaterialIcons.glyphMap;
  /**
   * The subset of the controller's `fieldErrors` messages that belong to
   * this field; the first one present is shown under it.
   */
  errorMessages?: readonly string[];
}

export type EditFieldSheetProps = {
  title: string;
  fields: readonly EditFieldSpec[];
  controller: ProfileEditController;
  /** Receives the current text of each field, in `fields` order. */
  onSave: (values: string[]) => Promise<ProfileEditResult>;
  /** Called with the result of a successful save -- the RN stand-in for the Dart sheet popping itself with that result. */
  onSaved: (result: ProfileEditResult) => void;
  helperText?: string;
  saveLabel?: string;
};

/**
 * Ports `flutter_app/lib/features/settings/presentation/widgets/edit_field_sheet.dart`
 * (issue #400 / P8-04): a reusable bottom-sheet form for editing one or more
 * profile fields through a {@link ProfileEditController}.
 *
 * On a successful save it hands the result to `onSaved` (the caller closes
 * the sheet and confirms); on failure it stays open and re-renders with the
 * controller's field/general errors. The sheet owns its own field text, the
 * way the Dart sheet owns its `TextEditingController`s.
 */
export function EditFieldSheet({
  title,
  fields,
  controller,
  onSave,
  onSaved,
  helperText,
  saveLabel = 'Save',
}: EditFieldSheetProps) {
  const colors = useSemanticColors();
  const { isSubmitting, submissionError, fieldErrors } = useProfileEditState(controller);
  const [values, setValues] = useState<string[]>(() => fields.map((field) => field.initialValue ?? ''));

  const handleSave = async () => {
    const result = await onSave(values);
    if (result.isSuccess) onSaved(result);
  };

  const matchedErrors = new Set<string>();
  const fieldErrorTexts = fields.map((field) => {
    const match = (field.errorMessages ?? []).find((message) => fieldErrors.includes(message));
    if (match !== undefined) matchedErrors.add(match);
    return match;
  });
  const unmatchedFieldError = fieldErrors.find((message) => !matchedErrors.has(message));
  const generalError =
    submissionError != null && submissionError !== '' ? submissionError : (unmatchedFieldError ?? null);

  return (
    <View style={{ paddingHorizontal: spacing.x5, paddingTop: spacing.x2, paddingBottom: spacing.x6 }}>
      <Text className="text-textXl font-outfitBold text-text">{title}</Text>
      <View style={{ height: spacing.x3_5 }} />
      {helperText !== undefined && (
        <>
          <Text className="text-textSm font-outfitRegular text-textMuted">{helperText}</Text>
          <View style={{ height: spacing.x4 }} />
        </>
      )}
      {fields.map((field, index) => (
        <View key={field.label} style={{ marginTop: index === 0 ? 0 : spacing.x3 }}>
          <AppTextField
            label={field.label}
            hint={field.hintText ?? ''}
            value={values[index]}
            onChangeText={(text) => setValues((current) => current.map((value, i) => (i === index ? text : value)))}
            keyboardType={field.keyboardType}
            autoCapitalize={field.autoCapitalize}
            prefixIcon={field.prefixIcon}
            readOnly={isSubmitting}
          />
          {fieldErrorTexts[index] !== undefined && (
            <Text style={{ marginTop: spacing.x1, color: colors.error }} className="text-textXs font-outfitMedium">
              {fieldErrorTexts[index]}
            </Text>
          )}
        </View>
      ))}
      {generalError != null && (
        <Text style={{ marginTop: spacing.x3, color: colors.error }} className="text-textSm font-outfitRegular">
          {generalError}
        </Text>
      )}
      <View style={{ height: spacing.x5 }} />
      <GradientActionButton label={isSubmitting ? 'Saving...' : saveLabel} onPress={isSubmitting ? null : handleSave} />
    </View>
  );
}
