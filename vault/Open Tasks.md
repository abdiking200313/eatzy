---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

**Updated 2026-10-09, 2nd run (board worker)** — re-check before relying on this for anything that matters. **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call.**

Full run-by-run history (2026-08-12 through 2026-10-08) archived to `vault/archive/Open Tasks 2026-08-to-2026-10.md` per this file's own ~150-line archive threshold (it had reached 443 lines, almost all consecutive "nothing eligible" entries). This file now holds current state only — check the archive if a prior run's exact reasoning on something now-resolved ever matters again.

## Current state

- **The RN migration batch is no longer mostly `needs-approval`** — the owner has relabeled roughly all of phases 1-10 (#357-417) to `todo` as well, not just Phase 0.
- **`todo`, blocked**: #55 (iOS build — partial fix merged via PR #332; the rest needs macOS/Xcode/CocoaPods + an Apple Developer Team ID, none available in any sandbox so far — don't re-attempt from a Linux sandbox).
- **`todo`, tracking-only, no direct work ever**: #29, #52 (umbrella/index issues whose real findings were already filed as their own child issues).
- **`todo`, actionable next run**: **#368** (forgot/reset password screens — all three dependencies, #361/#362/#367, are now merged) is the natural next pick, oldest-first. The bulk of phases 3-10 (#369-417) after that — not individually re-verified for dependency readiness this run, check each issue's own `## Depends on` before starting, per `/build-rn`'s own step 2.
- **#278 already closed** (PR #454, closed 2026-10-08) — the "actionable next run" note in a prior version of this file was stale; re-confirmed closed this run.
- **Stray orphan branch, harmless, do not reuse**: `agent/issue-366-register-screen` (2 commits, `68675ea`/`01aa35e`) exists on `origin` with no open PR and will never get one — it's a concurrent session's duplicate implementation of #366 that lost out to this run's own `agent/issue-366-register-screen-v2` (merged as PR #475, see [[Status Log]] 2026-10-09 2nd-run entry for why). Safe to ignore or delete; don't confuse it with real in-progress work on a future `agent-in-progress` check.
- **`agent-in-progress`, check fresh before touching**: none known stale as of this run's end — #362-367 all merged and closed this run, cleared.
- **`waiting-on-you`**: empty.
- **`needs-approval`**: still some remainder of the RN batch (exact count not re-verified this run). Not this routine's call to bulk-approve the rest.

## Recently resolved (kept here briefly for context, move to the archive once stable)

- **2026-10-09, 2nd run (board worker)**: #362-367 all merged and closed (RN Phase 2-3 auth work). See [[Status Log]] for full detail, including two process findings worth reading before the next run (a main-checkout `git checkout master` hygiene bug that silently reverted the working tree and dropped the `rn-*` agent types mid-run, and a concurrent-session duplicate on #366 resolved by verifying both implementations' actual DoD results rather than guessing).
- **2026-10-09, 1st run (board worker)**: #355, #351, #357, #359, #361, #360 all merged and closed (RN Phase 0-2 work). See [[Status Log]] for detail, including a stale pre-existing agent branch for #351 that got force-pushed over (judged reasonable), and a genuine `app.json` scheme bug (`reactnativeapp` instead of `zivo`) fixed as part of #361.
- **#301 closed** (seen as already closed at a prior run's start; not this routine's own work).
- **#276 closed 2026-10-08** (PR #450). See [[Multi-Agent Setup]]'s 2026-10-08 correction entry for the full story.

See [[Status Log]] for anything that happened more recently than this file's own last update.
