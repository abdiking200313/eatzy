---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

**Updated 2026-10-10, 4th run (board worker)** — re-check before relying on this for anything that matters. **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call.**

Full run-by-run history (2026-08-12 through 2026-10-08) archived to `vault/archive/Open Tasks 2026-08-to-2026-10.md` per this file's own ~150-line archive threshold. This file now holds current state only — check the archive if a prior run's exact reasoning on something now-resolved ever matters again.

## Current state

- **The RN migration batch is no longer mostly `needs-approval`** — the owner has relabeled roughly all of phases 1-10 (#357-417) to `todo` as well, not just Phase 0.
- **`todo`, blocked**: #55 (iOS build — partial fix merged via PR #332; the rest needs macOS/Xcode/CocoaPods + an Apple Developer Team ID, none available in any sandbox so far — don't re-attempt from a Linux sandbox).
- **`todo`, tracking-only, no direct work ever**: #29, #52 (umbrella/index issues whose real findings were already filed as their own child issues).
- **`todo`, actionable next run**: **#375** (P4-04 explore/discovery screen) — its one dependency, #373, merged this run. Phases 5-10 (#376-417) beyond that are not individually re-verified for dependency readiness — check each issue's own `## Depends on` before starting, per `/build-rn`'s own step 2.
- **`agent-in-progress`, no branch/PR, independently confirmed stale 3 times now**: **#376** (P5-01 cart store) and **#377** (P5-02 service pricing) — see [[Status Log]]'s 2026-10-10 4th-run entry. Reclaim as the known stale-label pattern ([[Multi-Agent Setup]]'s 2026-09-14 entry) whenever a future run reaches them.
- **Stray orphan branch, harmless, do not reuse**: `agent/issue-366-register-screen` (3 commits) exists on `origin` with no open PR — a concurrent session's parallel implementation of #366 that lost the race to `agent/issue-366-register-screen-v2` (merged as PR #475). Its own stray duplicate PR (#477) was found open and closed this run; the branch itself is still safe to ignore or delete.
- **`waiting-on-you`**: empty.
- **`needs-approval`**: still some remainder of the RN batch (exact count not re-verified this run). Not this routine's call to bulk-approve the rest.
- **Process note, read before the next run dispatches any subagent**: see [[Status Log]]'s 2026-10-10 4th-run entry and [[Multi-Agent Setup]] — dispatching a write-capable subagent via the `Agent` tool is currently denied outright ("Auto-Mode Bypass"). Expect to implement issues directly rather than fan out to role agents until this is resolved.

## Recently resolved (kept here briefly for context, move to the archive once stable)

- **2026-10-10, 4th run (board worker)**: #371, #378, #374, #373 all merged and closed (RN Phase 4 super-app shell: service registry, idempotency/RPC errors, services screen, home screen). See [[Status Log]] for full detail, including the new subagent-dispatch block and the real `StoreListingRepository` dependency gap found and resolved in #373.
- **2026-10-09, 2nd run (board worker)**: #362-367 all merged and closed (RN Phase 2-3 auth work). See [[Status Log]] for full detail.
- **2026-10-09, 1st run (board worker)**: #355, #351, #357, #359, #361, #360 all merged and closed (RN Phase 0-2 work).
- **#301 closed** (seen as already closed at a prior run's start; not this routine's own work).
- **#276 closed 2026-10-08** (PR #450). See [[Multi-Agent Setup]]'s 2026-10-08 correction entry for the full story.

See [[Status Log]] for anything that happened more recently than this file's own last update.
