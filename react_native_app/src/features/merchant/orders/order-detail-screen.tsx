/**
 * Ports `flutter_app/lib/features/merchant/orders/presentation/order_detail_screen.dart`
 * (issue #409 / P9-04): one order's line items, the address/contact info
 * captured on the order, its current status, and the accept / reject /
 * advance actions. Every status change goes through
 * `MerchantOrdersController.advanceStatus`, i.e. the vertical's
 * `advance_*_order_status` RPC -- no direct table writes.
 *
 * The buttons only ever offer what `nextForwardOrderStatus` /
 * `canCancelOrder` allow (the client mirror of the server's
 * `is_legal_order_status_transition`); the RPC stays the enforcement point,
 * and a server rejection is surfaced verbatim in a snackbar.
 *
 * Reads its order live from a `MerchantOrdersController` (by `orderId`)
 * rather than a snapshot, so a status change made here -- or pushed over
 * realtime -- shows immediately. Either a `controller` is injected (tests),
 * or, as on the `/merchant/orders/:orderId` route (a list tap or a deep
 * link), the screen resolves the signed-in merchant's store and builds its
 * own orders controller -- the Dart deep-link path. RN addition: that own
 * controller also subscribes to realtime (`watch`), like the Orders list.
 */
import { MaterialIcons } from '@expo/vector-icons';
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { ActivityIndicator, Pressable, ScrollView, Text, View, type StyleProp, type ViewStyle } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { CartSnackbar } from '@/components/cart-snackbar';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { OutlinedCard } from '@/components/outlined-card';
import { StatusPill } from '@/components/status-pill';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { formatCents } from '@/platform/money/format';
import { spacing } from '@/theme/tokens';

import { MerchantStoreController, useMerchantStoreState } from '../store/merchant-store-controller';
import {
  deliveryLine,
  lineTotalCents,
  shortOrderId,
  substitutionPreferenceLabel,
  type MerchantOrder,
  type MerchantOrderLineItem,
} from './api/merchant-order';
import {
  canCancelOrder,
  MERCHANT_ORDER_VERTICAL_CONFIG,
  merchantOrderStatusLabel,
  nextForwardOrderStatus,
} from './api/merchant-order-vertical';
import type { MerchantOrdersRepository } from './api/merchant-orders-repository';
import {
  MerchantOrdersController,
  ORDER_STATUS_FAILURE_MESSAGE,
  useMerchantOrdersState,
} from './merchant-orders-controller';

export const ORDER_GONE_MESSAGE = 'This order is no longer available.';
export const ORDER_COMPLETE_MESSAGE = 'This order is complete. No further action is available.';

export type OrderDetailScreenProps = {
  orderId: string;
  /**
   * The signed-in merchant's `profiles.id` (== `auth.uid()`); only used when
   * `controller` is not supplied. `null` (signed out) shows the
   * "no longer available" state, as in Dart.
   */
  ownerId?: string | null;
  /** Overridable for tests; only used when `controller` is not supplied. Defaults to a Supabase-backed controller. */
  storeController?: MerchantStoreController;
  /** Overridable for tests; only used when `controller` is not supplied. Defaults to a Supabase-backed repository (with realtime). */
  ordersRepository?: MerchantOrdersRepository;
  /** When supplied, the screen reads straight from it instead of resolving its own store/orders. */
  controller?: MerchantOrdersController;
};

export function OrderDetailScreen(props: OrderDetailScreenProps) {
  return (
    <AppScaffold title="Order" showBackButton>
      {props.controller ? (
        <OrderDetailContent controller={props.controller} orderId={props.orderId} />
      ) : (
        <SelfResolvingOrderDetail {...props} />
      )}
    </AppScaffold>
  );
}

/** The Dart deep-link path: resolve "my store", then build (and own) an orders controller for it. */
function SelfResolvingOrderDetail({
  orderId,
  ownerId = null,
  storeController: storeControllerProp,
  ordersRepository,
}: OrderDetailScreenProps) {
  const [ownStoreController] = useState(() => (storeControllerProp ? null : new MerchantStoreController()));
  const storeController = storeControllerProp ?? ownStoreController!;
  const storeState = useMerchantStoreState(storeController);
  const store = storeState.store;

  useEffect(() => {
    if (ownerId != null && !storeController.hasLoaded && !storeController.isLoading) {
      void storeController.load(ownerId);
    }
  }, [storeController, ownerId]);

  const storeId = ownerId == null ? null : (store?.id ?? null);
  const storeVertical = store?.vertical ?? null;
  const ordersController = useMemo(
    () =>
      storeId == null || storeVertical == null
        ? null
        : new MerchantOrdersController({ vertical: storeVertical, storeId, repository: ordersRepository }),
    [storeId, storeVertical, ordersRepository],
  );

  useEffect(() => {
    if (ordersController == null) return undefined;
    void ordersController.load();
    return ordersController.watch();
  }, [ordersController]);

  if (ordersController != null) {
    return <OrderDetailContent controller={ordersController} orderId={orderId} />;
  }
  if (ownerId == null) {
    return <OrderGoneMessage />;
  }
  // RN addition: Dart keeps spinning when the store lookup fails; here the
  // same retryable error the Orders list shows is offered instead.
  if (storeState.loadError != null && store == null) {
    return <ErrorState message={storeState.loadError} onRetry={() => void storeController.load(ownerId)} />;
  }
  // Mirrors `_selfResolutionFinished`: once the store lookup finished
  // without a store, there is nothing left to wait on.
  return storeState.hasLoaded ? <OrderGoneMessage /> : <LoadingState />;
}

function OrderDetailContent({ controller, orderId }: { controller: MerchantOrdersController; orderId: string }) {
  const state = useMerchantOrdersState(controller);
  const snackbar = useCartSnackbar();

  if (state.isLoading && !state.hasLoaded) {
    return <LoadingState />;
  }

  const order = state.orders.find((candidate) => candidate.id === orderId) ?? null;
  if (order == null) {
    return <OrderGoneMessage />;
  }

  const advance = async (newStatus: string) => {
    const current = controller.orderById(orderId);
    if (current == null) return;
    const succeeded = await controller.advanceStatus(current, newStatus);
    snackbar.show(
      succeeded
        ? `Order marked as ${merchantOrderStatusLabel(newStatus)}.`
        : (controller.saveError ?? ORDER_STATUS_FAILURE_MESSAGE),
    );
  };

  return (
    <View className="relative flex-1">
      <OrderDetailBody order={order} isSaving={state.isSaving} onAdvance={(status) => void advance(status)} />
      <CartSnackbar message={snackbar.message} />
    </View>
  );
}

function OrderGoneMessage() {
  const colors = useSemanticColors();
  return (
    <View className="flex-1 items-center justify-center" style={{ padding: spacing.x6 }}>
      <MaterialIcons name="search-off" size={48} color={colors.textMuted} />
      <Text style={{ marginTop: spacing.x3 }} className="text-center text-textSm font-outfitRegular text-text">
        {ORDER_GONE_MESSAGE}
      </Text>
    </View>
  );
}

type OrderDetailBodyProps = {
  order: MerchantOrder;
  isSaving: boolean;
  onAdvance: (status: string) => void;
};

function OrderDetailBody({ order, isSaving, onAdvance }: OrderDetailBodyProps) {
  const vertical = order.vertical;
  const nextStatus = nextForwardOrderStatus(vertical, order.status);
  const isConfirmed = order.status === MERCHANT_ORDER_VERTICAL_CONFIG[vertical].orderStatusFlow[0];
  const canCancel = canCancelOrder(vertical, order.status);
  const location = deliveryLine(order);
  const substitution = substitutionPreferenceLabel(order.substitutionPreference);

  return (
    <ScrollView
      testID="merchant-order-detail"
      contentContainerStyle={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.x4, paddingBottom: spacing.x6 }}>
      <View className="flex-row items-start">
        <View className="flex-1" style={{ marginRight: spacing.x3 }}>
          <Text className="text-textLg font-outfitSemiBold text-text" accessibilityRole="header">
            {`Order #${shortOrderId(order.id)}`}
          </Text>
          <Text style={{ marginTop: 3 }} className="text-textSm font-outfitRegular text-textMuted">
            {formatDateTime(order.createdAt)}
          </Text>
        </View>
        <StatusPill label={merchantOrderStatusLabel(order.status)} />
      </View>

      <SectionCard title="Items" style={{ marginTop: spacing.x5 }}>
        {order.items.map((item) => (
          <LineItemRow key={item.id} item={item} />
        ))}
        <Divider />
        <TotalsRow label="Subtotal" cents={order.subtotalCents} />
        <TotalsRow label="Delivery fee" cents={order.deliveryFeeCents} />
        {order.taxCents != null && <TotalsRow label="Tax" cents={order.taxCents} />}
        <TotalsRow label="Total" cents={order.totalCents} emphasize />
      </SectionCard>

      <SectionCard title="Delivery details" style={{ marginTop: spacing.x3 }}>
        <Text className="text-textSm font-outfitSemiBold text-text">{order.recipientName}</Text>
        <Text style={{ marginTop: 3 }} className="text-textSm font-outfitRegular text-text">
          {order.phone}
        </Text>
        <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-text">
          {location.length === 0 ? 'No delivery note. Call the customer for directions.' : location}
        </Text>
        {order.deliverySlotLabel != null && order.deliverySlotLabel.trim().length > 0 && (
          <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-text">
            {`Delivery window: ${order.deliverySlotLabel}`}
          </Text>
        )}
        {substitution != null && (
          <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-text">
            {substitution}
          </Text>
        )}
        {order.deliveryInstructions != null && order.deliveryInstructions.trim().length > 0 && (
          <Text style={{ marginTop: spacing.x2 }} className="text-textSm font-outfitRegular text-text">
            {`Instructions: ${order.deliveryInstructions}`}
          </Text>
        )}
      </SectionCard>

      {(order.paymentMethod != null || order.paymentStatus != null) && (
        <SectionCard title="Payment" style={{ marginTop: spacing.x3 }}>
          {order.paymentMethod != null && (
            <Text className="text-textSm font-outfitRegular text-text">{paymentMethodLabel(order.paymentMethod)}</Text>
          )}
          {order.paymentStatus != null && (
            <Text className="text-textSm font-outfitRegular text-text">{paymentStatusLabel(order.paymentStatus)}</Text>
          )}
        </SectionCard>
      )}

      <View style={{ marginTop: spacing.x5 }}>
        {nextStatus == null && !canCancel ? (
          <Text className="text-center text-textSm font-outfitRegular text-text">{ORDER_COMPLETE_MESSAGE}</Text>
        ) : (
          <View className="flex-row">
            {canCancel && (
              <ActionButton
                variant="outlined"
                testID="order-detail-cancel"
                label={isConfirmed ? 'Reject order' : 'Cancel order'}
                disabled={isSaving}
                onPress={() => onAdvance('cancelled')}
              />
            )}
            {canCancel && nextStatus != null && <View style={{ width: spacing.x3 }} />}
            {nextStatus != null && (
              <ActionButton
                variant="filled"
                testID="order-detail-advance"
                label={isConfirmed ? 'Accept order' : `Mark as ${merchantOrderStatusLabel(nextStatus)}`}
                disabled={isSaving}
                busy={isSaving}
                onPress={() => onAdvance(nextStatus)}
              />
            )}
          </View>
        )}
      </View>
    </ScrollView>
  );
}

function SectionCard({ title, style, children }: { title: string; style?: StyleProp<ViewStyle>; children: ReactNode }) {
  return (
    <View style={style}>
      <OutlinedCard padding={spacing.x4}>
        <Text style={{ marginBottom: spacing.headerToContent }} className="text-fontBoldBase font-outfitSemiBold text-text">
          {title}
        </Text>
        {children}
      </OutlinedCard>
    </View>
  );
}

function Divider() {
  const colors = useSemanticColors();
  return <View style={{ height: 1, backgroundColor: colors.border, marginHorizontal: 4, marginVertical: 4 }} />;
}

function LineItemRow({ item }: { item: MerchantOrderLineItem }) {
  return (
    <View className="flex-row items-center" style={{ paddingVertical: spacing.x1 }}>
      <Text className="text-textSm font-outfitRegular text-text">{`${item.quantity}x`}</Text>
      <Text style={{ marginLeft: spacing.x2 }} className="flex-1 text-textSm font-outfitRegular text-text">
        {item.name}
      </Text>
      <Text className="text-textSm font-outfitRegular text-text">{formatCents(lineTotalCents(item))}</Text>
    </View>
  );
}

function TotalsRow({ label, cents, emphasize = false }: { label: string; cents: number; emphasize?: boolean }) {
  const textClass = emphasize ? 'text-fontBoldBase font-outfitSemiBold text-text' : 'text-textSm font-outfitRegular text-text';
  return (
    <View className="flex-row justify-between" style={{ paddingVertical: 5, paddingHorizontal: 4 }}>
      <Text className={textClass}>{label}</Text>
      <Text className={textClass}>{formatCents(cents)}</Text>
    </View>
  );
}

type ActionButtonProps = {
  variant: 'filled' | 'outlined';
  label: string;
  onPress: () => void;
  disabled: boolean;
  busy?: boolean;
  testID: string;
};

/** The Dart `FilledButton` / error-tinted `OutlinedButton` pair, with a disabled state while a change is saving. */
function ActionButton({ variant, label, onPress, disabled, busy = false, testID }: ActionButtonProps) {
  const colors = useSemanticColors();
  const filled = variant === 'filled';
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled, busy }}
      disabled={disabled}
      onPress={onPress}
      style={{
        flex: 1,
        minHeight: 48,
        paddingVertical: spacing.x3,
        paddingHorizontal: spacing.x3,
        borderRadius: 999,
        backgroundColor: filled ? colors.primary : 'transparent',
        borderWidth: filled ? 0 : 1,
        borderColor: colors.error,
        opacity: disabled && !busy ? 0.5 : 1,
      }}
      className="items-center justify-center active:opacity-80">
      {busy ? (
        <ActivityIndicator size="small" color={colors.onPrimary} />
      ) : (
        <Text style={{ color: filled ? colors.onPrimary : colors.error }} className="text-button font-outfitSemiBold">
          {label}
        </Text>
      )}
    </Pressable>
  );
}

/** Mirrors the Dart `_formatDateTime`: local `yyyy-MM-dd HH:mm`. */
export function formatDateTime(date: Date): string {
  const twoDigits = (value: number) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${twoDigits(date.getMonth() + 1)}-${twoDigits(date.getDate())} ${twoDigits(
    date.getHours(),
  )}:${twoDigits(date.getMinutes())}`;
}

/** Mirrors the Dart `_paymentMethodLabel` (itself mirroring `ActivityItem.paymentMethodLabel`). */
export function paymentMethodLabel(raw: string): string {
  return raw === 'cash_on_delivery' ? 'Cash on delivery' : raw;
}

/** Mirrors the Dart `_paymentStatusLabel`. */
export function paymentStatusLabel(raw: string): string {
  switch (raw) {
    case 'pending_collection':
      return 'Pending collection';
    case 'collected':
      return 'Collected';
    case 'refunded':
      return 'Refunded';
    default:
      return raw;
  }
}
