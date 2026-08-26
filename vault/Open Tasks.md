---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

Refreshed 2026-08-26 (7th run today — after the mass approval batch; previous refresh was 2026-08-18). **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call** — re-check before relying on this for anything that matters.

**Major update 2026-08-26 ~19:20 UTC**: the human approved a huge batch of previously-`needs-approval` issues — open `needs-approval` count dropped from ~57 to 14. This ended the 11-day queue stall (stuck since 2026-08-15). The board worker processed 6 of the newly-eligible issues in its 7th run today; see [[Status Log]] 2026-08-26 for full detail. ~44 issues remain `todo`-only and not yet picked up (oldest-first queue starting around #10).

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

**#2 (PR #95) and #4 (PR #98) both rework `checkout_screen.dart` from the same pre-#95 master baseline and will conflict at merge** — each PR's description flags this explicitly; whichever merges second needs a rebase threading #95's `FoodDeliveryAddress` through `FoodController.confirmOrder()`. Human merge-order decision needed, not resolved by the routine.

Phase 7 (#28) still can't start: depends on all of phases 1-6, and phases 2 (#23) and 5 (#26) are still open/unmerged.

## `todo` but not yet actionable (tracking issues / blocked)

| # | Title | Why not picked up |
|---|---|---|
| 21 | Visual redesign: token refresh, card system, nav cleanup (tracking) | Umbrella/index issue, no direct implementation work — phases 22-28 are the real work |
| 29 | Deploy-readiness audit (tracking) | Umbrella/index issue — findings already filed as the `needs-approval` #30-83 batch |
| 28 | Redesign phase 7/7: closeout sweep | Explicitly depends on phases 1-6 merged; only phase 1 (#22) has landed so far, phases 2-6 (#23-27) are the open PRs above |

## Remaining `todo`, not yet picked up (~44 issues, post-approval-batch)

The mass approval on 2026-08-26 resolved the old "8 issues" stray-label problem — the issues previously listed here (17, 31, 34, 36, 37, 58, 66) are no longer `needs-approval`-gated; they're legitimately queued `todo` work now, along with ~37 others (#10, 11, 13-15, 17-19, 31, 34, 36, 37, 41, 42, 44-48, 52-54, 56-58, 61-72, 75-80, 83 — full list via live `list_issues`). Not itemized individually here (too many, changes every run); next run picks up oldest-first starting around #10. Only 14 issues remain `needs-approval`-gated as of 2026-08-26 (#9, 12, 30, 32, 38, 43, 49, 55, 59, 60, 73, 74, 81, 82).

## Known in-flight / interrupted work (not yet resolved)

- The 2026-08-12 dedup-extraction interruption (RPC-unwrap helper, load/error mixin, confirm-order flow left partially wired) was independently rediscovered and filed as **issue #72** (`needs-approval`) during the 2026-08-15 deploy-readiness audit — treat #72 as the current tracker for that, this note's old freestanding description is superseded.
