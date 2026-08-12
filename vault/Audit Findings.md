# Audit Findings

Three passes so far: two on 2026-08-12, one deeper pass on 2026-08-13. Don't re-run any wholesale without reason — check [[Open Tasks]]/`gh issue list` first to see what's already tracked.

## Pass 1 — shallow (dead code + lint)

- **Fixed**: deleted `chowflow_flutter/chowflow_flutter/`, a stale duplicate Flutter project from an accidental double `flutter create` (stock counter-app template, unreferenced, untouched since initial commit).
- **Fixed**: deleted 2 unused widgets (`payment_method_card.dart`, `order_card.dart`) superseded by inline code.
- **Fixed**: extracted `cleaning_booking_screen.dart`'s 240-line `build()` into sub-widgets (moot now — `cleaning` is being removed).
- **Fixed**: replaced hardcoded `Color(0x...)` literals in `restaurant_screen.dart` with the `TwColors.slate900.withOpacityValue(...)` convention.
- `flutter analyze`: 0 issues (was already clean before this pass too).
- No unused dependencies in `pubspec.yaml`.
- Deferred, not done: moving `lib/screens/`'s 5 leftover files into `lib/features/`, and the 38 outdated-dependency bumps. Low priority, no issue filed (user said skip both, not "later" — revisit only if asked).

## Pass 2 — deeper (security, tests, duplication, resilience)

**Security — mostly good news.** RLS is comprehensive and correctly scoped (no `USING (true)` on writes). Order-placement RPCs are well-hardened: server-derived `profile_id`, server-recomputed prices, `search_path` hardened, row-locking against oversell. No hardcoded secrets (the `sb_publishable_...` key in `main.dart` is the intended-public Supabase anon key). One real gap: **session/refresh-token stored in plaintext SharedPreferences** (SDK default, not consciously chosen) → issue #7.

**Test coverage.** Cart and grocery/pharmacy controller logic (math, stock limits, validation) is meaningfully tested. Gaps: **zero coverage of any checkout/order-placement failure path** (→ issue #5) and **`auth_service_test.dart` only covers the logged-out state** (→ issue #6).

**Duplication across food/grocery/pharmacy** (cleaning excluded — being removed). Three concrete instances: RPC-result-unwrap logic, load/error-state pattern, and confirm-order control flow, each copy-pasted 2-3x. Root cause: food has no controller like grocery/pharmacy do (checkout logic is inlined in the screen instead) → tracked as issue #4 (FoodController unification) in addition to the extraction work. **Extraction work was started same-day but interrupted mid-session (see [[Status Log]] 2026-08-12) — check `lib/services/shared/` and whether `grocery_controller.dart`/`pharmacy_controller.dart` actually use it before assuming this is done.**

**Error handling.** Repositories let exceptions propagate (correct — idiomatic), callers catch at the boundary and show loading/error/retry states consistently. Minor nit: `on Object catch` is broad, masks real bugs as generic messages — not filed as an issue, low priority.

**Feature gaps found (not bugs, product decisions)**:
- Wallet screen is entirely hardcoded/fake, doesn't touch the real `wallet_transactions` table → issue #1.
- Food checkout never collects/sends a real delivery address (grocery/pharmacy do) → issue #2.

**Docs drift**: `supabase/schema.sql`/`database_diagram.md` disagree with the Dart client on `profiles`' name column (`full_name` vs `firstname`/`lastname`), and no migration defines either — meaning there's no ground truth in-repo to check against. Also missing 19 tables the migrations actually create. Needs someone to check the live DB → issue #3 (`needs-clarification`, not `todo` — can't be resolved by an agent alone).

## Pass 3 — deep, 2026-08-13 (five parallel agents + a real running-app check)

Prompted by the user directly challenging whether a "good look" had actually happened (it hadn't, fully — see [[Status Log]] 2026-08-12 for the admission). This pass covered: agent-system reconciliation (`.codex`/AGENTS.md vs `.claude`), a proper currency/schema deep-dive, native platform configs + `lib/platform/`, every previously-unaudited feature vertical, a full test-suite read, and — new this pass — actually launching the app (Flutter web via a scratch Playwright setup, no project skill existed for this yet) and screenshotting it rather than relying only on static analysis.

**Release-blocking bug, found and fixed immediately**: `android/app/src/main/AndroidManifest.xml` had no `INTERNET` permission — only the debug/profile manifest overlays had it. A release Android build would have had zero network access, meaning every Supabase call fails. Fixed same-session.

**Currency/schema drift — resolved from "documented claim" to "verified, precise finding"** (issue #8, comment added): the repo has two internally inconsistent SQL currency conventions — `schema.sql` (old, `integer` cents, matches CLAUDE.md) vs. migrations since `20260727152319_connect_super_app_services.sql` (new, `numeric(12,2)` dollars, violates CLAUDE.md on the SQL side too). Most old-convention tables are dead code (nothing queries them). `menu_items.price` is the one live crossing point — Dart treats it as dollar-scale `double` with no cents conversion, and circumstantial evidence (test fixtures, RPC fee/tax literals) strongly suggests the live DB isn't actually integer cents despite `schema.sql`'s claim. Still needs a live DB check to close definitively. Issue #3 (profiles column drift) confirmed still fully live and unaffected by the big superapp commit — likely the same root cause (`schema.sql` is generally unreliable), noted as such via a comment linking the two issues.

**A misdiagnosis, corrected — see [[Decisions Log]] 2026-08-13**: one investigating agent concluded AGENTS.md's repository-authority claim was itself wrong. It wasn't — the agent checked the outer local folder instead of the actual repo root, the exact `chowflow_flutter/`-prefix trap already documented in [[Conventions]]. No fix was needed there.

**Six new "looks-done-but-isn't" feature gaps found**, same category as wallet (#1)/food-address (#2), all filed as separate `todo` issues rather than auto-built (product decisions):
- Rewards screen — entirely fake, worse than wallet (zero data layer at all) → #9
- Settings screen — 9 dead tap targets, toggles don't persist → #10
- Addresses screen — fully non-functional, linked from real checkout/profile → #11
- Payment methods screen — fully non-functional, linked from real flows → #12
- No profile-edit capability exists anywhere → #13
- Duplicated hardcoded wallet balance in profile screen, independent copy of the wallet finding → #14
- Onboarding has no first-launch gating, dead standalone `/onboarding/*` routes → #15

**Other issues filed**: native bundle IDs still `com.example.chowflow` everywhere despite "Zivo" branding, needs a rebrand pass before store submission → #16. No CI/CD anywhere, nothing enforces the verification sequence automatically on PRs → #17. Grocery/pharmacy cart & checkout screens have zero widget tests, plus duplicated test fixture setup across 5 files → #18. `ActivityController` is a hand-rolled `ChangeNotifier` singleton, not the stated Riverpod/AsyncNotifier convention → #19.

**Fixed directly this pass** (mechanical, low-risk): the INTERNET permission bug; dead code (`app_widgets.dart` — `FireSunGradientButton`/`PremiumCard`/`ZivoChip`/`GlassmorphContainer`, ~half the file, verified zero usages; `AppMoney.country` unused field; a dead commented-out import in `app_cards.dart`); renamed `test/widget_test.dart` → `test/categories_screen_test.dart` (was testing `CategoriesScreen`, not generic boilerplate); fixed `ActivityController.load()` to log the real exception instead of silently discarding it; rewrote `chowflow_flutter/README.md`'s stale sections (project structure, dependency list, "Known Issues: None," pre-backend-integration framing); added stale-warning banners to all 6 outer `eatzy/*.md` docs (not deleted — they're the user's local files, just flagged so a future session doesn't follow them); adopted the 3-question clarification cap and explicit task-brief schema from AGENTS.md into `.claude/skills/build/SKILL.md`; explicitly declared `pubspec.yaml`/`pubspec.lock`/native platform shells as unowned-by-subagents, orchestrator-handles-directly in the `/build` scope table.

**Live-app verification — partial, honestly reported**: the app was actually launched (Flutter web, port 8765) and screenshotted — it boots and renders the real welcome screen correctly, not just passes static analysis. Could not get further: the specific screens this pass wanted to visually check (restaurant detail post-color-refactor, cleaning booking post-decomposition) are behind auth, and this sandbox can't reach Supabase's network to sign in. Explicitly did **not** claim to have visually verified those two refactors — only that the app launches cleanly. No project skill existed yet for running this app; one could be generated via `/run-skill-generator` if this becomes a repeated need.

**Not done this pass, still open**: reconciling the remaining `.codex`/AGENTS.md process gaps beyond the 3-question cap and task-brief schema (a read-only quality-reviewer-equivalent agent, a stated concurrency cap) — noted but not built, since adding a new agent role is a bigger structural decision than a mechanical fix.
