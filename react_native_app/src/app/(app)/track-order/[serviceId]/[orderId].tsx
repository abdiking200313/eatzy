import { useLocalSearchParams } from 'expo-router';

import { TrackOrderScreen } from '@/features/orders/track-order-screen';

// Ports AppRoutes.trackOrderDetails ('/track-order/:serviceId/:orderId') from
// flutter_app/lib/app/app_router.dart (issue #398 / P8-02): the order
// details/tracking screen for one of the customer's own orders.
export default function TrackOrderDetailsRoute() {
  const { serviceId, orderId } = useLocalSearchParams<{ serviceId: string; orderId: string }>();
  return <TrackOrderScreen serviceId={serviceId} orderId={orderId} />;
}
