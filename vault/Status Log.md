---
tags: [history, log]
summary: Reverse-chronological session log for cross-session and cross-agent continuity; archived monthly once large.
status: append-only
upstream_concept: 00-Index
---

# Status Log

Reverse-chronological. Each session/major chunk of work gets an entry.

**Terse means terse, enforced literally (added 2026-08-13 after this file's own entries broke the rule)**: 1-4 short bullet points per task, not paragraphs. Point at where full detail already lives (an issue number, `Audit Findings.md`, `Decisions Log.md`, git history) rather than re-explaining it here. This file is an index, not a second copy of the record.

**Archive when this file passes ~150 lines or ~2 weeks of entries**: move everything older than the most recent ~2 weeks into `vault/archive/Status Log <YYYY-MM>.md`, leave a one-line pointer at the bottom. Whoever's finishing a task and notices the file has grown past that point should just do it, not wait to be asked.

---

## 2026-09-01 (18th run — nothing eligible, queue unchanged)

- `waiting-on-you` re-checked (#8/#16/#40/#74/#78/#79/#132): still no genuine human reply on any. #40's comment shows an `updated_at` of 2026-08-31 (a day after its `created_at`) but the content is unchanged and reads as the bot's own original clarifying question with just the attribution footer stripped — verified directly via `get_comments`, not a human edit.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work. No `todo`-and-not-blocked issue exists.
- Nothing implemented this run — stopped early, no eligible work.

## 2026-08-31 (17th run — nothing eligible, queue unchanged)

- `waiting-on-you` re-checked (#8/#16/#40/#74/#78/#79/#132): still no genuine human reply on any. #74 carries a promotional third-party comment (user `cekuu35`, `author_association: NONE`, not the repo owner, pitching a paid audit-kit product) — not an owner reply, doesn't unblock anything.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work. No `todo`-and-not-blocked issue exists.
- Nothing implemented this run — stopped early, no eligible work.

## 2026-08-31 (16th run — single issue, queue otherwise still blocked)

- `waiting-on-you` re-checked first (#8/#16/#40/#74/#78/#79/#132) — all still only bot-authored comments (posted under the owner's own account or as `claude[bot]`, each carrying the Claude Code footer), no genuine human reply on any.
- Only **#144** was actionable (checkout field errors should show inline below each field everywhere, like pharmacy already does) — implemented and merged as **PR #166**. `DeliveryAddressCard` and the food/grocery checkout screens now set `errorText` per field instead of a generic bullet-list/banner, matching pharmacy's existing pattern; new widget tests added in `test/checkout_screen_test.dart`/`test/grocery_checkout_screen_test.dart`; 187/187 tests, `dart format`/`flutter analyze` clean.
- Assumption worth a second look: `FoodController.addressErrors`/`GroceryController.validateCheckout` still return plain `List<String>` messages (not pharmacy's keyed `Map<String,String>`) — each screen maps the known message strings to field keys locally instead of touching the controllers, to stay inside this task's presentation-only scope.
- #133/#134/#135 still blocked on #132; #128/#52/#29 still tracking-only. Nothing else eligible — stopped early after 1 issue.

## 2026-08-30 (15th run — fresh-audit-pass batch cleared)

- **`waiting-on-you` re-checked first, no change**: #8/#16/#40/#78/#132 re-checked via `get_comments` — still only agent-authored comments, no genuine human reply on any. #74 unchanged (still blocked on #34's approval, per the 13th/14th run finding). #79's most recent comment is already this bot's own informational follow-up from the 14th run (posted after #131 merged) — nothing new to act on there, correctly left open per the human's own earlier instruction to leave it tracking until confirmed.
- **Processed all 6 remaining oldest `todo` issues from the #137-144 fresh-audit batch**, strict oldest-first, all dispatched as parallel `isolation: "worktree"` background agents from clean `master` (`a8d6529`), all merged:
  - **#138** ("Added to cart" snackbar used Flutter's plain 4s default, inconsistent wording/styling across 5 call sites) → PR #162. New shared `showCartSnackBar(context, message)` helper in `lib/widgets/app_misc.dart` — `SnackBarBehavior.floating`, ~1.8s duration, rounded shape, inset margin, existing `TwColors`/`TwSpacing`/`TwRadius` tokens. All 5 call sites (food's restaurant/cart screens, grocery's screen/cart screen, pharmacy's catalog screen) switched over, each site's own message-text logic preserved untouched. Verified via Flutter's own `Scaffold` source that a floating SnackBar's auto-lift-above-FAB/bottom-nav is independent of `margin`, so one shared style is safe everywhere including the food FAB screen. 164/164 tests.
  - **#139** (cart icon inconsistent: grocery/pharmacy had a small outline `IconButton`+default `Badge`, food had no AppBar icon at all and used a bottom FAB instead) → PR #160. New shared `CartAppBarAction` widget (`lib/widgets/cart_app_bar_action.dart`) — 44×44 filled chip in the vertical's soft accent color, solid icon, accent-colored count badge shown only when non-empty. Food's competing bottom FAB removed since the issue explicitly disallows two entry points on one screen.
  - **#142** (Recent Activity section cramped) → PR #159, `TwSpacing.rhythmTight`/`x3` → `x4` on the home screen.
  - **#143** (resize search bar/promo banner to match a user-attached reference image, plus a follow-up comment to remove the greeting) → PR #161 — **could not actually view the reference screenshot** (see process/environment finding below); removed the greeting entirely regardless (that instruction didn't depend on the image) and made a text-description-only sizing pass.
  - **#140** (grocery: browse one store at a time like food) → PR #163, `GroceryScreen` split into a store-list screen + new `GroceryStoreScreen` store-scoped catalog, mirroring food's restaurant-list→menu pattern; no schema change.
  - **#141** (pharmacy: same store-selection restructuring, was gated on #129 which merged last run) → PR #164, same pattern via a new `PharmacyStoreListScreen` + `pharmacy_stores`-scoped `PharmacyController`, plus a store-conflict cart guard mirroring grocery's.
  - All 6 agents correctly rebased onto each other's concurrent merges (`CartAppBarAction`/`showCartSnackBar` from #139/#138 got adopted into #140/#141's new screens rather than reverted) — no unresolved conflicts, no lost work.
- **Only #144 left unpicked from this batch** (picked up 2026-08-31, 16th run). #133/#134/#135 still blocked on #132 (`waiting-on-you`, unchanged).

**Process/environment finding, 15th run**: a GitHub issue-comment image attachment (`github.com/user-attachments/assets/...`) is **not fetchable from a dispatched agent's sandbox** — direct `curl` is blocked by the agent proxy (only allows repo-scoped GitHub API paths, not arbitrary `github.com` hosts) and `WebFetch` 404s (unauthenticated fetch against what resolves as a private-repo attachment). This is the second time this exact limitation has been hit (issue #143's own body already flagged a prior session hitting it when trying to attach the image in the first place) — treat any future issue that hinges on a user-attached screenshot as needing either the image pasted as inline issue text/markdown description, or a human to paste the relevant measurements/colors directly into the issue body, rather than expecting a dispatched agent to fetch the attachment URL itself.

## 2026-08-30 (14th run — merchant chain kickoff + blocking checkout fix)

- Processed #123 (merged, PR #152), #129 (merged, PR #151), #130 (merged, PR #153), #131 (merged, PR #154, also resolves #79's fulfilment-path question), #132 (**paused `waiting-on-you`** — issue's own text says it needs human scoping before pickup, asked the 3 questions the issue itself raises), #136 (merged, PR #157 — a real production-breaking bug, food checkout was broken for every user, now fixed), #137 (merged, PR #156).
- **#133/#134/#135 skipped**, all depend on #132. Merchant chain now blocked at #132 until the human answers the same-repo-vs-separate-repo question.

## 2026-08-30 (13th run — big backlog reload)

- The "nothing eligible" streak was stale — between the last run and this one the human approved/filed a large new batch: a 7-issue merchant self-service epic (#128 tracking + #129-135), 9 new small UI/bug issues (#137-144, plus #122/#123 approved to `todo`), and 5 older `todo`-without-`waiting-on-you` issues (#38, #43, #73, #74, #81).
- Processed 6 issues oldest-first: #38→PR #145, #73→PR #146, #81→PR #148, #122→PR #147, #43→PR #149, all merged; #74 found genuinely blocked (depends on issue #34, not itself `todo`-approved) and relabeled `waiting-on-you`.
- **#79 got a real human reply this run** (no bot footer) redirecting its fulfilment-model question to the new #128/#131 decision — left `waiting-on-you` as-is since the actual implementation lands via #131.
- #16/#40/#78 still no human reply.

---

Entries older than 2026-08-16 (2026-08-12 through 2026-08-15: initial setup, first thorough audit pass, and the routine-recreation/cleaning-removal/app-icons run) archived to `vault/archive/Status Log 2026-08.md`. **Archived 2026-08-30 (15th run)** per this file's own ~150-line threshold (it had grown to 291 lines). **Fixed 2026-08-29**: a prior archive attempt had added this pointer without actually removing the archived content, leaving a duplicate `## 2026-08-13` section and a split `## 2026-08-15` header sitting below it for ~2 weeks — cleaned up (merged the two 08-15 entries, dropped the duplicate 08-13 content, which was already safe in the archive file).
