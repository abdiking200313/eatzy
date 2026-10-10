# Grocery and pharmacy test parity (Flutter → React Native)

Issue #396 (P7-08). Each Flutter grocery and pharmacy test case is listed with its React Native
equivalent. RN paths are relative to `react_native_app/src/`. `grocery/` means `features/grocery/`
and `pharmacy/` means `features/pharmacy/`.

Besides the five files named in the issue, this also covers the grocery and pharmacy cases in
`cart_screens_test.dart` and `checkout_screens_test.dart`, which hold the real cart and checkout
screen tests. The shared `confirmDemoOrder` group in `checkout_screens_test.dart` is not
grocery- or pharmacy-specific. It is mapped in `food-test-parity.md`, so it is not counted here.

**Totals:** 70 Flutter cases: 60 already ported, 5 added in #396, 2 partly ported before and
completed in #396, 3 N/A, 0 gaps. #396 also added 2 supplementary tests for the in-flight checkout
cases.

Notes that apply to several rows:

- **Activity feed.** RN keeps no client-side activity record. The Activity tab reads the server's
  `customer_activity` view. Flutter assertions on `activityController.items` are therefore N/A. The
  rest of each case (order placed, cart cleared, server total returned) is ported.
- **Checkout logic.** Flutter's `GroceryController.confirmOrder` and
  `PharmacyController.placeDemoOrder` are split in RN. The pure order flow is in
  `grocery/grocery-checkout.ts` and `pharmacy/pharmacy-checkout.ts`. The in-flight guard and
  "loading" state belong to the checkout screens.
- **Idempotency key.** RN has no caller-supplied key. Each checkout visit creates one key and reuses
  it on retry. The order-flow functions still accept a key or generate one.

## grocery_controller_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| calculates unit and weighted product totals in USD amounts | `stores/grocery-cart-store.test.ts` › calculates unit and weighted product totals | ported |
| changing the pricing repository changes the displayed delivery-fee estimate, and unconfigured pricing reports it as unknown (#279) | `stores/grocery-cart-store.test.ts` › the delivery-fee estimate follows the loaded pricing, and unconfigured pricing reports fee and total as unknown (issue #279) | added in #396 |
| does not add unavailable products or exceed available stock | `stores/grocery-cart-store.test.ts` › does not add unavailable products, and rejects a quantity change that would exceed available stock | ported |
| adds several quantity steps at once, all or nothing | `stores/grocery-cart-store.test.ts` › adds several quantity steps at once, all or nothing | ported |
| a product photo URL survives the local cart snapshot | `stores/grocery-cart-store.test.ts` › GroceryProduct.toJson/fromJson round-trips, including a photo URL | ported |
| requires and records the selected substitution preference | `grocery/grocery-checkout.test.ts` › requires and records the selected substitution preference | ported (activity part N/A, see notes) |
| checkout validates cart, slot, and preference — no address | `grocery/grocery-checkout.test.ts` › validates cart, slot, and preference — no address | ported |
| grocery cart survives a simulated app reload | `stores/grocery-cart-store.test.ts` › grocery cart survives a simulated app reload | ported |
| switching accounts clears and reloads the grocery cart | `stores/grocery-cart-store.test.ts` › switching accounts clears and reloads the grocery cart | ported |
| confirmOrder surfaces an error, resets loading, and keeps the cart when the order repository throws | `grocery/grocery-checkout.test.ts` › surfaces an error and keeps the cart when the order repository throws; `grocery/grocery-checkout-screen.test.tsx` › rejects a slot that has passed with the same generic message as Flutter, keeps the cart, and retries with the same key | ported (the screen test checks that the button is re-enabled) |
| confirmOrder surfaces a generic error … when place_grocery_order rejects an elapsed delivery slot (#82) | `grocery/grocery-checkout.test.ts` › surfaces the generic error and keeps the cart when place_grocery_order rejects an elapsed delivery slot (issue #82) | ported |
| confirmOrder ignores a second call while a submission is in flight (#59) | `grocery/grocery-checkout-screen.test.tsx` › places only one order on a double tap (#59); › a dropped second tap does not disturb the first submission, which still completes | ported, plus 1 supplementary test added in #396 (the first test left the order unresolved, so it never checked that the first submission completes) |
| confirmOrder forwards a caller-supplied idempotency key, and synthesizes one when none is given (#59) | `grocery/grocery-checkout.test.ts` › forwards a caller-supplied idempotency key, and synthesizes one when none is given (issue #59) | ported |
| confirmOrder records the RPC-returned total, not the client cart total (#60) | `grocery/grocery-checkout.test.ts` › records the RPC-returned total, not the client cart total (issue #60) | ported (activity part N/A) |
| catalog staleness › load does not refetch an already-loaded, fresh catalog | — | N/A: RN grocery screens have no shared catalog controller or staleness clock. Each list or store screen loads its own data when it mounts. |
| catalog staleness › load refetches once the catalog goes stale | — | N/A: same reason. RN has no grocery catalog cache that can go stale. |
| catalog staleness › load(forceRefresh: true) always refetches regardless of staleness | `grocery/grocery-store-list-screen.test.tsx` › pulling to refresh reloads the store list; `grocery/grocery-store-screen.test.tsx` › pulling to refresh reloads the store, keeping it on screen if the refresh fails | N/A as a controller case. Its user-facing purpose (a forced reload) is covered by the pull-to-refresh tests listed. |

## grocery_screens_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| the store list renders every seeded store by name, and searching filters stores by name | `grocery/grocery-store-list-screen.test.tsx` › renders every seeded store by name for its own store type, and searching filters by name | ported |
| tapping a store opens a catalog scoped to just that store, searchable by product name | `grocery/grocery-store-list-screen.test.tsx` › tapping a store navigates to its details route; `grocery/grocery-store-screen.test.tsx` › shows a catalog scoped to just that store, searchable by product name | ported (split into navigation and screen) |
| tapping a product opens its details page, which adds the picked weight to the cart | `grocery/grocery-store-screen.test.tsx` › tapping a product pushes its per-store-type details route; `grocery/grocery-product-details-screen.test.tsx` › adds the picked weight of a by-weight product to the grocery cart | ported (split into navigation and screen) |
| pulling to refresh reloads the grocery catalog | `grocery/grocery-store-list-screen.test.tsx` › pulling to refresh reloads the store list | ported |
| products parse their embedded category and survive a cart round-trip | `grocery/api/grocery-repository.test.ts` › parses an embedded category and derives low/out-of-stock state…; › keeps the parsed category through a cart-snapshot round trip | parsing ported earlier; round-trip half added in #396 (the existing round-trip test only used a product with no category) |
| groupByCategory orders sections by sort order, "Other" last | `grocery/grocery-catalog.test.ts` › orders sections by sort order, "Other" last | ported |

## grocery_store_type_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| each category controller lists only its own stores | `grocery/grocery-store-list-screen.test.tsx` › each store type only lists its own stores | ported |
| carts are independent: a meat cart does not touch the grocery cart, and neither asks to replace the other | `stores/grocery-cart-store.test.ts` › a Fresh Meat cart does not touch the grocery cart, and neither reports a store conflict | ported |
| every category has its own registered list, store, cart and checkout routes | `grocery/grocery-store-type-meta.test.ts` › gives every store type its own list, store, cart and checkout routes, with no duplicates; › builds a URL-encoded store details route per store type | ported |
| Fresh Meat and Electronics have their own palettes | `grocery/grocery-store-type-meta.test.ts` › resolves three distinct accents, and plain grocery uses ServiceThemes.grocery | ported |
| the Fresh Meat cart is titled and linked as Fresh Meat | `grocery/grocery-cart-screen.test.tsx` › uses the fresh_meat store type’s own cart, copy and routes | ported |
| Order again puts a Fresh Meat order back into the Fresh Meat cart | `platform/activity/order-again-service.test.ts` › puts a Fresh Meat order back into the Fresh Meat cart, leaving the grocery cart alone | added in #396 (before this, only the route mapping was tested) |

## pharmacy_controller_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| pharmacy cart adds, adjusts, removes, and calculates USD totals | `stores/pharmacy-cart-store.test.ts` › adds, adjusts, removes, and calculates totals | ported |
| changing the pricing repository changes the displayed delivery-fee estimate, and unconfigured pricing reports it as unknown (#279) | `stores/pharmacy-cart-store.test.ts` › the delivery-fee estimate follows the loaded pricing, and unconfigured pricing reports fee and total as unknown (issue #279) | added in #396 |
| adds several units at once, all or nothing | `stores/pharmacy-cart-store.test.ts` › adds several units at once, all or nothing | ported |
| an unavailable OTC product cannot be added | `stores/pharmacy-cart-store.test.ts` › an unavailable (out of stock) OTC product cannot be added | ported |
| a non-OTC product is rejected by the domain controller | `stores/pharmacy-cart-store.test.ts` › a non-OTC (prescription/regulated) product is rejected | ported |
| checkout validates only the cart — no address | `pharmacy/pharmacy-checkout.test.ts` › validates only the cart — no address | ported |
| demo checkout records pharmacy activity and clears its cart | `pharmacy/pharmacy-checkout.test.ts` › places the order with ids and quantities only, then clears the cart; `pharmacy/pharmacy-checkout-screen.test.tsx` › places the order with the note and key, clears the cart and opens activity | ported (the "Pay on delivery" message is checked by the screen test; activity part N/A) |
| pharmacy cart survives a simulated app reload | `stores/pharmacy-cart-store.test.ts` › pharmacy cart survives a simulated app reload | ported |
| switching accounts clears and reloads the pharmacy cart | `stores/pharmacy-cart-store.test.ts` › switching accounts clears and reloads the pharmacy cart | ported |
| placeDemoOrder surfaces an error, resets loading, and keeps the cart when the order repository throws | `pharmacy/pharmacy-checkout.test.ts` › surfaces an error and keeps the cart when the order repository throws; `pharmacy/pharmacy-checkout-screen.test.tsx` › shows the generic error on failure, keeps the cart, and retries with the same key | ported |
| placeDemoOrder ignores a second call while a submission is in flight (#59) | `pharmacy/pharmacy-checkout-screen.test.tsx` › places only one order on a double tap (#59); › a dropped second tap does not disturb the first submission, which still completes | ported, plus 1 supplementary test added in #396 (same reason as grocery) |
| placeDemoOrder forwards a caller-supplied idempotency key, and synthesizes one when none is given (#59) | `pharmacy/pharmacy-checkout.test.ts` › forwards a caller-supplied idempotency key, and synthesizes one when none is given (issue #59) | ported |
| placeDemoOrder records the RPC-returned total, not the client cart total (#60) | `pharmacy/pharmacy-checkout.test.ts` › returns the RPC total, not the client cart total (issue #60) | ported (activity part N/A) |
| catalog staleness › loadProducts does not refetch an already-loaded, fresh catalog | `pharmacy/pharmacy-catalog-store.test.ts` › loadProducts does not refetch an already-loaded, fresh catalog | ported |
| catalog staleness › loadProducts refetches once the catalog goes stale | `pharmacy/pharmacy-catalog-store.test.ts` › loadProducts refetches once the catalog goes stale | ported |
| catalog staleness › loadProducts(forceRefresh: true) always refetches regardless of staleness | `pharmacy/pharmacy-catalog-store.test.ts` › loadProducts(forceRefresh: true) always refetches regardless of staleness | ported |
| store-scoped catalog › loadProducts scopes the catalog to one pharmacy at a time | `pharmacy/pharmacy-catalog-store.test.ts` › loadProducts scopes the catalog to one pharmacy at a time | ported |
| store-scoped catalog › loadProducts narrows results with a search query | `pharmacy/pharmacy-catalog-store.test.ts` › loadProducts narrows results with a search query | ported |
| store-scoped catalog › adding a product from a different pharmacy is rejected without replaceStoreCart | `stores/pharmacy-cart-store.test.ts` › adding a product from a different pharmacy is rejected without replaceStoreCart | ported |

## pharmacy_screens_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| store list › renders every pharmacy and stays overflow-free on a narrow, large-text screen | `pharmacy/pharmacy-store-list-screen.test.tsx` › renders every pharmacy with its address | ported (overflow half N/A: this is a Flutter `RenderFlex` overflow check, and RN flexbox does not raise overflow errors) |
| store list › typing a search term debounces before filtering | `pharmacy/pharmacy-store-list-screen.test.tsx` › typing a search term debounces before filtering, and clearing restores the full list | ported |
| store list › an empty search result shows a reachable, honest empty state | `pharmacy/pharmacy-store-list-screen.test.tsx` › an empty search result shows a reachable, honest empty state | ported |
| store list › tapping a pharmacy navigates to its scoped catalog route | `pharmacy/pharmacy-store-list-screen.test.tsx` › tapping a pharmacy navigates to its scoped catalog route with the name (and photo) attached | ported |
| catalog › pharmacy catalog clearly explains the OTC-only scope | `pharmacy/pharmacy-catalog-screen.test.tsx` › clearly explains the OTC-only scope and shows stock state | ported |
| catalog › tapping a product opens its details page, which adds the picked quantity to the cart | `pharmacy/pharmacy-catalog-screen.test.tsx` › tapping a product opens its details route; `pharmacy/pharmacy-product-details-screen.test.tsx` › adds the picked quantity to the pharmacy cart | ported (split into navigation and screen) |
| catalog › pulling to refresh reloads the pharmacy catalog | `pharmacy/pharmacy-catalog-screen.test.tsx` › pulling to refresh reloads the pharmacy catalog | ported |
| catalog › typing a search term narrows this pharmacy's catalog | `pharmacy/pharmacy-catalog-screen.test.tsx` › typing a search term narrows this pharmacy's catalog | ported |
| catalog › adding a product from a different pharmacy prompts to replace the cart | `pharmacy/pharmacy-catalog-screen.test.tsx` › adding a product from a different pharmacy prompts to replace the cart | ported |

## cart_screens_test.dart (grocery and pharmacy cases)

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| grocery cart › renders lines with totals, and increase/decrease updates the line total and the cart subtotal | `grocery/grocery-cart-screen.test.tsx` › shows the store, each line, subtotal and delivery fee, and continues to checkout; › increase/decrease updates the line total and the cart subtotal | rendering ported earlier; increase/decrease half added in #396 |
| grocery cart › removing the only line in the cart shows the empty state | `grocery/grocery-cart-screen.test.tsx` › removing the only line in the cart shows the empty state | added in #396 |
| grocery cart › increasing past available stock shows a snack bar and leaves the quantity capped | `grocery/grocery-cart-screen.test.tsx` › says no more is available at the stock limit, and steps down to removal | ported |
| pharmacy cart › renders items, the OTC reminder and totals; increase/decrease updates totals; Clear empties the cart | `pharmacy/pharmacy-cart-screen.test.tsx` › renders items, the OTC reminder and totals; increase/decrease updates totals; Clear empties the cart | ported |
| pharmacy cart › decrementing the only unit of an item removes it and shows the empty state | `pharmacy/pharmacy-cart-screen.test.tsx` › decrementing the only unit of an item removes it and shows the empty state | ported |
| pharmacy cart › an item already at its stock ceiling disables the increase button instead of over-adding it | `pharmacy/pharmacy-cart-screen.test.tsx` › an item already at its stock ceiling disables the increase button instead of over-adding it | ported |
| shared › grocery: an empty cart has no checkout button, and "Browse stores" navigates back to the catalog | `grocery/grocery-cart-screen.test.tsx` › uses the grocery store type’s own cart, copy and routes | added in #396 (a `grocery` row added to the existing per-store-type `it.each`, which now also checks that there is no checkout button) |
| shared › grocery: tapping continue navigates to checkout | `grocery/grocery-cart-screen.test.tsx` › shows the store, each line, subtotal and delivery fee, and continues to checkout | ported |
| shared › pharmacy: an empty cart has no checkout button, and "Browse pharmacy" navigates back to the catalog | `pharmacy/pharmacy-cart-screen.test.tsx` › an empty cart has no checkout button, and "Browse pharmacy" navigates back to the catalog | ported |
| shared › pharmacy: tapping continue navigates to checkout | `pharmacy/pharmacy-cart-screen.test.tsx` › a filled cart continues to checkout | ported |

## checkout_screens_test.dart (grocery and pharmacy cases)

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| grocery checkout › an incomplete grocery checkout flags only the slot and substitution sections, since there are no address fields to fill | `grocery/grocery-checkout-screen.test.tsx` › flags only the slot and substitution sections on an incomplete checkout, since there are no address fields | ported |
| double-tap places only one order (#59) › grocery | `grocery/grocery-checkout-screen.test.tsx` › places only one order on a double tap (#59) | ported |
| double-tap places only one order (#59) › pharmacy | `pharmacy/pharmacy-checkout-screen.test.tsx` › places only one order on a double tap (#59) | ported |
