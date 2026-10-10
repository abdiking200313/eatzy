---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

**Updated 2026-10-10, 5th run (board worker)** — re-check before relying on this for anything that matters. **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call.**

Full run-by-run history (2026-08-12 through 2026-10-08) archived to `vault/archive/Open Tasks 2026-08-to-2026-10.md` per this file's own ~150-line archive threshold. This file now holds current state only — check the archive if a prior run's exact reasoning on something now-resolved ever matters again.

## Current state

- **The RN migration batch is no longer mostly `needs-approval`** — the owner has relabeled roughly all of phases 1-10 (#357-417) to `todo` as well, not just Phase 0.
- **`todo`, blocked**: #55 (iOS build — partial fix merged via PR #332; the rest needs macOS/Xcode/CocoaPods + an Apple Developer Team ID, none available in any sandbox so far — don't re-attempt from a Linux sandbox).
- **`todo`, tracking-only, no direct work ever**: #29, #52 (umbrella/index issues whose real findings were already filed as their own child issues).
- **`todo`, actionable next run**: **#384** (P6-03 menu item details/add-to-cart) — both its dependencies (#383, #379) merged this run. Phases 6 (rest)-10 beyond that are not individually re-verified for dependency readiness — check each issue's own `## Depends on` before starting, per `/build-rn`'s own step 2.
- **`waiting-on-you`**: empty.
- **`needs-approval`**: still some remainder of the RN batch (exact count not re-verified this run). Not this routine's call to bulk-approve the rest.
- **Subagent dispatch is working normally again** (see [[Status Log]]'s 2026-10-10 5th-run entry) — the 4th run's "Auto-Mode Bypass" denial did not recur across ~15 dispatches this run. Dispatch normally (`rn-logic-agent`/`rn-ui-agent`/`rn-qa-agent`); don't default to implementing everything directly unless a fresh denial shows up.
- **Watch for issue text naming the wrong Flutter source files or test files** — recurred twice this run (#382's `## Ports from Flutter` named the checkout layer instead of the real home-screen data source; #380's named test file exercises a different, already-ported component). Always confirm by reading the actual screen/widget file's own imports before trusting the issue body's file list.

## Recently resolved (kept here briefly for context, move to the archive once stable)

- **2026-10-10, 5th run (board worker)**: #376, #379, #380, #381, #382, #383 all merged and closed (RN Phase 5 shared commerce + Phase 6 food start: cart stores, shared cart/checkout views, store list/header components, delivery note model, food home screen, restaurant screen with menu). See [[Status Log]] for full detail, including the subagent-dispatch correction, two issue-text/file mismatches found, a human-merged PR, and a QA dispatch that hit the account's own rate limit mid-task but left good work behind.
- **2026-10-10, 4th run (board worker)**: #371, #378, #374, #373 all merged and closed (RN Phase 4 super-app shell: service registry, idempotency/RPC errors, services screen, home screen). See [[Status Log]] for full detail, including the real `StoreListingRepository` dependency gap found and resolved in #373.
- **2026-10-09, 2nd run (board worker)**: #362-367 all merged and closed (RN Phase 2-3 auth work). See [[Status Log]] for full detail.
- **2026-10-09, 1st run (board worker)**: #355, #351, #357, #359, #361, #360 all merged and closed (RN Phase 0-2 work).
- **#301 closed** (seen as already closed at a prior run's start; not this routine's own work).
- **#276 closed 2026-10-08** (PR #450). See [[Multi-Agent Setup]]'s 2026-10-08 correction entry for the full story.

See [[Status Log]] for anything that happened more recently than this file's own last update.
