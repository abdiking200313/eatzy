---
tags: [decisions, history]
summary: Dated record of explicit user decisions and the reasoning behind them, so they don't get re-litigated or silently reversed.
status: append-only
upstream_concept: 00-Index
---

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

### 2026-08-13 — CORRECTION: an investigating agent misdiagnosed AGENTS.md's repo-authority claim as wrong — it was actually right

Follow-up to the 2026-08-12 entry above's "not reconciled yet" note. A dispatched investigation agent, tasked with reconciling `.codex/agents/`/AGENTS.md against the `.claude` setup, checked whether AGENTS.md's "the Flutter project at the repository root is canonical, don't edit `chowflow_flutter/**`" claim was still accurate. It concluded AGENTS.md was **wrong**, reasoning: "`c:\Users\Abdimalik\projects\eatzy` (the repository root AGENTS.md calls canonical) has no `lib/`, no `pubspec.yaml`, and is not even a git repository."

**That conclusion is itself wrong — the agent checked the wrong folder.** It's the exact same `chowflow_flutter/`-prefix confusion already documented in [[Conventions]] ("Repo structure gotcha"): `c:\Users\Abdimalik\projects\eatzy` is the *outer local folder*, one level above the actual git repo, and was never the repo root. AGENTS.md is a file committed inside the repo, so "the repository root" it refers to is the repo's own root — which, on this machine, is the local folder confusingly also named `chowflow_flutter/` (i.e. `c:\Users\Abdimalik\projects\eatzy\chowflow_flutter\`). That folder does have `lib/`, `pubspec.yaml`, and the `.git` — exactly matching what AGENTS.md describes as canonical. And `chowflow_flutter/**` in AGENTS.md's warning correctly refers to the nested subdirectory *inside* that repo root (`<repo-root>/chowflow_flutter/`) — the same starter/duplicate project already discussed and deleted per the entry above. AGENTS.md was right the whole time; no fix to it was needed or made.

**Lesson, reinforcing rather than replacing the existing [[Conventions]] note**: this confusion has now caused a real mistake (the original deletion-authorization gap) AND a false "AGENTS.md is wrong" finding from an agent that was never pointed at the vault's existing warning about exactly this trap. Dispatching investigation agents into this repo without directing them to read [[00-Index]]/[[Conventions]] first means they can rediscover — and misdiagnose — problems the vault already has answers for. When dispatching agents for repo-structure-sensitive investigation, point them at the vault explicitly, not just the code.

The same investigation's *other* findings (process-rule gaps, the still-live `item_categories`/currency schema drift, README staleness) were independently verified as accurate and acted on — see [[Audit Findings]] 2026-08-13 and [[Open Tasks]]. Only the repo-authority conclusion was wrong.

### 2026-08-13 — Added an explicit approval gate before the board worker may act on any issue

User noticed that filing an issue with the `todo` label — including the 18 issues filed by an AI session earlier the same day, purely from audit findings, with no individual per-item sign-off — made it immediately eligible for the board worker to pick up and implement. Wanted an explicit approve-before-pickup step instead of "labeled `todo`" alone being sufficient trust.

**Decision**: introduced `needs-approval` as the default label for any newly filed issue (whether filed by the user or by an AI session on their behalf going forward — see [[Conventions]] for the full label table). `todo` now strictly means "the user has actually reviewed and approved this." Approval is a plain relabel (`needs-approval` → `todo`) via GitHub's own UI/mobile app — deliberately no bot/automation/comment-trigger layer, since this is a low-traffic solo project and the simplest mechanism is the most trustworthy one. Retroactively relabeled all 18 then-open `todo` issues (#1,2,4-19; #3 was already `needs-clarification`, untouched) to `needs-approval`, since none had actually been individually approved. Updated the board-worker routine prompt with an explicit `APPROVAL GATE` section as defense-in-depth on top of the label-filtered query (which already only ever asked for `todo`, so this was already functionally safe — the explicit section is about making the invariant impossible to miss on a future routine edit, not fixing an actual gap in what the worker could act on).

**Going forward**: when I file an issue on the user's behalf (audit findings, etc.), default to `needs-approval`, not `todo`. Only use `todo` directly if the user explicitly says to skip the approval step for that specific item (e.g. "just add it to todo" in the moment).
