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

## Tool gotcha — commenting on an issue

`mcp__github__issue_write` with `method: "create"` does **not** add a comment when given an `issue_number` — it silently creates a brand-new top-level issue instead (found 2026-08-30, 14th board-worker run, created and had to close a stray issue #155 after this exact mistake). Use `mcp__github__add_issue_comment` (`owner`/`repo`/`issue_number`/`body`) to post a comment. `issue_write` is only for creating a new issue or updating an existing issue's own fields (title/body/labels/state) — never for comments.

## Tests — where new cases go (consolidated 2026-09-24)

The suite was trimmed from 77 to 64 test files; don't re-split it. Add to the existing file instead of creating a new one:
- A 320x640 @1.4x no-overflow case for a redesigned screen → a row in `test/layout_test.dart` (unless that screen's own test file already has one, next to its fakes). List-virtualization and design-system widget checks live there too.
- Cart or checkout behavior → `test/cart_screens_test.dart` / `test/checkout_screens_test.dart`. Behavior identical across verticals (empty-state browse, continue-to-checkout, double-tap submit guard) is table-driven there — add a case row for a new vertical, not a copy of the test.
- Redirect rules, protected/registered routes, path builders → a row in the tables in `test/app_router_test.dart`.

Per-file startup (~0.7s each) dominates suite time, not individual tests, so prefer fewer files over fewer assertions.

## Getting dependencies in a new screen/controller (added 2026-10-03, issue #281)

Phase 1 of #280 (the composition-root tracking issue) added `lib/app/app_services.dart`
(`AppServices`, a plain Dart class — no Riverpod/get_it/provider, per
`AGENTS.md`'s "no new state management framework" rule) and
`lib/app/app_scope.dart` (`AppScope`, an `InheritedWidget` exposing it).
`AppServices` currently bundles the `SupabaseClient`, `QueryCache`,
`ErrorReporter`, `SessionResetRegistry`, `CartController`, and
`ActivityController` — the shared dependencies audited in #280 as safe to
centralize without touching any vertical's screens/controllers yet. It is
built once in `runStartupSequence` (`lib/platform/startup/startup_gate.dart`)
right after `Supabase.initialize` succeeds, and installed near the root in
`lib/main.dart` by wrapping `ZivoApp` in `AppScope`.

**Going forward, a new screen or controller should read these dependencies
via `AppScope.of(context)`** (or `AppScope.maybeOf` where a missing ancestor
is a legitimate case) instead of:
- constructing `Supabase.instance.client` directly or as a default-parameter
  fallback (`SupabaseClient? client` → `client ?? Supabase.instance.client`
  is still fine for a plain non-widget class's constructor injection, as
  `AuthService` already does — the thing to avoid is a *screen* reaching for
  `Supabase.instance.client` itself instead of taking a client/service via
  its constructor or `AppScope.of(context)`);
- adding a new process-wide `.instance` singleton for shared state.

`PharmacyController`/`GroceryController` and the other per-vertical
singletons (`PushNotificationGateway.instance`, etc.) are **not** on
`AppServices` yet — that migration is phases #282-285, not a green light to
add more ad hoc singletons in the meantime. Every existing `.instance`
getter this phase touched (`CartController`, `ActivityController`,
`QueryCache`, `SessionResetRegistry`, `ErrorReporting`) still works exactly
as before for any call site that hasn't migrated — they now carry a doc
comment pointing at `AppScope` instead of `@Deprecated`, since the latter
would have surfaced `flutter analyze` warnings across ~20 files this phase
didn't touch.

For a widget test that needs an `AppScope` ancestor, use
`test/helpers/app_scope_test_helpers.dart`'s `buildTestAppServices` (a
fully in-memory/test-double `AppServices`) and `pumpWithAppScope` (pumps a
widget wrapped in `MaterialApp` + `AppScope`) rather than hand-rolling the
wiring per test file.

## App label rules (`app:*`) — added 2026-10-08

The board-worker routine's own prompt ends with "follow the `app:*` label rules in `vault/Conventions.md`" (added 2026-10-05 when the 75-issue `react_native_app/` migration batch was filed, labeled `app:react-native`) — this section is that rule, finally written down after the owner noticed the whole batch was sitting in `needs-approval` with no automation ready for it (see [[Decisions Log]] 2026-10-08 and [[Multi-Agent Setup]] "React Native migration agents").

- **An issue labeled `app:react-native`** is work inside `react_native_app/` (the Expo/TypeScript port of the Flutter app), not `flutter_app/`. Use the **`/build-rn`** skill (`.claude/skills/build-rn/SKILL.md`) and its subagents — `rn-ui-agent`, `rn-logic-agent`, `rn-qa-agent` — instead of `/build` and the Flutter-scoped `ui-agent`/`logic-agent`/`supabase-agent`/`qa-agent`. The existing `supabase-agent` still owns `supabase/` itself if an RN issue genuinely needs a schema change (expected to be rare — this migration ports against the already-live schema).
- **Every issue in this batch names its own dependencies** under a `## Depends on` heading (issue numbers). Check those are already closed/merged before starting, even though the batch happens to be filed in exact dependency order (ascending issue number = build order) — don't rely on FIFO alone once this batch starts interleaving with unrelated issues or gets reordered.
- An issue with no `app:*` label (everything before this batch, and anything filed against `flutter_app/`/`supabase/` going forward) is unchanged — plain `/build` + the original four Flutter subagents, as documented in [[Multi-Agent Setup]].
- If a future `app:*` label shows up (e.g. an eventual `app:merchant-rn` or similar) with no rule here yet, don't guess a routing — comment on the issue and treat it the same as any other genuine ambiguity (relabel `waiting-on-you`, don't implement blind).

## Dependency versions

38 packages have newer versions available as of the last check (including majors like `go_router` 13→17, `google_fonts` 6→8) — not urgent, deliberately deferred. Don't auto-upgrade without a reason; major bumps risk breaking changes.
