# Status Log

Reverse-chronological. Each session/major chunk of work gets an entry.

**Terse means terse, enforced literally (added 2026-08-13 after this file's own entries broke the rule)**: 1-4 short bullet points per task, not paragraphs. Point at where full detail already lives (an issue number, `Audit Findings.md`, `Decisions Log.md`, git history) rather than re-explaining it here. This file is an index, not a second copy of the record.

**Archive when this file passes ~150 lines or ~2 weeks of entries**: move everything older than the most recent ~2 weeks into `vault/archive/Status Log <YYYY-MM>.md`, leave a one-line pointer at the bottom. Whoever's finishing a task and notices the file has grown past that point should just do it, not wait to be asked. **Consolidate long runs of identical "nothing eligible" entries into one merged block even within the 2-week window** (done 2026-09-10, folding the 43rd-56th runs together) — the per-run detail isn't worth the line count once a dozen runs in a row say the exact same thing.

---

## 2026-09-14 (70th run — mass backlog unlock, 6 old audit issues merged)

- **Human approved a large batch of long-dormant `needs-approval` issues to `todo` at ~11:27 UTC today** (between the 69th run's check and this one): #10, #13, #14, #15, #17, #18, #19, #31, #36, #37, #41, #42, #44, #45, #46, #47, #48, #49 — the original 2026-08-12/2026-08-14 audit batches that had sat gated this whole time. #34 re-checked first (`waiting-on-you`) — still no human reply to the schema-dump request from the 67th run, stays blocked.
- **Processed the 6 oldest actionable issues from the newly-unlocked batch** (all from the 2026-08-12 audit pass, all unambiguous — no clarification needed), 5 dispatched in parallel as `isolation:"worktree"` background agents, #14 held back and dispatched only after #13 merged since both touch `lib/features/profile/presentation/profile_screen.dart`:
  - **#10** (settings screen: 9 dead tap targets, toggles don't persist) → PR #205. Real email/phone from `profile_repository.dart`; notification toggles now persisted via new `SharedPreferences`-backed `NotificationPreferencesRepository`; Change Password already wired (issue #39 shipped); Language/Currency/Theme → non-interactive "Coming soon" rows (no backend exists); About Us → new minimal static bottom sheet; Privacy Policy/Terms left as "Coming soon" placeholders (tracked separately by blocking issue #37, not built here).
  - **#13** (no profile-edit capability anywhere) → PR #204. New `ProfileRepository.updateProfile({firstName, lastName, phone})` (scoped to `auth.currentUser.id`, relies on existing owner RLS policy) + new `EditProfileScreen`/`ProfileEditController`, reachable via a new edit icon on `ProfileScreen`, new protected route `/profile/edit`. Avatar editing explicitly out of scope (no Storage plumbing to reuse cheaply).
  - **#14** (hardcoded `$120.50` wallet balance duplicated in `profile_screen.dart`, independent of the now-real `wallet_screen.dart`) → PR #207. Profile screen's balance row now reads from the same `WalletRepository.fetchBalance()` wallet_screen.dart uses, formatted via `AppMoney.formatCents` — no more second hardcoded literal. Also removed the dead 'Coupons & Offers' row (no backing feature anywhere) and wired 'Notifications' to the Settings screen (real toggles as of #10 this same run).
  - **#15** (onboarding: no first-launch gating, dead standalone `/onboarding/*` routes) → PR #203. New `SharedPreferencesOnboardingPreferences`/`OnboardingLaunchGate` persists "hasSeenOnboarding"; router redirects a returning signed-out user away from `/welcome`; dead `AppRoutes.onboardingOne/Two/Three` removed entirely (fully redundant with `WelcomeScreen`'s own PageView, nothing ever navigated to them).
  - **#17** (no CI/CD enforcing format/analyze/test on PRs) → PR #202. New `.github/workflows/ci.yml`, pinned actions, runs the exact three `AGENTS.md` DoD commands on every PR and push to `master`. **Manual follow-up for the owner**: mark the new `verify` check as required in branch-protection settings — it exists and fails correctly but nothing yet blocks a merge on red until that's turned on.
  - **#18** (grocery/pharmacy cart screens had zero widget tests; duplicated test fixture setup) → PR #206. Added `test/grocery_cart_screen_test.dart`/`test/pharmacy_cart_screen_test.dart` (13 new tests, golden path + edge cases); extracted shared `test/helpers/controllers.dart` and refactored 10 test files off hand-copied setup onto it. (Checkout screens already had coverage from an earlier PR since the issue was filed — only the cart screens were still actually gapped.)
- All 6 merged clean onto `master` (each agent re-merged `master` into its branch and re-ran the full DoD when a concurrent sibling landed first — happened repeatedly since all 6 ran close together), all DoD checks (`dart format`, `flutter analyze`, `flutter test`) actually run and green throughout; final full-suite count after all 6: **283/283**. No Supabase/migration changes in any of the six.
- **Archived this file's 13th-15th run entries (2026-08-30) to `vault/archive/Status Log 2026-08.md`** per this file's own ~150-line threshold.
- **Next up, oldest-first from the newly-unlocked batch**: #19 (ActivityController hand-rolled ChangeNotifier vs. Riverpod/AsyncNotifier convention), then #31/#36/#37/#41/#42/#44/#45/#46/#47/#48/#49 (2026-08-14 audit batch — not yet triaged for ambiguity this run). #34 still `waiting-on-you`/blocked; #74 still blocked on #34. #132/#133/#134/#135 still correctly not board-worker-pickable. #29/#52/#128/#176 remain tracking-only.
- Stopped after 6 issues per the routine's own per-run cap.

## 2026-09-14 (69th run — nothing eligible, queue unchanged)

- `list_issues` for `todo`/`waiting-on-you` matched the 68th run's end state exactly: `waiting-on-you` holds only #34, `get_comments` shows still just the bot's own request-for-schema comment, no human reply. `todo` still just #74 (blocked on #34 landing), #132 (needs human kickoff)/#133/#134/#135 (blocked on #132), and tracking-only #29/#52/#128/#176.
- Nothing implemented this run.

## 2026-09-14 (68th run — 2026-09-12 audit batch cleared, #177-181 all merged)

- Processed the 5 remaining fresh 2026-09-12 audit-batch issues (all unambiguous, no clarification needed), oldest-first, batch-1 (#177/#179/#181, disjoint files) dispatched in parallel then batch-2 (#178/#180, both touch `grocery_controller.dart`/`pharmacy_controller.dart`) sequentially to avoid conflicts:
  - **#177** → PR #199: restored `ListView.builder`/`SliverList.builder` in `grocery_screen.dart`/`grocery_store_screen.dart`/`pharmacy_store_list_screen.dart` (reverted by PR #163/#164); added store-scoped `GroceryCatalogRepository.fetchStore(storeId)` + `GroceryController.loadStore`, mirroring pharmacy's existing pattern; new `test/list_virtualization_test.dart` pins it (verified failing against the pre-fix code first).
  - **#179** → PR #198: `SecureSessionStorage.initialize()` now migrates the legacy pre-#7 plaintext `SharedPreferences` session (`sb-<project-ref>-auth-token`, key derived from the configured Supabase URL) into secure storage if none exists yet, then unconditionally deletes the legacy key; 9 new tests in `test/secure_session_storage_test.dart`.
  - **#181** → PR #197: `super_app_home_screen.dart`'s screen-wide `AnimatedBuilder` narrowed to a new `_RecentActivitySection` widget wrapping just the Recent Activity preview; pure refactor, no behavior change. Issue also named a header notification badge as needing scoping — that field doesn't exist in current code, nothing to do there.
  - **#178** → PR #200: `confirm_order_flow.dart`'s `confirmDemoOrder` now binds `on Object catch (error, stackTrace)` (was silently discarding it) and `onSaveFailed` widened to `T Function(Object, StackTrace)`, mirroring `LoadableState.runLoad`'s `onError`; all three vertical controllers now `debugPrint` the error, fallback strings unchanged. This was the deliberate carve-out #40's PR #191 (67th run) left for this issue. New `test/confirm_order_flow_test.dart`.
  - **#180** → PR #201: lifted the byte-identical cart write-queue helper out of all three controllers into a shared `CartWriteQueue`/`readCartLogged()` in `lib/services/shared/data/cart_storage.dart` — the write side is now actually guarded (previously `write()` itself was unguarded inside the queue) and both write and read failures are `debugPrint`-logged instead of silently dropped/mapped to an empty cart. New `test/cart_storage_test.dart` (8 tests).
- All 5 merged clean onto `master`, all DoD checks (`dart format`, `flutter analyze`, `flutter test`) actually run and green for each (final full-suite count after all 5: 238/238). No Supabase/migration changes in any of the five.
- **This clears the entire 2026-09-12 audit batch.** Only #176 remains from it, tracking-only (no direct work). Full per-issue detail (exact diffs, empirical verification steps, line numbers) is in each PR's own body — not re-derived here.

## 2026-09-14 (67th run — 5 issues merged, #34 paused again)

- Processed 6 issues oldest-first: **#34** (core tables missing migration) found genuinely blocked — no live Supabase credentials/CLI link exist in any board-worker sandbox, and the proxy blocks arbitrary outbound hosts (confirmed via direct `curl` to the project's own REST host, got a 403 from the proxy tunnel — same class of restriction as the earlier user-attachment-image finding). Commented asking the owner to run `supabase db pull`/`pg_dump --schema-only` locally and paste the output, or provide a read-only connection string; relabeled `waiting-on-you`. **#34 and #40 were both found stale-labeled `agent-in-progress` at run start with no branch/PR/vault trace of real work** — treated as a labeling artifact, not real in-progress work; see [[Multi-Agent Setup]] gotcha added this run.
- **#40** (global error handling) → PR #191, **#59** (checkout idempotency) → PR #192, **#60** (pricing/fee single source of truth) → PR #193, **#82** (grocery delivery-window race) → PR #194, **#78** (shared `delivery_addresses` platform layer, owner's 2026-09-13 decision) → PR #195 — all merged clean, all DoD checks actually run and green. Each of #59/#60/#82/#78 redefined the same three `place_*_order` RPCs one after another (dispatched sequentially, never in parallel, specifically because of this shared-file overlap) using the drop-then-recreate-plus-restate-ACL pattern from issue #136's postmortem — `supabase/migrations/20260917000000_add_shared_delivery_addresses.sql` is now the authoritative definition for all three. Full per-issue detail (schema shapes, Dart changes, explicit scope exclusions) is in each PR's own body — not re-derived here.
- **None of the 5 new migrations have been applied to any live/production database** — each PR flags its own `supabase db push` as a manual follow-up, per convention.
- **Next up, oldest-first**: #74 (RLS enable) still blocked, depends on #34. The rest of the 2026-08-15 audit batch that was `todo`-and-unblocked is now cleared. Real next candidates were the fresh 2026-09-12 batch (#177-181) — see the 68th run entry above, all five cleared same-day.

## 2026-09-13 (66th run — big backlog reload, 6 issues merged + Flutter SDK fix)

- **Mass human reply/approval session happened today** (all comments timestamped ~2026-09-13T17:10-17:41 UTC): the owner answered every long-blocked `waiting-on-you` question in one pass and relabeled all of them back to plain `todo` (no `waiting-on-you` left) — #3 (live DB check for `profiles` columns), #8 (currency: standardize on integer cents, live-checked `menu_items.price` is decimal), #9 (remove rewards feature entirely, no backend), #12 (remove payment-methods entry point, gated on #30), #16 (`com.zivo.app` identifier), #30 (cash-on-delivery-only, add `payment_method`/`payment_status` columns), #40 (Firebase Crashlytics, land SDK-independent half first), #74 (approved #34 so the RLS fix can proceed after it), #78 (shared `delivery_addresses` table + fulfilment-snapshot columns, clean-break no backfill), #132 (merchant app: same-repo, `com.zivo.merchant`, but **still explicitly not board-worker-pickable** — the owner's own comment reaffirms "no subagent owns creating a brand-new top-level app... needs a human to scope/kick off" even with `todo` on it). This ended the 25-run "nothing eligible" streak (43rd through 65th run) — see the consolidated blocks below it for that whole stretch.
- **Environment finding: this session's container had no Flutter/Dart SDK installed at all** (`flutter`/`dart` not on PATH or anywhere on disk) — a first, not previously seen in this vault's history of runs that all claimed real `dart format`/`flutter analyze`/`flutter test` output. Manually installed Flutter to `/opt/flutter` and symlinked into `/usr/local/bin` (works for both the main session and worktree-isolated dispatched agents, since they share the same container/filesystem). Also found `.tool-versions`' pinned `flutter 3.41.9` **cannot actually run `pub get`** on this project — `flutter_native_splash ^2.4.8` needs `meta ^1.18.0`, 3.41.9's bundled `flutter_test` only ships `meta 1.17.0`. Fixed by bumping to `3.47.4` (latest stable, satisfies the project's own `flutter: ">=3.41.9"` floor) and landed a `.claude/hooks/session-start.sh` (registered via new `.claude/settings.json`) that auto-installs Flutter for every future session — merged as **PR #188**. **If a future run finds Flutter missing again, check whether this hook actually fired (`SessionStart` hooks require `.claude/settings.json` to be present in the checkout) before re-doing the manual install.**
- **Processed 6 issues, strict oldest-`todo`-first, all dispatched as `isolation:"worktree"` background agents (three at a time once file-scope disjointness was checked), all merged clean, no lost work**:
  - **#3** → PR #182: `schema.sql`/`database_diagram.md` `profiles.full_name` → `firstname`/`lastname`, matching the live-DB check quoted in the issue.
  - **#8** → PR #185 (the big one): new migration converts `menu_items.price`, `grocery_products.unit_price`, `pharmacy_products.unit_price`, and every `food_orders`/`grocery_orders`/`pharmacy_orders`(+`_items`) money column from `numeric` decimal-dollars to `integer` cents; rewrote all three `place_*_order` RPCs to compute entirely in cents; every Dart money field (`MenuItem`, cart controllers, `ActivityItem.amount`, `WalletTransactionRecord.amount`) changed `double`→`int` cents with a new `AppMoney.formatCents()` display helper. `orders`/`cart_items` were already dead (dropped by #75 earlier); `wallet_transactions` was already integer cents, left alone. **Migration not yet applied to production** — needs a manual `supabase db push`.
  - **#9** → PR #183: deleted `lib/features/rewards/` entirely (screens/models/widgets), its two routes, and the profile-screen nav entry; left generic non-functional "rewards" prose (onboarding/login copy) untouched.
  - **#12** → PR #186: deleted the fake `lib/screens/payment_methods.dart`, its route, and its profile-screen nav entry (gated on #30's cash-on-delivery decision); wallet's own separate real payment-method feature untouched.
  - **#16** → PR #184: `com.example.chowflow` → `com.zivo.app` across Android/iOS/macOS/Linux (Windows has no equivalent identifier field, only incidental placeholder text cleaned); iOS/macOS `RunnerTests` → `com.zivo.app.RunnerTests`. Web manifest/index.html already had real Zivo copy from an earlier issue, nothing to change there. Android debug APK build **not** verified — no Android SDK in this environment.
  - **#30** → PR #187: new migration adds `payment_method`/`payment_status` (small `check`-constrained enums) to all three order tables, defaulting to `cash_on_delivery`/`pending_collection`; `place_*_order` RPCs set them explicitly; all three checkout screens show a non-interactive "Cash on delivery" line; `track_order_screen.dart` shows a new Payment card. **Migration not yet applied to production.**
  - All 6 verified via the now-working `dart format`/`flutter analyze`/`flutter test` before merging; no PR needed conflict resolution since each agent branched from a freshly-fetched `master` right before starting and file scopes were kept disjoint by design (checked overlaps — e.g. #9/#12 both touch `lib/app/app_router.dart`+`app_routes.dart`+`profile_screen.dart` — before deciding sequencing/parallelism).
- **Next up (not yet picked, oldest-first)**: #34 (core tables missing migration, now approved), #40 (crash reporting SDK-independent half), #59, #60, #74 (RLS, depends on #34 landing first), #78 (shared platform layer), #82. #132/#133/#134/#135 still correctly not board-worker-pickable (see above). #29/#52/#128/#176 remain tracking-only. #177-181 (new 2026-09-12 audit batch) not yet triaged for ambiguity.
- Stopped after 6 issues per the routine's own per-run cap (plus the one infra PR, which doesn't count against it).

## 2026-09-12 (64th-65th runs — nothing eligible, queue unchanged)

- `list_issues` for `todo`/`waiting-on-you` returned the same 13 issues as prior runs in both runs; `updated_at` on all 7 `waiting-on-you` issues (#8/#16/#40/#74/#78/#79/#132) unchanged since the 63rd run's check across both runs — re-verified by timestamp comparison only (no new comment landed, so no need to re-fetch comment bodies).
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work.
- Nothing implemented in either run.

## 2026-09-11 (61st-63rd runs — nothing eligible, queue unchanged)

- `list_issues` for `todo`/`waiting-on-you` returned the same 13 issues as prior runs in all three runs; `updated_at` on all 7 `waiting-on-you` issues (#8/#16/#40/#74/#78/#79/#132) unchanged since the 60th run's check, so no new comment landed on any across any of the three runs — skipped re-fetching comment bodies since the timestamp alone rules out a reply.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work.
- Nothing implemented in any of the three runs.

## 2026-09-10 (57th-60th runs — nothing eligible, queue unchanged)

- `list_issues` for `todo`/`waiting-on-you` returned the same 13 issues as prior runs in all four runs; `updated_at` on all 7 `waiting-on-you` issues (#8/#16/#40/#74/#78/#79/#132) unchanged since the 56th run's check, so no new comment (human or otherwise) landed on any across any of the four runs — skipped re-fetching comment bodies since the timestamp alone rules out a reply.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work.
- Also consolidated this file's own 43rd-56th run entries (14 near-identical "nothing eligible" entries) into one merged block below, per this file's own archive-threshold rule — line count had grown past the point where per-run detail was still worth carrying.
- Nothing implemented in any of the four runs.

## 2026-09-07 to 2026-09-09 (43rd-56th runs — nothing eligible, queue unchanged)

- Fourteen consecutive runs (43rd through 56th) each re-checked the `waiting-on-you` set (#8/#16/#40/#74/#78/#79/#132) — most via `get_comments`, some via an `updated_at` timestamp check against the prior run's already-confirmed state (sufficient on its own: an unchanged timestamp rules out a new comment without re-fetching bodies). Every comment on all 7 across the whole span remained agent-authored (owner-account-posted questions/informational follow-ups, `claude[bot]`'s own #79 comment, or `cekuu35`'s non-owner promotional comment on #74) — no genuine human reply landed on any of them.
- #133/#134/#135 stayed blocked on #132 the whole span; #128/#52/#29 remained tracking-only, no direct work. `list_issues` for `todo`/`waiting-on-you` returned the same 13 issues in every run.
- **Process fix (43rd run)**: found this file (`vault/Status Log.md`) had been stored on disk as a single line of base64 text (no line terminators, ~16KB) instead of plain markdown — some prior run's write path base64-encoded the content instead of writing it directly. Decoded it, verified the decoded content matched the expected reverse-chronological history, and rewrote the file as plain text. If a future run finds a vault note unreadable/garbled again, try `base64 -d` on it before assuming data loss — check `file <path>` for "ASCII text, with very long lines, with no line terminators" as the tell.
- Nothing implemented in any of the 14 runs.

## 2026-09-06 (37th-41st runs — nothing eligible, queue unchanged)

- All five runs re-checked `waiting-on-you` via `get_comments` on all 7 (#8/#16/#40/#74/#78/#79/#132): every comment on all 7 is still agent-authored (owner-account-posted questions/informational follow-ups, `claude[bot]`'s own #79 comment, or `cekuu35`'s non-owner promotional comment on #74) — no genuine human reply on any.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work. No `todo`-and-not-blocked issue exists. `list_issues` for `todo`/`waiting-on-you` returned the same 13 issues as prior runs.
- Nothing implemented in any of the 5 runs.

## 2026-09-05 (34th-36th runs — nothing eligible, queue unchanged)

- All three runs re-checked `waiting-on-you` via `get_comments` on all 7 (#8/#16/#40/#74/#78/#79/#132): every comment on all 7 is still agent-authored (owner-account-posted questions/informational follow-ups, `claude[bot]`'s own #79 comment, or `cekuu35`'s non-owner promotional comment on #74) — no genuine human reply on any.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work. `list_issues` for `todo`/`waiting-on-you` returned the exact same 13 issues as prior runs.
- Nothing implemented in any of the 3 runs.

## 2026-09-04 (31st-33rd runs — nothing eligible, queue unchanged)

- All three runs re-checked `waiting-on-you` via `get_comments` on all 7 (#8/#16/#40/#74/#78/#79/#132): every comment on all 7 is still agent-authored (owner-account-posted questions/informational follow-ups, `claude[bot]`'s own #79 comment, or `cekuu35`'s non-owner promotional comment on #74) — no genuine human reply on any.
- #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work. `list_issues` for `todo`/`waiting-on-you` returned the exact same 13 issues as prior runs.
- Nothing implemented in any of the 3 runs.

## 2026-09-03 to 2026-09-04 (27th-30th runs — nothing eligible, queue unchanged)

- Four consecutive runs each re-checked `waiting-on-you` (#8/#16/#40/#74/#78/#79/#132) via `get_comments` — no genuine human reply landed on any across this span. #74's only non-bot comment throughout is a non-owner promotional post from `cekuu35`.
- #133/#134/#135 stayed blocked on #132 the whole span; #128/#52/#29 remained tracking-only. No `todo`-and-not-blocked issue existed in any of these runs.
- Nothing implemented in any of the 4 runs.

## 2026-08-31 to 2026-09-03 (17th-26th runs — nothing eligible, queue unchanged)

- Ten consecutive runs each re-checked `waiting-on-you` (#8/#16/#40/#74/#78/#79/#132) via `get_comments`/`list_issues` — no genuine human reply landed on any across this entire span. #74's only non-bot comment throughout is a non-owner promotional post from `cekuu35`.
- #133/#134/#135 stayed blocked on #132 the whole span; #128/#52/#29 remained tracking-only. No `todo`-and-not-blocked issue existed in any of these runs.
- Nothing implemented in any of the 10 runs.

## 2026-08-31 (16th run — single issue, queue otherwise still blocked)

- `waiting-on-you` re-checked first (#8/#16/#40/#74/#78/#79/#132) — all still only bot-authored comments (posted under the owner's own account or as `claude[bot]`, each carrying the Claude Code footer), no genuine human reply on any.
- Only **#144** was actionable (checkout field errors should show inline below each field everywhere, like pharmacy already does) — implemented and merged as **PR #166**. `DeliveryAddressCard` and the food/grocery checkout screens now set `errorText` per field instead of a generic bullet-list/banner, matching pharmacy's existing pattern; new widget tests added in `test/checkout_screen_test.dart`/`test/grocery_checkout_screen_test.dart`; 187/187 tests, `dart format`/`flutter analyze` clean.
- Assumption worth a second look: `FoodController.addressErrors`/`GroceryController.validateCheckout` still return plain `List<String>` messages (not pharmacy's keyed `Map<String,String>`) — each screen maps the known message strings to field keys locally instead of touching the controllers, to stay inside this task's presentation-only scope.
- #133/#134/#135 still blocked on #132; #128/#52/#29 still tracking-only. Nothing else eligible — stopped early after 1 issue.

---

Entries older than 2026-08-31 (2026-08-12 through 2026-08-30: initial setup, first thorough audit pass, the routine-recreation/cleaning-removal/app-icons run, and the 13th-15th board-worker runs) archived to `vault/archive/Status Log 2026-08.md`. **Archived 2026-09-14 (70th run)** per this file's own ~150-line threshold. **Fixed 2026-08-29**: a prior archive attempt had added this pointer without actually removing the archived content, leaving a duplicate `## 2026-08-13` section and a split `## 2026-08-15` header sitting below it for ~2 weeks — cleaned up (merged the two 08-15 entries, dropped the duplicate 08-13 content, which was already safe in the archive file).
