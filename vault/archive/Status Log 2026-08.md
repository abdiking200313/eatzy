---
tags: [history, log, archive]
summary: Archived Status Log entries for 2026-08-12 through 2026-08-30 (setup, first thorough audit pass, routine recreation/cleaning removal/app-icons run, and the 13th-15th board-worker runs), moved out of the live log once it passed the ~150-line archive threshold.
status: append-only
upstream_concept: 00-Index
---

# Status Log archive — 2026-08 (early)

Moved out of `vault/Status Log.md` on 2026-08-23 (2026-08-12/13 entries) and 2026-08-30 (2026-08-15 entry, 15th board-worker run) per that file's own archive rule. The 2026-08-12/13 entries predate the "terse means terse" rule (added 2026-08-13) and are longer than current entries — left as-is rather than retroactively edited.

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

---

## 2026-08-15

- Board-worker run at ~20:34 UTC found nothing eligible: 0 `todo` issues, `waiting-on-you` issue #16 still has no human reply since the agent's clarifying question, and all 3 `agent-in-progress` issues (#7, #33, #50) already have open PRs (#20, #51, #84) awaiting review. Stopped early per the loop's step 3, no action taken.
- Noting for whoever next touches [[Open Tasks]]: it's now significantly behind reality — repo has issues up to #84, almost all `needs-approval` from a large audit batch (#29-83ish, deploy-readiness + architecture/perf review tracking issues), not reflected in that cache at all. Didn't rebuild it this run (out of scope for a no-op cycle); worth a refresh next time someone's doing vault upkeep.
- Board-worker routine had vanished entirely (404 + absent from `list`) — recreated as `trig_017jPchk8L4LVskUZMGwiDDG`, now every 5h (was 2h, changed at user request), rebuilt from [[Multi-Agent Setup]]'s spec since the original prompt wasn't recoverable. See [[Decisions Log]] for full detail.
- Added: routine now processes up to 6 issues per run (was 1), each dispatched via a fresh `Task` per issue to keep the top-level session's context from compounding.
- **Issue #50 executed**: cleaning/cleaner vertical deleted entirely — `lib/services/cleaning/`, its 2 dedicated test files, all `ServiceId.cleaning`/route/theme/session references removed; `ActivityItem.fromMap` now drops legacy `'cleaning'`-typed activity rows instead of throwing. New unapplied migration `supabase/migrations/20260815153920_remove_cleaning_vertical.sql` drops the cleaning tables/RPCs/view branch — **not run against the live DB**, manual follow-up. `dart format`/`flutter analyze`/`flutter test` (53/53) all clean. See PR for #50.
- **Board worker built issue #33** (stock Flutter template app icons/splash screen on Android+iOS): made `ZivoMarkPainter` in `lib/widgets/zivo_logo.dart` public and added `tool/generate_brand_assets.dart` (a `flutter_test`-based rasterizer) so the app-icon/splash source PNGs under `assets/icon/` are generated from the exact same brand mark used in-app, not a separate hand-made asset. Wired via `flutter_launcher_icons` + `flutter_native_splash` (new dev deps, config in `pubspec.yaml`); ran both generators for Android (incl. adaptive icon)/iOS/macOS/Windows/web. `flutter_launcher_icons` has no Linux target — left Linux icon untouched, noted as an assumption in the PR. Also fixed the stale "A new Flutter project." description in `web/manifest.json` and `web/index.html` per the issue. Format/analyze/test all clean (60/60).
- Issue #16 (native bundle identifiers) is still `waiting-on-you` — my clarifying question is up, no reply yet.

---

## 2026-08-30 (13th run — big backlog reload)

- The "nothing eligible" streak was stale — between the last run and this one the human approved/filed a large new batch: a 7-issue merchant self-service epic (#128 tracking + #129-135), 9 new small UI/bug issues (#137-144, plus #122/#123 approved to `todo`), and 5 older `todo`-without-`waiting-on-you` issues (#38, #43, #73, #74, #81).
- Processed 6 issues oldest-first: #38→PR #145, #73→PR #146, #81→PR #148, #122→PR #147, #43→PR #149, all merged; #74 found genuinely blocked (depends on issue #34, not itself `todo`-approved) and relabeled `waiting-on-you`.
- **#79 got a real human reply this run** (no bot footer) redirecting its fulfilment-model question to the new #128/#131 decision — left `waiting-on-you` as-is since the actual implementation lands via #131.
- #16/#40/#78 still no human reply.

## 2026-08-30 (14th run — merchant chain kickoff + blocking checkout fix)

- Processed #123 (merged, PR #152), #129 (merged, PR #151), #130 (merged, PR #153), #131 (merged, PR #154, also resolves #79's fulfilment-path question), #132 (**paused `waiting-on-you`** — issue's own text says it needs human scoping before pickup, asked the 3 questions the issue itself raises), #136 (merged, PR #157 — a real production-breaking bug, food checkout was broken for every user, now fixed), #137 (merged, PR #156).
- **#133/#134/#135 skipped**, all depend on #132. Merchant chain now blocked at #132 until the human answers the same-repo-vs-separate-repo question.

## 2026-08-30 (15th run — fresh-audit-pass batch cleared)

- **`waiting-on-you` re-checked first, no change**: #8/#16/#40/#78/#132 re-checked via `get_comments` — still only agent-authored comments, no genuine human reply on any. #74 unchanged (still blocked on #34's approval, per the 13th/14th run finding). #79's most recent comment is already this bot's own informational follow-up from the 14th run (posted after #131 merged) — nothing new to act upon there, correctly left open per the human's own earlier instruction to leave it tracking until confirmed.
- **Processed all 6 remaining oldest `todo` issues from the #137-144 fresh-audit batch**, strict oldest-first, all dispatched as parallel `isolation: "worktree"` background agents from clean `master` (`a8d6529`), all merged:
  - **#138** ("Added to cart" snackbar used Flutter's plain 4s default, inconsistent wording/styling across 5 call sites) → PR #162. New shared `showCartSnackBar(context, message)` helper in `lib/widgets/app_misc.dart` — `SnackBarBehavior.floating`, ~1.8s duration, rounded shape, inset margin, existing `TwColors`/`TwSpacing`/`TwRadius` tokens. All 5 call sites (food's restaurant/cart screens, grocery's screen/cart screen, pharmacy's catalog screen) switched over, each site's own message-text logic preserved untouched. Verified via Flutter's own `Scaffold` source that a floating SnackBar's auto-lift-above-FAB/bottom-nav is independent of `margin`, so one shared style is safe everywhere including the food FAB screen. 164/164 tests.
  - **#139** (cart icon inconsistent: grocery/pharmacy had a small outline `IconButton`+default `Badge`, food had no AppBar icon at all and used a bottom FAB instead) → PR #160. New shared `CartAppBarAction` widget (`lib/widgets/cart_app_bar_action.dart`) — 44x44 filled chip in the vertical's soft accent color, solid icon, accent-colored count badge shown only when non-empty. Food's competing bottom FAB removed since the issue explicitly disallows two entry points on one screen.
  - **#142** (Recent Activity section cramped) → PR #159, `TwSpacing.rhythmTight`/`x3` → `x4` on the home screen.
  - **#143** (resize search bar/promo banner to match a user-attached reference image, plus a follow-up comment to remove the greeting) → PR #161 — **could not actually view the reference screenshot** (see process/environment finding below); removed the greeting entirely regardless (that instruction didn't depend on the image) and made a text-description-only sizing pass.
  - **#140** (grocery: browse one store at a time like food) → PR #163, `GroceryScreen` split into a store-list screen + new `GroceryStoreScreen` store-scoped catalog, mirroring food's restaurant-list→menu pattern; no schema change.
  - **#141** (pharmacy: same store-selection restructuring, was gated on #129 which merged last run) → PR #164, same pattern via a new `PharmacyStoreListScreen` + `pharmacy_stores`-scoped `PharmacyController`, plus a store-conflict cart guard mirroring grocery's.
  - All 6 agents correctly rebased onto each other's concurrent merges (`CartAppBarAction`/`showCartSnackBar` from #139/#138 got adopted into #140/#141's new screens rather than reverted) — no unresolved conflicts, no lost work.
- **Only #144 left unpicked from this batch** (picked up 2026-08-31, 16th run). #133/#134/#135 still blocked on #132 (`waiting-on-you`, unchanged).

**Process/environment finding, 15th run:** a GitHub issue-comment image attachment (`github.com/user-attachments/assets/...`) is **not fetchable from a dispatched agent's sandbox** — direct `curl` is blocked by the agent proxy (only allows repo-scoped GitHub API paths, not arbitrary `github.com` hosts) and `WebFetch` 404s (unauthenticated fetch against what resolves as a private-repo attachment). This is the second time this exact limitation has been hit (issue #143's own body already flagged a prior session hitting it when trying to attach the image in the first place) — treat any future issue that hinges on a user-attached screenshot as needing either the image pasted as inline issue text/markdown description, or a human to paste the relevant measurements/colors directly into the issue body, rather than expecting a dispatched agent to fetch the attachment URL itself.

## 2026-08-31 (16th run — single issue, queue otherwise still blocked)

- `waiting-on-you` re-checked first (#8/#16/#40/#74/#78/#79/#132) — all still only bot-authored comments (posted under the owner's own account or as `claude[bot]`, each carrying the Claude Code footer), no genuine human reply on any.
- Only **#144** was actionable (checkout field errors should show inline below each field everywhere, like pharmacy already does) — implemented and merged as **PR #166**. `DeliveryAddressCard` and the food/grocery checkout screens now set `errorText` per field instead of a generic bullet-list/banner, matching pharmacy's existing pattern; new widget tests added in `test/checkout_screen_test.dart`/`test/grocery_checkout_screen_test.dart`; 187/187 tests, `dart format`/`flutter analyze` clean.
- Assumption worth a second look: `FoodController.addressErrors`/`GroceryController.validateCheckout` still return plain `List<String>` messages (not pharmacy's keyed `Map<String,String>`) — each screen maps the known message strings to field keys locally instead of touching the controllers, to stay inside this task's presentation-only scope.
- #133/#134/#135 still blocked on #132; #128/#52/#29 still tracking-only. Nothing else eligible — stopped early after 1 issue.

## 2026-08-31 to 2026-09-03 (17th-26th runs — nothing eligible, queue unchanged)

- Ten consecutive runs each re-checked `waiting-on-you` (#8/#16/#40/#74/#78/#79/#132) via `get_comments`/`list_issues` — no genuine human reply landed on any across this entire span. #74's only non-bot comment throughout is a non-owner promotional post from `cekuu35`.
- #133/#134/#135 stayed blocked on #132 the whole span; #128/#52/#29 remained tracking-only. No `todo`-and-not-blocked issue existed in any of these runs.
- Nothing implemented in any of the 10 runs.

## 2026-09-03 to 2026-09-04 (27th-30th runs — nothing eligible, queue unchanged)

- Four consecutive runs each re-checked `waiting-on-you` (#8/#16/#40/#74/#78/#79/#132) via `get_comments` — no genuine human reply landed on any across this span. #74's only non-bot comment throughout is a non-owner promotional post from `cekuu35`.
- #133/#134/#135 stayed blocked on #132 the whole span; #128/#52/#29 remained tracking-only. No `todo`-and-not-blocked issue existed in any of these runs.
- Nothing implemented in any of the 4 runs.

## 2026-09-04 (31st-33rd runs — nothing eligible, queue unchanged)

- All three runs re-checked `waiting-on-you` via `get_comments` on all 7 (#8/#16/#40/#74/#78/#79/#132): every comment on all 7 is still agent-authored (owner-account-posted questions/informational follow-ups, `claude[bot]`'s own #79 comment, or `cekuu35`'s non-owner promotional comment on #74) — no genuine human reply on any.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work. `list_issues` for `todo`/`waiting-on-you` returned the exact same 13 issues as prior runs.
- Nothing implemented in any of the 3 runs.

## 2026-09-05 (34th-36th runs — nothing eligible, queue unchanged)

- All three runs re-checked `waiting-on-you` via `get_comments` on all 7 (#8/#16/#40/#74/#78/#79/#132): every comment on all 7 is still agent-authored (owner-account-posted questions/informational follow-ups, `claude[bot]`'s own #79 comment, or `cekuu35`'s non-owner promotional comment on #74) — no genuine human reply on any.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work. `list_issues` for `todo`/`waiting-on-you` returned the exact same 13 issues as prior runs.
- Nothing implemented in any of the 3 runs.

## 2026-09-06 (37th-41st runs — nothing eligible, queue unchanged)

- All five runs re-checked `waiting-on-you` via `get_comments` on all 7 (#8/#16/#40/#74/#78/#79/#132): every comment on all 7 is still agent-authored (owner-account-posted questions/informational follow-ups, `claude[bot]`'s own #79 comment, or `cekuu35`'s non-owner promotional comment on #74) — no genuine human reply on any.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work. No `todo`-and-not-blocked issue exists. `list_issues` for `todo`/`waiting-on-you` returned the same 13 issues as prior runs.
- Nothing implemented in any of the 5 runs.
