import { MerchantShell } from '@/features/merchant/shell/merchant-shell';

// Ports AppRoutes.merchantDashboard ('/merchant') from
// flutter_app/lib/app/app_router.dart, which maps it straight to
// `MerchantShell()` (issue #406). The merchant-role gate itself lives in
// `merchant/_layout.tsx` (issue #363).
export default function MerchantDashboardScreen() {
  return <MerchantShell />;
}
