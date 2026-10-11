/**
 * Ports `flutter_app/lib/features/merchant/orders/presentation/orders_screen.dart`
 * (issue #408 / P9-03): the signed-in merchant's incoming-order queue for
 * their own store, newest first, with pull-to-refresh and explicit
 * loading / no-store / empty / error / loaded states.
 *
 * Reuses `MerchantStoreController` to resolve "my store" instead of
 * re-deriving that logic (a merchant owns at most one store); the merchant
 * shell passes the same controller to "My Store" so the store is fetched
 * once, as in Dart.
 *
 * RN addition (the issue's realtime task -- the Dart screen has no
 * realtime): once the store is known, the screen subscribes to that store's
 * order table via `MerchantOrdersController.watch`, so a new customer order
 * (or a status change made elsewhere) shows up without a refresh. The
 * subscription is torn down on unmount.
 *
 * Tapping an order opens `/merchant/orders/:orderId` (the detail screen
 * itself is P9-04, #409). Dart reloads the list when that pushed route pops;
 * here the realtime UPDATE event for the changed row covers that instead.
 */
import { router } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { FlatList, RefreshControl, ScrollView, Text, View } from 'react-native';

import { EmptyState } from '@/components/empty-state';
import { ErrorState } from '@/components/error-state';
import { LoadingState } from '@/components/loading-state';
import { OutlinedCard } from '@/components/outlined-card';
import { StatusPill } from '@/components/status-pill';
import { useSemanticColors } from '@/hooks/use-semantic-colors';
import { formatCents } from '@/platform/money/format';
import { merchantOrderDetailPath } from '@/platform/navigation/app-routes';
import { spacing } from '@/theme/tokens';

import type { MerchantStore } from '../store/api/merchant-store';
import { MerchantStoreController, useMerchantStoreState } from '../store/merchant-store-controller';
import { shortOrderId, type MerchantOrder } from './api/merchant-order';
import { merchantOrderStatusLabel } from './api/merchant-order-vertical';
import type { MerchantOrdersRepository } from './api/merchant-orders-repository';
import { MerchantOrdersController, useMerchantOrdersState } from './merchant-orders-controller';

export type OrdersScreenProps = {
  /** The signed-in merchant's `profiles.id` (== `auth.uid()`). */
  ownerId: string;
  /** Shared with "My Store" by `MerchantShell` so the store is fetched once; overridable for tests. Defaults to a Supabase-backed controller. */
  storeController?: MerchantStoreController;
  /** Overridable for tests; defaults to a Supabase-backed repository (with realtime). */
  ordersRepository?: MerchantOrdersRepository;
  /** Test seam for opening an order; defaults to pushing `/merchant/orders/:orderId`. */
  onOpenOrder?: (orderId: string) => void;
};

const defaultOpenOrder = (orderId: string) => router.push(merchantOrderDetailPath(orderId) as never);

export function OrdersScreen({ ownerId, storeController: storeControllerProp, ordersRepository, onOpenOrder = defaultOpenOrder }: OrdersScreenProps) {
  const [ownStoreController] = useState(() => (storeControllerProp ? null : new MerchantStoreController()));
  const storeController = storeControllerProp ?? ownStoreController!;
  const storeState = useMerchantStoreState(storeController);
  const store = storeState.store;

  useEffect(() => {
    if (!storeController.hasLoaded && !storeController.isLoading) {
      void storeController.load(ownerId);
    }
  }, [storeController, ownerId]);

  // One orders controller per resolved store (Dart creates it once the
  // store first resolves). Keyed on id + vertical so a store created later
  // from "My Store" gets its own controller.
  const storeId = store?.id ?? null;
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

  if (!storeState.hasLoaded && (storeState.isLoading || storeState.loadError == null)) {
    return <LoadingState />;
  }
  if (storeState.loadError != null && store == null) {
    return <ErrorState message={storeState.loadError} onRetry={() => void storeController.load(ownerId)} />;
  }
  if (store == null) {
    return (
      <EmptyState
        icon="storefront"
        title="Set up your store first"
        message={'Set up your store from the "My Store" tab to start receiving orders.'}
      />
    );
  }
  if (ordersController == null) {
    return <LoadingState />;
  }
  return <OrdersListView controller={ordersController} store={store} onOpenOrder={onOpenOrder} />;
}

type OrdersListViewProps = {
  controller: MerchantOrdersController;
  store: MerchantStore;
  onOpenOrder: (orderId: string) => void;
};

function OrdersListView({ controller, store, onOpenOrder }: OrdersListViewProps) {
  const state = useMerchantOrdersState(controller);
  // Only a user-initiated pull shows the refresh spinner -- a realtime
  // reload happens silently in the background.
  const [isRefreshing, setIsRefreshing] = useState(false);
  const refresh = useCallback(async () => {
    setIsRefreshing(true);
    try {
      await controller.load();
    } finally {
      setIsRefreshing(false);
    }
  }, [controller]);

  let body;
  if (!state.hasLoaded && (state.isLoading || state.loadError == null)) {
    body = <LoadingState />;
  } else if (state.loadError != null && state.orders.length === 0) {
    body = <ErrorState message={state.loadError} onRetry={() => void controller.load()} />;
  } else if (state.orders.length === 0) {
    body = (
      <ScrollView
        testID="merchant-orders-list"
        contentContainerStyle={{ flexGrow: 1 }}
        refreshControl={<RefreshControl refreshing={isRefreshing} onRefresh={refresh} />}>
        <EmptyState icon="receipt-long" title="No orders yet" message="New orders show up here as soon as a customer places one." />
      </ScrollView>
    );
  } else {
    body = (
      <FlatList
        testID="merchant-orders-list"
        data={state.orders}
        keyExtractor={(order) => order.id}
        contentContainerStyle={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.x4, paddingBottom: spacing.x6 }}
        ItemSeparatorComponent={OrderSeparator}
        refreshControl={<RefreshControl refreshing={isRefreshing} onRefresh={refresh} />}
        renderItem={({ item }) => <OrderTile order={item} onPress={() => onOpenOrder(item.id)} />}
      />
    );
  }

  return (
    <View className="flex-1">
      <Text
        style={{ paddingHorizontal: spacing.screenX, paddingTop: spacing.x4 }}
        className="text-textLg font-outfitMedium text-text"
        accessibilityRole="header">
        {store.name}
      </Text>
      <View className="flex-1">{body}</View>
    </View>
  );
}

function OrderSeparator() {
  return <View style={{ height: spacing.x2 }} />;
}

/** Mirrors the Dart `_OrderTile`: short id, items summary, status pill and total. */
function OrderTile({ order, onPress }: { order: MerchantOrder; onPress: () => void }) {
  const itemsSummary =
    order.items.length === 0 ? 'No items' : order.items.map((item) => `${item.quantity}x ${item.name}`).join(', ');
  return (
    <OutlinedCard onPress={onPress} padding={spacing.x4} testID={`merchant-order-${order.id}`}>
      <View className="flex-row items-center">
        <View className="flex-1" style={{ marginRight: spacing.x3 }}>
          <Text className="text-fontBoldBase font-outfitSemiBold text-text">{`Order #${shortOrderId(order.id)}`}</Text>
          <Text numberOfLines={1} className="text-textSm font-outfitRegular text-textMuted" style={{ marginTop: spacing.x1 }}>
            {itemsSummary}
          </Text>
        </View>
        <View className="items-end">
          <OrderStatusPill status={order.status} />
          <Text style={{ marginTop: spacing.x1 }} className="text-textSm font-outfitMedium text-text">
            {formatCents(order.totalCents)}
          </Text>
        </View>
      </View>
    </OutlinedCard>
  );
}

/** Mirrors the Dart `_StatusChip`: muted for terminal states, accented otherwise. */
function OrderStatusPill({ status }: { status: string }) {
  const colors = useSemanticColors();
  const isTerminal = status === 'delivered' || status === 'cancelled';
  return (
    <StatusPill
      label={merchantOrderStatusLabel(status)}
      fontSize={11}
      backgroundColor={isTerminal ? colors.bgMuted : undefined}
      foregroundColor={isTerminal ? colors.textMuted : undefined}
    />
  );
}
