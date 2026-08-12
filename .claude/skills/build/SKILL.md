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

**Unowned by any subagent — handle these yourself, don't dispatch**: `pubspec.yaml`, `pubspec.lock`, and the native platform shells (`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` — not `lib/platform/`, which is Dart code and is `logic-agent`'s per the pattern above). These are high-conflict/high-stakes files (dependency changes, native manifests, build config) that no subagent's scope covers — if a task needs one touched, edit it directly as the orchestrator rather than inventing an owner for it.

## Steps

1. **Read the feature request** (`$ARGUMENTS`, or ask the user if empty) and skim the current state of any files it touches so you understand what exists already.

2. **Clarify before you scope, if the request is genuinely ambiguous.** Don't dispatch agents on a guess when the guess could go multiple visibly different ways. Ask when the request is missing something you can't infer from the code itself — e.g. which screen a new feature belongs on, what the exact trigger/condition is, whether it touches existing data vs. needs a new table, or a genuine UX choice (confirmation dialog vs. instant action). Do **not** ask about things you can just check yourself (existing conventions, whether a file/table already exists) or about implementation detail a competent engineer would just decide (variable names, minor styling that follows existing theme). If the request is already unambiguous and small, skip this step entirely — don't manufacture questions for their own sake. **Cap it at three high-value questions per round**, batched into one ask, not a drip of separate ones — if you find yourself wanting a fourth, it's a sign the request needs more independent investigation first, not more questions.

   **How you ask depends on who's there to answer:** interactively, use `AskUserQuestion` and wait for the reply in the same session. Running as the async board worker with no live user present, do **not** guess blindly on consequential ambiguity just because no one's watching — post the questions as a comment on the driving GitHub issue and pause this task for a future run to pick back up once answered (the board-worker routine instructions own the exact labeling/resume protocol for this). Only fall back to stating an assumption and proceeding immediately if there is genuinely no mechanism to ever receive an answer later.

3. **Rewrite the request into a precise task brief** before touching any agent. Fold in the answers from step 2 (if asked) plus what you learned skimming the code in step 1. Use this fixed shape, not free-form prose — it's what gets used to build contracts and dispatch prompts in the steps below:
   - **Goal and user outcome**: what the feature does, in one or two sentences, from the user's point of view.
   - **In-scope / out-of-scope**: which screen/flow it lives in, what's explicitly NOT part of this task (prevents scope creep into an agent's dispatch).
   - **Constraints and explicit assumptions**: anything you decided rather than asked about, stated plainly so it can be corrected on review.
   - **Observable acceptance criteria**: what a reviewer should be able to see/click/verify to confirm this is done.
   - **Verification commands**: at minimum `dart format --output=none --set-exit-if-changed <touched files>`, `flutter analyze`, `flutter test` (or the relevant subset) — never claim one passed if it wasn't actually run.

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
    - **Always**: append to `vault/Status Log.md` under today's existing dated section (create one if there isn't one yet — don't create a duplicate). **Terse means terse — enforce it literally**: 1-4 short bullet points per task, not prose paragraphs. A one-file task is one bullet. State *what changed and where the full detail lives* (an issue number, a PR, another vault file) rather than re-explaining the detail here — this file is an index into the real record (git history, issues, `Audit Findings.md`, `Decisions Log.md`), not a second copy of it. If you're about to write more than ~6 lines for one task, that content almost certainly belongs in `Audit Findings.md` or `Decisions Log.md` instead, with just a pointer left here.
    - **Archive when it grows**: if `vault/Status Log.md` exceeds roughly 150 lines or spans more than ~2 weeks of entries, move everything except the most recent ~2 weeks into `vault/archive/Status Log <YYYY-MM>.md` (named for the month of the oldest entry being moved), and leave a one-line pointer at the bottom of the live file (e.g. "Entries before 2026-08-01 archived in `archive/Status Log 2026-07.md`"). Do this as part of finishing a task if you notice the file has grown past that point — don't wait to be asked.
    - **If relevant, also**: update `vault/Open Tasks.md` if this task closed/relabeled/obsoleted anything it lists; update `vault/Architecture.md` if this task changed something it describes (new shared module, new domain, changed layer boundaries); add to `vault/Decisions Log.md` if a real judgment call or tradeoff was made along the way. Skip whichever of these don't apply — don't touch a note just to have touched it.
    - **If you edited any vault note's body in a way that changes what it's actually about**: update that note's YAML frontmatter `summary` field to match (see `00-Index.md`'s "How each note is structured" section for the full frontmatter schema — `tags`/`summary`/`status`/`upstream_concept`). A stale `summary` is actively misleading, not neutral — treat keeping it in sync as part of the edit, not a separate optional step. Adding a brand-new vault note (rare) requires frontmatter from creation, not as an afterthought.
    - Vault edits are ordinary file edits, not a separate commit — they land in the same commit/PR as the code change, made by whoever finishes the task per the existing commit/PR conventions.

## Notes

- If the feature is small enough for one agent alone (e.g. "change the primary button color"), just dispatch that one agent — don't manufacture parallelism for its own sake.
- If two needed agents would likely touch the same file despite the scope split (rare, but possible for something like `main.dart`), call that out before dispatching rather than risking a silent conflict.
- This skill produces the code change (and the vault update from step 10). It does not commit, push, or open a PR — that's handled by whatever invoked it (interactively, that's the user's call; for the scheduled board worker, see the board-worker routine instructions).
