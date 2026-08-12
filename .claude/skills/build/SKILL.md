---
name: build
description: Implement a feature request in eatzy (chowflow_flutter) by fanning it out to role-scoped subagents (UI, app logic, Supabase, tests) that work in parallel, then reconcile their output into one coherent change. Use when the user invokes /build with a feature description.
---

# /build — parallel role-based feature implementation

You are orchestrating several specialized subagents (defined in `.claude/agents/`) to implement one feature request together: `ui-agent`, `logic-agent`, `supabase-agent`, `qa-agent`. Each owns a distinct part of this codebase so they don't collide on the same files. The codebase is organized by domain (`lib/features/<name>/`, `lib/services/<name>/`, `lib/platform/<name>/`), each with `data/`, `models/`, `presentation/` subfolders — and `presentation/` mixes screen files with colocated `*_controller.dart` state files, so the UI/logic split is by filename pattern, not just directory. See each agent's own definition for the exact pattern; summary:

- `ui-agent` → `lib/screens/`, `lib/widgets/`, `lib/config/theme.dart`, `lib/config/tailwind.dart`, plus `*_screen.dart`/`*_page.dart`/`presentation/widgets/*` files inside any domain's `presentation/` folder
- `logic-agent` → `lib/app/`, `lib/main.dart`, cross-cutting `lib/platform/{session,system_ui,localization}/`, plus every domain's `data/`/`models/` folders and any `*_controller.dart`/`*_service.dart`/`*_repository.dart` file even when it's colocated inside a `presentation/` folder
- `supabase-agent` → `supabase/`
- `qa-agent` → `test/` (runs after the others, not alongside them)

Before assuming a file belongs to a given agent, check its name against the pattern above — don't infer ownership from directory alone.

## Steps

1. **Read the feature request** (`$ARGUMENTS`, or ask the user if empty) and skim the current state of any files it touches so you understand what exists already.

2. **Clarify before you scope, if the request is genuinely ambiguous.** Don't dispatch agents on a guess when the guess could go multiple visibly different ways. Ask when the request is missing something you can't infer from the code itself — e.g. which screen a new feature belongs on, what the exact trigger/condition is, whether it touches existing data vs. needs a new table, or a genuine UX choice (confirmation dialog vs. instant action). Do **not** ask about things you can just check yourself (existing conventions, whether a file/table already exists) or about implementation detail a competent engineer would just decide (variable names, minor styling that follows existing theme). If the request is already unambiguous and small, skip this step entirely — don't manufacture questions for their own sake.

   **How you ask depends on who's there to answer:** interactively, use `AskUserQuestion` and wait for the reply in the same session. Running as the async board worker with no live user present, do **not** guess blindly on consequential ambiguity just because no one's watching — post the questions as a comment on the driving GitHub issue and pause this task for a future run to pick back up once answered (the board-worker routine instructions own the exact labeling/resume protocol for this). Only fall back to stating an assumption and proceeding immediately if there is genuinely no mechanism to ever receive an answer later.

3. **Rewrite the request into a precise spec** before touching any agent. Fold in the answers from step 2 (if asked) plus what you learned skimming the code in step 1, so the spec you're about to hand to agents is unambiguous: what the feature does, which screen/flow it lives in, what data it reads or writes, and any edge cases. This rewritten spec — not the raw one-liner — is what gets used to build contracts and dispatch prompts in the steps below.

4. **Scope the work**: decide which of `ui-agent`, `logic-agent`, `supabase-agent` are actually needed. A pure styling tweak may only need `ui-agent`; a new backend table with no new screen may only need `supabase-agent`. Don't dispatch an agent with nothing to do.

5. **Define shared contracts before dispatching anything.** This is the part that makes parallel dispatch actually work: since the agents run at the same time and can't talk to each other, you must decide up front — not them — the interfaces that let their work fit together. For a typical feature that spans layers, pin down:
   - Any new Supabase table/RPC names, their columns, and return shapes.
   - The exact Dart method signatures `logic-agent` will expose for `ui-agent` to call (e.g. `Future<List<Order>> fetchOrders()`), and the data model shape.
   - Route names if navigation is involved.
   State these explicitly in each agent's dispatch prompt — verbatim, identical across agents — so nobody free-styles an interface the others don't match.

6. **Dispatch the needed layer agents together, in parallel**, in a single message with one `Agent` tool call per agent (this is required for true parallelism — sequential calls block on each other). Each prompt should include: the rewritten spec from step 3, their scope boundaries, the shared contracts from step 5, and an instruction to clearly flag in their summary any stub or TODO they left for another layer.

   **Model policy**: each agent's own definition (`.claude/agents/*.md`) sets a sensible default model for its role — leave the `Agent` call's `model` param unset to use it. If the task specifies an explicit override (e.g. a `model:opus` / `model:sonnet` label on the driving GitHub issue, or the user says so directly), pass that `model` value on every agent call for this task instead, overriding the per-role default.

7. **Wait for all of them to complete**, then review the combined result:
   - Check each agent's summary for stubs/blockers left for another layer — if `ui-agent` expected a method `logic-agent` didn't build (or built differently), fix the mismatch yourself now rather than leaving it broken.
   - Run `flutter analyze` (and `flutter pub get` first if a new dependency was mentioned) across the whole project to catch integration issues the per-agent analysis missed.

8. **Offer `qa-agent` as a follow-up** once the feature is coherent and analyzing clean — dispatch it after, not during, step 6, since it needs to read the finished diff to write meaningful tests. If a user is present and only asked for the feature (not tests), ask first. If running unattended, dispatch it automatically — an unreviewed PR should come with test coverage.

9. **Summarize**: what changed, in which files, any contract decisions or assumptions made, and anything still open (e.g. a migration that needs to be applied to the live Supabase project, which must never happen without explicit human confirmation — flag it, don't do it).

10. **Update the vault — always, not optional, but proportionate to the task.** This is what keeps `vault/` trustworthy instead of stale; don't skip it because the task felt small.
    - **Always**: append one dated entry to `vault/Status Log.md` (append to today's existing dated section if there is one, don't create a duplicate). Keep it terse — a task that touched one file gets one line, not a paragraph; git history already has the diff, this is for orientation, not a changelog.
    - **If relevant, also**: update `vault/Open Tasks.md` if this task closed/relabeled/obsoleted anything it lists; update `vault/Architecture.md` if this task changed something it describes (new shared module, new domain, changed layer boundaries); add to `vault/Decisions Log.md` if a real judgment call or tradeoff was made along the way. Skip whichever of these don't apply — don't touch a note just to have touched it.
    - Vault edits are ordinary file edits, not a separate commit — they land in the same commit/PR as the code change, made by whoever finishes the task per the existing commit/PR conventions.

## Notes

- If the feature is small enough for one agent alone (e.g. "change the primary button color"), just dispatch that one agent — don't manufacture parallelism for its own sake.
- If two needed agents would likely touch the same file despite the scope split (rare, but possible for something like `main.dart`), call that out before dispatching rather than risking a silent conflict.
- This skill produces the code change (and the vault update from step 10). It does not commit, push, or open a PR — that's handled by whatever invoked it (interactively, that's the user's call; for the scheduled board worker, see the board-worker routine instructions).
