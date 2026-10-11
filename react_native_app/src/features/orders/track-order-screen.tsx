import { MaterialIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { ActivityIndicator, Pressable, Text, View } from 'react-native';

import { AppScaffold } from '@/components/app-scaffold';
import { CartSnackbar } from '@/components/cart-snackbar';
import { LoadingState } from '@/components/loading-state';
import { useCartSnackbar } from '@/hooks/use-cart-snackbar';
import type { OrderDetails } from '@/platform/activity/api/order-details';
import { confirmReplaceCart } from '@/platform/activity/confirm-replace-cart';
import { canReorder, OrderAgainService, runOrderAgain } from '@/platform/activity/order-again-service';
import { useOrderDetails, type FetchOrderDetails, type WatchOrder } from '@/platform/activity/use-order-details';
import { forId, type ServiceId } from '@/theme/service-theme';
import { spacing } from '@/theme/tokens';

import { OrderDetailsContent } from './order-details-content';
import { TrackOrderMessage } from './track-order-message';

/**
 * Ports `app_router.dart`'s `_serviceIdFromPathSegment`: the route's
 * `serviceId` segment picks the page's service palette; anything
 * unrecognized falls back to the neutral `unknown` colors.
 */
function serviceIdFromPathSegment(raw: string | undefined): ServiceId {
  return raw === 'food' || raw === 'grocery' || raw === 'pharmacy' ? raw : 'unknown';
}

export type TrackOrderScreenProps = {
  /** The `customer_activity` row id. Missing/empty means "no order selected". */
  orderId?: string;
  /** The raw `service_id` (`food`, `grocery`, `pharmacy`) scoping the lookup. */
  serviceId?: string;
  /** Test seam; defaults to the Supabase-backed `fetchOrderDetails`. */
  fetchDetails?: FetchOrderDetails;
  /** Test seam; defaults to the Supabase Realtime `watchOrder`. */
  watch?: WatchOrder;
  /** Test seam; defaults to a service over the app-wide carts. */
  orderAgainService?: OrderAgainService;
  /** Test seam for the "Replace your cart?" prompt. */
  confirmReplace?: () => Promise<boolean>;
  /** Test seam for opening the filled cart (the Dart `context.go`). */
  navigate?: (route: string) => void;
};

const defaultNavigate = (route: string) => router.navigate(route as never);

/**
 * Ports `flutter_app/lib/features/orders/presentation/track_order_screen.dart`
 * (issue #398 / P8-02): the order details page for one of the customer's own
 * orders -- progress timeline, items and charges, delivery address and
 * payment, with an "Order again" action -- kept live by a Realtime
 * subscription on the order's row while it can still change (see
 * `useOrderDetails`). With no id/service (the bare `/track-order` route,
 * e.g. an old deep link) it renders a "no order selected" state instead.
 * There is no customer cancel button: the Flutter app has none.
 */
export function TrackOrderScreen({ orderId, serviceId, fetchDetails, watch, orderAgainService, confirmReplace = confirmReplaceCart, navigate = defaultNavigate }: TrackOrderScreenProps) {
  const { status, order, isRefreshing, reload } = useOrderDetails({ orderId, serviceId, fetchDetails, watch });
  const palette = forId(serviceIdFromPathSegment(serviceId));
  const snackbar = useCartSnackbar();
  const service = useMemo(() => orderAgainService ?? new OrderAgainService(), [orderAgainService]);
  const [loadingReorder, setLoadingReorder] = useState(false);

  const orderAgain = async (loaded: OrderDetails) => {
    setLoadingReorder(true);
    let stopped = false;
    try {
      await runOrderAgain({
        service,
        item: loaded.summary,
        confirmReplace: async () => {
          // The Dart screen clears its spinner before asking.
          setLoadingReorder(false);
          stopped = true;
          return confirmReplace();
        },
        showMessage: snackbar.show,
        navigate,
      });
    } finally {
      if (!stopped) setLoadingReorder(false);
    }
  };

  let body;
  if (status === 'noReference') {
    body = <TrackOrderMessage icon="receipt-long" title="No order selected" message="Open an order from your Activity tab to see its details here." />;
  } else if (status === 'loading') {
    body = <LoadingState />;
  } else if (status === 'error') {
    body = <TrackOrderMessage icon="error-outline" title="Order could not be loaded" message="Please try again." actionLabel="Try again" onAction={() => void reload()} />;
  } else if (status === 'notFound' || order == null) {
    body = (
      <TrackOrderMessage
        icon="search-off"
        title="Order not found"
        message="We couldn't find this order. It may not exist, or it may belong to a different account."
      />
    );
  } else {
    body = (
      <OrderDetailsContent
        order={order}
        palette={palette}
        refreshing={isRefreshing}
        onRefresh={() => void reload()}
        orderAgainButton={
          canReorder(order.summary) ? (
            <Pressable
              testID="order-details-order-again"
              accessibilityRole="button"
              accessibilityState={{ disabled: loadingReorder, busy: loadingReorder }}
              disabled={loadingReorder}
              onPress={() => void orderAgain(order)}
              style={{ paddingVertical: spacing.x3_5, opacity: loadingReorder ? 0.6 : 1 }}
              className="w-full flex-row items-center justify-center rounded-full bg-primaryFill active:opacity-80">
              {loadingReorder ? <ActivityIndicator size="small" color="white" /> : <MaterialIcons name="replay" size={18} color="white" />}
              <Text style={{ marginLeft: spacing.x2 }} className="text-button font-outfitSemiBold text-onPrimary">
                Order again
              </Text>
            </Pressable>
          ) : undefined
        }
      />
    );
  }

  return (
    <AppScaffold title="Order details" showBackButton>
      <View className="relative flex-1">
        {body}
        <CartSnackbar message={snackbar.message} />
      </View>
    </AppScaffold>
  );
}
