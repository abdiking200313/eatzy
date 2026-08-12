# eatzy / chowflow_flutter — Vault

**STOP — read `AGENTS.md` at the repo root FIRST, before this file or anything else.** It is the user's own authoritative standing instructions for this repo (written 2026-07-27, predates this vault), covers repository authority/scope, architecture principles, delegation rules, project map, Flutter/Supabase conventions, and required verification commands (`dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`). This vault supplements it and must never contradict it. **A past session skipped this and deleted something AGENTS.md explicitly says is out of scope** — see [[Decisions Log]] 2026-08-12. Don't repeat that.

This vault is the persistent knowledge base for this project — read it after AGENTS.md, before exploring the codebase from scratch. It exists to save time/usage: don't re-derive what's already written down here, but don't trust it blindly either — it can go stale. If something here contradicts what you actually find in the code (or in AGENTS.md), the code/AGENTS.md wins; update the note.

**Read order for a cold start**: `AGENTS.md` (repo root) → this file → [[Architecture]] → [[Multi-Agent Setup]] → [[Conventions]] → [[Open Tasks]] → [[Status Log]] (most recent entries).

## Map

- [[Architecture]] — domain-based lib/ layout, key files, backend shape
- [[Multi-Agent Setup]] — the ui-agent/logic-agent/supabase-agent/qa-agent split, `/build` skill, scheduled board worker
- [[Conventions]] — GitHub labels, branch naming, PR rules, model policy
- [[Decisions Log]] — dated record of explicit choices made and why
- [[Audit Findings]] — what the codebase audits found, what's fixed vs. open
- [[Open Tasks]] — quick-reference cache of open GitHub issues (source of truth is always `gh issue list --repo abdiking200313/eatzy`, re-check if it matters)
- [[Status Log]] — dated chronological log of what happened each session; the most important note for continuity across sessions/usage-limit boundaries

## What this project is

eatzy (repo name) / chowflow (in-app name) — a Flutter "super app" for food delivery, grocery, pharmacy, and (soon-to-be-removed) cleaning-booking, backed by Supabase. Solo project, owner `abdiking200313`.

## What this vault is not

Not a replacement for `gh issue list` (issues) or `git log` (history) — those are ground truth. This vault is for things that take real exploration to (re)derive: architecture shape, decisions and their reasoning, and a running log of what's been done. When in doubt, prefer a quick `git log`/`gh` check over an old vault note for anything time-sensitive.
