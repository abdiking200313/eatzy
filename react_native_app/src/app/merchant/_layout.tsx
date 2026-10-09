import { Redirect, Stack } from 'expo-router';

import { AppRoutes } from '@/platform/navigation/app-routes';
import { useMerchantSessionGateStore } from '@/stores/merchant-session-gate';
import { useSessionStore } from '@/stores/session-store';

// Standalone merchant dashboard (issue #232/#236), outside the customer
// (app) shell -- mirrors app_router.dart's `MerchantShell` + its
// merchant-session gating (issue #363).
//
// `(auth)/_layout.tsx`/`(app)/_layout.tsx`'s own `resolveRedirect` calls
// already confine a signed-in `merchant`/`admin` account to this path (and
// any sub-path under it) for the whole session. `resolveRedirect` itself
// has no rule for the opposite direction -- a plain customer (or a
// signed-out visitor) reaching `/merchant` -- because this top-level
// `merchant` route group sits outside both the `(auth)` and `(app)` groups
// those layouts gate, so this file is where that other direction is
// enforced instead: a non-merchant is sent back to the main customer area,
// and a signed-out visitor to `/login`, exactly mirroring
// `isProtectedLocation('/merchant')`/`resolveRedirect`'s own rules for this
// path.
//
// Renders nothing (rather than the shell, or a redirect) while the role is
// still resolving for the current user -- see `(auth)/_layout.tsx`'s doc
// comment on `merchantRolePending`. This never flashes the shell to a
// plain customer, and never bounces a real merchant/admin out while their
// own role lookup is still in flight.
export default function MerchantLayout() {
  const status = useSessionStore((state) => state.status);
  const userId = useSessionStore((state) => state.userId);
  const merchantResolvedUserId = useMerchantSessionGateStore((state) => state.resolvedUserId);
  const isMerchantRole = useMerchantSessionGateStore((state) => state.isMerchantRole);

  if (status === 'loading') {
    return null;
  }

  if (userId == null) {
    return <Redirect href={AppRoutes.login} />;
  }

  const merchantRolePending = merchantResolvedUserId !== userId;
  if (merchantRolePending) {
    return null;
  }

  if (!isMerchantRole) {
    return <Redirect href={AppRoutes.mainApp} />;
  }

  return <Stack screenOptions={{ headerShown: false }} />;
}
