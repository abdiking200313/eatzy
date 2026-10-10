import { router } from 'expo-router';

import { CartAppBarAction } from '@/components/cart-app-bar-action';
import { AppRoutes } from '@/platform/navigation/app-routes';
import { selectPharmacyCartItemCount, usePharmacyCartStore } from '@/stores/pharmacy-cart-store';

export type PharmacyCartStoreHook = typeof usePharmacyCartStore;

/**
 * Ports the `CartBadgeAction(key: 'pharmacy-cart-action', ...)` both
 * `PharmacyStoreListScreen` and `PharmacyCatalogScreen` put in their app
 * bar: the pharmacy cart's item count, opening `/pharmacy/cart` on press.
 */
export function PharmacyCartAction({ cartStore = usePharmacyCartStore }: { cartStore?: PharmacyCartStoreHook }) {
  const itemCount = cartStore((state) => selectPharmacyCartItemCount(state.items));
  return (
    <CartAppBarAction
      itemCount={itemCount}
      onPress={() => router.push(AppRoutes.pharmacyCart as never)}
      tooltip={`Pharmacy cart (${itemCount})`}
      icon="shopping-bag"
      service="pharmacy"
    />
  );
}
