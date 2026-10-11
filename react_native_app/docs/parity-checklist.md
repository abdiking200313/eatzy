# Route-by-route parity checklist (Flutter → React Native)

Issue #415 (P10-03). This file has one row for every route registered in
`flutter_app/lib/app/app_routes.dart` / `app_router.dart`, plus Flutter's
`NotFoundScreen`. Each row compares the route with its Expo Router file under
`react_native_app/src/app/`. RN paths below are relative to
`react_native_app/src/`. Flutter test files are in `flutter_app/test/`.

## How this was checked

The check was done by reading code and tests only. No screen was compared
visually on a device or simulator. For each column:

- **Layout**: the RN screen was read next to the Flutter screen. The check
  covers the same scaffold and title, section order, shared components and
  copy. Pixel-level differences and spacing are not covered (see
  #416 for the accessibility pass and P10-06 #418 for store screenshots).
- **States**: the loading, empty, error and success branches in both screens
  were compared, along with any not-found or signed-out branch.
- **Behavior**: navigation targets, params, redirects and actions were
  compared. "Linked" means the route has an in-app entry point. This is
  checked automatically by `flutter-route-parity.test.ts`.
- **Tests**: the RN tests that port or match the Flutter test file for that
  screen. For food, grocery and pharmacy, the test-by-test mapping is already
  in [`food-test-parity.md`](food-test-parity.md) (#388) and
  [`grocery-pharmacy-test-parity.md`](grocery-pharmacy-test-parity.md)
  (#396), so this file does not repeat it.

Flutter `RenderFlex` overflow tests (`layout_test.dart` and the
"stays overflow-free" cases) have no RN equivalent. They are N/A for every
row and are not listed again.

### Automated guards

- `src/flutter-route-parity.test.ts` (added in #415) reads `app_routes.dart`
  and fails in these cases:
  - a Flutter route constant has no row in its table;
  - a row's RN file is missing, or is served at a different URL;
  - an RN route file maps to no Flutter route and is not listed as RN-only;
  - a route has no in-app link and is not documented as deep-link-only;
  - a deep-link-only route gains an in-app link.

  The last two port the "linked from somewhere" half of
  `route_reachability_test.dart`. The earlier port, `route-reachability.test.tsx`
  (#358), left that half out.
- `src/route-reachability.test.tsx` mounts most routes through the real
  router, and checks every legacy redirect.

**Result:** 55 rows. 48 signed off, 7 linked to 6 follow-up issues (#540–#545).

## Public and auth

| Flutter route | Flutter screen | RN route file | Layout | States | Behavior | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `root` `/` | redirect → `/welcome` | `app/index.tsx` | n/a (redirect) | n/a | Redirects to `/welcome`, same as Flutter. Flutter never links here. RN's `AppScaffold` back fallback does (`router.replace('/')`), see #540 | `route-reachability.test.tsx` › root redirects to /welcome; `flutter-route-parity.test.ts` (known divergence) | Gap: #540 |
| `welcome` `/welcome` (+ `?revisit=true`) | `WelcomeScreen` + `OnboardingPage1/2/3` | `app/(auth)/welcome.tsx` | Same 3-slide pager, skip, dots, CTA | n/a (static) | Onboarding seen flag, the revisit flag skips the returning-user redirect, Register/Login CTAs | `(auth)/welcome.test.tsx`, `welcome-back-navigation.test.tsx` ↔ `onboarding_screen_test.dart` (6), `auth_back_to_onboarding_test.dart` (5) | Signed off |
| `login` `/login` | `LoginScreen` | `app/(auth)/login.tsx` | Same `AuthCard` form, logo and links | Submitting, invalid credentials and navigation-error states | Customer → `/app`, merchant/admin → `/merchant`, forgot-password and register links, back → welcome revisit | `(auth)/login*.test.tsx` (5 files) ↔ `login_screen_test.dart` (6) | Signed off |
| `register` `/register` | `RegisterScreen` | `app/(auth)/register.tsx` | Same fields, including date of birth | Validation, submitting, failure, email-confirmation and session outcomes | Same sign-up outcomes and redirects | `(auth)/register*.test.tsx` (5 files) ↔ `register_screen_test.dart` (10) | Signed off |
| `forgotPassword` `/forgot-password` | `ForgotPasswordScreen` | `app/(auth)/forgot-password.tsx` | Same `AuthCard` layout | Sending, sent and error states (code read) | Sends a reset email, back → login. Errors use `describeAuthError` fixed copy instead of Flutter's raw exception text (a deliberate change, see the file header) | `route-reachability.test.tsx` mount only. Flutter has no screen test either | Signed off |
| `resetPassword` `/reset-password` | `ResetPasswordScreen` | `app/(app)/reset-password.tsx` | Same `AuthCard` layout | Saving and error states (code read) | Reachable from Settings and from the recovery link (`reset-callback.tsx` + `use-password-recovery-redirect.ts`) | `password-recovery.test.ts`, `use-password-recovery-redirect.test.ts`, `reset-callback.test.tsx`. Flutter has no screen test | Signed off |

## Main shell (bottom-nav tabs) and standalone pages

| Flutter route | Flutter screen | RN route file | Layout | States | Behavior | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `mainApp` `/app` | `SuperAppHomeScreen` in `MainAppScreen` shell | `app/(app)/(tabs)/app.tsx` + `(tabs)/_layout.tsx` | Same header, search, promo, service grid, popular stores and recent activity | Popular Stores has an error state with retry. Recent activity can be empty | Service tiles switch shell branches, "More" → `/services` | `(tabs)/app.test.tsx` ↔ `super_app_home_test.dart`: 6 of 7 ported (1 N/A overflow). The "one card with row dividers" case is not ported | Gap: #544 |
| `explore` `/explore` | `ExploreScreen` | `app/(app)/(tabs)/explore.tsx` | Search and store list match. **The food-category chip row is missing** | Loading, error ("Stores could not be loaded.") and empty ("No stores match your search.") match | Search filter and opening a store match. The chip-to-search action is missing | `(tabs)/explore.test.tsx` ↔ `explore_screen_test.dart` (3/3) | Gap: #542 |
| `activity` `/activity` | `ActivityScreen` | `app/(app)/(tabs)/activity.tsx` | Same rows with status pills | Loading, empty, error with retry, pull-to-refresh | Row → track-order details and Realtime refresh match. **Switching to the tab does not reload** | `(tabs)/activity.test.tsx`, `stores/activity-store.test.ts` ↔ `activity_controller_test.dart`. `main_app_screen_test.dart` case 4 is not ported | Gap: #541 |
| `profile` `/profile` | `ProfileScreen` | `app/(app)/(tabs)/profile.tsx` | Same header, options (Notifications, Help & Support, Settings) and logout | Loading and fallback "Zivo customer" | Reloads after returning from Settings, logout → `/login`. Deep-link-only (tab), as in Flutter | `(tabs)/profile.test.tsx` ↔ `profile_screen_test.dart` (4) | Signed off |
| shell itself | `MainAppScreen` | `app/(app)/(tabs)/_layout.tsx` | 4 tabs. Food, grocery and pharmacy are hidden branches | n/a | Per-tab state is kept, and the nav bar stays visible in verticals | `(tabs)/main-app-tabs.test.tsx` ↔ `main_app_screen_test.dart`: 3 of 4 (case 4 → #541) | Covered by `activity` row |
| `services` `/services` | `CategoriesScreen` | `app/(app)/services.tsx` | Same photo cards, coming-soon placeholders and back control | n/a (static registry) | Opens each vertical. Coming-soon tiles show a message | `(app)/services.test.tsx` ↔ `categories_screen_test.dart`: 4 screen cases ported, 1 N/A. 2 component cases are not ported (see `food` row) | Signed off |
| `addresses` `/addresses` | `AddressesScreen` | `app/(app)/addresses.tsx` | **Placeholder text only** | none | Deep-link-only in both apps (addresses out of scope, 2026-09-25) | Placeholder mount in `route-reachability.test.tsx`. `delivery_address_repository_test.dart` is not ported | Gap: #545 |
| `settings` `/settings` | `SettingsScreen` | `app/(app)/settings/index.tsx` → `features/settings/settings-screen.tsx` | Same sections | Preference load/save errors, delete-account flow | Links to reset password, privacy and terms. Logout and delete → `/login` | `features/settings/settings-screen.test.tsx` ↔ `settings_screen_test.dart` (18) | Signed off |
| `support` `/support` | `SupportScreen` | `app/(app)/support.tsx` | Same help topics, FAQ and contact cards | n/a (static) | Static content | `(app)/support.test.tsx`. Flutter has no screen test | Signed off |
| `privacyPolicy` `/settings/privacy-policy` | `PrivacyPolicyScreen` | `app/(app)/settings/privacy-policy.tsx` | Shared `LegalDocumentScreen` | n/a (static) | Linked from Settings | `features/legal/legal-screens.test.tsx` ↔ `legal_screens_test.dart` (3) | Signed off |
| `termsOfService` `/settings/terms-of-service` | `TermsOfServiceScreen` | `app/(app)/settings/terms-of-service.tsx` | Shared `LegalDocumentScreen` | n/a (static) | Linked from Settings | same as above | Signed off |
| `trackOrder` `/track-order` | `TrackOrderScreen` (no order) | `app/(app)/track-order/index.tsx` | Same screen | "No order selected" empty state | Deep-link-only in both apps | `features/orders/track-order-screen.test.tsx` ↔ `track_order_screen_test.dart` (11) | Signed off |
| `trackOrderDetails` `/track-order/:serviceId/:orderId` | `TrackOrderScreen` | `app/(app)/track-order/[serviceId]/[orderId].tsx` | Same timeline and summary | Loading, not found, error, live updates | Linked from Activity rows and food checkout | same as above | Signed off |

## Merchant

| Flutter route | Flutter screen | RN route file | Layout | States | Behavior | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `merchantDashboard` `/merchant` | `MerchantShell` | `app/merchant/index.tsx` + `merchant/_layout.tsx` | Merchant: "Zivo Merchant" bar with My Store and Orders tabs (kept mounted). Admin: "Zivo Admin" Accounts screen only. Same as Flutter | Per-tab loading, empty and error. Signed-out "session ended" view | Merchant/admin sessions are confined to `/merchant/**`, customers are redirected away | `features/merchant/shell/merchant-shell.test.tsx`, `orders/orders-screen.test.tsx`, `store/my-store-screen.test.tsx`, `admin/admin-accounts-screen.test.tsx`, `merchant-redirect.test.tsx` ↔ `merchant_shell_test.dart`, `orders_screen_test.dart`, `my_store_screen_test.dart`, `admin_accounts_screen_test.dart`, `merchant_session_gate_test.dart` | Signed off |
| `merchantOrderDetail` `/merchant/orders/:orderId` | `OrderDetailScreen` | `app/merchant/orders/[orderId].tsx` | Same detail and status actions | Loading, error, transition errors | Linked from the orders list (`merchantOrderDetailPath`) | `features/merchant/orders/order-detail-screen.test.tsx` ↔ `order_detail_screen_test.dart` (6) | Signed off |
| `merchantCatalog` `/merchant/catalog` | `CatalogScreen` | `app/merchant/catalog.tsx` | Same catalog editor | Loading, empty, error, pull-to-refresh | Linked from My Store | `features/merchant/catalog/catalog-screen.test.tsx` ↔ `catalog_screen_test.dart` (6) | Signed off |

## Food

Test mapping: [`food-test-parity.md`](food-test-parity.md) (35 Flutter cases, 0 gaps).

| Flutter route | Flutter screen | RN route file | Layout | States | Behavior | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `food` `/food` | `FoodHomeScreen` | `app/(app)/(tabs)/food/index.tsx` | Same search, category chips, restaurant rows and cart action | Loading, error, filtered empty | Server-side category filter, debounced search | `food/index.test.tsx` ↔ `food_home_screen_test.dart`. `CategoriesSection` empty state and `SectionHeader` action cases (`categories_screen_test.dart`) are not ported | Gap: #544 |
| `foodRestaurant` `/food/restaurants/:restaurantId` | `RestaurantScreen` | `app/(app)/(tabs)/food/restaurants/[restaurantId]/index.tsx` | Same hero, category chip bar and grouped menu | Loading, error with retry, empty menu | Add to cart with snackbar, chip scroll, open item | `food/restaurants/[restaurantId]/index.test.tsx` ↔ `restaurant_screen_test.dart` | Signed off |
| `foodMenuItem` `/food/restaurants/:restaurantId/item/:itemId` | `MenuItemDetailsScreen` | `app/(app)/(tabs)/food/restaurants/[restaurantId]/item/[itemId].tsx` | Shared `ProductDetailsView` | Loading, error, not found | Add with quantity | `…/item/[itemId].test.tsx`. Flutter has only a `layout_test.dart` overflow case | Signed off |
| `foodCategories` `/food/categories` | `FoodCategoriesScreen` | `app/(app)/(tabs)/food/categories.tsx` | White-card grid | Loading, empty, error | Card → `/food/explore?categoryId=&categoryName=` | `food/categories.test.tsx` ↔ `food_categories_screen_test.dart` | Signed off |
| `foodExplore` `/food/explore` | `FoodExploreScreen` | `app/(app)/(tabs)/food/explore.tsx` | Search and restaurant list | Loading, error, category-aware empty | Reads `categoryId`/`categoryName` query params | `food/explore.test.tsx` ↔ `food_explore_screen_test.dart` | Signed off |
| `foodCart` `/food/cart` | `CartScreen` | `app/(app)/(tabs)/food/cart.tsx` | Shared `CartView` | Empty ("Browse restaurants"), pricing pending | Quantity, remove, clear, continue → checkout | `food/cart.test.tsx` ↔ `cart_screens_test.dart` (food) | Signed off |
| `foodCheckout` `/food/checkout` | `CheckoutScreen` | `app/(app)/(tabs)/food/checkout.tsx` | Shared `CheckoutView` | Empty, submitting, error with retry | Idempotent order placement → track order | `food/checkout.test.tsx` ↔ `food_controller_test.dart`, `checkout_screens_test.dart` | Signed off |

## Grocery engine (Grocery, Fresh Meat, Electronics)

The three store types share one RN screen per role, set up by
`features/grocery/grocery-store-type-meta.ts`. Flutter does the same with
`GroceryStoreType`. Test mapping:
[`grocery-pharmacy-test-parity.md`](grocery-pharmacy-test-parity.md) (70
Flutter cases, 0 gaps).

| Flutter route | Flutter screen | RN route file | Layout | States | Behavior | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `grocery` `/grocery` | `GroceryScreen(grocery)` | `app/(app)/(tabs)/grocery/index.tsx` | Store list with search and cart action | Loading, error, empty, pull-to-refresh | Store → store details | `features/grocery/grocery-store-list-screen.test.tsx` ↔ `grocery_screens_test.dart` | Signed off |
| `groceryStore` `/grocery/stores/:storeId` | `GroceryStoreScreen` | `app/(app)/(tabs)/grocery/stores/[storeId]/index.tsx` | Store hero and catalog by category | Loading, error, not found, refresh | Search, add to cart, open product | `grocery-store-screen.test.tsx` | Signed off |
| `groceryProduct` `/grocery/stores/:storeId/product/:productId` | `GroceryProductDetailsScreen` | `…/grocery/stores/[storeId]/product/[productId].tsx` | Shared `ProductDetailsView` | Loading, error, not found | Weight/quantity picker → cart | `grocery-product-details-screen.test.tsx` | Signed off |
| `groceryCart` `/grocery/cart` | `GroceryCartScreen` | `app/(app)/(tabs)/grocery/cart.tsx` | Shared `CartView` | Empty, stock-limit snackbar | Quantity changes → checkout | `grocery-cart-screen.test.tsx` ↔ `cart_screens_test.dart` | Signed off |
| `groceryCheckout` `/grocery/checkout` | `GroceryCheckoutScreen` | `app/(app)/(tabs)/grocery/checkout.tsx` | Slot and substitution pickers | Empty, submitting, elapsed-slot error | Idempotent order → `/activity` | `grocery-checkout-screen.test.tsx`, `grocery-checkout.test.ts` | Signed off |
| `freshMeat` `/grocery/fresh-meat` | `GroceryScreen(freshMeat)` | `…/grocery/fresh-meat/index.tsx` | Same as `grocery`, with its own palette and title | same | same | same as `grocery` (store-type cases) | Signed off |
| `freshMeatStore` `/grocery/fresh-meat/stores/:storeId` | `GroceryStoreScreen` | `…/fresh-meat/stores/[storeId]/index.tsx` | same | same | same | same | Signed off |
| `freshMeatProduct` `…/fresh-meat/stores/:storeId/product/:productId` | `GroceryProductDetailsScreen` | `…/fresh-meat/stores/[storeId]/product/[productId].tsx` | same | same | same | same | Signed off |
| `freshMeatCart` `/grocery/fresh-meat/cart` | `GroceryCartScreen` | `…/fresh-meat/cart.tsx` | same | same | Separate cart (owner decision 2026-09-25) | same | Signed off |
| `freshMeatCheckout` `/grocery/fresh-meat/checkout` | `GroceryCheckoutScreen` | `…/fresh-meat/checkout.tsx` | same | same | same | same | Signed off |
| `electronics` `/grocery/electronics` | `GroceryScreen(electronics)` | `…/grocery/electronics/index.tsx` | Same as `grocery`, with its own palette and title | same | same | same | Signed off |
| `electronicsStore` `/grocery/electronics/stores/:storeId` | `GroceryStoreScreen` | `…/electronics/stores/[storeId]/index.tsx` | same | same | same | same | Signed off |
| `electronicsProduct` `…/electronics/stores/:storeId/product/:productId` | `GroceryProductDetailsScreen` | `…/electronics/stores/[storeId]/product/[productId].tsx` | same | same | same | same | Signed off |
| `electronicsCart` `/grocery/electronics/cart` | `GroceryCartScreen` | `…/electronics/cart.tsx` | same | same | Separate cart | same | Signed off |
| `electronicsCheckout` `/grocery/electronics/checkout` | `GroceryCheckoutScreen` | `…/electronics/checkout.tsx` | same | same | same | same | Signed off |

## Pharmacy

Test mapping: [`grocery-pharmacy-test-parity.md`](grocery-pharmacy-test-parity.md).

| Flutter route | Flutter screen | RN route file | Layout | States | Behavior | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `pharmacy` `/pharmacy` | `PharmacyStoreListScreen` | `app/(app)/(tabs)/pharmacy/index.tsx` | Searchable pharmacy list | Loading, error, empty | Store → `/pharmacy/stores/:id?name=&photoUrl=` | `features/pharmacy/pharmacy-store-list-screen.test.tsx` ↔ `pharmacy_screens_test.dart` | Signed off |
| `pharmacyStore` `/pharmacy/stores/:storeId` | `PharmacyCatalogScreen` | `…/pharmacy/stores/[storeId]/index.tsx` | Store hero (name and photo from query params) and catalog | Loading, error, empty, refresh | Add to cart, open product | `pharmacy-catalog-screen.test.tsx`, `pharmacy-catalog-store.test.ts` | Signed off |
| `pharmacyProduct` `/pharmacy/stores/:storeId/product/:productId` | `PharmacyProductDetailsScreen` | `…/pharmacy/stores/[storeId]/product/[productId].tsx` | Shared `ProductDetailsView` | Loading, not found | Add with quantity | `pharmacy-product-details-screen.test.tsx` | Signed off |
| `pharmacyCart` `/pharmacy/cart` | `PharmacyCartScreen` | `…/pharmacy/cart.tsx` | Shared `CartView` and OTC reminder | Empty ("Browse pharmacy"), stock ceiling | → checkout | `pharmacy-cart-screen.test.tsx` ↔ `cart_screens_test.dart` | Signed off |
| `pharmacyCheckout` `/pharmacy/checkout` | `PharmacyCheckoutScreen` | `…/pharmacy/checkout.tsx` | Shared `CheckoutView` | Empty ("Browse OTC products"), submitting, error | Idempotent order → `/activity` | `pharmacy-checkout-screen.test.tsx`, `pharmacy-checkout.test.ts` | Signed off |

## Legacy redirect aliases

All six are deep-link-only in both apps. `route-reachability.test.tsx` ›
"redirects to" checks each destination, and `flutter-route-parity.test.ts`
checks that none of them has an in-app link.

| Flutter route | Redirects to | RN route file | Status |
| --- | --- | --- | --- |
| `home` `/home` | `/app` | `app/(app)/home.tsx` | Signed off |
| `categories` `/categories` | `/services` | `app/(app)/categories.tsx` | Signed off |
| `cart` `/cart` | `/food/cart` | `app/(app)/cart.tsx` | Signed off |
| `checkout` `/checkout` | `/food/checkout` | `app/(app)/checkout.tsx` | Signed off |
| `restaurants` `/restaurants` | `/food` | `app/(app)/restaurants/index.tsx` | Signed off |
| `restaurant` `/restaurants/:restaurantId` | `/food/restaurants/:restaurantId` | `app/(app)/restaurants/[restaurantId].tsx` | Signed off |

## Unmatched routes

| Flutter | RN route file | Layout | States | Behavior | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `NotFoundScreen` (GoRouter `errorBuilder`) | `app/+not-found.tsx` | **Unstyled #358 skeleton**: no `AppScaffold`, title or icon | Message text matches | "Go to home" is a plain `Link` to `/app`, not a button | None. `app_router_test.dart` › NotFoundScreen case is not ported | Gap: #543 |

## RN-only routes (no Flutter counterpart)

| RN route file | Why |
| --- | --- |
| `app/reset-callback.tsx` | Landing route for the password-recovery deep link. Flutter handles it in `AppRouter`'s auth listener |
| `app/dev-gallery.tsx` | Development-only component gallery (redirects away in production) |
| `app/theme-preview.tsx` | Development-only theme token preview |

## Follow-up issues

| Issue | Gap | Rows |
| --- | --- | --- |
| #540 | `AppScaffold` back fallback goes to `/` instead of `/app` | `root` |
| #541 | Activity tab does not reload when you switch to it | `activity`, shell |
| #542 | Explore tab is missing the food-category chip row | `explore` |
| #543 | Not-found screen is an unstyled placeholder with no test | `NotFoundScreen` |
| #544 | Three unported widget-test cases (CategoriesSection empty, SectionHeader action, Recent Activity dividers) | `mainApp`, `food` |
| #545 | `/addresses` is a placeholder (owner decision needed: port or accept) | `addresses` |
