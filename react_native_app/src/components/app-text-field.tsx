import { MaterialIcons } from '@expo/vector-icons';
import { useState } from 'react';
import {
  Pressable,
  Text,
  TextInput,
  View,
  type KeyboardTypeOptions,
  type TextInputProps,
} from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, rawColors, spacing } from '@/theme/tokens';

export type AppTextFieldProps = {
  hint: string;
  label?: string;
  value?: string;
  onChangeText?: (text: string) => void;
  keyboardType?: KeyboardTypeOptions;
  prefixIcon?: keyof typeof MaterialIcons.glyphMap;
  obscureText?: boolean;
  textInputAction?: TextInputProps['returnKeyType'];
  /** RN's `autoComplete` is a single value, unlike Dart's `autofillHints`
   * list — pass the single closest hint. */
  autoComplete?: TextInputProps['autoComplete'];
  onSubmitted?: (text: string) => void;
  readOnly?: boolean;
  onPress?: () => void;
};

/**
 * Ports flutter_app/lib/widgets/app_widgets.dart's `AppTextField`: the
 * app's standard outlined text field, with a show/hide toggle for
 * `obscureText` and a `primary`-tinted prefix icon.
 *
 * Simplification: `label` renders as a static caption above the field
 * rather than Material's floating label (which animates into the border
 * once focused/filled) — there is no equivalent built into React Native's
 * `TextInput`, and a full floating-label re-implementation is out of scope
 * for this port.
 */
export function AppTextField({
  hint,
  label,
  value,
  onChangeText,
  keyboardType = 'default',
  prefixIcon,
  obscureText = false,
  textInputAction,
  autoComplete,
  onSubmitted,
  readOnly = false,
  onPress,
}: AppTextFieldProps) {
  const colors = useSemanticColors();
  const [isFocused, setIsFocused] = useState(false);
  const [isHidden, setIsHidden] = useState(obscureText);

  const field = (
    <View
      style={{
        backgroundColor: rawColors.white,
        borderRadius: radius.xl,
        borderWidth: isFocused ? 1.5 : 1,
        borderColor: isFocused ? colors.primary : colors.borderStrong,
        paddingHorizontal: spacing.x4,
        paddingVertical: spacing.x5,
      }}
      className="flex-row items-center">
      {prefixIcon && (
        <MaterialIcons
          name={prefixIcon}
          size={22}
          color={colors.primary}
          style={{ marginRight: spacing.x3 }}
        />
      )}
      <TextInput
        value={value}
        onChangeText={onChangeText}
        keyboardType={keyboardType}
        secureTextEntry={isHidden}
        returnKeyType={textInputAction}
        autoComplete={autoComplete}
        onSubmitEditing={(event) => onSubmitted?.(event.nativeEvent.text)}
        readOnly={readOnly}
        onFocus={() => setIsFocused(true)}
        onBlur={() => setIsFocused(false)}
        placeholder={hint}
        placeholderTextColor={colors.textMuted}
        pointerEvents={onPress ? 'none' : 'auto'}
        className="flex-1 text-textBase font-outfitRegular text-text"
      />
      {obscureText && (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={isHidden ? 'Show password' : 'Hide password'}
          onPress={() => setIsHidden((hidden) => !hidden)}>
          <MaterialIcons
            name={isHidden ? 'visibility' : 'visibility-off'}
            size={22}
            color={colors.textMuted}
          />
        </Pressable>
      )}
    </View>
  );

  return (
    <View>
      {label && (
        <Text
          style={{ marginBottom: spacing.x1 }}
          className="text-textSm font-outfitMedium text-textMuted">
          {label}
        </Text>
      )}
      {onPress ? (
        <Pressable accessibilityRole="button" onPress={onPress}>
          {field}
        </Pressable>
      ) : (
        field
      )}
    </View>
  );
}
