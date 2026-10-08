---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

**Updated 2026-10-08 (interactive session)** — re-check before relying on this for anything that matters. **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call.**

Full run-by-run history (2026-08-12 through 2026-10-08) archived to `vault/archive/Open Tasks 2026-08-to-2026-10.md` per this file's own ~150-line archive threshold (it had reached 443 lines, almost all consecutive "nothing eligible" entries). This file now holds current state only — check the archive if a prior run's exact reasoning on something now-resolved ever matters again.

## Current state

- **`todo`, blocked**: #55 (iOS build — partial fix merged via PR #332; the rest needs macOS/Xcode/CocoaPods + an Apple Developer Team ID, none available in any sandbox so far — don't re-attempt from a Linux sandbox).
- **`todo`, unblocked 2026-10-08, not yet started**: #301 (v1 cleanup/doc rebuild — waited on every issue #276-299; #278 was the last one open, now closed. Large, repo-wide, 3-PR task that archives `vault/Decisions Log.md`/`Status Log.md`/`Audit Findings.md` and rewrites `AGENTS.md`/README/vault from current code — flagged to the owner in chat before starting rather than auto-dispatched).
- **`todo`, tracking-only, no direct work ever**: #29, #52 (umbrella/index issues whose real findings were already filed as their own child issues).
- **`agent-in-progress`**: #351 (last checked 2026-10-08 — real branch `agent/issue-351-crashlytics-error-boundary` exists, no PR yet, claimed by a different concurrently-running session).
- **`waiting-on-you`**: empty.
- **`todo`, newly eligible 2026-10-08**: #352-#417 (66 of the 75 React Native migration issues, phases 1-9 plus phase-10 E2E/parity/a11y/perf) — owner bulk-approved these directly in an interactive session (see [[Decisions Log]] 2026-10-08). Normal `todo` queue, route via `app:react-native` → `/build-rn` per [[Conventions]].
- **`needs-approval`, held back deliberately**: #418 (`[P10-06]` store listing content), #419 (`[P10-07]` TestFlight/Play internal beta), #420 (`[P10-08]` production release + `flutter_app/` removal) — owner's explicit call to make closer to actual launch, see [[Decisions Log]] 2026-10-08. Do not bulk-approve these three on this routine's own initiative. As of this update the owner is actively deciding on these three with the orchestrator in the same session — check chat/[[Decisions Log]] for whether that landed before trusting this line.

## Recently resolved (kept here briefly for context, move to the archive once stable)

- **#276 closed 2026-10-08** (PR #450, squash-merged). The "no Docker daemon" story that blocked this for 19+ runs was only ever half-true — see [[Multi-Agent Setup]]'s 2026-10-08 correction entry for the full story and the workaround that actually closed it (a local-Postgres migration replay, not the Supabase CLI). #303 closed as superseded by #450.
- **#278 closed 2026-10-08** (PR #454, squash-merged). 5 pgTAP files, 155 assertions, new `.github/workflows/supabase.yml` `db-test` job (green on the PR). Found and fixed two real replay bugs along the way: `20260926010000_reseed_store_catalog.sql` didn't actually replay cleanly on an empty DB (missing `item_categories` rows, fixed with `on conflict do nothing` placeholders — the #276/#450 "migrations replay cleanly" claim was incomplete), and `seed.sql`'s unqualified `gen_salt`/`crypt` calls failed under the real CLI (pgcrypto lives in the `extensions` schema). Also found a real pre-existing bug, filed separately as **#455**: `admin_lookup_profile_by_email` raises an ambiguous-column error for every caller (fails closed, not a security issue, just dead code since `admin_list_profiles` replaced it).

See [[Status Log]] for anything that happened more recently than this file's own last update.
