---
tags: [architecture, lib-layout, backend, security, testing]
summary: Domain-based lib/ layout (features/services/platform), Supabase backend shape and RLS posture, test coverage summary.
status: living
upstream_concept: 00-Index
---

# Architecture

## lib/ layout

Domain-based, not layer-based. Top level:

- `lib/app/` — routing & app-level wiring: `app_router.dart`, `app_routes.dart`, `main_app_screen.dart`, `service_module.dart`
- `lib/config/` — `theme.dart`, `tailwind.dart` (design tokens; `tailwind.dart:296` has the `ColorHelpers.withOpacityValue` extension used for semi-transparent colors — prefer it over raw `Color(0x...)` literals)
- `lib/features/` — `auth`, `cart`, `checkout`, `home`, `onboarding`, `orders`, `profile`, `restaurant`, `rewards`, `settings`, `super_app`, `support`, `wallet` — several of these (`rewards`, `settings`, `profile`, `onboarding`) have real UI backed by fake/incomplete data underneath, see [[Open Tasks]]. `wallet` was fixed in issue #1 (2026-08-26): `WalletScreen` now reads real balance/transactions/payment-methods via `WalletRepository` — the "Add Money"/"Send"/"Add payment method" actions remain stubbed ("coming soon"), since no secure write RPC exists yet for wallet mutations.
- `lib/platform/` — cross-cutting: `activity/` (has its own data/models/presentation like a feature), `localization/app_money.dart`, `session/account_state_coordinator.dart`, `system_ui/android_navigation_bar_controller.dart`
- `lib/screens/` — 5 legacy files not yet migrated into `features/`: `addresses.dart`, `cart.dart`, `categories.dart`, `explore.dart`, `payment_methods.dart`. All still routed/used — not dead, just an organizational leftover. Low priority to move.
- `lib/services/` — the "vertical" domains: `food`, `grocery`, `pharmacy` (`cleaning` was removed entirely in issue #50, 2026-08-15 — don't reintroduce it)
- `lib/widgets/` — shared widgets, all actively used: `app_cards.dart`, `app_scaffold.dart`, `app_misc.dart`, `zivo_logo.dart`, `add_to_cart_button.dart`, `app_widgets.dart`
- `lib/main.dart` — entry point; calls `Supabase.initialize(url:, publishableKey:)` with default (plaintext SharedPreferences) session storage — see [[Audit Findings]]

## The domain subfolder pattern

Each `features/<name>/` and `services/<name>/` has some subset of `data/`, `models/`, `presentation/`. **`presentation/` is not UI-only** — it also holds `*_controller.dart` state-management files colocated with their screens. E.g. `lib/services/grocery/presentation/` has both `grocery_screen.dart` and `grocery_controller.dart` side by side. This tripped up the agent scope definitions once already (see [[Multi-Agent Setup]]) — don't assume a file's role from its directory alone, check the filename pattern.

Not every domain has every layer — e.g. `food` has no controller (its cart lives in the app-wide `CartController`, checkout logic is inlined in `checkout_screen.dart`'s `State`), unlike `grocery`/`pharmacy` which each own a `ChangeNotifier` controller. This asymmetry is real, tracked as a known gap — see issue tracking `FoodController` unification in [[Open Tasks]].

`lib/services/shared/` exists (as of the dedup work) for logic extracted out of the duplicated grocery/pharmacy/food pattern: `data/rpc_helpers.dart`, `presentation/loadable_state_mixin.dart`, `presentation/confirm_order_flow.dart`. Check [[Status Log]] for whether the controllers have actually been wired up to use these yet — that work was interrupted mid-session at least once.

## Backend (Supabase)

- `supabase/schema.sql` and `supabase/database_diagram.md` are the checked-in reference docs — **currently known to be stale/incomplete** relative to the real migrations (missing 19 tables, and a `profiles` column-name discrepancy not yet resolved — see [[Open Tasks]]). Don't trust them as ground truth without cross-checking `supabase/migrations/`.
- RLS is applied consistently and correctly across the schema — every table has row-level security with owner-scoped policies; no `USING (true)` on writes.
- Order placement (`place_food_order`, `place_grocery_order`, `place_pharmacy_order`) goes through `SECURITY DEFINER` RPCs, not direct client INSERTs: they derive `profile_id` server-side from `auth.uid()`, recompute prices from the DB rather than trusting client-submitted amounts, validate input, and use `set search_path = ''`. Pharmacy order placement takes a row lock before decrementing stock (prevents oversell races). This is solid, above-MVP-average backend security — don't assume it needs hardening without checking first.

## Tests

20 files (post issue #50 cleaning removal). Cart logic and grocery/pharmacy controller logic (cart math, stock limits, validation) are meaningfully tested. **Known gaps**: no test anywhere exercises a failure path (network/Supabase error) for any checkout flow; `auth_service_test.dart` only covers the logged-out state, not sign-in/sign-up/sign-out. See [[Open Tasks]] for the filed issues.
