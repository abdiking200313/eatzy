# Status Log

Reverse-chronological. Each session/major chunk of work gets an entry.

**Terse means terse, enforced literally (added 2026-08-13 after this file's own entries broke the rule)**: 1-4 short bullet points per task, not paragraphs. Point at where full detail already lives (an issue number, `Audit Findings.md`, `Decisions Log.md`, git history) rather than re-explaining it here. This file is an index, not a second copy of the record.

**Archive when this file passes ~150 lines or ~2 weeks of entries**: move everything older than the most recent ~2 weeks into `vault/archive/Status Log <YYYY-MM>.md`, leave a one-line pointer at the bottom. Whoever's finishing a task and notices the file has grown past that point should just do it, not wait to be asked. **Consolidate long runs of identical "nothing eligible" entries into one merged block even within the 2-week window** (done 2026-09-10, folding the 43rd-56th runs together) — the per-run detail isn't worth the line count once a dozen runs in a row say the exact same thing.

---

## 2026-09-14 (issue #177 — grocery/pharmacy list virtualization restored, grocery catalog read scoped)

- Restored `ListView.builder`/`SliverList.builder` in the three screens PR #163/#164 had flattened back to eager `ListView(children:[...])`/`Column(children:[...])`: `grocery_screen.dart`, `grocery_store_screen.dart`, `pharmacy_store_list_screen.dart` (the last one rebuilt as `CustomScrollView` + `SliverList.builder`, since it never had a builder version to revert to). Empirically confirmed with a throwaway probe test that the real regression was specifically a `Column` nested inside a scrollable (500/500 rows built eagerly) — a flat `ListView(children:[...])` was already lazy on its own; the pharmacy screen's `_buildStoreList`/`_buildFilteredStoreList` used the eager nested-`Column` shape.
- Added `GroceryCatalogRepository.fetchStore(storeId)` (store- and product-scoped, mirrors `PharmacyCatalogRepository.fetchProducts(storeId: ...)`) and `GroceryController.loadStore`/`hasLoadedStore`; `GroceryStoreScreen` now calls this instead of the unscoped `load()`/`fetchStores()` (up to 30 stores × 300 products) just to render one store. Updated the stale `grocery_repository.dart` comment that had claimed no "selected store" concept existed (issue #140 added one).
- New `test/list_virtualization_test.dart` pins virtualization for all three screens; verified by temporarily swapping back the pre-fix pharmacy file and confirming that exact test fails against it (found `Pharmacy 299` built when it shouldn't be), then restored the fix.
- Rebased onto the 2026-09-13/14 board-worker batch that landed underneath (notably #60's `GroceryProduct.unitPrice` `double`→`int`-cents change, which needed one test literal fixed); 227/227 tests, `dart format`/`flutter analyze` clean. PR: see `agent/issue-177-grocery-catalog-virtualization`.

## 2026-09-14 (67th run — 5 issues merged, #34 paused again)

- Processed 6 issues oldest-first: **#34** (core tables missing migration) found genuinely blocked — no live Supabase credentials/CLI link exist in any board-worker sandbox, and the proxy blocks arbitrary outbound hosts (confirmed via direct `curl` to the project's own REST host, got a 403 from the proxy tunnel — same class of restriction as the earlier user-attachment-image finding). Commented asking the owner to run `supabase db pull`/`pg_dump --schema-only` locally and paste the output, or provide a read-only connection string; relabeled `waiting-on-you`. **#34 and #40 were both found stale-labeled `agent-in-progress` at run start with no branch/PR/vault trace of real work** — treated as a labeling artifact, not real in-progress work; see [[Multi-Agent Setup]] gotcha added this run.
- **#40** (global error handling) → PR #191, **#59** (checkout idempotency) → PR #192, **#60** (pricing/fee single source of truth) → PR #193, **#82** (grocery delivery-window race) → PR #194, **#78** (shared `delivery_addresses` platform layer, owner's 2026-09-13 decision) → PR #195 — all merged clean, all DoD checks actually run and green. Each of #59/#60/#82/#78 redefined the same three `place_*_order` RPCs one after another (dispatched sequentially, never in parallel, specifically because of this shared-file overlap) using the drop-then-recreate-plus-restate-ACL pattern from issue #136's postmortem — `supabase/migrations/20260917000000_add_shared_delivery_addresses.sql` is now the authoritative definition for all three. Full per-issue detail (schema shapes, Dart changes, explicit scope exclusions) is in each PR's own body — not re-derived here.
- **None of the 5 new migrations have been applied to any live/production database** — each PR flags its own `supabase db push` as a manual follow-up, per convention.
- **Next up, oldest-first**: #74 (RLS enable) still blocked, depends on #34. The rest of the 2026-08-15 audit batch that was `todo`-and-unblocked is now cleared. Real next candidates are the fresh 2026-09-12 batch, not yet triaged for ambiguity: #177, #178 (note: #40's PR #191 deliberately left `confirm_order_flow.dart`'s error swallow for this issue rather than fixing it inline), #179, #180, #181. #176/#128/#52/#29 remain tracking-only; #132/#133/#134/#135 remain not-board-worker-pickable.
- **#179** (pre-#7 plaintext session never migrated/deleted) → separate interactive-session fix, PR pending. `SecureSessionStorage.initialize()` now migrates the legacy `sb-<project-ref>-auth-token` `SharedPreferences` entry into secure storage (only if secure storage has no session yet) and unconditionally deletes the legacy key afterward — key derived from the configured Supabase URL (`Uri.parse(url).host.split('.').first`), not hardcoded. Added a `LegacySessionStore` seam (real impl backed by `SharedPreferencesAsync`, fake in tests) so the migration is unit-testable without a platform mock; `main.dart` now passes its Supabase URL into `SecureSessionStorage(supabaseUrl: ...)`. 9 tests in `test/secure_session_storage_test.dart`, full suite (224 tests) green, `flutter analyze` clean.

## 2026-09-14 (issue #181 — scope home-screen ActivityController rebuilds)

- `super_app_home_screen.dart`'s single screen-wide `AnimatedBuilder` (wrapping the whole `Scaffold`) replaced with a small `_RecentActivitySection` `StatelessWidget` that wraps just the Recent Activity preview in its own `AnimatedBuilder`, following the `GroceryCartBadgeAction`/`PharmacyCartBadgeAction` narrow-listener pattern — header/promo/service-grid/popular-restaurants now build once per screen build instead of on every `ActivityController` notification.
- **Deviation from the issue text**: the issue described a header `notificationCount` badge as a second thing needing scoping, but the current code has no such field — `_HomeHeader`'s notification icon is a static `IconButton` with an empty `onNotifications: () {}` and never reads `ActivityController`. Left as-is (out of scope: no new behavior/visual change); only the Recent Activity section actually depended on the controller.
- Pure refactor, no behavior/visual change. 218/218 tests pass (including all 4 `super_app_home_test.dart` cases), `flutter analyze` clean, `dart format` clean. PR: see this entry's follow-up or check `gh pr list` for `agent/issue-181-scope-home-screen-rebuilds`.

## 2026-09-14 (issue #178 — bind order-placement errors in the shared checkout flow)

- `confirm_order_flow.dart`'s `confirmDemoOrder` now catches `on Object catch (error, stackTrace)` (was a bare `on Object` that discarded the exception) and widened `onSaveFailed` from `T Function()` to `T Function(Object error, StackTrace stackTrace)`, mirroring `LoadableState.runLoad`'s existing `onError` signature per the issue's own suggestion.
- Updated all three call sites (`food_controller.dart`, `grocery_controller.dart`, `pharmacy_controller.dart`) to `debugPrint` the error/stack trace (matching `ActivityController.load`'s existing pattern), preserving each vertical's existing user-facing fallback string unchanged. No RPC-specific error-code-to-message mapping attempted (no existing infra for it in the client, and the issue scoped that out as a nice-to-have only if cheap) — this was the deliberate carve-out #40's PR #191 had already flagged as left for this issue (see the 67th-run entry above).
- New `test/confirm_order_flow_test.dart` unit-tests `confirmDemoOrder` in isolation: error/stack-trace pass-through to `onSaveFailed`, the success path (`onConfirmed`/`recordActivity`/`clearCart`), and the invalid-validation short-circuit. Existing `food_controller_test.dart` failure-path test still passes and now visibly prints the logged error during the run.
- 230/230 tests pass, `flutter analyze` clean, `dart format --set-exit-if-changed` clean. PR: `agent/issue-178-bind-order-placement-errors`.

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
