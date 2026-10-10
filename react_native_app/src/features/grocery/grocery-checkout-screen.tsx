/**
 * Ports `flutter_app/lib/services/grocery/presentation/grocery_checkout_screen.dart`'s
 * `GroceryCheckoutScreen` (issue #392 / P7-04): checkout for every
 * grocery-engine store (Grocery, Fresh Meat, Electronics) -- the shared
 * `CheckoutView` plus grocery's own delivery-slot and substitution-
 * preference sections, placing a real order via `place_grocery_order`
 * (`confirmGroceryOrder` in `grocery-checkout.ts`).
 *
 * Delivery slots load once the cart's store is known, from the
 * `grocery_delivery_slots_available` view (which already hides slots whose
 * window has passed). If a slot elapses while the screen is open, the RPC
 * rejects it and -- as in Flutter -- the generic "could not be saved"
 * message is shown.
 *
 * Double-submit protection mirrors the food checkout (#387): a ref-based
 * in-flight guard plus the button disabled while submitting, and one
 * idempotency key per visit to this screen, reused for every retry.
 *
 * Deviations from Flutter:
 * - Flutter's screen shows nothing while slots load or when they fail to
 *   load (`slotLoadError` is never rendered); this shows a short loading /
 *   error line in the slot section so an empty list is not silent.
 * - The "order placed" confirmation is a native `Alert` (with the order
 *   reference, as in `showOrderPlacedDialog`) rather than an awaited
 *   dialog; navigation to the activity tab happens right away.
 */
import { router } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Alert, Pressable, Text, View } from 'react-native';

import { CheckoutView, checkoutLine, pendingCheckoutLine } from '@/components/checkout-view';
import { SectionTitle } from '@/components/section-title';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { AppRoutes } from '@/platform/navigation/app-routes';
import type { PlacedOrder } from '@/platform/orders/placed-order';
import { generateIdempotencyKey } from '@/platform/orders/idempotency-key';
import {
  groceryCartLineTotal,
  groceryCartStoreFor,
  groceryQuantityLabel,
  useGroceryCartTotals,
  type GroceryStoreType,
} from '@/stores/grocery-cart-store';
import { spacing } from '@/theme/tokens';

import {
  fetchGroceryDeliverySlots,
  GROCERY_SUBSTITUTION_PREFERENCES,
  grocerySubstitutionDescription,
  grocerySubstitutionLabel,
  type GroceryDeliverySlot,
  type GroceryOrderRequest,
  type GrocerySubstitutionPreference,
} from './api/grocery-order-repository';
import { confirmGroceryOrder, GROCERY_SLOT_ERROR, GROCERY_SUBSTITUTION_ERROR } from './grocery-checkout';
import { GROCERY_STORE_TYPE_META } from './grocery-store-type-meta';

export const GROCERY_SLOT_LOAD_ERROR = 'Delivery slots could not be loaded.';

export type GroceryCheckoutScreenProps = {
  /** Grocery, Fresh Meat and Electronics each have their own cart. */
  storeType?: GroceryStoreType;
  /** Test seam; defaults to `fetchGroceryDeliverySlots`. */
  slotsLoader?: (storeId: string) => Promise<GroceryDeliverySlot[]>;
  /** Test seam; defaults to the real `placeGroceryOrder`. */
  placeOrder?: (request: GroceryOrderRequest) => Promise<PlacedOrder>;
};

/** The last settled slot load, tagged with the store it was for (anything else reads as loading). */
type SlotsResult = { storeId: string; status: 'error' } | { storeId: string; status: 'data'; slots: GroceryDeliverySlot[] };
type SlotsState = { status: 'idle' | 'loading' | 'error' } | { status: 'data'; slots: GroceryDeliverySlot[] };

type RadioRowProps = {
  testID: string;
  title: string;
  subtitle: string;
  selected: boolean;
  onPress: () => void;
};

/** Stands in for Flutter's `RadioListTile` (zero content padding). */
function RadioRow({ testID, title, subtitle, selected, onPress }: RadioRowProps) {
  const colors = useSemanticColors();
  return (
    <Pressable
      testID={testID}
      accessibilityRole="radio"
      accessibilityState={{ checked: selected }}
      onPress={onPress}
      style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.x2 }}
      className="active:opacity-70">
      <View
        style={{
          width: 20,
          height: 20,
          borderRadius: 10,
          borderWidth: 2,
          borderColor: selected ? colors.primary : colors.borderStrong,
          alignItems: 'center',
          justifyContent: 'center',
          marginRight: spacing.x4,
        }}>
        {selected && <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: colors.primary }} />}
      </View>
      <View style={{ flex: 1 }}>
        <Text className="text-fontBoldSm font-outfitSemiBold text-text">{title}</Text>
        <Text className="text-textSm font-outfitRegular text-textMuted">{subtitle}</Text>
      </View>
    </Pressable>
  );
}

function InlineError({ message }: { message: string }) {
  return <Text className="text-textSm font-outfitRegular text-error">{message}</Text>;
}

export function GroceryCheckoutScreen({
  storeType = 'grocery',
  slotsLoader = fetchGroceryDeliverySlots,
  placeOrder,
}: GroceryCheckoutScreenProps) {
  const meta = GROCERY_STORE_TYPE_META[storeType];
  const useStore = groceryCartStoreFor(storeType).store;
  const lines = useStore((state) => state.lines);
  const isLoading = useStore((state) => state.isLoading);
  const clearAndPersist = useStore((state) => state.clearAndPersist);
  const totals = useGroceryCartTotals(storeType);
  const storeId = totals.storeId;

  const [note, setNote] = useState('');
  const [slot, setSlot] = useState<GroceryDeliverySlot | null>(null);
  const [substitutionPreference, setSubstitutionPreference] = useState<GrocerySubstitutionPreference | null>(null);
  const [errors, setErrors] = useState<string[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [slotsResult, setSlotsResult] = useState<SlotsResult | null>(null);
  const inFlight = useRef(false);
  // Generated once per visit to this screen and reused for every retry.
  const [idempotencyKey] = useState(generateIdempotencyKey);

  // Mirrors `didChangeDependencies` → `loadDeliverySlots()` (a no-op until
  // the cart has a store).
  useEffect(() => {
    if (storeId == null) return;
    let cancelled = false;
    slotsLoader(storeId)
      .then((slots) => {
        if (!cancelled) setSlotsResult({ storeId, status: 'data', slots });
      })
      .catch(() => {
        if (!cancelled) setSlotsResult({ storeId, status: 'error' });
      });
    return () => {
      cancelled = true;
    };
  }, [storeId, slotsLoader]);

  const slotsState: SlotsState =
    storeId == null ? { status: 'idle' } : slotsResult?.storeId === storeId ? slotsResult : { status: 'loading' };

  const generalError = errors.find((error) => error !== GROCERY_SLOT_ERROR && error !== GROCERY_SUBSTITUTION_ERROR) ?? null;

  async function confirm() {
    if (inFlight.current) return;
    inFlight.current = true;
    setIsSubmitting(true);

    let result;
    try {
      result = await confirmGroceryOrder({
        lines,
        delivery: { note },
        slot,
        substitutionPreference,
        clearCart: clearAndPersist,
        idempotencyKey,
        placeOrder,
      });
    } finally {
      inFlight.current = false;
      setIsSubmitting(false);
    }
    setErrors(result.errors);
    if (!result.isSuccess) return;

    Alert.alert('Order placed', `Your order was sent to the store. Pay on delivery.\n\nReference: ${result.confirmation.orderId}`);
    router.replace(AppRoutes.activity as never);
  }

  const slotSection = (
    <View>
      <SectionTitle title="Delivery slot" />
      <View style={{ marginTop: spacing.x2 }}>
        {slotsState.status === 'loading' && (
          <Text className="text-textSm font-outfitRegular text-textMuted">Loading delivery slots...</Text>
        )}
        {slotsState.status === 'error' && <InlineError message={GROCERY_SLOT_LOAD_ERROR} />}
        {slotsState.status === 'data' &&
          slotsState.slots.map((option) => (
            <RadioRow
              key={option.id}
              testID={`grocery-slot-${option.id}`}
              title={option.label}
              subtitle={option.detail}
              selected={slot?.id === option.id}
              onPress={() => setSlot(option)}
            />
          ))}
      </View>
      {errors.includes(GROCERY_SLOT_ERROR) && <InlineError message={GROCERY_SLOT_ERROR} />}
    </View>
  );

  const substitutionSection = (
    <View>
      <SectionTitle title="If an item becomes unavailable" />
      <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-text">
        Choose one option before ordering.
      </Text>
      {GROCERY_SUBSTITUTION_PREFERENCES.map((preference) => (
        <RadioRow
          key={preference}
          testID={`grocery-substitution-${preference}`}
          title={grocerySubstitutionLabel(preference)}
          subtitle={grocerySubstitutionDescription(preference)}
          selected={substitutionPreference === preference}
          onPress={() => setSubstitutionPreference(preference)}
        />
      ))}
      {errors.includes(GROCERY_SUBSTITUTION_ERROR) && <InlineError message={GROCERY_SUBSTITUTION_ERROR} />}
    </View>
  );

  return (
    <CheckoutView
      title={`${meta.serviceName} checkout`}
      isLoading={isLoading}
      isEmpty={lines.length === 0}
      emptyMessage="Your cart is empty"
      browseLabel="Browse stores"
      // `router.replace` mirrors the Dart `context.go(storeType.listRoute)`.
      onBrowse={() => router.replace(meta.listRoute as never)}
      note={note}
      onNoteChange={setNote}
      itemLines={lines.map((line) =>
        checkoutLine(`${line.product.name} ×${groceryQuantityLabel(line)}`, groceryCartLineTotal(line)),
      )}
      feeLines={[
        checkoutLine('Subtotal', totals.subtotal),
        totals.deliveryFee == null
          ? pendingCheckoutLine('Delivery fee')
          : checkoutLine('Delivery fee', totals.deliveryFee),
      ]}
      total={totals.total}
      isSubmitting={isSubmitting}
      errorText={generalError}
      onSubmit={() => void confirm()}
      extraSections={[slotSection, substitutionSection]}
    />
  );
}
