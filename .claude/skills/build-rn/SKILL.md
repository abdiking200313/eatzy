---
name: build-rn
description: Implement a React Native migration issue in eatzy's react_native_app (Expo + TypeScript port of the Flutter app) by fanning it out to role-scoped subagents (rn-ui-agent, rn-logic-agent, rn-qa-agent) that work in parallel, then reconcile their output into one coherent change. Use for any issue labeled `app:react-native`, in place of the Flutter-only `/build` skill.
---

# /build-rn — parallel React Native port implementation

You are orchestrating specialized subagents (defined in `.claude/agents/`) to implement one issue from the `react_native_app/` migration plan: `rn-ui-agent`, `rn-logic-agent`, `rn-qa-agent`. Each owns a distinct part of `react_native_app/` so they don't collide on the same files — see each agent's own definition for the exact file-pattern scope; summary:

- `rn-ui-agent` → `src/components/**`, leaf screen `.tsx` files under `src/app/**` (not `_layout.tsx`), `tailwind.config.js`, `src/theme/tokens.ts`, presentational hooks
- `rn-logic-agent` → `src/app/**/_layout.tsx` (navigators + redirects), `src/platform/**`, `src/stores/**`, any hook that touches Supabase/TanStack Query/a store
- `rn-qa-agent` → `*.test.ts(x)`, `src/test-utils/**`, `e2e/**` (runs after the other two, not alongside them)

**Unowned by any subagent — handle these yourself as the orchestrator**: `package.json`, `package-lock.json`, `app.json`, `app.config.ts`, `eas.json`, `tsconfig.json`, `eslint.config.js`, `babel.config.js`, `metro.config.js`, and `.github/workflows/react-native.yml`. These are high-conflict/high-stakes (dependency changes, CI config) and no subagent's scope covers them — same precedent as `pubspec.yaml`/native shells on the Flutter side.

**Never**: edit anything under `flutter_app/` (it's the read-only source you're porting *from*, never a target) or `supabase/` (owned by the existing `supabase-agent`; every issue in this migration reuses the already-live schema — if one genuinely seems to need a new table/column/RPC, stop and state the exact contract needed rather than guessing or reaching into `supabase/` yourself).

## Steps

1. **Read the driving GitHub issue in full**, not just its title. Every issue in this migration is already unusually well-specified — it names the exact Flutter source files to port (`## Ports from Flutter`), the exact Flutter test files whose cases define correctness (`## Flutter tests to port or match`), a concrete task checklist, acceptance criteria, and its own `## Depends on` list. Read every named Flutter file before writing anything — the issue text is a summary, the Flutter source is the real spec.

2. **Verify every issue listed under `## Depends on` is already closed/merged before starting.** This migration's issues happen to be filed in dependency order (issue number ascending matches the stated build order), so picking oldest-`todo`-first will usually already respect this — but check explicitly via `list_issues`/`issue_read` rather than trusting the numbering alone, especially once issues from outside this batch (or a reordering) are mixed into the queue. If a dependency isn't merged yet, don't start — leave the issue for a later run and move to the next eligible one instead.

3. **Clarify only if genuinely ambiguous.** Given how specific these issues are, this should be rare — the main case is a named Flutter source file that's moved or been renamed since the issue was filed (check `flutter_app/` directly rather than assuming the issue is wrong). Interactively, use `AskUserQuestion`. Running unattended (the board worker), post the question as an issue comment, relabel `waiting-on-you`, and move on — never guess on a real behavioral ambiguity just because no one's watching.

4. **Rewrite the issue into a precise task brief** before dispatching anything, using the issue's own sections directly rather than re-deriving them:
   - **Goal and user outcome**: the issue's `## Goal`.
   - **In-scope / out-of-scope**: the issue's task checklist, plus "work only in `react_native_app/`, never edit `flutter_app/`" as a hard constraint.
   - **Constraints and explicit assumptions**: anything you decided that the issue left open, stated plainly.
   - **Observable acceptance criteria**: the issue's `## Acceptance criteria`, plus "every case in the named Flutter test file(s) is ported and passes" where test files are named.
   - **Verification commands**: `npm run lint`, `npx tsc --noEmit` (use this directly unless a `typecheck` script already exists in `package.json`), and `npm test` once P0-07 (Jest setup) has merged — never claim one passed if it wasn't actually run.

5. **Scope the work**: decide which of `rn-ui-agent`/`rn-logic-agent`/`rn-qa-agent` are actually needed. Many Phase 0-2 foundation issues (env config, the Supabase client, the router skeleton) are pure `rn-logic-agent` work with no UI component at all; a pure styling/token issue may only need `rn-ui-agent`. Don't dispatch an agent with nothing to do, and don't manufacture parallelism for a change small enough for one agent alone.

6. **Define shared contracts before dispatching anything** whenever both `rn-ui-agent` and `rn-logic-agent` are needed for the same issue — they run in parallel and can't talk to each other mid-task. Pin down and state verbatim in both dispatch prompts:
   - The exact hook/store function signatures `rn-logic-agent` will expose (e.g. `useFoodCategories(): { data, isLoading, error }`) and the data shape.
   - Any new route names/params, if navigation is involved.

7. **Dispatch the needed agents together, in parallel**, in a single message with one `Agent` tool call per agent. Each prompt should include the task brief from step 4, the scope boundaries, any contracts from step 6, and an instruction to clearly flag any stub/TODO left for another layer. Pass `isolation: "worktree"` on every call whenever more than one agent is dispatched in the same batch — a shared working directory across parallel dispatches has caused real git-HEAD races before. If a dispatch prompt tells an agent to self-merge its own PR, that instruction is sometimes denied outright by the permission classifier for no discoverable reason (inconsistent across otherwise-identical dispatches) — if that happens, redispatch the identical task with the self-merge step removed and finish the merge yourself once CI is green, rather than treating the denial as a real blocker. Tell each agent dispatched in parallel to use a uniquely-prefixed scratchpad filename (e.g. include the issue number) — the scratchpad directory is shared across concurrent dispatches even under worktree isolation.

   **Model policy**: leave `model` unset to use each agent's own default (`sonnet`) unless the driving issue carries a `model:opus`/`model:sonnet` label, in which case pass that value to every dispatch for this issue.

8. **Wait for all of them to complete**, then review the combined result:
   - Check each agent's summary for a flagged stub/blocker left for another layer — if `rn-ui-agent` expected a hook `rn-logic-agent` didn't build (or built differently), fix the mismatch yourself now.
   - Run `npm run lint` and `npx tsc --noEmit` across the whole `react_native_app/` project (not just the touched files) to catch integration issues the per-agent checks missed.
   - If a dispatched agent ends its turn saying it's "waiting for CI" rather than polling in-loop, don't assume it will resume promptly — poll the check-run status yourself (e.g. a short `curl`+`$GITHUB_TOKEN` loop) and be ready to finish the merge if its own resumption doesn't land first.

9. **Dispatch `rn-qa-agent` as a follow-up** once the change is coherent and lint/typecheck are clean — after, not during, step 7, since it needs to read the finished diff. Skip it only if Jest isn't set up yet (before P0-07 merges) — note that explicitly rather than silently skipping test coverage.

10. **Summarize**: which Flutter source file(s) were ported, which Flutter test file(s) were ported (and whether all their cases made it over), what changed and where, any contract decisions, and anything still open.

11. **Update the vault — always, proportionate to the task.** Same conventions as the Flutter `/build` skill's step 10: append a terse (1-4 bullet) entry to `vault/Status Log.md` under today's date; update `vault/Open Tasks.md`/`vault/Decisions Log.md`/`vault/Architecture.md` only if this task actually changed what they describe. Keep each note's YAML `summary` in sync with any body edit.

## Notes

- This skill produces the code change (and the vault update from step 11). It does not commit, push, or open a PR — that's handled by whatever invoked it (interactively, the user's call; for the scheduled board worker, see the board-worker routine instructions and `vault/Conventions.md`'s `app:*` label rules).
- If two needed agents would plausibly touch the same file despite the scope split (e.g. a root `_layout.tsx` that both gates auth and renders meaningful chrome), call it out before dispatching rather than risking a silent conflict.
