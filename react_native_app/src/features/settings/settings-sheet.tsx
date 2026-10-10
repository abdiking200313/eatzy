import type { ReactNode } from 'react';
import { KeyboardAvoidingView, Modal, Platform, Pressable, View } from 'react-native';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, spacing } from '@/theme/tokens';

export type SettingsSheetProps = {
  visible: boolean;
  onDismiss: () => void;
  children: ReactNode;
};

/**
 * The RN stand-in for the Settings screen's `showModalBottomSheet` calls
 * (`isScrollControlled`, `showDragHandle`, top corners rounded to
 * `TwRadius.hero`): a slide-up `Modal` anchored to the bottom, dismissed by
 * tapping the scrim or the platform back gesture, and lifted above the
 * keyboard the way Dart's `viewInsets.bottom` padding lifts it.
 */
export function SettingsSheet({ visible, onDismiss, children }: SettingsSheetProps) {
  const colors = useSemanticColors();
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onDismiss}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} className="flex-1 justify-end">
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Dismiss"
          onPress={onDismiss}
          style={{ backgroundColor: 'rgba(0,0,0,0.4)' }}
          className="absolute inset-0"
        />
        <View
          style={{
            backgroundColor: colors.card,
            borderTopLeftRadius: radius.hero,
            borderTopRightRadius: radius.hero,
            paddingTop: spacing.x3,
          }}>
          <View
            style={{ width: 32, height: 4, borderRadius: 2, backgroundColor: colors.borderStrong, marginBottom: spacing.x2 }}
            className="self-center"
          />
          {children}
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}
