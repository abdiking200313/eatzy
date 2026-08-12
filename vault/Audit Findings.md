# Audit Findings

Two passes so far, both on 2026-08-12. Don't re-run either wholesale without reason — check [[Open Tasks]]/`gh issue list` first to see what's already tracked.

## Pass 1 — shallow (dead code + lint)

- **Fixed**: deleted `chowflow_flutter/chowflow_flutter/`, a stale duplicate Flutter project from an accidental double `flutter create` (stock counter-app template, unreferenced, untouched since initial commit).
- **Fixed**: deleted 2 unused widgets (`payment_method_card.dart`, `order_card.dart`) superseded by inline code.
- **Fixed**: extracted `cleaning_booking_screen.dart`'s 240-line `build()` into sub-widgets (moot now — `cleaning` is being removed).
- **Fixed**: replaced hardcoded `Color(0x...)` literals in `restaurant_screen.dart` with the `TwColors.slate900.withOpacityValue(...)` convention.
- `flutter analyze`: 0 issues (was already clean before this pass too).
- No unused dependencies in `pubspec.yaml`.
- Deferred, not done: moving `lib/screens/`'s 5 leftover files into `lib/features/`, and the 38 outdated-dependency bumps. Low priority, no issue filed (user said skip both, not "later" — revisit only if asked).

## Pass 2 — deeper (security, tests, duplication, resilience)

**Security — mostly good news.** RLS is comprehensive and correctly scoped (no `USING (true)` on writes). Order-placement RPCs are well-hardened: server-derived `profile_id`, server-recomputed prices, `search_path` hardened, row-locking against oversell. No hardcoded secrets (the `sb_publishable_...` key in `main.dart` is the intended-public Supabase anon key). One real gap: **session/refresh-token stored in plaintext SharedPreferences** (SDK default, not consciously chosen) → issue #6.

**Test coverage.** Cart and grocery/pharmacy controller logic (math, stock limits, validation) is meaningfully tested. Gaps: **zero coverage of any checkout/order-placement failure path** (→ issue #4) and **`auth_service_test.dart` only covers the logged-out state** (→ issue #5).

**Duplication across food/grocery/pharmacy** (cleaning excluded — being removed). Three concrete instances: RPC-result-unwrap logic, load/error-state pattern, and confirm-order control flow, each copy-pasted 2-3x. Root cause: food has no controller like grocery/pharmacy do (checkout logic is inlined in the screen instead) → tracked as issue #4 (FoodController unification) in addition to the extraction work. **Extraction work was started same-day but interrupted mid-session (see [[Status Log]] 2026-08-12) — check `lib/services/shared/` and whether `grocery_controller.dart`/`pharmacy_controller.dart` actually use it before assuming this is done.**

**Error handling.** Repositories let exceptions propagate (correct — idiomatic), callers catch at the boundary and show loading/error/retry states consistently. Minor nit: `on Object catch` is broad, masks real bugs as generic messages — not filed as an issue, low priority.

**Feature gaps found (not bugs, product decisions)**:
- Wallet screen is entirely hardcoded/fake, doesn't touch the real `wallet_transactions` table → issue #1.
- Food checkout never collects/sends a real delivery address (grocery/pharmacy do) → issue #2.

**Docs drift**: `supabase/schema.sql`/`database_diagram.md` disagree with the Dart client on `profiles`' name column (`full_name` vs `firstname`/`lastname`), and no migration defines either — meaning there's no ground truth in-repo to check against. Also missing 19 tables the migrations actually create. Needs someone to check the live DB → issue #3 (`needs-clarification`, not `todo` — can't be resolved by an agent alone).
