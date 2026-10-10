import { MaterialIcons } from '@expo/vector-icons';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AppScaffold } from './app-scaffold';
import { GradientActionButton } from './gradient-action-button';
import { LoadingState } from './loading-state';
import { OutlinedCard } from './outlined-card';
import { SectionTitle } from './section-title';
import { SummaryRow } from './summary-row';

import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { formatCents } from '@/platform/money/format';
import { radius, spacing } from '@/theme/tokens';

/**
 * Ports flutter_app/lib/widgets/checkout_view.dart's `CheckoutLine`: one
 * line of a `CheckoutView`/`CartView` order summary, e.g. "Bananas ×2" or
 * "Delivery fee". `amount` is integer cents.
 *
 * `isPending` marks a fee/tax line whose `amount` is not actually known yet
 * (e.g. `service_pricing` hasn't loaded): render it as "Calculated at
 * checkout" instead of a dollar figure via {@link checkoutLineDisplayValue},
 * so the client never shows a fabricated/guessed number. `amount` is
 * ignored when `isPending` is `true` (kept `0`); build one with
 * {@link pendingCheckoutLine} rather than setting this directly, mirroring
 * the Dart `CheckoutLine.pending` named constructor.
 */
export type CheckoutLine = {
  label: string;
  amount: number;
  isPending: boolean;
};

/** Ports `CheckoutLine`'s default (non-pending) constructor. */
export function checkoutLine(label: string, amount: number): CheckoutLine {
  return { label, amount, isPending: false };
}

/** Ports `CheckoutLine.pending`. */
export function pendingCheckoutLine(label: string): CheckoutLine {
  return { label, amount: 0, isPending: true };
}

/**
 * Ports `CheckoutLine.displayValue`: the value to actually display for this
 * line -- "Calculated at checkout" when `isPending`, otherwise `amount`
 * formatted as money.
 */
export function checkoutLineDisplayValue(line: CheckoutLine): string {
  return line.isPending ? 'Calculated at checkout' : formatCents(line.amount);
}

export type FeeSummaryRowProps = {
  label: string;
  value: string;
  isBold?: boolean;
};

/**
 * Ports flutter_app/lib/widgets/checkout_view.dart's `FeeSummaryRow`: a
 * fee/total summary row, visually matching `SummaryRow` but with the value
 * side wrapped so a much longer `CheckoutLine.pending` value ("Calculated
 * at checkout") shrinks and ellipsizes instead of overflowing a narrow
 * screen. Used in place of `SummaryRow` specifically for fee/tax/total
 * rows, which are the only ones that can ever be pending.
 */
export function FeeSummaryRow({ label, value, isBold = false }: FeeSummaryRowProps) {
  return (
    <View className="flex-row items-start">
      <Text
        className={`flex-1 text-text ${
          isBold ? 'text-fontBoldBase font-outfitSemiBold' : 'text-textSm font-outfitRegular'
        }`}>
        {label}
      </Text>
      <View style={{ marginLeft: spacing.x3, flexShrink: 1 }}>
        <Text
          numberOfLines={1}
          className={`text-right ${
            isBold
              ? 'text-fontBoldBase font-outfitSemiBold text-primary'
              : 'text-fontBoldSm font-outfitSemiBold text-text'
          }`}>
          {value}
        </Text>
      </View>
    </View>
  );
}

/** A thin 1px rule, standing in for Flutter's themed `Divider()`. */
function Rule({ compact = false }: { compact?: boolean }) {
  const colors = useSemanticColors();
  return (
    <View
      style={{
        height: 1,
        backgroundColor: colors.border,
        marginVertical: compact ? spacing.x1 : spacing.x2,
        marginHorizontal: compact ? spacing.x1 : 0,
      }}
    />
  );
}

export type CheckoutEmptyStateProps = {
  message: string;
  browseLabel: string;
  onBrowse: () => void;
};

/**
 * Ports flutter_app/lib/widgets/checkout_view.dart's `CheckoutEmptyState`:
 * the empty-cart/empty-checkout view shared by `CartView` and
 * `CheckoutView` -- a muted icon, the message, and a "browse" text action.
 */
export function CheckoutEmptyState({ message, browseLabel, onBrowse }: CheckoutEmptyStateProps) {
  const colors = useSemanticColors();
  return (
    <View className="flex-1 items-center justify-center p-x8">
      <MaterialIcons name="remove-shopping-cart" size={52} color={colors.textMuted} />
      <Text style={{ marginTop: spacing.x4 }} className="text-center text-textXl font-outfitBold text-text">
        {message}
      </Text>
      <Pressable
        accessibilityRole="button"
        onPress={onBrowse}
        style={{ marginTop: spacing.x4 }}
        className="active:opacity-70">
        <Text className="text-button font-outfitSemiBold text-primary">{browseLabel}</Text>
      </Pressable>
    </View>
  );
}

export type CheckoutDeliveryNoteProps = {
  note: string;
  onNoteChange: (text: string) => void;
};

/**
 * Ports flutter_app/lib/widgets/checkout_view.dart's `CheckoutDeliveryNote`:
 * the only delivery input checkout asks for -- an optional free-text note.
 *
 * Flutter's `TextEditingController` has no RN equivalent; this takes a
 * controlled `note`/`onNoteChange` pair instead (same controlled-input
 * shape `AppTextField` already uses), so `CheckoutView` stays a plain
 * presentational component and the note's value lives with whichever
 * screen owns the rest of the checkout state.
 *
 * Simplification: `labelText` ("Delivery note / landmark (optional)")
 * renders as a static caption above the field rather than Material's
 * floating label -- same documented simplification `AppTextField` already
 * makes, for the same reason (no RN equivalent).
 */
export function CheckoutDeliveryNote({ note, onNoteChange }: CheckoutDeliveryNoteProps) {
  const colors = useSemanticColors();
  const [isFocused, setIsFocused] = useState(false);

  return (
    <View>
      <SectionTitle title="Delivery" />
      <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-text">
        We&apos;ll call the phone number on your profile to arrange delivery.
      </Text>
      <View style={{ marginTop: spacing.x3 }}>
        <Text
          style={{ marginBottom: spacing.x1 }}
          className="text-textSm font-outfitMedium text-textMuted">
          Delivery note / landmark (optional)
        </Text>
        <TextInput
          testID="checkout-delivery-note"
          value={note}
          onChangeText={onNoteChange}
          multiline
          numberOfLines={2}
          autoCapitalize="sentences"
          placeholder="e.g. Near the mosque, blue gate"
          placeholderTextColor={colors.textMuted}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          style={{
            borderRadius: radius.xl,
            borderWidth: isFocused ? 1.5 : 1,
            borderColor: isFocused ? colors.primary : colors.borderStrong,
            paddingHorizontal: spacing.x4,
            paddingVertical: spacing.x4,
            textAlignVertical: 'top',
          }}
          className="text-textBase font-outfitRegular text-text"
        />
      </View>
    </View>
  );
}

export type CheckoutSummaryCardProps = {
  /** One row per cart line. */
  itemLines: CheckoutLine[];
  /** Subtotal, tax, delivery fee -- whatever this vertical charges. */
  feeLines: CheckoutLine[];
  /**
   * `null` when a fee/tax line is still `isPending` -- see
   * {@link CheckoutViewProps.total}.
   */
  total: number | null;
};

/**
 * Ports flutter_app/lib/widgets/checkout_view.dart's `CheckoutSummaryCard`:
 * the order summary card -- item lines, fee lines, the total, and the
 * "Pay on delivery" line.
 */
export function CheckoutSummaryCard({ itemLines, feeLines, total }: CheckoutSummaryCardProps) {
  const colors = useSemanticColors();
  return (
    <OutlinedCard borderRadius={radius.card}>
      <Text className="text-fontBoldBase font-outfitSemiBold text-text">Order summary</Text>
      <View style={{ marginTop: spacing.x4 }}>
        {itemLines.map((line, index) => (
          <View key={`item-${index}-${line.label}`} style={{ marginBottom: spacing.x2_5 }}>
            <SummaryRow label={line.label} value={checkoutLineDisplayValue(line)} />
          </View>
        ))}
      </View>
      {itemLines.length > 0 && <Rule compact />}
      {feeLines.map((line, index) => (
        <View key={`fee-${index}-${line.label}`} style={{ marginBottom: spacing.x2_5 }}>
          <FeeSummaryRow label={line.label} value={checkoutLineDisplayValue(line)} />
        </View>
      ))}
      <Rule compact />
      <FeeSummaryRow
        label="Total"
        value={total == null ? 'Calculated at checkout' : formatCents(total)}
        isBold
      />
      <View style={{ marginTop: spacing.x3 }} className="flex-row items-center">
        <MaterialIcons name="payments" size={18} color={colors.textMuted} />
        <Text
          style={{ marginLeft: spacing.x2, flexShrink: 1 }}
          numberOfLines={1}
          className="text-textSm font-outfitRegular text-text">
          Pay on delivery
        </Text>
      </View>
    </OutlinedCard>
  );
}

export type CheckoutViewProps = {
  title: string;
  isEmpty: boolean;
  isLoading?: boolean;
  emptyMessage: string;
  browseLabel: string;
  onBrowse: () => void;
  /** Controlled value for `CheckoutDeliveryNote` -- see its own doc comment for why this replaces Flutter's `TextEditingController`. */
  note: string;
  onNoteChange: (text: string) => void;
  /** One row per cart line. */
  itemLines: CheckoutLine[];
  /** Subtotal, tax, delivery fee -- whatever this vertical charges. */
  feeLines: CheckoutLine[];
  /**
   * `null` when any fee/tax line is still `isPending` (pricing hasn't
   * loaded yet): shown as "Calculated at checkout" instead of a fabricated
   * number. Placing an order is never blocked on this -- the real
   * `place_*_order` RPC (wired up by the caller) remains authoritative
   * regardless.
   */
  total: number | null;
  isSubmitting: boolean;
  onSubmit: () => void;
  /** Vertical-specific sections, e.g. grocery's delivery slot picker. */
  extraSections?: ReactNode[];
  errorText?: string | null;
};

/**
 * Ports flutter_app/lib/widgets/checkout_view.dart's `CheckoutView`: the
 * checkout screen shared by food, grocery (incl. Fresh Meat and
 * Electronics) and pharmacy -- an optional delivery note, any
 * vertical-specific sections (`extraSections`), the order summary with a
 * "Pay on delivery" line, and one "Place order" button.
 *
 * There is no address and no payment step (owner decision, 2026-09-25): the
 * recipient name and phone come from the customer's profile server-side,
 * and every order is paid on delivery.
 */
export function CheckoutView({
  title,
  isEmpty,
  isLoading = false,
  emptyMessage,
  browseLabel,
  onBrowse,
  note,
  onNoteChange,
  itemLines,
  feeLines,
  total,
  isSubmitting,
  onSubmit,
  extraSections = [],
  errorText,
}: CheckoutViewProps) {
  const colors = useSemanticColors();
  const showButton = !isEmpty && !isLoading;

  return (
    <AppScaffold
      title={title}
      showBackButton
      bottomBar={
        showButton ? (
          <SafeAreaView
            edges={['bottom']}
            style={{ paddingHorizontal: spacing.x4, paddingTop: spacing.x4, paddingBottom: spacing.x3 }}>
            <GradientActionButton
              testID="checkout-place-order"
              label={
                isSubmitting
                  ? 'Placing order...'
                  : total == null
                    ? 'Place order'
                    : `Place order • ${formatCents(total)}`
              }
              onPress={isSubmitting ? null : onSubmit}
              borderRadius={radius.media}
              paddingVertical={spacing.x4}
              paddingHorizontal={spacing.x5}
              icon={<MaterialIcons name="check-circle-outline" size={20} color={colors.onPrimary} />}
            />
          </SafeAreaView>
        ) : undefined
      }>
      {isLoading ? (
        <LoadingState />
      ) : isEmpty ? (
        <CheckoutEmptyState message={emptyMessage} browseLabel={browseLabel} onBrowse={onBrowse} />
      ) : (
        <ScrollView
          contentContainerStyle={{
            paddingHorizontal: spacing.screenX,
            paddingTop: spacing.x2,
            paddingBottom: spacing.x6,
          }}>
          <CheckoutDeliveryNote note={note} onNoteChange={onNoteChange} />
          {extraSections.map((section, index) => (
            <View key={index} style={{ marginTop: spacing.x6 }}>
              {section}
            </View>
          ))}
          <View style={{ marginTop: spacing.x6 }}>
            <CheckoutSummaryCard itemLines={itemLines} feeLines={feeLines} total={total} />
          </View>
          {errorText != null && (
            <Text
              testID="checkout-error"
              style={{ marginTop: spacing.x4 }}
              className="text-textSm font-outfitRegular text-error">
              {errorText}
            </Text>
          )}
        </ScrollView>
      )}
    </AppScaffold>
  );
}
