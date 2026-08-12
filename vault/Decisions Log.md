# Decisions Log

Dated record of explicit choices the user made, and why — so future sessions don't re-litigate or accidentally reverse them.

### 2026-08-12 — Multi-agent split: role-based (UI/logic/Supabase/QA), not per-attempt or research-only
User confirmed role-based over independent-worktree-attempts or pure-research fan-out. Reasoning: matches how features actually decompose in this codebase. See [[Multi-Agent Setup]].

### 2026-08-12 — Four agents is enough for now, not more
Considered splitting further (e.g. a dedicated payments-agent). Decision: hold at 4 — the current split follows real non-overlapping directory boundaries; further splitting adds contract-coordination overhead without much parallelism payoff since most features cut across UI+state+data together. Revisit reactively if a specific domain (e.g. payments) becomes a real bottleneck, not preemptively.

### 2026-08-12 — Task board = GitHub Issues, not a file-based checklist
Chosen for visibility from anywhere and native tooling (`gh`) support, over a TASKS.md-style file.

### 2026-08-12 — Unattended agent work always lands as a PR, never a direct push
Safety default for anything happening while no one's watching — matches the general "hard to reverse / affects shared state" caution principle.

### 2026-08-12 — Board worker cadence: every 2 hours
Chosen over hourly (too many no-op runs for a low-traffic solo project) or every 6 hours (too slow to pick things up same-day). Minimum allowed interval is 1 hour.

### 2026-08-12 — Model policy: role-based defaults + per-issue override label
`supabase-agent` defaults to opus (schema/RLS mistakes are costliest); others default to sonnet. A `model:opus`/`model:sonnet` label on an issue overrides the default for that task. Top-level board-worker orchestrator session itself is fixed to sonnet at the routine-config level (can't be dynamic per-run since the model is set before the session reads the issue).

### 2026-08-12 — Board worker asks and waits, not guesses, on real ambiguity
When genuinely ambiguous, the worker posts clarifying questions as an issue comment and relabels `waiting-on-you`, checking for a reply on future runs, rather than making assumptions the way a strictly one-shot unattended run would have to. Only falls back to stating an assumption if there's truly no mechanism to ever get an answer.

### 2026-08-12 — Vault committed inside `chowflow_flutter/`, not kept local-only
Chosen so the scheduled cloud board worker can also read it (cutting its own exploration/usage each run), accepting that audit notes/decisions now live alongside app source rather than staying private-local.

### 2026-08-12 — Deferred audit fixes: feature gaps get filed, not silently built
Wallet being fake and food checkout missing a real address are product decisions (build it for real vs. mark as not-ready vs. remove), not things to unilaterally implement. Filed as issues (#1, #2) instead of executed directly. Mechanical/low-risk fixes (dedup extraction, stale-doc correction) were executed directly in the same pass.
