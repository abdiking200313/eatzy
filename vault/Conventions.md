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

- Board worker branches: `agent/issue-<number>-<short-kebab-slug>`, off `master`.
- **Policy changed 2026-08-27 (11th run): the board worker now merges its own PRs.** The routine's own prompt explicitly says it "no longer waits for human review to land a change" — after DoD checks pass and the PR is cleanly mergeable, the routine squash-merges it itself. This supersedes the older "never self-merge" rule below, which held from setup (2026-08-13) through the 10th run (2026-08-27 morning). Still never push directly to `master` without a PR — the PR is still required, only the merge step changed. A merge conflict is still handled per the routine prompt (merge `master` into the branch, resolve, re-run DoD, then push before merging) — never force through a red or conflicted PR.
- This does *not* change policy for interactive (non-routine) sessions — treat direct pushes/self-merges to `master` from an interactive session as something to flag/confirm, not a default, unless the user says otherwise for that session.
- PR body should reference `Closes #<number>` and list any assumptions made (especially for async/unattended runs where no one was there to ask).

## Migrations / Supabase

- Never apply a migration to the live/production database without explicit confirmation — note it as a manual follow-up in a PR description instead.
- `supabase-agent` owns `supabase/` exclusively; other agents that need a new query/RPC should state the exact contract needed (table/RPC name, params, return shape) rather than reaching into `supabase/` themselves.

## Repo structure gotcha — read this carefully, it has caused repeat mistakes

`chowflow_flutter/` is the name of the *local folder on the user's machine* that happens to be the real git repo (remote: `github.com/abdiking200313/eatzy`) — **but that name is not part of the repo's own content.** A fresh clone of this repo (e.g. what the cloud board worker checks out) has `lib/`, `pubspec.yaml`, `supabase/`, `test/`, `AGENTS.md`, `.claude/` etc. **directly at the repository root**, with no `chowflow_flutter/` subdirectory to `cd` into — confirmed directly from a board-worker run's tool output (`ls` at repo root, 2026-08-12).

This is genuinely confusing because a nested `chowflow_flutter/chowflow_flutter/` subdirectory *did* used to exist inside the repo (the deleted starter/duplicate project — see [[Decisions Log]] 2026-08-12) — but that was a coincidence of naming, not the project root. **When writing paths for anything that operates on a fresh checkout (the board-worker routine prompt, `AGENTS.md` references, etc.), never prefix with `chowflow_flutter/`.** When writing paths for *this interactive local session* (this vault's other notes, `.claude/agents/*.md` in the outer `eatzy/.claude/` folder), the `chowflow_flutter/` prefix IS correct, because the local workspace root is one level above the repo. Two different contexts, two different correct answers — check which one applies before assuming.

The outer `eatzy/` folder (one level up from the repo, containing README.md, FEATURES_TO_COMPLETE.md, etc.) is **not** part of the git repo at all — it's untracked local reference material only. Always check `git remote -v` if unsure which directory is "the repo."

## Dependency versions

38 packages have newer versions available as of the last check (including majors like `go_router` 13→17, `google_fonts` 6→8) — not urgent, deliberately deferred. Don't auto-upgrade without a reason; major bumps risk breaking changes.
