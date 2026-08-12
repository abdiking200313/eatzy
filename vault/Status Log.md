# Status Log

Reverse-chronological. Each session/major chunk of work gets an entry. Keep entries terse — this is for fast orientation, not a full changelog (git history has that).

---

## 2026-08-12

**Set up the whole multi-agent + automation system from scratch this session**:
- Found and fixed a real problem first: git was accidentally initialized at the *home directory* (`C:\Users\Abdimalik`) instead of the project — removed (it had zero commits, nothing lost). Confirmed the real repo is `chowflow_flutter/` → `github.com/abdiking200313/eatzy`, already had history and a remote.
- Built 4 subagents + `/build` skill (see [[Multi-Agent Setup]]), mirrored into `chowflow_flutter/.claude/` so the repo itself carries the config.
- Set up GitHub Issues as the task board (labels — see [[Conventions]]) and a scheduled cloud "board worker" routine (every 2h) with an async ask-and-wait clarification flow instead of blind guessing.
- **Caught a real bug in the setup itself**: agent scope definitions were written against a stale/flat view of `lib/` that didn't match the actual domain-based layout. Both `ui-agent` and `logic-agent` correctly refused out-of-scope edits rather than guessing — fixed the scope definitions to match reality (see [[Architecture]], [[Multi-Agent Setup]]).

**Ran two audit passes** (see [[Audit Findings]] for full detail):
- Shallow pass: removed a stale duplicate Flutter project folder + 2 dead widgets, fixed 2 code-quality nits. All executed directly, committed.
- Deeper pass (security/tests/duplication/resilience): found RLS/RPC security is solid, but real gaps in test coverage (failure paths, auth), 2x-3x duplicated logic across food/grocery/pharmacy, 2 "looks-done-but-isn't" feature gaps (wallet, food address), and schema docs drifted from migrations. Feature-gap items filed as issues (#1, #2) rather than auto-implemented since they need product decisions; mechanical items (dedup extraction, doc fix) attempted directly.

**Interrupted mid-work**: hit a session/usage-limit boundary while dispatching the dedup extraction. The `logic-agent` background task got cut off mid-task (host process exited); on return, tried to resume it but it had already been stopped/cancelled by the user meanwhile — left as cancelled per instruction, partial work sits uncommitted in the working tree. See [[Open Tasks]] for exact state. The `supabase-agent` doc-fix task, run in parallel, completed but found the schema doc fix couldn't be safely done without a live DB check — filed as issue #3 instead of guessing.

Filed issues #1-7 total this session (see [[Open Tasks]]).

**Built this vault** in response to the session-interruption experience above — the point is exactly to avoid re-deriving all of this from scratch (and burning usage re-exploring/re-discovering) in whatever session picks this up next. Committed inside `chowflow_flutter/` (not kept local-only) so the board worker can read it too.

Vault committed and pushed; board-worker routine updated to read the vault first (PART 0 added to its prompt).

**Then, while checking on the board worker's first few runs (all 3 had actually hit an account-level rate limit and done nothing — see below), found something important in a run's tool-call log: `AGENTS.md` exists at the repo root, written by the user on 2026-07-27, and no session this whole day had ever read it.** It explicitly says the deleted `chowflow_flutter/chowflow_flutter/` folder was an intentionally-tracked out-of-scope starter project, not garbage — directly contradicting the framing used to get deletion approval earlier this session. Disclosed to the user in full; **user confirmed the deletion stands as a knowing exception**, not to be re-litigated. Full writeup in [[Decisions Log]]. Also surfaced: AGENTS.md documents a currency decimal-vs-integer-units issue and other schema drift beyond what the audit found (filed as issue #8), and a pre-existing Codex-oriented multi-agent system (`.codex/agents/*.toml`) not yet reconciled with the `.claude/agents/` system built today.

**Lesson for future sessions, already reflected at the top of [[00-Index]]**: always read `AGENTS.md` at the repo root — and generally do a plain top-level `ls`/`find` of a repo's root before diving into subfolders — before making any destructive change. This session went straight into `lib/`, `supabase/`, `test/` without ever looking at what else sat at the repo root.

**Board worker rate-limiting observed**: all 3 runs so far today (18:16, 19:28, 20:17 UTC) hit `rate_limit: rejected (five_hour)` and did nothing — the scheduled cloud routine appears to share the same account-level usage pool as interactive sessions. Not a bug to fix, just something to know: silence/no-op from the board worker doesn't necessarily mean "no todo issues" — check `get_run_log` for a `rate_limit` rejection before assuming that. Should self-resolve on later runs once the limit window rolls over.

Added `dart format --output=none --set-exit-if-changed` to all `.claude/agents/*.md` verification steps (both the in-repo copy and the outer local mirror) to close that gap. Updated the board-worker routine to read `AGENTS.md` before the vault, and confirmed the deletion decision as final.

**Caught and fixed a second, related mistake while doing that update**: the routine prompt had always said "cd into chowflow_flutter/, that's the actual project root" — wrong, per [[Conventions]] "Repo structure gotcha." Wrote it wrong *again* in the very next routine update (`chowflow_flutter/AGENTS.md`) before catching it from re-reading the actual cloud run's `ls` output and fixing it properly. See [[Conventions]] for the corrected explanation — worth a careful read if touching the routine prompt again, this mistake is easy to repeat.

**Not yet done as of end of this entry**: issue #8's currency/schema-drift investigation hasn't started; reconciling `.codex/agents/` guidance into the Claude Code agent setup hasn't happened; the interrupted dedup extraction (see [[Open Tasks]]) is still sitting uncommitted/unfinished.

---

## 2026-08-13

**User directly challenged whether the prior audits were actually thorough** ("did you take a good look at the project"). Honest answer given: no — never ran the app, never reconciled `.codex`/AGENTS.md, several areas never read at all (native configs, `lib/platform/`, several feature verticals), issue #8 left uninvestigated. User asked for a real pass, pre-authorizing investigation questions.

**Ran a genuinely thorough pass**: 5 parallel read-only investigation agents (agent-system reconciliation, currency/schema deep-dive, native-platform/branding audit, remaining-verticals audit, full test-suite read) plus an actual live-app launch. See [[Audit Findings]] Pass 3 for the full writeup. Highlights:
- **Release-blocking bug found and fixed same-session**: Android release manifest was missing the `INTERNET` permission entirely.
- Currency/schema drift (issue #8) went from "documented claim, unverified" to a precise, evidence-backed finding — two conflicting SQL conventions in the repo, one live crossing point (`menu_items.price`), needs a live DB check to close.
- 6 new "looks-done-but-isn't" feature gaps found (rewards, settings, addresses, payment methods, profile-edit, onboarding-gating) — filed as issues #9-15, not auto-built, matching the existing wallet/food-address precedent.
- Plus: branding/bundle-ID drift (#16), no CI/CD (#17), test-suite gaps (#18), `ActivityController` architecture violation (#19).
- **A misdiagnosis happened and was caught**: an investigation agent, not pointed at the vault, rediscovered and misapplied the `chowflow_flutter/`-path confusion, wrongly concluding AGENTS.md's repo-authority claim was stale. Corrected in [[Decisions Log]] — no fix to AGENTS.md was actually needed.
- **Live-app check was honest about its limits**: launched the app for real (Flutter web + a scratch Playwright script, no project run-skill existed), got a real screenshot of the welcome screen rendering correctly — but could not reach the two specific refactored screens (restaurant detail, cleaning booking) because they're auth-gated and this sandbox can't reach Supabase's network. Reported that limitation plainly rather than claiming a visual check that didn't happen.

**Fixed directly this session** (mechanical/low-risk, same pattern as before): the INTERNET permission bug, dead code in `app_widgets.dart`/`app_money.dart`/`app_cards.dart`, `ActivityController`'s error-swallowing, `test/widget_test.dart` renamed, `chowflow_flutter/README.md` rewritten to stop being stale, stale-warning banners added to all 6 outer `eatzy/*.md` docs, and three `.claude/skills/build/SKILL.md` process gaps closed (3-question cap, task-brief schema, explicit pubspec/native-platform non-ownership) — adopted from the AGENTS.md/`.codex` reconciliation findings. Verified with a full `dart format --set-exit-if-changed lib test` / `flutter analyze` / `flutter test` pass — all clean, 60/60 tests passing.

**Also fixed two stale issue-number references** in [[Audit Findings]] Pass 2 (had #4/#6 where it should've said #5/#7) — a small internal-consistency bug in the vault itself, worth remembering the vault needs its own accuracy upkeep, not just the code's.

**Not done this session, tracked in [[Open Tasks]]**: the interrupted dedup extraction from 2026-08-12 is still sitting uncommitted, untouched; the 6 new feature-gap issues (#9-15) and the currency verdict (#8) all still need either a live DB check or a product decision from the user before anyone can act further.
