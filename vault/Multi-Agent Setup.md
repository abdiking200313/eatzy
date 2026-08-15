---
tags: [agents, automation, build-skill, board-worker, github]
summary: The four Claude Code subagents and their scope, the /build skill's 10-step flow, and the scheduled board-worker routine.
status: living
upstream_concept: 00-Index
---

# Multi-Agent Setup

Full source of truth is always `.claude/agents/*.md` and `.claude/skills/build/SKILL.md` (both live in this repo, at `chowflow_flutter/.claude/`) — this note is a map/summary, not a copy. Read the actual files before dispatching if the details matter; they're short.

## The four subagents

- **`ui-agent`** — visual/presentation. `lib/screens/`, `lib/widgets/`, `lib/config/theme.dart`+`tailwind.dart`, plus `*_screen.dart`/`*_page.dart`/`presentation/widgets/*` files inside any domain's `presentation/` folder. Model: sonnet.
- **`logic-agent`** — app wiring, state, business logic. `lib/app/`, `lib/main.dart`, cross-cutting `lib/platform/{session,system_ui,localization}/`, plus every domain's `data/`/`models/` folders and any `*_controller.dart`/`*_service.dart`/`*_repository.dart` file even when colocated inside `presentation/`. Model: sonnet.
- **`supabase-agent`** — `supabase/` only (migrations, schema, RLS, edge functions). Model: **opus** (higher stakes — schema/RLS mistakes are the costliest to get wrong).
- **`qa-agent`** — `test/` only, runs after the others (not alongside), since it needs to read the finished diff. Model: sonnet.

**Unowned by design**: `pubspec.yaml`, `pubspec.lock`, and native platform shells (`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`) belong to none of the four — added 2026-08-13 after finding these had no owner at all. The orchestrator (whoever's running `/build`) handles these directly rather than dispatching, since they're high-conflict/high-stakes (dependency changes, native manifests) and no subagent's prompt covers them.

**Critical gotcha already hit once**: the scope definitions were originally written against a flat `lib/screens/`+`lib/widgets/` view of the codebase. The real layout moved to domain-based `features/services/platform` with controllers colocated inside `presentation/` folders (see [[Architecture]]). Both `ui-agent` and `logic-agent` correctly *refused* to touch out-of-scope files rather than guessing — which is the system working as intended, not a failure. If dispatching an agent and it refuses on a file that seems like it should obviously be in scope, the scope definition is probably stale again — check the actual current directory structure and fix `.claude/agents/*.md` before re-dispatching, don't just force it.

**Model override**: a `model:opus` or `model:sonnet` label on the driving GitHub issue overrides every agent's default model for that task.

## `/build` skill

`.claude/skills/build/SKILL.md`. Given a feature request: (1) read the code, (2) ask clarifying questions only if genuinely ambiguous, **capped at 3 per round** — interactively via `AskUserQuestion`, or async (see below) if no live user, (3) rewrite into a fixed-shape task brief (goal, in/out-of-scope, constraints/assumptions, acceptance criteria, verification commands — not free-form prose), (4) decide which agents are actually needed, (5) define shared contracts (method signatures, table/RPC names, routes) *before* dispatching so parallel agents' work fits together without talking to each other, (6) dispatch the needed agents in parallel (single message, multiple `Agent` calls), (7) reconcile + `flutter analyze`, (8) optionally dispatch `qa-agent`, (9) summarize, (10) update the vault (mandatory, see step 10 in the actual file for exactly what's required vs. conditional).

**When dispatching read-only investigation agents (audits, not `/build` feature work)**: point them at `vault/00-Index.md` explicitly in the prompt, not just the code. One investigation agent on 2026-08-13 wasn't told to read the vault, independently rediscovered the exact `chowflow_flutter/`-path confusion [[Conventions]] already warns about, and produced a wrong finding as a result (see [[Decisions Log]] 2026-08-13). Agents without the vault's context can waste effort rediscovering — and getting wrong — things already answered here.

## Scheduled board worker

A cron routine ("eatzy board worker", every 2 hours) runs in Anthropic's cloud, independent of any interactive session — see [[Conventions]] for the label protocol it follows. It:
0. **Never acts on `needs-approval`-labeled issues** — only `todo` (approved) or `waiting-on-you` (already-approved, paused on a question). Added 2026-08-13 as an explicit gate; see [[Conventions]] and [[Decisions Log]] 2026-08-13.
1. Checks `waiting-on-you`-labeled issues first — if the human replied to a previously-asked clarifying question, resumes that task.
2. Otherwise picks the oldest `todo`-labeled issue. If ambiguous, comments with specific questions and relabels `waiting-on-you` instead of guessing. If clear, claims it (`agent-in-progress`) and implements via the same `/build` flow.
3. Always opens a PR against `master`, never pushes directly, never merges itself.
4. **Processes up to 6 eligible issues per run** (added 2026-08-15), looping back to step 1 after finishing/pausing each one instead of stopping after the first. Each issue's actual implementation is dispatched via `Task` as its own fresh unit of work — no diffs/tool-output/discussion detail carried from a previously finished issue into the next one's context, only lightweight bookkeeping (issue number, count so far) persists across loop iterations. This keeps the top-level routine session cheap regardless of how many issues it works in a cycle, and keeps unrelated issues from bleeding into each other, without needing a separate cloud session per issue (the routine API only spawns one session per cron fire).
5. Routine ID: `trig_017jPchk8L4LVskUZMGwiDDG` — view/manage at `https://claude.ai/code/routines/trig_017jPchk8L4LVskUZMGwiDDG`. **Recreated 2026-08-15**: the original routine (`trig_01Mmi2RgzNt2Zj53QvTx8SW2`) had vanished — 404'd on lookup and didn't appear in the routine list at all, cause unknown (not a config error, the ID simply stopped resolving). Rebuilt from this note's spec since the old trigger's exact prompt text wasn't recoverable. If it happens again, check `RemoteTrigger {action: "list"}` first — an ID that 404s and is also absent from `list` means the routine itself is gone, not paused.

**This vault is committed inside the repo specifically so the board worker can read it too** — if updating the routine prompt, point it at `vault/00-Index.md` first so it doesn't re-explore the whole codebase cold every run.

## Parallelism policy

Within one task spanning layers, dispatch relevant agents in parallel (that's the whole point of the role split). Across *different* tasks: parallelize only when they touch genuinely disjoint files (e.g. a `lib/services/` refactor + a `supabase/` doc fix ran together safely); default to one-at-a-time when tasks might overlap or build on each other.
