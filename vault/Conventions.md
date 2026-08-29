---
tags: [conventions, github, repo-structure]
summary: GitHub label meanings and the approval gate, branching/PR rules, Supabase migration rules, the chowflow_flutter path-prefix gotcha, dependency policy.
status: living
upstream_concept: 00-Index
---

# Conventions

## GitHub labels (repo: `abdiking200313/eatzy`)

| Label | Meaning |
|---|---|
| `needs-approval` | **Default label for any newly filed issue** — proposed, reviewed by no one yet. The board worker will never act on this label under any circumstance. |
| `todo` | The user has explicitly reviewed and approved this — queued for the board worker to pick up. Relabeling `needs-approval` → `todo` *is* the approval action (plain GitHub UI/mobile app, no extra tooling). |
| `agent-in-progress` | Worker has claimed an approved (`todo`) issue, working or PR open |
| `waiting-on-you` | Worker asked a clarifying question in a comment, waiting on a human reply (this only happens on already-approved work, never on `needs-approval` issues) |
| `needs-clarification` | Worker genuinely couldn't proceed even after asking — needs a person to unblock, not just answer a question |
| `model:opus` / `model:sonnet` | Forces that model for every subagent dispatched on this task, overriding the per-role default |

**Approval gate, added 2026-08-13**: the user asked for an explicit approve-before-pickup step after noticing that any issue getting the `todo` label — including ones filed by an AI session on their behalf, with no individual sign-off — was immediately eligible for the board worker to act on. Now: any issue I (or the user) file defaults to `needs-approval`. Nothing progresses until the user relabels it to `todo` themselves. The board worker's routine prompt has an explicit `APPROVAL GATE` section reinforcing this (defense in depth on top of the label-filtered query already only ever asking for `todo`). See [[Decisions Log]] 2026-08-13 for the full reasoning and the retroactive relabel of issues #1-19.

## Branching / PRs

- Board worker branches: `agent/issue-<number>-<short-kebab-slug>`, off the current tip of `master`.
- **Board worker self-merges (changed 2026-08-27, see [[Decisions Log]])**: it still opens a PR for every issue (branch + PR is never skipped), but now merges it itself — squash merge — once the DoD checks pass, resolving any conflict against `master` itself first rather than waiting on a human. Applies uniformly, including Supabase/migration-touching PRs (the migration *file* lands in git; it is still never applied to the live/production database — that rule is unchanged). A PR whose DoD checks don't pass stays open unmerged with an explanatory comment rather than being force-merged.
- **Interactive/manual sessions are unchanged**: still never push directly to `master` or self-merge without confirmation. The self-merge exception above is specific to the automated board-worker routine, not a blanket policy change.
- PR body should reference `Closes #<number>` and list any assumptions made (especially for async/unattended runs where no one was there to ask) — this is also what auto-closes the issue on merge, so no separate "done" label is needed.
- **Backlog PR/conflict cleanup is a separate manual-only routine, not part of the scheduled board worker** (added 2026-08-29, see [[Decisions Log]]): the board worker self-merges only what it opens fresh within its own run; sweeping already-open `agent/issue-*` PRs (including known conflict pairs) requires the user to explicitly fire `trig_01BhBGebMrc2tJfHy1MyHT6R` — see [[Multi-Agent Setup]]'s "Manual PR merger routine" section.

## Migrations / Supabase

- Never apply a migration to the live/production database without explicit confirmation — note it as a manual follow-up in a PR description instead.
- `supabase-agent` owns `supabase/` exclusively; other agents that need a new query/RPC should state the exact contract needed (table/RPC name, params, return shape) rather than reaching into `supabase/` themselves.

## Repo structure gotcha — read this carefully, it has caused repeat mistakes

`chowflow_flutter/` is the name of the *local folder on the user's machine* that happens to be the real git repo (remote: `github.com/abdiking200313/eatzy`) — **but that name is not part of the repo's own content.** A fresh clone of this repo (e.g. what the cloud board worker checks out) has `lib/`, `pubspec.yaml`, `supabase/`, `test/`, `AGENTS.md`, `.claude/` etc. **directly at the repository root**, with no `chowflow_flutter/` subdirectory to `cd` into — confirmed directly from a board-worker run's tool output (`ls` at repo root, 2026-08-12).

This is genuinely confusing because a nested `chowflow_flutter/chowflow_flutter/` subdirectory *did* used to exist inside the repo (the deleted starter/duplicate project — see [[Decisions Log]] 2026-08-12) — but that was a coincidence of naming, not the project root. **When writing paths for anything that operates on a fresh checkout (the board-worker routine prompt, `AGENTS.md` references, etc.), never prefix with `chowflow_flutter/`.** When writing paths for *this interactive local session* (this vault's other notes, `.claude/agents/*.md` in the outer `eatzy/.claude/` folder), the `chowflow_flutter/` prefix IS correct, because the local workspace root is one level above the repo. Two different contexts, two different correct answers — check which one applies before assuming.

The outer `eatzy/` folder (one level up from the repo, containing README.md, FEATURES_TO_COMPLETE.md, etc.) is **not** part of the git repo at all — it's untracked local reference material only. Always check `git remote -v` if unsure which directory is "the repo."

## Dependency versions

38 packages have newer versions available as of the last check (including majors like `go_router` 13→17, `google_fonts` 6→8) — not urgent, deliberately deferred. Don't auto-upgrade without a reason; major bumps risk breaking changes.
