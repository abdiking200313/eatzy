import { EmptyState } from '@/components/empty-state';

export type OrdersScreenProps = {
  /** The signed-in merchant's `profiles.id`. Unused until P9-03 (#408) loads this merchant's incoming orders. */
  ownerId: string;
};

/**
 * Placeholder for `flutter_app/lib/features/merchant/orders/presentation/
 * orders_screen.dart`'s `OrdersScreen` -- the real incoming-order queue
 * (with realtime) lands in P9-03 (#408). The merchant shell (P9-01, #406)
 * only needs a destination to route its "Orders" tab to.
 */
export function OrdersScreen(_props: OrdersScreenProps) {
  return (
    <EmptyState
      icon="receipt-long"
      title="Incoming orders are coming soon"
      message="New orders for your store will show up here."
    />
  );
}
