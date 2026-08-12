# Multi-Agent Setup

Full source of truth is always `.claude/agents/*.md` and `.claude/skills/build/SKILL.md` (both live in this repo, at `chowflow_flutter/.claude/`) — this note is a map/summary, not a copy. Read the actual files before dispatching if the details matter; they're short.

## The four subagents

- **`ui-agent`** — visual/presentation. `lib/screens/`, `lib/widgets/`, `lib/config/theme.dart`+`tailwind.dart`, plus `*_screen.dart`/`*_page.dart`/`presentation/widgets/*` files inside any domain's `presentation/` folder. Model: sonnet.
- **`logic-agent`** — app wiring, state, business logic. `lib/app/`, `lib/main.dart`, cross-cutting `lib/platform/{session,system_ui,localization}/`, plus every domain's `data/`/`models/` folders and any `*_controller.dart`/`*_service.dart`/`*_repository.dart` file even when colocated inside `presentation/`. Model: sonnet.
- **`supabase-agent`** — `supabase/` only (migrations, schema, RLS, edge functions). Model: **opus** (higher stakes — schema/RLS mistakes are the costliest to get wrong).
- **`qa-agent`** — `test/` only, runs after the others (not alongside), since it needs to read the finished diff. Model: sonnet.

**Critical gotcha already hit once**: the scope definitions were originally written against a flat `lib/screens/`+`lib/widgets/` view of the codebase. The real layout moved to domain-based `features/services/platform` with controllers colocated inside `presentation/` folders (see [[Architecture]]). Both `ui-agent` and `logic-agent` correctly *refused* to touch out-of-scope files rather than guessing — which is the system working as intended, not a failure. If dispatching an agent and it refuses on a file that seems like it should obviously be in scope, the scope definition is probably stale again — check the actual current directory structure and fix `.claude/agents/*.md` before re-dispatching, don't just force it.

**Model override**: a `model:opus` or `model:sonnet` label on the driving GitHub issue overrides every agent's default model for that task.

## `/build` skill

`.claude/skills/build/SKILL.md`. Given a feature request: (1) read the code, (2) ask clarifying questions only if genuinely ambiguous — interactively via `AskUserQuestion`, or async (see below) if no live user, (3) rewrite into a precise spec, (4) decide which agents are actually needed, (5) define shared contracts (method signatures, table/RPC names, routes) *before* dispatching so parallel agents' work fits together without talking to each other, (6) dispatch the needed agents in parallel (single message, multiple `Agent` calls), (7) reconcile + `flutter analyze`, (8) optionally dispatch `qa-agent`, (9) summarize.

## Scheduled board worker

A cron routine ("eatzy board worker", every 2 hours) runs in Anthropic's cloud, independent of any interactive session — see [[Conventions]] for the label protocol it follows. It:
1. Checks `waiting-on-you`-labeled issues first — if the human replied to a previously-asked clarifying question, resumes that task.
2. Otherwise picks the oldest `todo`-labeled issue. If ambiguous, comments with specific questions and relabels `waiting-on-you` instead of guessing. If clear, claims it (`agent-in-progress`) and implements via the same `/build` flow.
3. Always opens a PR against `master`, never pushes directly, never merges itself.
4. Routine ID: `trig_01Mmi2RgzNt2Zj53QvTx8SW2` — view/manage at `https://claude.ai/code/routines/trig_01Mmi2RgzNt2Zj53QvTx8SW2`.

**This vault is committed inside the repo specifically so the board worker can read it too** — if updating the routine prompt, point it at `vault/00-Index.md` first so it doesn't re-explore the whole codebase cold every run.

## Parallelism policy

Within one task spanning layers, dispatch relevant agents in parallel (that's the whole point of the role split). Across *different* tasks: parallelize only when they touch genuinely disjoint files (e.g. a `lib/services/` refactor + a `supabase/` doc fix ran together safely); default to one-at-a-time when tasks might overlap or build on each other.
