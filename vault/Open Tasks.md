---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

Refreshed 2026-08-18 (previous refresh was 2026-08-13, badly stale by the time this happened — repo had grown from 19 to 76 open issues, mostly a large `needs-approval` audit batch #30-83). **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call** — re-check before relying on this for anything that matters.

**76 open issues total.** 57 are `needs-approval` (untouchable by the board worker per the approval gate — see [[Conventions]]) — not itemized individually here, that's a lot of churn to keep in sync for issues nobody can act on yet. The tables below cover everything the board worker's loop actually looks at: `todo`, `waiting-on-you`, `agent-in-progress`.

## `waiting-on-you` — paused on a human reply

| # | Title | Asked | Notes |
|---|---|---|---|
| 16 | Native app identifiers still `com.example.chowflow` | 2026-08-15T00:55 UTC | Needs the reverse-domain identifier to use (no existing `com.zivo.*` anywhere to infer from) |
| 40 | No global error handling / crash reporting / production logging | 2026-08-17T20:38 UTC | Needs crash-reporting SDK choice (Sentry vs Firebase Crashlytics vs none) + credentials; offered to land the SDK-independent half first |

Both still have only the agent's own clarifying-question comment as of 2026-08-18 — no human reply on either yet across several checks.

## `agent-in-progress` — open PR awaiting review

| # | Title | PR |
|---|---|---|
| 23 | Redesign phase 2/7: Home & onboarding | #89 |
| 24 | Redesign phase 3/7: Auth | #90 |
| 25 | Redesign phase 4/7: Browse/catalog | #91 |
| 26 | Redesign phase 5/7: Cart & checkout | #92 |
| 27 | Redesign phase 6/7: Orders, activity, account | #93 |
| 33 | [Blocking] Default Flutter template app icons/splash ship | #51 |

None merged yet as of 2026-08-18 — #7's PR #20 and #50's PR #84 (both listed as `agent-in-progress` in earlier refreshes) have since resolved (issue #7/#50 no longer appear as open `agent-in-progress`; check history in [[Status Log]] if the exact merge/close date matters).

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
