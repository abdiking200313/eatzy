import { CatalogScreen } from '@/features/merchant/catalog/catalog-screen';
import { useSessionStore } from '@/stores/session-store';

// Ports AppRoutes.merchantCatalog ('/merchant/catalog') from
// flutter_app/lib/app/app_router.dart, which builds `CatalogScreen()` with
// no store params and lets it resolve the signed-in merchant's own store
// (issue #410). Reached from My Store's "Manage catalog" button or a deep
// link; the merchant-role gate lives in `merchant/_layout.tsx`.
export default function MerchantCatalogRoute() {
  const ownerId = useSessionStore((state) => state.userId);
  return <CatalogScreen ownerId={ownerId} />;
}
