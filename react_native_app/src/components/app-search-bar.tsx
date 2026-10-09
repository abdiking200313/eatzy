import { MaterialIcons } from '@expo/vector-icons';
import { Pressable, Text, TextInput, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, spacing } from '@/theme/tokens';

// `AppSearchBar.height` in app_search_bar.dart.
const HEIGHT = spacing.x12;

export type AppSearchBarEditableProps = {
  hintText: string;
  value: string;
  onChangeText: (text: string) => void;
  /** Replaces the default clear behavior (clearing and reporting `''`
   * through `onChangeText`). */
  onClear?: () => void;
  backgroundColor?: string;
  onPress?: never;
};

export type AppSearchBarTapToOpenProps = {
  hintText: string;
  onPress: () => void;
  backgroundColor?: string;
  value?: never;
  onChangeText?: never;
  onClear?: never;
};

/**
 * Ports flutter_app/lib/widgets/app_search_bar.dart's `AppSearchBar`: the
 * app's one search bar, a soft grey-filled, borderless pill used by every
 * customer-facing search.
 *
 * Two mutually exclusive modes, enforced at the type level in place of the
 * Dart `assert`:
 * - **Editable** (`value`/`onChangeText`): a real text input with a clear
 *   button that appears while there is text.
 * - **Tap-to-open** (`onPress`, no `value`): a read-only stand-in that
 *   looks identical and navigates somewhere when tapped, e.g. the home
 *   header opening Explore.
 */
export type AppSearchBarProps = AppSearchBarEditableProps | AppSearchBarTapToOpenProps;

export function AppSearchBar(props: AppSearchBarProps) {
  const colors = useSemanticColors();
  const backgroundColor = props.backgroundColor ?? colors.searchFill;
  const isEditable = props.value !== undefined;

  const handleClear = () => {
    if (!isEditable) return;
    if (props.onClear) {
      props.onClear();
      return;
    }
    props.onChangeText('');
  };

  const content = (
    <View
      style={{ height: HEIGHT, backgroundColor, borderRadius: radius.input }}
      className="flex-row items-center overflow-hidden">
      <MaterialIcons name="search" size={22} color={colors.textMuted} style={{ marginLeft: spacing.x4 }} />
      <View style={{ marginLeft: spacing.x3 }} className="flex-1">
        {isEditable ? (
          <TextInput
            value={props.value}
            onChangeText={props.onChangeText}
            placeholder={props.hintText}
            placeholderTextColor={colors.textMuted}
            returnKeyType="search"
            className="text-textBase font-outfitRegular text-text"
          />
        ) : (
          <Text
            style={{ color: colors.textMuted }}
            className="text-textBase font-outfitRegular"
            numberOfLines={1}>
            {props.hintText}
          </Text>
        )}
      </View>
      {isEditable && props.value.length > 0 ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Clear"
          onPress={handleClear}
          style={{ width: HEIGHT, height: HEIGHT }}
          className="items-center justify-center">
          <MaterialIcons name="clear" size={20} color={colors.textMuted} />
        </Pressable>
      ) : (
        <View style={{ width: spacing.x4 }} />
      )}
    </View>
  );

  if (isEditable) {
    return content;
  }

  return (
    <Pressable accessibilityRole="button" onPress={props.onPress} className="active:opacity-80">
      {content}
    </Pressable>
  );
}
