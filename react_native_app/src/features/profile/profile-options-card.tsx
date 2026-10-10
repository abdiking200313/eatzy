import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Fragment } from 'react';
import { Pressable, Text, View } from 'react-native';

import { OutlinedCard } from '@/components/outlined-card';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { radius, spacing } from '@/theme/tokens';

import type { ProfileOption } from './profile-option';

export type ProfileOptionsCardProps = {
  options: readonly ProfileOption[];
  /**
   * Overrides each row's default `router.push(option.route)` navigation
   * when set, letting the caller react to the tap -- e.g. `ProfileScreen`
   * reloading its header after a trip through Settings. Mirrors the Dart
   * `onOptionTap` parameter.
   */
  onOptionPress?: (option: ProfileOption) => void;
};

/**
 * Ports `flutter_app/lib/features/profile/presentation/widgets/profile_options_card.dart`'s
 * `ProfileOptionsCard` (issue #399 / P8-03): one outlined card holding
 * every option row, with dividers between rows.
 */
export function ProfileOptionsCard({ options, onOptionPress }: ProfileOptionsCardProps) {
  const colors = useSemanticColors();
  return (
    <OutlinedCard padding={0} borderRadius={radius.card}>
      {options.map((option, index) => (
        <Fragment key={option.title}>
          <ProfileOptionRow
            option={option}
            onPress={
              option.route === undefined
                ? undefined
                : () => {
                    if (onOptionPress) {
                      onOptionPress(option);
                    } else if (option.route !== undefined) {
                      router.push(option.route);
                    }
                  }
            }
          />
          {index < options.length - 1 && <View style={{ height: 1, backgroundColor: colors.border }} />}
        </Fragment>
      ))}
    </OutlinedCard>
  );
}

export type LogoutCardProps = {
  onPress: () => void;
};

/** Ports the same file's `LogoutCard`: a single destructive "Logout" row in its own card. */
export function LogoutCard({ onPress }: LogoutCardProps) {
  return (
    <OutlinedCard padding={0} borderRadius={radius.card}>
      <ProfileOptionRow option={{ title: 'Logout', icon: 'logout' }} onPress={onPress} isDestructive />
    </OutlinedCard>
  );
}

function ProfileOptionRow({
  option,
  onPress,
  isDestructive = false,
}: {
  option: ProfileOption;
  onPress?: () => void;
  isDestructive?: boolean;
}) {
  const colors = useSemanticColors();
  const foreground = isDestructive ? colors.error : colors.text;
  return (
    <Pressable
      accessibilityRole={onPress ? 'button' : undefined}
      accessibilityLabel={option.title}
      disabled={!onPress}
      onPress={onPress}
      style={{ minHeight: 58, paddingHorizontal: spacing.x4, paddingVertical: spacing.x2 }}
      className="flex-row items-center active:opacity-70">
      <View
        style={{
          width: 42,
          height: 42,
          borderRadius: 13,
          backgroundColor: isDestructive ? colors.errorSoft : colors.primarySoft,
        }}
        className="items-center justify-center">
        <MaterialIcons name={option.icon} size={20} color={foreground} />
      </View>
      <Text style={{ marginLeft: spacing.x4, color: foreground }} className="flex-1 text-fontBoldSm">
        {option.title}
      </Text>
      {option.trailingText !== undefined && <Text className="text-textXs text-textMuted">{option.trailingText}</Text>}
      <View style={{ marginLeft: spacing.x2 }}>
        <MaterialIcons name="arrow-forward" size={18} color={isDestructive ? colors.error : colors.textMuted} />
      </View>
    </Pressable>
  );
}
