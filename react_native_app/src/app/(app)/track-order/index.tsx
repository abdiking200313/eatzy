import { TrackOrderScreen } from '@/features/orders/track-order-screen';

// Ports AppRoutes.trackOrder ('/track-order') from
// flutter_app/lib/app/app_routes.dart / app_router.dart. Kept only for old
// deep links with no order id: the real screen renders its "No order
// selected" state here (issue #398). The reachable form is
// trackOrderDetails ('/track-order/:serviceId/:orderId').
export default function TrackOrderRoute() {
  return <TrackOrderScreen />;
}
