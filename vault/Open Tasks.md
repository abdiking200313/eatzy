---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

Quick-reference cache as of 2026-08-13. **Source of truth is always `gh issue list --repo abdiking200313/eatzy --state open`** — this file can go stale the moment an issue is closed or a new one filed; re-check before relying on it for anything that matters.

| # | Title | Label | Notes |
|---|---|---|---|
| 1 | Wallet screen is entirely fake/static, not wired to real data | `todo` | Product decision needed: build real, mark as preview, or remove |
| 2 | Food checkout never collects a real delivery address | `todo` | Product decision needed: wire up real, or remove the misleading UI |
| 3 | schema.sql `profiles` columns disagree with Dart client — need live DB check | `needs-clarification` | Can't be resolved by an agent; needs a human to query the live DB. Confirmed still fully live 2026-08-13, likely same root cause as #8 (`schema.sql` unreliable) |
| 4 | Unify food checkout under a FoodController | `todo` | Root-cause fix for the duplication found in the deeper audit; own reviewed PR since it touches the highest-traffic checkout flow |
| 5 | No test coverage of checkout/order-placement failure paths | `todo` | food/grocery/pharmacy, all three |
| 6 | auth_service_test.dart only covers logged-out state | `todo` | sign-in/sign-up/sign-out untested |
| 7 | Session storage should move to secure storage, not plaintext SharedPreferences | `todo` | Conscious decision needed, SDK default currently unreviewed |
| 8 | Currency stored as decimal in Dart vs. integer smallest-units in SQL, plus other schema drift | `todo` | Investigated 2026-08-13, verdict: real inconsistency between two SQL conventions, `menu_items.price` is the one live crossing point, needs a live DB check to close — see [[Audit Findings]] Pass 3 |
| 9 | Rewards screen is entirely fake, no backend at all | `todo` | Worse than wallet — zero data layer, not even a stub |
| 10 | Settings screen: 9 dead tap targets, notification toggles don't persist | `todo` | |
| 11 | Addresses screen is fully non-functional despite being linked from real checkout/profile flows | `todo` | Blocks a real fix for #2 too |
| 12 | Payment methods screen is fully non-functional despite being linked from real flows | `todo` | |
| 13 | No profile-edit capability exists anywhere in the app | `todo` | |
| 14 | Duplicated hardcoded wallet balance ($120.50) in profile_screen.dart, independent of wallet_screen.dart | `todo` | Resolve alongside #1 |
| 15 | Onboarding has no first-launch/returning-user gating; standalone /onboarding/* routes are dead ends | `todo` | |
| 16 | Native app identifiers still com.example.chowflow across all platforms despite Zivo branding | `todo` | Not urgent, but hard to change post-release — do before store submission |
| 17 | No CI/CD — nothing enforces flutter analyze/test/dart format automatically on PRs | `todo` | Relevant given the board-worker PR workflow |
| 18 | Test suite gaps: grocery/pharmacy cart/checkout screens have zero widget tests; duplicated test fixture setup | `todo` | |
| 19 | ActivityController uses a hand-rolled ChangeNotifier singleton instead of the stated Riverpod/AsyncNotifier convention | `todo` | Architecture/product decision — migrate or document as deliberate exception |

## Known in-flight / interrupted work (not yet an issue)

- **Dedup extraction (RPC-unwrap helper, load/error mixin, confirm-order flow)**: started 2026-08-12, session was interrupted mid-task. Partial state left on disk uncommitted: `food_repository.dart`/`grocery_repository.dart`/`pharmacy_repository.dart` modified (RPC-unwrap part done), `lib/services/shared/{data/rpc_helpers.dart, presentation/loadable_state_mixin.dart, presentation/confirm_order_flow.dart}` created but **not yet wired into `grocery_controller.dart`/`pharmacy_controller.dart`**. Check `git status`/`git diff` in `chowflow_flutter/` before assuming this is finished or redoing it from scratch — the agent that did this was cancelled, not resumed, per explicit user instruction at the time. See [[Status Log]] for exact date/context.
