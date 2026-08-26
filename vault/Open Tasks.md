---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

Refreshed 2026-08-26 (previous refresh was 2026-08-18). **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call** — re-check before relying on this for anything that matters.

**81 open issues total** (58 carry `todo`, most of those also gated by `needs-approval`; untouchable-by-worker issues aren't itemized individually here). The tables below cover everything the board worker's loop actually looks at: `todo`, `waiting-on-you`, `agent-in-progress`.

## `waiting-on-you` — paused on a human reply

| # | Title | Asked | Notes |
|---|---|---|---|
| 16 | Native app identifiers still `com.example.chowflow` | 2026-08-15T00:55 UTC | Needs the reverse-domain identifier to use (no existing `com.zivo.*` anywhere to infer from) |
| 40 | No global error handling / crash reporting / production logging | 2026-08-17T20:38 UTC | Needs crash-reporting SDK choice (Sentry vs Firebase Crashlytics vs none) + credentials; offered to land the SDK-independent half first |

Both still have only the agent's own clarifying-question comment as of 2026-08-26 — no human reply on either yet across many checks (going on ~11 and ~9 days respectively).

## `agent-in-progress` — open PR awaiting review

| # | Title | PR |
|---|---|---|
| 23 | Redesign phase 2/7: Home & onboarding | #89 |
| 26 | Redesign phase 5/7: Cart & checkout | #92 |
| 33 | [Blocking] Default Flutter template app icons/splash ship | #51 |

**Update 2026-08-26**: the human merged phases 3, 4, and 6 today (PRs #90, #91, #93 → issues #24, #25, #27 all closed) — first movement on this queue since 2026-08-18. Phase 7 (#28) still can't start: it explicitly depends on all of phases 1-6, and phases 2 (#23) and 5 (#26) are still open/unmerged.

## `todo` but not yet actionable (tracking issues / blocked)

| # | Title | Why not picked up |
|---|---|---|
| 21 | Visual redesign: token refresh, card system, nav cleanup (tracking) | Umbrella/index issue, no direct implementation work — phases 22-28 are the real work |
| 29 | Deploy-readiness audit (tracking) | Umbrella/index issue — findings already filed as the `needs-approval` #30-83 batch |
| 28 | Redesign phase 7/7: closeout sweep | Explicitly depends on phases 1-6 merged; only phase 1 (#22) has landed so far, phases 2-6 (#23-27) are the open PRs above |

## Other `todo` issues (currently `needs-approval`-gated, listed only because they carry a stray `todo` label too)

8, 17, 31, 34, 36, 37, 58, 66 all carry both `todo` and `needs-approval` — the gate treats `needs-approval` as exclusive regardless of `todo` also being present (see [[Conventions]]'s approval gate note). Not acted on. Worth a human pass to strip the stray `todo` label from these if it's not intentional, since it's a bit misleading at a glance.

## Known in-flight / interrupted work (not yet resolved)

- The 2026-08-12 dedup-extraction interruption (RPC-unwrap helper, load/error mixin, confirm-order flow left partially wired) was independently rediscovered and filed as **issue #72** (`needs-approval`) during the 2026-08-15 deploy-readiness audit — treat #72 as the current tracker for that, this note's old freestanding description is superseded.
