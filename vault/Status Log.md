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
