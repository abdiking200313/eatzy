---
tags: [index, navigation]
summary: Entry point and read-order map for the vault — read AGENTS.md first, then this.
status: reference
upstream_concept: AGENTS.md
---

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

eatzy (repo name) / chowflow (in-app name) — a Flutter "super app" for food delivery, grocery, and pharmacy, backed by Supabase. A fourth vertical, cleaning-booking, was removed entirely in issue #50 (2026-08-15). Solo project, owner `abdiking200313`.

## What this vault is not

Not a replacement for `gh issue list` (issues) or `git log` (history) — those are ground truth. This vault is for things that take real exploration to (re)derive: architecture shape, decisions and their reasoning, and a running log of what's been done. When in doubt, prefer a quick `git log`/`gh` check over an old vault note for anything time-sensitive.

## How each note is structured (added 2026-08-13)

Every note in this vault carries YAML frontmatter — scan it before deciding whether to read the full file:

- **`tags`**: topic keywords, consistent across notes (`architecture`, `agents`, `automation`, `conventions`, `decisions`, `audit`, `security`, `testing`, `currency`, `github`, `tasks`, `history`, `index`, `navigation`) — used for filtering, not unique per note.
- **`summary`**: one line, what the note is for. Must be kept in sync with the body — a wrong summary is worse than none, treat it with the same discipline as the content itself, update it whenever the note's actual purpose/scope changes.
- **`status`**: one of —
  - `reference` — stable, rarely changes (this file)
  - `living` — actively maintained, edited in place as facts change ([[Architecture]], [[Multi-Agent Setup]], [[Conventions]])
  - `append-only` — grows via dated/numbered entries, old entries are not rewritten ([[Decisions Log]], [[Audit Findings]], [[Status Log]])
  - `cache` — mirrors an external source of truth and **can be stale by design** — always re-check the real source before relying on it for anything that matters ([[Open Tasks]], source of truth is `gh issue list`)
- **`upstream_concept`**: the note this one exists to elaborate on — `AGENTS.md` for this file, `00-Index` for every other note in the vault (single-hop hierarchy, keeps it simple).

Within notes, `##` headers are chunk boundaries — written so a `Grep` for a header plus a scoped `Read` can pull just that section instead of the whole file. Keep using them that way when editing: one `##` per logically independent sub-topic, not run-on sections.
