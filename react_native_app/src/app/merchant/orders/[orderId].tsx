import { useLocalSearchParams } from 'expo-router';

import { OrderDetailScreen } from '@/features/merchant/orders/order-detail-screen';
import { useSessionStore } from '@/stores/session-store';

// Ports AppRoutes.merchantOrderDetail ('/merchant/orders/:orderId') from
// flutter_app/lib/app/app_router.dart, which builds
// `OrderDetailScreen(orderId: ...)` and lets it resolve the signed-in
// merchant's own store and orders (issue #409). Reached from a tap on the
// Orders list (`merchantOrderDetailPath`) or a deep link; the merchant-role
// gate lives in `merchant/_layout.tsx`.
export default function MerchantOrderDetailRoute() {
  const { orderId } = useLocalSearchParams<{ orderId: string }>();
  const ownerId = useSessionStore((state) => state.userId);
  return <OrderDetailScreen orderId={String(orderId ?? '')} ownerId={ownerId} />;
}
