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

### 2026-08-12 — CRITICAL: AGENTS.md existed and was never read; deletion of chowflow_flutter/chowflow_flutter/ confirmed as a knowing exception

A session earlier the same day deleted the nested `chowflow_flutter/chowflow_flutter/` folder (commit `c3e7e72`, already pushed) based on an audit agent's assessment ("stock template, unreferenced, safe to delete") and got user approval for that framing. What that session didn't know: `AGENTS.md` at the repo root (committed 2026-07-27, by the user, predates this whole vault/agent-setup effort) explicitly states *"Do not edit `chowflow_flutter/**`. It is a tracked starter/duplicate project and is out of scope unless the user explicitly names it."* — i.e. the deletion contradicted a standing instruction that was never discovered because no session had done a plain top-level `ls` of the repo root before diving into `lib/`/`supabase/`/`test/`.

This was only discovered afterward, while inspecting a scheduled board-worker cloud run's logs — that run *did* find and read AGENTS.md correctly (its investigation trail shows it discovering the file naturally), which is what surfaced the conflict.

**Decision, once disclosed to the user**: deletion stands. The user confirmed this knowingly, as a deliberate exception to AGENTS.md, not an oversight — the folder really was dead stock-template code, and now that it's a documented, discussed exception it satisfies AGENTS.md's own carve-out ("out of scope unless the user explicitly names it" — it has now been explicitly named). Do not re-delete or re-litigate this. If `chowflow_flutter/chowflow_flutter/` reappears in a diff for any other reason, treat it as unrelated to this decision.

**Also surfaced by AGENTS.md and not yet acted on** (filed as issue #8 rather than deep-investigated immediately, per user instruction): a documented currency-representation issue (Dart using decimal/double for prices vs. SQL using integer smallest-currency units — directly conflicts with the top-level currency convention) plus additional schema drift (`item_categories`/`icon_url`/`logo_url`/`menu_items.categorie_id` vs. what SQL actually defines) beyond what the deeper audit pass had already found and filed as issue #3.

**Structural implication**: AGENTS.md also documents a full pre-existing multi-agent delegation system (`.codex/agents/*.toml` — `product_analyst`, `super_app_architect`, `flutter_engineer`, `supabase_engineer`, `quality_reviewer`) built for Codex, with process rules (task briefs, 3-question clarification cap, file-ownership rules, a `dart format --set-exit-if-changed` verification step) that the `.claude/agents/` + `/build` system in this vault was built independently of, not in reference to. Not reconciled yet — worth comparing in a future session rather than treating the two systems as unrelated.
