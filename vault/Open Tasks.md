---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

**Updated 2026-10-09 (board worker)** — re-check before relying on this for anything that matters. **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call.**

Full run-by-run history (2026-08-12 through 2026-10-08) archived to `vault/archive/Open Tasks 2026-08-to-2026-10.md` per this file's own ~150-line archive threshold (it had reached 443 lines, almost all consecutive "nothing eligible" entries). This file now holds current state only — check the archive if a prior run's exact reasoning on something now-resolved ever matters again.

## Current state

- **The RN migration batch is no longer mostly `needs-approval`** — as of 2026-10-09 the owner has relabeled roughly all of phases 1-10 (#357-417) to `todo` as well, not just Phase 0. The "69 of 75 stay `needs-approval`" line below is stale history, not current state; always re-check live.
- **`todo`, blocked**: #55 (iOS build — partial fix merged via PR #332; the rest needs macOS/Xcode/CocoaPods + an Apple Developer Team ID, none available in any sandbox so far — don't re-attempt from a Linux sandbox).
- **`todo`, tracking-only, no direct work ever**: #29, #52 (umbrella/index issues whose real findings were already filed as their own child issues).
- **`todo`, actionable next run**: #278 (pgTAP RLS/RPC tests + new CI job — its own verification runs in CI with real Docker, not locally). #363 (merchant session gate — depends on #359, merged 2026-10-09, now unblocked). The bulk of phases 3-10 (#364-417) — not individually re-verified for dependency readiness this run, check each issue's own `## Depends on` before starting, per `/build-rn`'s own step 2.
- **`agent-in-progress`, check fresh before touching**: none known stale as of this run's end — #351/#357/#359/#361/#360 all merged and closed this run, cleared.
- **`waiting-on-you`**: empty.
- **`needs-approval`**: still some remainder of the RN batch (count not re-verified exactly this run — the 2026-10-08 "69 of 75" figure is superseded, see above). Not this routine's call to bulk-approve the rest.

## Recently resolved (kept here briefly for context, move to the archive once stable)

- **2026-10-09 (board worker)**: #355, #351, #357, #359, #361, #360 all merged and closed (RN Phase 0-2 work). See [[Status Log]] 2026-10-09 entry for detail, including two real findings worth knowing about: a stale pre-existing agent branch for #351 that got force-pushed over (judged reasonable — flagged in [[Multi-Agent Setup]]), and a genuine `app.json` scheme bug (`reactnativeapp` instead of `zivo`) fixed as part of #361.
- **#301 closed** (seen as already closed at this run's start; not this run's own work — likely closed directly by the owner or another session once #276-299 all resolved).
- **#276 closed 2026-10-08** (PR #450, squash-merged). The "no Docker daemon" story that blocked this for 19+ runs was only ever half-true — see [[Multi-Agent Setup]]'s 2026-10-08 correction entry for the full story and the workaround that actually closed it (a local-Postgres migration replay, not the Supabase CLI). #303 closed as superseded by #450.

See [[Status Log]] for anything that happened more recently than this file's own last update.
