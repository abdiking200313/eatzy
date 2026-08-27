---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

Refreshed 2026-08-27 (9th run). **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call** — re-check before relying on this for anything that matters.

**Major update 2026-08-26 ~19:20 UTC**: the human approved a huge batch of previously-`needs-approval` issues — open `needs-approval` count dropped from ~57 to 14. This ended the 11-day queue stall (stuck since 2026-08-15). The board worker processed 6 issues in its 7th run and another 6 in its 8th run that day; see [[Status Log]] 2026-08-26 for full detail on both.

**9th run (2026-08-27, early UTC morning)**: processed the next 6 oldest `todo` issues, all from the #52 audit batch: #62/#63/#64/#65/#66/#67 → PRs #107/#110/#108/#106/#105/#109. All 6 dispatched as independent worktree-isolated background agents in parallel; all opened clean/mergeable PRs with full verification (`dart format`/`flutter analyze`/`flutter test`) passing. Two agents (#63, #67) hit the session's shared API rate limit mid-task and were resumed via `SendMessage` to the same agent id once the limit reset — both picked up from their in-progress worktree state rather than restarting, see [[Status Log]] 2026-08-27 for detail. **New process note**: nested subagents spawned via the top-level `Agent` tool do NOT themselves have access to a further `Agent`/`Task` tool — all 6 agents independently reported this and implemented directly instead of fanning out to `ui-agent`/`logic-agent`/etc., while still respecting each role's declared file scope by hand. See [[Multi-Agent Setup]] for the implication this has on how `/build`-flow dispatch actually nests.

## `waiting-on-you` — paused on a human reply

| # | Title | Asked | Notes |
|---|---|---|---|
| 8 | Currency decimal-vs-integer + schema drift (`item_categories`/`icon_url`/etc.) | 2026-08-26 (7th run) | Needs the live `menu_items.price` column type checked (integer cents vs numeric dollars) — no DB credentials available to any session here; comment lays out the mechanical fix for either answer |
| 16 | Native app identifiers still `com.example.chowflow` | 2026-08-15T00:55 UTC | Needs the reverse-domain identifier to use (no existing `com.zivo.*` anywhere to infer from) |
| 40 | No global error handling / crash reporting / production logging | 2026-08-17T20:38 UTC | Needs crash-reporting SDK choice (Sentry vs Firebase Crashlytics vs none) + credentials; offered to land the SDK-independent half first |

#16/#40 still have only the agent's own clarifying-question comment as of 2026-08-26 — no human reply on either yet (going on ~11 and ~9 days respectively).

## `agent-in-progress` — open PR awaiting review

| # | Title | PR |
|---|---|---|
| 1 | Wallet screen fake/static data | #96 |
| 2 | Food checkout never collects a real address | #95 |
| 4 | Unify food checkout under a FoodController | #98 |
| 5 | No failure-path test coverage for checkout | #97 |
| 6 | auth_service_test.dart only covers logged-out state | #94 |
| 23 | Redesign phase 2/7: Home & onboarding | #89 |
| 26 | Redesign phase 5/7: Cart & checkout | #92 |
| 33 | [Blocking] Default Flutter template app icons/splash ship | #51 |
| 53 | [Medium] macOS builds missing network entitlement | #101 |
| 54 | [Medium] Flutter/Android SDK versions unpinned | #100 |
| 56 | [Low] Screen-orientation policy inconsistent | #99 |
| 57 | [High] Food vertical has no module boundary | #103 |
| 58 | [High] Session coordinator imports service controllers directly | #102 |
| 61 | [High] Catalog reads unbounded, no list virtualization | #104 |
| 62 | [High] Malformed activity row blanks order history; menu price falls back to $0.00 | #107 |
| 63 | [Medium] Grocery/pharmacy carts never persisted | #110 |
| 64 | [Medium] No refresh/cache-invalidation path (stale stock/prices/order status) | #108 |
| 65 | [Medium] Text design tokens are per-build GoogleFonts lookups, blocking const | #106 |
| 66 | [Medium] No image resize/decode limits anywhere | #105 |
| 67 | [Medium] No ShellRoute for bottom nav — vertical entry hides nav bar | #109 |

**Known merge-conflict pairs, human decision needed on order (none resolved by the routine)**:
- PR #95 (#2) and PR #98 (#4) both rework `checkout_screen.dart` from the same pre-#95 baseline — whichever merges second needs a rebase threading #95's `FoodDeliveryAddress` through `FoodController.confirmOrder()`.
- PR #103 (#57, moves `features/{home,restaurant,cart,checkout}` → `services/food/`) and PR #104 (#61, edits `restaurant_screen.dart`/repository internals at their old paths) touch the same files — whichever merges second needs to re-apply the other's changes at the post-move paths.
- PR #103 (#57) also expects a conflict with PR #98 (#4) on `checkout_screen.dart`, since #103 branched before #98 merged.
- PR #107 (#62) and PR #108 (#64) both touch `activity_controller.dart`/`activity_screen.dart` — whichever merges second needs to reconcile.
- PR #108 (#64) and PR #110 (#63) both touch `pharmacy_controller.dart` (#64 adds a staleness timestamp/early-return replacement, #63 adds persistence load/save) — whichever merges second needs to reconcile.

Phase 7 (#28) still can't start: depends on all of phases 1-6, and phases 2 (#23) and 5 (#26) are still open/unmerged.

## `todo` but not yet actionable (tracking issues / blocked)

| # | Title | Why not picked up |
|---|---|---|
| 21 | Visual redesign: token refresh, card system, nav cleanup (tracking) | Umbrella/index issue, no direct implementation work — phases 22-28 are the real work |
| 29 | Deploy-readiness audit (tracking) | Umbrella/index issue — findings already filed as the `needs-approval` #30-83 batch |
| 52 | Architecture, performance & cross-layer review (tracking) | Umbrella/index issue, same pattern as #21/#29 — its 31 child issues (#53-83ish) are the real work |
| 28 | Redesign phase 7/7: closeout sweep | Explicitly depends on phases 1-6 merged; only phase 1 (#22) has landed so far, phases 2-6 (#23-27) are the open PRs above |

## Remaining `todo`, not yet picked up

After the 9th run pulled #62/63/64/65/66/67 into `agent-in-progress`, remaining unpicked `todo` issues (all from the #52 audit batch, oldest-first): **#68, 69, 70, 71, 72, 75, 76, 77, 78, 79, 80, 83** (12 issues). Note #72's issue text describes an *uncommitted* working-tree landmine from 2026-08-15 — re-verified 2026-08-26: it's since been committed as-is (still real: `lib/services/shared/{loadable_state_mixin,confirm_order_flow}.dart` exist but have zero call sites anywhere in `lib/`), so the fix is still needed, just reframe "uncommitted" as "committed but never wired in" when picking it up. Only 14 issues remain `needs-approval`-gated as of 2026-08-26 (#9, 12, 30, 32, 38, 43, 49, 55, 59, 60, 73, 74, 81, 82).

## Known in-flight / interrupted work (not yet resolved)

- The 2026-08-12 dedup-extraction interruption (RPC-unwrap helper, load/error mixin, confirm-order flow left partially wired) was independently rediscovered and filed as **issue #72** (`needs-approval`) during the 2026-08-15 deploy-readiness audit — treat #72 as the current tracker for that, this note's old freestanding description is superseded.
