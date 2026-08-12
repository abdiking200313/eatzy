# Conventions

## GitHub labels (repo: `abdiking200313/eatzy`)

| Label | Meaning |
|---|---|
| `todo` | Queued for the board worker to pick up |
| `agent-in-progress` | Worker has claimed it, working or PR open |
| `waiting-on-you` | Worker asked a clarifying question in a comment, waiting on a human reply |
| `needs-clarification` | Worker genuinely couldn't proceed even after asking — needs a person to unblock, not just answer a question |
| `model:opus` / `model:sonnet` | Forces that model for every subagent dispatched on this task, overriding the per-role default |

## Branching / PRs

- Board worker branches: `agent/issue-<number>-<short-kebab-slug>`, off `master`.
- **Never push directly to `master`, never self-merge.** Every automated change lands as a PR for human review. This applies to interactive sessions too, by extension — treat direct pushes to `master` as something to flag/confirm, not a default.
- PR body should reference `Closes #<number>` and list any assumptions made (especially for async/unattended runs where no one was there to ask).

## Migrations / Supabase

- Never apply a migration to the live/production database without explicit confirmation — note it as a manual follow-up in a PR description instead.
- `supabase-agent` owns `supabase/` exclusively; other agents that need a new query/RPC should state the exact contract needed (table/RPC name, params, return shape) rather than reaching into `supabase/` themselves.

## Repo structure gotcha

`chowflow_flutter/` is the real Flutter project root *and* the real git repo (remote: `github.com/abdiking200313/eatzy`). The outer `eatzy/` folder (one level up, containing README.md, FEATURES_TO_COMPLETE.md, etc.) is **not** part of that repo — it's untracked local reference material only. Don't confuse the two; always check `git remote -v` if unsure which directory is "the repo."

## Dependency versions

38 packages have newer versions available as of the last check (including majors like `go_router` 13→17, `google_fonts` 6→8) — not urgent, deliberately deferred. Don't auto-upgrade without a reason; major bumps risk breaking changes.
