---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

Refreshed 2026-08-29 (PR-merger run). **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call** — re-check before relying on this for anything that matters.

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

**Empty as of the 2026-08-29 "PR-merger run"** — that run merged every open `agent/issue-*` PR (all 19 rows previously listed here: #1/#2/#4/#5/#6/#23/#26/#33/#53/#54/#56/#57/#58/#61/#62/#63/#64/#65/#66/#67, PRs #51/#89/#92/#94-#110), in dependency order (see [[Status Log]] 2026-08-29 "PR-merger run" for the exact order and which merges needed real conflict reconciliation vs. a plain rebase). Nothing left in this table unless a new issue gets picked up and opens a fresh PR.

**Corrects a stale note from the concurrent watcher session** (its own 2026-08-29 entry, [[Status Log]]): #110's actual merged resolution does **not** add a `SessionResetRegistry.registerOwnerAware`/`notifyOwnerChanged` variant (that was the watcher's own independently-drafted, never-merged fix, discarded once it saw the PR-merger session land first). The version that actually merged instead changed `SessionResetCallback` itself to `void Function(String? nextOwnerId)`, so the *existing* `register`/`notifyAll` calls all just started carrying the owner id — see `lib/platform/session/session_reset_registry.dart` and the PR #110 comment thread for the real diff.

**Phase 7 (#28) is now unblocked**: it depended on phases 1-6 merging, and phases 2 (#23, PR #89) and 5 (#26, PR #92) — the last two still open — both merged in the 2026-08-29 PR-merger run. Ready to pick up.

## `todo` but not yet actionable (tracking issues / blocked)

| # | Title | Why not picked up |
|---|---|---|
| 21 | Visual redesign: token refresh, card system, nav cleanup (tracking) | Umbrella/index issue, no direct implementation work — phases 22-28 are the real work |
| 29 | Deploy-readiness audit (tracking) | Umbrella/index issue — findings already filed as the `needs-approval` #30-83 batch |
| 52 | Architecture, performance & cross-layer review (tracking) | Umbrella/index issue, same pattern as #21/#29 — its 31 child issues (#53-83ish) are the real work |

## Remaining `todo`, not yet picked up

| # | Title | Notes |
|---|---|---|
| 28 | Redesign phase 7/7: App-wide polish pass and closeout sweep | Newly actionable as of the 2026-08-29 PR-merger run — phases 2-6 (#23/#26/#27/#24/#25, the last two of which were #89/#92) all merged. Labeled `todo` already (pre-approved), no open PR. Board worker's to pick up next. |

**11th run (2026-08-27) processed the last 6 issues from the #52 audit batch's `agent:supabase` tail: #76, 77, 78, 79, 80, 83.** #76/77/80/83 were clear mechanical fixes, implemented and merged same-run (see [[Status Log]] for detail, including the new self-merge policy). #78 and #79 both explicitly ask the reader to "decide" on an architecture/product question (a shared-platform schema shape; which fulfilment/ops model to build) rather than describing one target behavior — judged genuinely ambiguous per AGENTS.md's own criteria (affects data contracts/security/solution size), so both got a clarifying-question comment and moved to `waiting-on-you` instead of a guessed implementation. This was **the last unpicked batch from the #52 audit** — no more `todo`-and-not-`agent-in-progress` issues remain from that source as of this run. Only 14 issues remain `needs-approval`-gated as of 2026-08-26 (#9, 12, 30, 32, 38, 43, 49, 55, 59, 60, 73, 74, 81, 82) — next run has nothing left to pick up unless the human approves more of those, replies to a `waiting-on-you` issue, or a new issue is filed.

## Known in-flight / interrupted work (not yet resolved)

- The 2026-08-12 dedup-extraction interruption (RPC-unwrap helper, load/error mixin, confirm-order flow left partially wired) was tracked as **issue #72**, resolved and merged via PR #112 (10th run, 2026-08-27) which wired `LoadableState`/`confirmDemoOrder` into the grocery/pharmacy controllers — closed, no longer in-flight. PRs #108/#110's individual rebases against it were completed in the 2026-08-29 PR-merger run (both merged).
