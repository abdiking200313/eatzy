# Food test parity (Flutter → React Native)

Issue #388 (P6-07). Each Flutter food test case is listed with its React Native
equivalent. RN paths are relative to `react_native_app/src/`; `food/` means
`app/(app)/(tabs)/food/`.

**Totals:** 35 Flutter cases: 29 already ported, 1 added in #388 (plus 1 supplementary #388 test for the in-flight case), 5 N/A, 0 gaps.

## food_home_screen_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| food home coordinates category and restaurant loading | `food/index.test.tsx` › shows a loading state until both categories and restaurants have loaded | ported |
| food home stays overflow-free on a narrow, large-text screen | — | N/A: Flutter `RenderFlex` overflow check; RN flexbox does not raise overflow errors |
| tapping a category chip runs a real, server-side filter | `food/index.test.tsx` › tapping a category chip runs a real, server-side filter; tapping it again clears it | ported |
| typing a search term debounces before filtering | `food/index.test.tsx` › typing a search term debounces before filtering, and the clear button clears it immediately | ported |
| an empty filtered result set shows a reachable, honest empty state | `food/index.test.tsx` › shows the category-filtered empty-state copy for an empty filtered result set | ported |

## food_controller_test.dart

In RN, `FoodController.confirmOrder` lives inside `food/checkout.tsx`, so these cases are tested at the screen level.

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| confirmOrder is a no-op when the cart is empty | `food/checkout.test.tsx` › submitting with an empty cart is a no-op: no order is placed and no error is shown | added in #388 |
| confirmOrder places the order, records activity, and clears the cart | `food/checkout.test.tsx` › on success clears the food cart and opens order tracking for the server-returned order id | ported (the activity part is N/A because RN reads activity from the server's `customer_activity` view and keeps no client-side record) |
| confirmOrder surfaces a message when the repository throws | `food/checkout.test.tsx` › surfaces an error, resets the submit button, and keeps the cart when placing the order fails | ported |
| confirmOrder ignores a second call while a submission is in flight (#59) | `food/checkout.test.tsx` › drops a second tap in the same frame, before the disabled button has re-rendered; › a dropped second tap does not disturb the first submission, which still completes | ported + added in #388 (the first test only covered the dropped call; the new one checks that the first submission still completes) |
| confirmOrder forwards a caller-supplied idempotency key, and synthesizes one when none is given (#59) | `food/checkout.test.tsx` › a double tap on "Place order" places only one order, with an idempotency key…; › a retry after a failure reuses the same idempotency key; `platform/orders/idempotency-key.test.ts` › returns a 32-character lowercase hex string | ported (RN has no caller-supplied key. The screen creates one key per visit and reuses it on retry) |
| confirmOrder records the RPC-returned total, not the client cart total, into the activity feed (#60) | `features/food/api/food-order-repository.test.ts` › calls place_food_order with ids, quantities and the idempotency key only, and returns the server-computed totals | N/A: RN has no client activity record. Order tracking reads the server's totals. The repository test checks that the server totals are what gets returned |

## restaurant_screen_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| menu item parses numeric strings from Supabase | `features/food/api/restaurant-menu-repository.test.ts` › menuItemFromRow › parses numeric strings from Supabase | ported |
| menu item throws instead of silently pricing at $0.00 for an unparseable price (#62) | `restaurant-menu-repository.test.ts` › throws instead of silently pricing at $0.00 for an unparseable price (#62) | ported |
| menu item throws for a missing price rather than defaulting to $0.00 | `restaurant-menu-repository.test.ts` › throws for a missing price rather than defaulting to $0.00 | ported |
| restaurant page groups and navigates categorized items | `food/restaurants/[restaurantId]/index.test.tsx` › renders the restaurant header, categories…; › tapping a category chip scrolls the menu list to that category; › adds a menu item to the food cart store and shows a confirmation; `hooks/use-cart-snackbar.test.ts` › auto-hides the message after 1800ms | ported (the floating `SnackBar` shape is Flutter-only, and the short auto-dismiss is tested on the hook) |
| restaurant page shows a useful menu error | `food/restaurants/[restaurantId]/index.test.tsx` › shows an ErrorState with a working retry on a first load that fails | ported |
| menu cards grow for narrow screens and larger text | — | N/A: Flutter `RenderBox` overflow check under a text scale, with no RN equivalent |

## food_categories_screen_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| food categories renders a white-card grid of categories | `food/categories.test.tsx` › food categories renders a white-card grid of categories | ported |
| food categories stays overflow-free on a narrow, large-text screen | — | N/A: Flutter overflow check |
| tapping a category card navigates to a filtered explore view | `food/categories.test.tsx` › tapping a category card navigates to a filtered explore view | ported |

## food_explore_screen_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| food Explore lists restaurants rather than service modules | `food/explore.test.tsx` › food Explore lists restaurants rather than service modules | ported |
| food Explore stays overflow-free on a narrow, large-text screen | — | N/A: Flutter overflow check |
| a category-scoped explore view titles itself and filters via the repository | `food/explore.test.tsx` › a category-scoped explore view titles itself and filters via the repository | ported |
| an empty category result shows a category-aware empty state | `food/explore.test.tsx` › an empty category result shows a category-aware empty state | ported |

## checkout_screens_test.dart (food cases only)

The `grocery checkout` group and the grocery and pharmacy double-tap cases are other verticals, so they are out of scope and not counted.

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| food checkout › placing an order surfaces an error, resets the submit button, and keeps the cart when the order repository throws | `food/checkout.test.tsx` › surfaces an error, resets the submit button, and keeps the cart when placing the order fails | ported (no activity assertion, for the reason given above) |
| food checkout › asks only for an optional delivery note (no address, no payment picker) and sends the note with the order | `food/checkout.test.tsx` › asks only for an optional delivery note (no address, no payment picker) and sends the note with the order | ported |
| double-tap places only one order (#59) › food | `food/checkout.test.tsx` › a double tap on "Place order" places only one order, with an idempotency key and no client-computed prices | ported |
| confirmDemoOrder › passes the thrown error and stack trace to onSaveFailed | `platform/orders/confirm-order-flow.test.ts` › routes a thrown placeOrder error to onSaveFailed without recording activity or clearing the cart | ported (JS errors carry their own `stack`, so there is no separate stack-trace argument) |
| confirmDemoOrder › returns onConfirmed and records activity/clears the cart when placeOrder succeeds | `confirm-order-flow.test.ts` › runs placeOrder -> recordActivity -> clearCart -> onConfirmed, in order, on the happy path | ported |
| confirmDemoOrder › returns onInvalid without placing an order | `confirm-order-flow.test.ts` › returns onInvalid without ever calling placeOrder when validation fails | ported |

## food_order_request_test.dart

| Flutter case | RN test (file › name) | Status |
| --- | --- | --- |
| FoodOrderRequest.toRpcParams › sends the trimmed delivery note as the street and leaves name, phone, district and city blank | `features/food/api/food-order-repository.test.ts` › foodOrderRequestToRpcParams › sends the trimmed delivery note as the street and leaves name, phone, district and city blank for the server to fill | ported |
| FoodOrderRequest.toRpcParams › the delivery note is optional | `food-order-repository.test.ts` › the delivery note is optional | ported |
| FoodOrderRequest.toRpcParams › still rejects an empty item list | `food-order-repository.test.ts` › still rejects an empty item list | ported |
| describeOrderSaveError › shows the server message when the profile has no name/phone | `platform/orders/order-errors.test.ts` › shows the server message when the profile has no name/phone | ported |
| describeOrderSaveError › falls back to the generic message for any other failure | `platform/orders/order-errors.test.ts` › falls back to the generic message for any other failure | ported |
