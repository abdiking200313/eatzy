import { MaterialIcons } from '@expo/vector-icons';
import { Fragment } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { OutlinedCard } from '@/components/outlined-card';
import { StatusPill } from '@/components/status-pill';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { useServiceTheme } from '@/hooks/use-service-theme';
import { radius, spacing } from '@/theme/tokens';

/**
 * Ports flutter_app/lib/features/addresses/presentation/addresses_screen.dart
 * (issue #545).
 *
 * Faithful to Flutter: the list is hardcoded demo data and every button is a
 * no-op. Flutter's screen does not consume `DeliveryAddressRepository` yet
 * (that file's own doc comment says so), so neither does this one -- the
 * ported repository in `./api/delivery-address-repository.ts` is ready for
 * when the feature returns. Delivery addresses are out of scope (owner
 * decision, 2026-09-25), so the route stays deep-link-only: nothing in the
 * app links here.
 *
 * Sits outside any service module, so Flutter's `context.serviceColors`
 * resolves to the neutral platform palette (`useServiceTheme('unknown')`).
 */

export interface SavedAddressDemo {
  label: string;
  address: string;
  isDefault?: boolean;
}

/** Ports `AddressesScreen._addresses`, verbatim. */
export const DEMO_ADDRESSES: readonly SavedAddressDemo[] = [
  { label: 'Home', address: 'Maka Al-Mukarama Road\nHodan, Mogadishu, Somalia', isDefault: true },
  { label: 'Work', address: 'Airport Road\nWadajir, Mogadishu, Somalia' },
  { label: 'Family', address: 'Taleex Road\nHodan, Mogadishu, Somalia' },
];

// Flutter's buttons all have `onPressed: () {}` -- enabled, but inert.
const noop = () => {};

export function AddressesScreen() {
  const colors = useSemanticColors();
  return (
    <AppScaffold title="Saved Addresses" showBackButton>
      <ScrollView
        contentContainerStyle={{
          paddingHorizontal: spacing.x5,
          paddingTop: spacing.x5,
          paddingBottom: spacing.x6,
        }}>
        {/* Flutter `FilledButton` (theme: primary, min 44px, TwRadius.lg). */}
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Add New Address"
          onPress={noop}
          style={{ backgroundColor: colors.primary, minHeight: 44, borderRadius: radius.lg, paddingHorizontal: spacing.x6 }}
          className="w-full flex-row items-center justify-center active:opacity-80">
          <Text
            numberOfLines={1}
            style={{ color: colors.onPrimary }}
            className="shrink text-button font-outfitSemiBold">
            Add New Address
          </Text>
          <View style={{ width: spacing.x2 }} />
          <MaterialIcons name="add" size={19} color={colors.onPrimary} />
        </Pressable>

        <View style={{ height: spacing.sectionGap }} />

        <OutlinedCard testID="addresses-list" padding={0} borderRadius={radius.card}>
          {DEMO_ADDRESSES.map((address, index) => (
            <Fragment key={address.label}>
              <AddressRow address={address} />
              {index < DEMO_ADDRESSES.length - 1 && (
                <View testID="addresses-list-divider" style={{ height: 1, backgroundColor: colors.border }} />
              )}
            </Fragment>
          ))}
        </OutlinedCard>
      </ScrollView>
    </AppScaffold>
  );
}

/** Ports `_AddressRow`. */
function AddressRow({ address }: { address: SavedAddressDemo }) {
  const colors = useSemanticColors();
  const palette = useServiceTheme('unknown');
  return (
    <View testID={`address-row-${address.label}`} style={{ paddingHorizontal: spacing.x4, paddingVertical: spacing.x3_5 }}>
      <View className="flex-row items-center justify-between">
        <Text className="text-fontBoldBase font-outfitSemiBold text-text">{address.label}</Text>
        {address.isDefault && (
          <StatusPill label="Default" backgroundColor={palette.soft} foregroundColor={palette.accent} fontSize={11} />
        )}
      </View>
      <View style={{ height: spacing.x2 }} />
      <Text style={{ lineHeight: 15 * 1.5 }} className="text-textSm font-outfitRegular text-textMuted">
        {address.address}
      </Text>
      <View style={{ height: spacing.x3_5 }} />
      <View className="flex-row items-center">
        <View className="flex-1">
          {/* Flutter `OutlinedButton`: disabled ("Default Address") for the default row. */}
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={address.isDefault ? 'Default Address' : 'Set as Default'}
            accessibilityState={{ disabled: !!address.isDefault }}
            disabled={address.isDefault}
            onPress={noop}
            style={{
              minHeight: 44,
              borderRadius: radius.lg,
              borderWidth: 1,
              borderColor: address.isDefault ? colors.border : colors.borderStrong,
              paddingHorizontal: spacing.x3,
            }}
            className="items-center justify-center active:opacity-70">
            <Text
              numberOfLines={1}
              style={{ color: address.isDefault ? colors.textMuted : colors.primary }}
              className="text-button font-outfitSemiBold">
              {address.isDefault ? 'Default Address' : 'Set as Default'}
            </Text>
          </Pressable>
        </View>
        <View style={{ width: spacing.x3 }} />
        <OutlinedIconButton label={`Edit ${address.label}`} icon="edit" color={palette.accent} />
        <View style={{ width: spacing.iconButtonGap }} />
        <OutlinedIconButton label={`Delete ${address.label}`} icon="delete-outline" color={colors.error} />
      </View>
    </View>
  );
}

/** Flutter `IconButton.outlined` (44px, `colorScheme.outline` border); its `tooltip` becomes the accessibility label. */
function OutlinedIconButton({
  label,
  icon,
  color,
}: {
  label: string;
  icon: keyof typeof MaterialIcons.glyphMap;
  color: string;
}) {
  const colors = useSemanticColors();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={noop}
      style={{ width: 44, height: 44, borderRadius: radius.full, borderWidth: 1, borderColor: colors.borderStrong }}
      className="items-center justify-center active:opacity-70">
      <MaterialIcons name={icon} size={18} color={color} />
    </Pressable>
  );
}
