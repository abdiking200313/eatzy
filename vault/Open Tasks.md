---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

Refreshed 2026-08-27 (11th run). **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call** — re-check before relying on this for anything that matters.

**Major update 2026-08-26 ~19:20 UTC**: the human approved a huge batch of previously-`needs-approval` issues — open `needs-approval` count dropped from ~57 to 14. This ended the 11-day queue stall (stuck since 2026-08-15). The board worker processed 6 issues in its 7th run and another 6 in its 8th run that day; see [[Status Log]] 2026-08-26 for full detail on both.

**9th run (2026-08-27, early UTC morning)**: processed the next 6 oldest `todo` issues, all from the #52 audit batch: #62/#63/#64/#65/#66/#67 → PRs #107/#110/#108/#106/#105/#109. All 6 dispatched as independent worktree-isolated background agents in parallel; all opened clean/mergeable PRs with full verification (`dart format`/`flutter analyze`/`flutter test`) passing. Two agents (#63, #67) hit the session's shared API rate limit mid-task and were resumed via `SendMessage` to the same agent id once the limit reset — both picked up from their in-progress worktree state rather than restarting, see [[Status Log]] 2026-08-27 for detail. **New process note**: nested subagents spawned via the top-level `Agent` tool do NOT themselves have access to a further `Agent`/`Task` tool — all 6 agents independently reported this and implemented directly instead of fanning out to `ui-agent`/`logic-agent`/etc., while still respecting each role's declared file scope by hand. See [[Multi-Agent Setup]] for the implication this has on how `/build`-flow dispatch actually nests.

**10th run (2026-08-27, later UTC morning)**: processed the next 6 oldest `todo` issues (all from the #52 audit batch, the last of the ones not gated by `needs-approval`): #68/#69/#70/#71/#72/#75 → PRs #115/#111/#116/#114/#112/#113. Same worktree-isolated parallel-dispatch pattern as the 9th run, all 6 opened clean PRs with full DoD checks passing. See [[Status Log]] 2026-08-27 for full detail including per-issue judgment calls (#70's search/filter wiring, #71's delete-vs-keep-vs-wire route decisions, #72's finish-vs-revert call, #75's dead-table investigation).

## `waiting-on-you` — paused on a human reply

| # | Title | Asked | Notes |
|---|---|---|---|
| 8 | Currency decimal-vs-integer + schema drift (`item_categories`/`icon_url`/etc.) | 2026-08-26 (7th run) | Needs the live `menu_items.price` column type checked (integer cents vs numeric dollars) — no DB credentials available to any session here; comment lays out the mechanical fix for either answer |
| 16 | Native app identifiers still `com.example.chowflow` | 2026-08-15T00:55 UTC | Needs the reverse-domain identifier to use (no existing `com.zivo.*` anywhere to infer from) |
| 40 | No global error handling / crash reporting / production logging | 2026-08-17T20:38 UTC | Needs crash-reporting SDK choice (Sentry vs Firebase Crashlytics vs none) + credentials; offered to land the SDK-independent half first |
| 78 | Every vertical models delivery address/order differently — no shared platform layer | 2026-08-27 (11th run) | Issue itself asks to "decide on a shared platform core" — needs the schema shape picked (shared `delivery_addresses` + mandated column set vs. full `orders` supertype) and how it relates to #2's already-in-flight food-address migration (PR #95) |
| 79 | Order status can never change after creation — no UPDATE path exists | 2026-08-27 (11th run) | Issue itself asks to "decide the fulfilment model" — needs a pick between service-role/dashboard-only, a separate ops app (out of repo scope), or an in-app operator-role RPC, plus whether customer-initiated cancellation is in scope |

#16/#40 still have only the agent's own clarifying-question comment as of 2026-08-26 — no human reply on either yet (going on ~11 and ~9 days respectively). #78/#79 are new as of this run, too early to expect a reply yet.

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
| 65 | [Medium] Text design tokens are per-build GoogleFonts lookups, blocking const | #106 |
| 66 | [Medium] No image resize/decode limits anywhere | #105 |
| 67 | [Medium] No ShellRoute for bottom nav — vertical entry hides nav bar | #109 |

**#62/#63/#64/#66 (PRs #107/#110/#108/#105) confirmed merged as of 2026-08-29** (webhook `pull_request.closed`/`merged` events received directly). #63×#64's `pharmacy_controller.dart` conflict (and their individual conflicts against `master`'s already-merged #72/PR #112) is therefore resolved — per the separate 2026-08-29 "PR-merger run" entry in [[Status Log]], a concurrent session merged `master` into #110 and resolved it directly (extended `SessionResetRegistry` with an owner-aware callback variant so `loadForOwner(ownerId)` could keep working without reverting #58's no-service-imports-in-platform-session fix — see that session's own merge commit for the exact resolution). Dropped both rows from this table. #65/#66/#67 not yet confirmed merged as of this note — check live.

**#68/#69/#70/#71/#72/#75 all merged 2026-08-27 ~09:48-09:49 UTC**, within ~1 minute of each other — the human cleared the entire 10th-run batch almost immediately after it opened. Dropped from this table (closed via their PRs). The flagged #69×#71 (`app_router.dart`) conflict evidently didn't materialize as a blocking git conflict (both merged cleanly in sequence).

**Known merge-conflict pairs, human decision needed on order (none resolved by the routine)**:
- PR #95 (#2) and PR #98 (#4) both rework `checkout_screen.dart` from the same pre-#95 baseline — whichever merges second needs a rebase threading #95's `FoodDeliveryAddress` through `FoodController.confirmOrder()`.
- PR #103 (#57, moves `features/{home,restaurant,cart,checkout}` → `services/food/`) and PR #104 (#61, edits `restaurant_screen.dart`/repository internals at their old paths) touch the same files — whichever merges second needs to re-apply the other's changes at the post-move paths.
- PR #103 (#57) also expects a conflict with PR #98 (#4) on `checkout_screen.dart`, since #103 branched before #98 merged.
- ~~PR #107 (#62) and PR #108 (#64) both touch `activity_controller.dart`/`activity_screen.dart`~~ — both merged (2026-08-29), resolved by whichever session merged second.
- ~~PR #108 (#64) and PR #110 (#63) both touch `pharmacy_controller.dart`, and both individually conflicted with merged `master`'s #112/#72~~ — both merged (2026-08-29); #110's resolution added `SessionResetRegistry.registerOwnerAware`/`notifyOwnerChanged` (see [[Status Log]] 2026-08-29 PR-merger run).

Phase 7 (#28) still can't start: depends on all of phases 1-6, and phases 2 (#23) and 5 (#26) are still open/unmerged.

## `todo` but not yet actionable (tracking issues / blocked)

| # | Title | Why not picked up |
|---|---|---|
| 21 | Visual redesign: token refresh, card system, nav cleanup (tracking) | Umbrella/index issue, no direct implementation work — phases 22-28 are the real work |
| 29 | Deploy-readiness audit (tracking) | Umbrella/index issue — findings already filed as the `needs-approval` #30-83 batch |
| 52 | Architecture, performance & cross-layer review (tracking) | Umbrella/index issue, same pattern as #21/#29 — its 31 child issues (#53-83ish) are the real work |
| 28 | Redesign phase 7/7: closeout sweep | Explicitly depends on phases 1-6 merged; only phase 1 (#22) has landed so far, phases 2-6 (#23-27) are the open PRs above |

## Remaining `todo`, not yet picked up

**11th run (2026-08-27) processed the last 6 issues from the #52 audit batch's `agent:supabase` tail: #76, 77, 78, 79, 80, 83.** #76/77/80/83 were clear mechanical fixes, implemented and merged same-run (see [[Status Log]] for detail, including the new self-merge policy). #78 and #79 both explicitly ask the reader to "decide" on an architecture/product question (a shared-platform schema shape; which fulfilment/ops model to build) rather than describing one target behavior — judged genuinely ambiguous per AGENTS.md's own criteria (affects data contracts/security/solution size), so both got a clarifying-question comment and moved to `waiting-on-you` instead of a guessed implementation. This was **the last unpicked batch from the #52 audit** — no more `todo`-and-not-`agent-in-progress` issues remain from that source as of this run. Only 14 issues remain `needs-approval`-gated as of 2026-08-26 (#9, 12, 30, 32, 38, 43, 49, 55, 59, 60, 73, 74, 81, 82) — next run has nothing left to pick up unless the human approves more of those, replies to a `waiting-on-you` issue, or a new issue is filed.

## Known in-flight / interrupted work (not yet resolved)

- The 2026-08-12 dedup-extraction interruption (RPC-unwrap helper, load/error mixin, confirm-order flow left partially wired) was tracked as **issue #72**, resolved and merged via PR #112 (10th run, 2026-08-27) which wired `LoadableState`/`confirmDemoOrder` into the grocery/pharmacy controllers — closed, no longer in-flight. See the conflict note above: PRs #108/#110 now individually need a rebase against it.
