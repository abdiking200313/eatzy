# Open Tasks

Quick-reference cache as of 2026-08-12. **Source of truth is always `gh issue list --repo abdiking200313/eatzy --state open`** — this file can go stale the moment an issue is closed or a new one filed; re-check before relying on it for anything that matters.

| # | Title | Label | Notes |
|---|---|---|---|
| 1 | Wallet screen is entirely fake/static, not wired to real data | `todo` | Product decision needed: build real, mark as preview, or remove |
| 2 | Food checkout never collects a real delivery address | `todo` | Product decision needed: wire up real, or remove the misleading UI |
| 3 | schema.sql `profiles` columns disagree with Dart client — need live DB check | `needs-clarification` | Can't be resolved by an agent; needs a human to query the live DB. Also flags schema.sql missing 19 tables. |
| 4 | Unify food checkout under a FoodController | `todo` | Root-cause fix for the duplication found in the deeper audit; own reviewed PR since it touches the highest-traffic checkout flow |
| 5 | No test coverage of checkout/order-placement failure paths | `todo` | food/grocery/pharmacy, all three |
| 6 | auth_service_test.dart only covers logged-out state | `todo` | sign-in/sign-up/sign-out untested |
| 7 | Session storage should move to secure storage, not plaintext SharedPreferences | `todo` | Conscious decision needed, SDK default currently unreviewed |

## Known in-flight / interrupted work (not yet an issue)

- **Dedup extraction (RPC-unwrap helper, load/error mixin, confirm-order flow)**: started 2026-08-12, session was interrupted mid-task. Partial state left on disk uncommitted: `food_repository.dart`/`grocery_repository.dart`/`pharmacy_repository.dart` modified (RPC-unwrap part done), `lib/services/shared/{data/rpc_helpers.dart, presentation/loadable_state_mixin.dart, presentation/confirm_order_flow.dart}` created but **not yet wired into `grocery_controller.dart`/`pharmacy_controller.dart`**. Check `git status`/`git diff` in `chowflow_flutter/` before assuming this is finished or redoing it from scratch — the agent that did this was cancelled, not resumed, per explicit user instruction at the time. See [[Status Log]] for exact date/context.
