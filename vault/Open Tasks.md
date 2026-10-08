---
tags: [tasks, github, cache]
summary: Quick-reference cache of open GitHub issues; source of truth is always gh issue list, this file can lag behind it.
status: cache
upstream_concept: 00-Index
---

# Open Tasks

**Updated 2026-10-08 (board worker, later run)** — re-check before relying on this for anything that matters. **Source of truth is always a live `list_issues`/`gh issue list --repo abdiking200313/eatzy --state open` call.**

## Update, 2026-10-08 (board worker, later run) — RN Phase 0 smoke test effectively cleared; two sessions ran it concurrently

- **#346-350 all merged**, **#351 (the last Phase 0 issue) is `agent-in-progress`** under a *different* concurrently-running session — not touched this run, re-check its real state (branch/PR vs. still just a label) fresh next time rather than assuming either way. Full detail, including exactly which PRs/issues collided and how each was reconciled, in [[Status Log]] 2026-10-08 "RN Phase 0 smoke test cleared".
- **New, unlabeled issue** [#441](https://github.com/abdiking200313/eatzy/issues/441) (`app.config.ts` nested `.ts` import breaks `expo config`/`expo-doctor`/`expo install`, likely `eas build` too) — filed by the concurrent session, not yet `needs-approval` or anything else. Worth the user's attention; it'll keep blocking `expo install <pkg>` in `react_native_app/` until fixed.
- **Not this routine's call**: whether to approve more of the batch (Phases 1-10, ~69 issues) now that Phase 0 has gone through real dispatches end to end and surfaced one genuine bug (#441) rather than failing outright. Leave `needs-approval` alone per the standing instruction below until the user decides.
- The pre-existing 6 blocked/tracking issues (#29, #52, #55, #276, #278, #301) reconfirmed unchanged a 19th+ time — same Docker-daemon/no-human-reply blockers as every prior run.

## Update, 2026-10-08 (interactive session) — Phase 0 of the React Native migration approved as a smoke test

- **#346-351 (all 6 `react_native_app/` Phase 0 issues) relabeled `needs-approval` → `todo`** — see [[Decisions Log]] 2026-10-08. These are now board-worker-eligible and should route through `/build-rn` + `rn-*` agents per [[Conventions]] "App label rules", not the Flutter `/build` flow.
- **The other 69 issues of the batch (Phases 1-10) stay `needs-approval` deliberately** — this is an explicit smoke test of brand-new, never-dispatched automation. Do not bulk-approve the rest just because a run finds the queue otherwise empty; wait for Phase 0 to actually clear cleanly first.
- Next board-worker run should pick these up oldest-first (#346 first) same as any other `todo` issue — no special-casing needed beyond the label-based routing already documented.
- The pre-existing 6 blocked/tracking issues (#29, #52, #55, #276, #278, #301) are unchanged — still blocked on sandbox Docker/macOS limitations, see the entries below.

## Update, 2026-10-08 (board worker, 3rd run) — nothing eligible, same 6 blockers reconfirmed an eighteenth time

- Eligibility check: identical 6 `todo` issues as every prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. PR #303 stays open/unmerged (`mergeable_state: unknown`, base still `b51c385`, well behind current `master`). #278 stays blocked on #276.
- **#55**: re-checked `get_comments` directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`6cf20ce`, PR #434) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, eighteenth no-op run in a row.**

## Update, 2026-10-08 (board worker, 2nd run) — nothing eligible, same 6 blockers reconfirmed a seventeenth time

- Eligibility check: identical 6 `todo` issues as every prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. PR #303 stays open/unmerged, base still well behind current `master`. #278 stays blocked on #276.
- **#55**: re-checked `get_comments` directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`3e18588`, PR #433) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, seventeenth no-op run in a row.**

## Update, 2026-10-08 (board worker, 1st run) — nothing eligible, same 6 blockers reconfirmed a sixteenth time

- Eligibility check: identical 6 `todo` issues as every prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. #278 stays blocked on #276.
- **#55**: re-checked `get_comments` directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`83ffa87`, PR #432) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, sixteenth no-op run in a row.**

## Update, 2026-10-07 (board worker, 4th run) — nothing eligible, same 6 blockers reconfirmed a fifteenth time

- Eligibility check: identical 6 `todo` issues as every prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. #278 stays blocked on #276.
- **#55**: re-checked `get_comments` directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`246c773`, PR #431) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, fifteenth no-op run in a row.**

## Update, 2026-10-07 (board worker, 3rd run) — nothing eligible, same 6 blockers reconfirmed a fourteenth time

- Eligibility check: identical 6 `todo` issues as every prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. #278 stays blocked on #276.
- **#55**: re-checked `get_comments` directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`dcfe0b0`, PR #430) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, fourteenth no-op run in a row.**

## Update, 2026-10-07 (board worker, 2nd run) — nothing eligible, same 6 blockers reconfirmed a thirteenth time

- Eligibility check: identical 6 `todo` issues as every prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. #278 stays blocked on #276.
- **#55**: re-checked `get_comments` directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`3744c01`, PR #429) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, thirteenth no-op run in a row.**

## Update, 2026-10-07 (board worker, 1st run) — nothing eligible, same 6 blockers reconfirmed a twelfth time

- Eligibility check: identical 6 `todo` issues as every prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. PR #303 stays open/unmerged (`mergeable_state: unknown`, no new activity since 2026-10-03). #278 stays blocked on #276.
- **#55**: re-checked `get_comments` directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#301**: re-read directly — still explicitly blocked on #276/#278 (the only two of #276–#299 still open).
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`cd65949`, PR #428) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, twelfth no-op run in a row.**

## Update, 2026-10-06 (board worker, 6th run) — nothing eligible, same 6 blockers reconfirmed an eleventh time

- Eligibility check: identical 6 `todo` issues as the prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. #278 stays blocked on #276.
- **#55**: re-checked its comments directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`89bc89d`, PR #427) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, eleventh no-op run in a row.**

## Update, 2026-10-06 (board worker, 5th run) — nothing eligible, same 6 blockers reconfirmed a tenth time

- Eligibility check: identical 6 `todo` issues as the prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. PR #303 stays open/unmerged. #278 stays blocked on #276.
- **#55**: re-checked its comments directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`9a98d10`, PR #426) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, tenth no-op run in a row.**

## Update, 2026-10-06 (board worker, 4th run) — nothing eligible, same 6 blockers reconfirmed a ninth time

- Eligibility check: identical 6 `todo` issues as the prior run (#29, #52, #55, #276, #278, #301). `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. PR #303 stays open/unmerged. #278 stays blocked on #276.
- **#55**: re-checked its comments directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`1d9cf21`, PR #425) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, ninth no-op run in a row.**

## Update, 2026-10-06 (board worker, 3rd run) — nothing eligible, same 6 blockers reconfirmed an eighth time

- Eligibility check: identical 6 `todo` issues as the prior run (#29, #52, #55, #276, #278, #301), same `updated_at` on every one. `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (still v29.8.2), still no running daemon (`/var/run/docker.sock` absent, `docker info` fails to connect) — same confirmed blocker, re-verified directly. PR #303 stays open/unmerged. #278 stays blocked on #276.
- **#55**: re-checked its comments directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`9d832cf`, PR #424) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, eighth no-op run in a row.**

## Update, 2026-10-06 (board worker, 2nd run) — nothing eligible, same 6 blockers reconfirmed a seventh time

- Eligibility check: identical 6 `todo` issues as the prior run (#29, #52, #55, #276, #278, #301), same `updated_at` on every one. `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (now v29.8.2, up from v29.6.2), still no running daemon (`/var/run/docker.sock` absent, `docker ps` fails to connect) — same confirmed blocker, re-verified directly. PR #303 stays open/unmerged. #278 stays blocked on #276.
- **#301**: re-read directly — still explicitly blocked on #276-#299 all closing per its own body; #276/#278 are the only two of that range still open.
- **#55**: re-checked its comments directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the prior run's own vault-update commit (`ab6e886`, PR #423) since that run — no new work that changes eligibility.
- **Net result: 0 issues processed, seventh no-op run in a row.**

## Update, 2026-10-06 (board worker, 1st run) — nothing eligible, same 6 blockers reconfirmed a sixth time

- Eligibility check: identical 6 `todo` issues as the 5th run (#29, #52, #55, #276, #278, #301), same `updated_at` on every one. `waiting-on-you` still empty.
- **#276/#278**: Docker CLI present (v29.6.2), still no running daemon (`/var/run/docker.sock` absent, `docker ps` fails to connect) — same confirmed blocker. PR #303 stays open/unmerged. #278 stays blocked on #276.
- **#55**: re-checked its comments directly — still only the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the 5th run's own vault-update commit (`bcf34cc`, PR #422) since the 5th run — no new work that changes eligibility.
- **Net result: 0 issues processed, sixth no-op run in a row.**

## Update, 2026-10-05 (5th run) — nothing eligible, same 6 blockers reconfirmed a fifth time

- Eligibility check: identical 6 `todo` issues as the 4th run (#29, #52, #55, #276, #278, #301), same `updated_at` on every one.
- **#276/#278/#301**: Docker CLI present (v29.6.2), still no running daemon (`/var/run/docker.sock` absent) — same confirmed blocker. #278/#301 stay blocked on #276.
- **#55**: re-checked its one comment directly — still the bot's own 2026-10-04 comment, no human reply since.
- **#29/#52**: tracking-only, unchanged.
- `master` gained only the 4th run's own vault-update commit (`7d89028`) plus one unrelated owner commit ignoring stray root-level build artifacts (`69ead72`, PR #345) — no new work that changes eligibility.
- **Net result: 0 issues processed, fifth no-op run in a row.**

## Update, 2026-10-05 (4th run) — nothing eligible, same 6 blockers; major repo restructure found and logged

- Eligibility check: identical 6 `todo` issues as the 3rd run (#29, #52, #55, #276, #278, #301), same `updated_at` on every one.
- **Big non-issue finding**: `master` picked up a direct owner-driven monorepo restructure since the 3rd run (`flutter_app/` now holds the Flutter app, new `react_native_app/` scaffolded) — not reflected anywhere in this vault before now. Logged in [[Architecture]] "Repo root" and [[Multi-Agent Setup]] (stale `.claude/agents/*.md` scope paths, stray untracked build artifacts at the old root). Doesn't change any of the 6 issues' eligibility — see below.
- **#276/#278**: still no running Docker daemon (confirmed again). PR #303 additionally now has a base 36+ commits behind current `master` (predates the restructure) — will need a rebase whenever it's eventually mergeable, but moot while the Docker blocker holds.
- **#55**: re-checked its one comment directly — still the bot's own 2026-10-04 comment, no human reply since. Same blocker (Linux sandbox, no Xcode/CocoaPods).
- **#301**: still blocked on #276/#278 per its own body. **#29/#52**: tracking-only, unchanged.
- **Net result: 0 issues processed, fourth no-op run in a row** — but worth the extra investigation time this run since the restructure was a real, previously-unlogged change.

## Update, 2026-10-05 (3rd run) — nothing eligible, all 6 blockers reconfirmed a third time, 0 issues processed

- Eligibility check: identical 6 `todo` issues as the 2nd run (#29, #52, #55, #276, #278, #301), same `updated_at` timestamps on every one — nothing changed since that run.
- **#276/#278**: Docker CLI present, no running daemon — same confirmed blocker. PR #303 stays open/unmerged.
- **#55**: still a Linux sandbox, no iOS tooling — same blocker.
- **#301**: still blocked on #276/#278 per its own body.
- **#29/#52**: tracking-only, unchanged.
- `master`'s only new commit since the 2nd run was that run's own vault-update commit (`83c3b65`, PR #335) — no new issue landed that changes eligibility.
- **Net result: 0 issues processed, third no-op run in a row.**

## Update, 2026-10-05 (2nd run) — nothing eligible, all 6 blockers reconfirmed again, 0 issues processed

- Eligibility check: identical 6 `todo` issues as the 1st run today, same `updated_at` timestamps on every one (#29, #52, #55, #276, #278, #301) — confirms literally nothing changed since that run logged its findings. `waiting-on-you` still empty.
- **#276/#278**: re-checked Docker directly — CLI present (`docker info` shows client v29.6.2), still no running daemon (`/var/run/docker.sock` absent). Same confirmed blocker. PR #303 stays open/unmerged, no new comment (nothing changed since the last confirmation). #278 stays blocked on #276.
- **#55**: this sandbox is Linux (`uname -a`), no `pod`/`xcodebuild` on `PATH` — same blocker as every prior run, not re-attempted.
- **#301**: still blocked on #276/#278 per its own body, neither moved.
- **#29/#52**: tracking-only, unchanged.
- `master`'s only new commit since the 1st run today is that run's own vault-update commit (`ae69167`, PR #334) — no new issue landed that changes eligibility.
- **Net result: 0 issues processed, queue fully unchanged for the second run in a row.** Cost only the cheap eligibility query plus the same three targeted re-checks (Docker, platform/iOS tooling, master HEAD) — no subagent dispatch needed.

## Update, 2026-10-05 (1st run) — nothing eligible, all 6 blockers reconfirmed, 0 issues processed

- Eligibility check: same 6 `todo` issues as the 2026-10-04 4th run's end state — #29, #52, #55, #276, #278, #301. `waiting-on-you` empty.
- **#276/#278**: Docker still has no running daemon in this sandbox (`docker info` — CLI present, `/var/run/docker.sock` absent) — same blocker as every prior check. PR #303 stays open/unmerged, no new comment (nothing changed since the last confirmation). #278 stays blocked on #276.
- **#55**: re-read the issue — still 1 comment, no new human reply since PR #332's partial fix. Remaining work (real `Podfile`/`Podfile.lock` via `flutter build ipa`, a real `DEVELOPMENT_TEAM`) still needs macOS/Xcode/CocoaPods + an Apple Developer Team ID, none available in this (Linux) sandbox. Not re-attempted, per the existing note in this file.
- **#301**: still blocked on #276/#278 per its own body; not re-checked further since neither of its blockers moved.
- **#29/#52**: tracking-only, no direct work, unchanged.
- Master had advanced (`b51c385` → `f152ba9`) since PR #303's base, but the added commits are entirely the already-logged 2026-10-04 4th-run work (#32/#222/#298/#55-partial + that run's own vault-update commit) — no new issue landed that changes eligibility.
- **Net result: 0 issues processed, queue fully unchanged.** This run cost only the cheap eligibility query plus three targeted re-checks (Docker socket, PR #303, issue #55) — no subagent dispatch needed since nothing was actionable.

## Update, 2026-10-04 (4th run) — #32/#222/#298 merged, #55 partial, #276/#278/#301 still blocked

- Eligibility check found the queue had grown since the last logged run: **#32, #55, #222** (previously `needs-approval`, off-limits in every prior entry below) are now `todo` — the owner approved them at some point between runs, outside this routine. Combined with the already-known #276/#278/#298/#301 and tracking-only #29/#52, that's 9 eligible issues.
- **#222** (hardcoded Windows JDK path) → PR #329, merged. Trivial one-line deletion, no agent dispatch needed.
- **#32** (Android release signing) → PR #330, merged. Wired `signingConfigs["release"]` to read `android/key.properties` (gitignored) when present, falling back to debug signing otherwise; added `android/SIGNING.md` + `key.properties.example`. **Deliberately did not generate a real keystore** — doing so in a disposable sandbox risks permanent loss of the one credential that can never be regenerated; that step needs the owner on their own machine. See SIGNING.md.
- **#298** (CI android-build job) → PR #331, merged, **after** #222 (explicit dependency in its own body). New `android-build` job actually ran and passed on the PR itself (Temurin 17 + `flutter build apk --debug`) — proof the job works, not just that it was added.
- **#55** (iOS build never verified) → PR #332, merged, but **issue left open, not closed**. Confirmed this sandbox has no `pod`/CocoaPods and no Xcode (Linux), so the real blocker — generating `ios/Podfile`/`Podfile.lock` via an actual `flutter build ipa`, and setting a real `DEVELOPMENT_TEAM` — needs a Mac + an Apple Developer Program Team ID, neither available here. Did the safe static-only part instead: `CODE_SIGN_IDENTITY` modernized from deprecated `"iPhone Developer"` → `"Apple Development"` (3 build configs), `Info.plist` gained `ITSAppUsesNonExemptEncryption=false`. Commented on the issue with exactly what's done vs. what needs a human on a Mac.
- **#276** re-checked a 5th+ time: still no running Docker daemon in any sandbox so far (`docker info` shows the CLI but no socket) — PR #303 stays open/unmerged, no new comment posted since nothing changed from the last confirmation. **#278** stays blocked on #276 (explicit dependency).
- **#301**: per its own "stop and comment, don't touch files" instruction, checked #276-#299 and commented listing #276/#278/#298 as the still-open blockers (at the time of checking; #298 merged minutes later this same run, so only #276/#278 block it now). Did not touch any files.
- **Net result: 3 issues closed (#32, #222, #298), 1 partial (#55, stays open with a clear status comment), #276/#278/#301 stay blocked on the same sandbox/dependency chain.** 7 issues touched this run (slightly over the nominal 6-issue cap, since #276/#278/#301 were quick re-checks/comments rather than full implementation cycles).

## Update, 2026-10-04 (3rd run) — nothing eligible, same blockers rechecked, one new unlabeled issue noted

- Eligibility check found the same 6 `todo` issues as the prior run minus #288 (closed last run): #29, #52, #276, #278, #298, #301. `waiting-on-you` empty.
- **#276** re-checked: still no running Docker daemon in this sandbox (confirmed again) — PR #303 stays open/unmerged. **#278** stays blocked on #276. **#298** stays blocked on #222, which is still `needs-approval`. **#301** still not ready.
- **New: #300** is open but has no `todo`/`waiting-on-you`/`needs-approval` label — same as #11, outside the board worker's protocol until a human labels it.
- Net result: 0 issues moved this run.

## Update, 2026-10-04 (later run) — #288 merged (PR #326 was already sitting ready), rest still blocked

- Eligibility check found only the same 7 `todo` issues as the prior run today (#29, #52, #276, #278, #288, #298, #301); `waiting-on-you` empty.
- **#288** carried `agent-in-progress` with a real, already-open PR #326 (not the stale-label pattern) — a prior session had implemented it (5 `Navigator.push` call sites routed through `go_router`, 575/575 tests) and left it unmerged. `mergeable_state: clean`, `verify` CI already green. Squash-merged directly, no new work needed. **#288 closed.**
- **#276** re-checked: this sandbox has the `docker` CLI but still no running daemon (`/var/run/docker.sock` absent) — same blocker as the prior run, confirmed a third time now. Still left open with PR #303 unmerged.
- **#278** stays blocked on #276 (unchanged). **#298** stays blocked on #222, which is still `needs-approval` (not yet approved by the owner) — re-checked directly, not just assumed from the vault. **#301** stays not-ready (explicitly waits on #276-299 all closing, and #276/#278 are still open).
- Only #29/#52 (tracking) had no direct work. **Net result: 1 issue closed (#288, via an already-ready PR), nothing else eligible.** Stopped well under the 6-issue cap since nothing else in the queue could move.
- **Gap noted**: a `list_issues` CLOSED/UPDATED_AT check found #287 and #289-297/#299 (the rest of the #276-301 audit batch) were all already closed between 12:08 and 16:34 UTC today, none of it logged in this vault — done by other sessions (interactive and/or earlier board-worker runs today) between the last logged entry and this one. Not re-derived in detail here since it's not this run's work; `git log`/`list_issues` is ground truth if it matters later.

## Update, 2026-10-04 — #282-286 merged, #280 closed, #276 blocked on a sandbox limitation

- Queue jumped from empty (just #29/#52) to 24 open `todo` issues since the last board-worker entry — a large new audit batch (#276-301) was filed and owner-approved directly between 2026-09-25 and 2026-10-03, outside this routine. Full detail on this run's work in [[Status Log]] 2026-10-04.
- **Merged**: #282 (PR #308), #283 (PR #307), #284 (PR #309), #285 (PR #306), #286 (PR #310). **Closed directly**: #280 (composition-root tracking issue — all 5 phases now merged).
- **Blocked, left open**: #276 — PR #303 exists (from a prior interactive session) but needs a `supabase db reset` replay neither that sandbox nor this one can run (no working Docker daemon; starting one by hand is refused as a Containment Escape). Commented on the issue; needs a human or a sandbox with real Docker. **#278 stays blocked on #276** (explicit dependency in its own issue body) — not yet picked up.
- Queue now 18 open `todo`/`waiting-on-you` issues (16 concrete + #29/#52 tracking). Oldest unpicked, next run: #276 (still blocked, re-check first)/#278 (still blocked on #276), then #287 ([High] Firebase Crashlytics), #288-299 (mix of medium/low UI/logic/infra cleanup), #301 (explicitly waits on #276-299 all closing, not ready).

## Update, 2026-09-25 (4th run) — nothing eligible, queue unchanged

- Same as the 2026-09-25 3rd run's end state (PR #271): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. `master` gained no new commits since PR #271 (vault update) merged — still at `90a391c`. Nothing implemented this run.

## Update, 2026-09-25 (3rd run) — nothing eligible, queue unchanged

- Same as the 2026-09-25 2nd run's end state (PR #270): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. `master` gained no new commits since PR #270 (vault update) merged — still at `08733a2`. Nothing implemented this run.

## Update, 2026-09-25 (2nd run) — nothing eligible, queue unchanged

- Same as the 2026-09-25 1st run's end state (PR #269): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. `master` gained no new commits since PR #269 (vault update) merged — still at `df073a5`. Nothing implemented this run.

## Update, 2026-09-25 (1st run) — nothing eligible, queue unchanged

- Same as the 2026-09-24 4th run's end state (PR #268): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. `master` gained no new commits since PR #268 (vault update) merged — still at `a889540`. Nothing implemented this run.

## Update, 2026-09-24 (4th run) — nothing eligible, queue unchanged

- Same as the 2026-09-24 3rd run's end state (PR #267): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. `master` gained only that 3rd run's own vault-update commit (`977cf53`) since PR #263 — no new work. Nothing implemented this run.

## Update, 2026-09-24 (3rd run) — nothing eligible, queue unchanged

- Same as the 2026-09-24 2nd run's end state (PR #263): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. `master` gained one new interactive-session commit since PR #263 merged (`f5c841d`, "Merchant photo uploads, store logos, and grocery/pharmacy item pages") — not picked up, no open issue tracks it, consistent with the pattern of unrelated interactive commits noted on 2026-09-18/2026-09-20. Nothing implemented this run.

## Update, 2026-09-24 (2nd run) — nothing eligible, queue unchanged

- Same as the 2026-09-24 1st run's end state (PR #263): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. No new commits to `master` since PR #263 (vault update) merged. Nothing implemented this run.

## Update, 2026-09-24 (1st run) — nothing eligible, queue unchanged

- Same as the 2026-09-23 4th run's end state (PR #262): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. No new commits to `master` since PR #262 (vault update) merged. Nothing implemented this run.

## Update, 2026-09-23 (4th run) — nothing eligible, queue unchanged

- Same as the 2026-09-23 3rd run's end state (PR #261): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. No new commits to `master` since PR #261 (vault update) merged. Nothing implemented this run.

## Update, 2026-09-23 (3rd run) — nothing eligible, queue unchanged

- Same as the 2026-09-23 2nd run's end state (PR #260): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. No new commits to `master` since PR #260 (vault update) merged. Nothing implemented this run.

## Update, 2026-09-23 (2nd run) — nothing eligible, queue unchanged

- Same as the 2026-09-23 1st run's end state (PR #259): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. No new commits to `master` since PR #259 (vault update) merged. Nothing implemented this run.

## Update, 2026-09-23 (1st run) — nothing eligible, queue unchanged

- Same as every run since 2026-09-22's 4-issue batch: only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. No new commits to `master` since PR #258 (vault update) merged — `git log origin/master -1` still shows that commit. Nothing implemented this run.

## Update, 2026-09-22 (board worker, 4-issue run) — #249/#250/#251/#252 all processed and merged

- All 4 concrete `todo` issues from the owner's part-3 filing batch (same day) implemented and merged: #249→PR #253, #250→PR #256 (plus follow-up PR #257 for a route-wiring gap #250's dispatch correctly left out of its file scope), #251→PR #255, #252→PR #254. Full detail, including two new process gotchas (a curl/GitHub-substring sandbox block one dispatch couldn't work around, and a shared-scratchpad file collision between two worktree-isolated parallel dispatches), in [[Status Log]] 2026-09-22 "board worker — 4 issues processed".
- Queue back down to just tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. 6 open issues total, same shape as every prior "nothing eligible" run: #29/#52 (tracking), #32/#55/#222 (`needs-approval`, off-limits), #11 (unlabeled Addresses-screen bug, still outside the board worker's protocol).

## Update, 2026-09-22 (2nd run) — nothing eligible, queue unchanged

- Same as the 2026-09-22 1st run's end state (PR #246): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. Still 6 open issues total: #29/#52 (tracking), #32/#55/#222 (`needs-approval`, off-limits), #11 (unlabeled Addresses-screen bug, still outside the board worker's protocol). No new commits to `master` since PR #246 merged. Nothing implemented.

## Update, 2026-09-22 (1st run) — nothing eligible, queue unchanged

- Same as the 2026-09-21 3rd run's end state: only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. Still 6 open issues total: #29/#52 (tracking), #32/#55/#222 (`needs-approval`, off-limits), #11 (unlabeled Addresses-screen bug, still outside the board worker's protocol). No new commits to `master` since PR #245 merged. Nothing implemented.

## Update, 2026-09-21 (3rd run) — nothing eligible, queue unchanged

- Same as the 2026-09-20 2nd run's end state: only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. Still 6 open issues total: #29/#52 (tracking), #32/#55/#222 (`needs-approval`, off-limits), #11 (unlabeled Addresses-screen bug, still outside the board worker's protocol). No change to the queue since the last run. Nothing implemented.

## Update, 2026-09-20 (2nd run) — nothing eligible, queue unchanged

- Same as the 1st run's end state (PR #241): only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. Still 6 open issues total: #29/#52 (tracking), #32/#55/#222 (`needs-approval`, off-limits), #11 (unlabeled Addresses-screen bug, still outside the board worker's protocol). No new commits to `master` since PR #241 merged. Nothing implemented.

## Update, 2026-09-20 (1st run) — nothing eligible, queue unchanged

- Same as the 2026-09-19 end state: only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. Still 6 open issues total: #29/#52 (tracking), #32/#55/#222 (`needs-approval`, off-limits), #11 (unlabeled Addresses-screen bug, still outside the board worker's protocol). One unrelated interactive-session commit (`660cf69`, "merchant and admin fix with ui beterments") landed on `master`, not this routine.

## Update, 2026-09-19 — nothing eligible, only 6 open issues total

- Same as the 2026-09-18 5th run's end state: only tracking-only **#29/#52** in `todo`, `waiting-on-you` empty. Repo is down to 6 open issues total: #29/#52 (tracking), #32/#55/#222 (`needs-approval`, off-limits), and **#11** — which has neither `todo`, `waiting-on-you`, nor `needs-approval` on it (just domain + severity labels), so it's outside the board worker's protocol either way (not `todo`-approved, and the approval gate only ever *bars* `needs-approval`, it doesn't make an unlabeled issue eligible). Worth a human look since it reads like a real bug (non-functional Addresses screen) that simply has no process label — not touched this run.

## Update, 2026-09-18 (5th run) — nothing eligible

- Same as the 4th run's end state: only tracking-only **#29/#52** remain in `todo`, `waiting-on-you` empty, nothing implemented. One unrelated commit (admin role management) landed on `master` via an interactive session, not this routine — see [[Status Log]] 2026-09-18 "5th run" for detail.

## Update, 2026-09-18 (4th run) — new issue #236 filed, implemented, and merged same-run

- **#236** filed by the owner today at 16:57 UTC (immediately after testing #232's merchant-login unification) — a signed-in merchant/admin could still navigate directly to any customer route, only the login screens were blocked. Already `todo`-approved on filing (owner-authored). Implemented by `logic-agent`: `AppRouter.resolveRedirect` now blocks every non-`/merchant` location for a merchant/admin session (with a `/reset-password` carve-out, since there's no dedicated recovery-session flag to key off instead). New router tests added. DoD checks (`dart format`/`flutter analyze`/`flutter test`, 429/429) all green.
- **PR #237 merged** (squash), CI green. **#236 closed.**
- Queue otherwise unchanged: #29/#52 (tracking-only) remain, no direct work.

## Update, 2026-09-17 — #34 resolved by owner directly, #74 unblocked and merged

- **#34 closed by the owner** (2026-09-17, interactive session via the Supabase connector) — live DB had zero migrations ever applied; all 21 pending migrations applied live, RLS confirmed on via `get_advisors`. **Fixed the live DB only, no migration files added** — repo history still had zero RLS coverage for the tables #74 named.
- **#74 unblocked and merged as PR #230** — new migration enables RLS + adds public read policies for `restaurants`/`menu_items`/`item_categories`/`restaurant_locations`/`profiles`. `deals`/`deal_items` deliberately excluded (no migration/schema.sql ever references them, `fetchDeals` has no callers) — flagged as a same-class-as-#34 follow-up if the owner wants it resolved.
- **Queue is now down to #29/#52 only** (tracking-only umbrellas, no direct work) — the first time the `todo`/`waiting-on-you` queue has had zero blocked/waiting items since #34 was filed. Next run: re-check `list_issues` fresh, nothing else is currently known-eligible.

## Update, 2026-09-15 (75th run) — merchant self-service epic complete, #128 closed

- **#47 and #132 both merged** (PR #224, PR #225) — the interactive-session update below (post-74th-run) had made both actionable again; picked up as this run's first two issues, dispatched in parallel since their files are disjoint.
- **#132 landing unblocked #133/#134/#135** — all three processed the same run and merged: #133 (PR #226, store profile + catalog CRUD), #134 (PR #227, order queue/fulfillment — also closed a real RLS gap #131 had left open, see [[Status Log]]), #135 (PR #228, controller/screen test coverage).
- **#128 (tracking issue) closed directly** once all 7 children (#129-135) confirmed closed — same pattern as #21/#176. The entire merchant self-service feature (schema, RLS, RPCs, a whole second `merchant_app/` Flutter project, screens, tests) is now merged to `master`. Two remaining follow-ups noted on the closing comment: an unapplied migration batch needs a manual `supabase db push`, and RLS/RPC integration testing stays blocked on #81.
- **New process gotcha this run** (see [[Multi-Agent Setup]]): dispatching #47/#132 in parallel without `isolation: "worktree"` caused a real git HEAD race in the shared working directory — both agents self-detected and repaired it with no data loss, but future parallel dispatches should use `isolation: "worktree"` rather than relying on that. #133/#134/#135 were dispatched sequentially with worktree isolation afterward, no issues.

## Update, 2026-09-15 (interactive session, post-74th-run)

- **#132 is no longer human-only.** The owner reversed their own 2026-09-13 "needs a human to kick off" instruction — issue body rewritten to bake in the already-decided answers (same repo, `merchant_app/` at root, `com.zivo.merchant`) and drop the "flag for approver" framing entirely. Also added to [[Multi-Agent Setup]]: creating a new top-level Flutter project is orchestrator-owned (like `pubspec.yaml`/native shells already are), not something that needs a human. **Treat #132 as a normal `todo` pick from the next run onward** — #133/#134/#135 still wait on it actually landing (real dependency, not an approval gate).
- **#47 relabeled back to `todo`** (off `waiting-on-you`) — the owner created a Firebase project and committed `google-services.json`/`GoogleService-Info.plist` for both platforms. Scope narrowed to **Android only** in the issue body (Gradle plugin, `firebase_core`/`firebase_messaging`, FCM init, permission/toggle UI) — iOS explicitly deferred pending an Apple Developer account (same blocker as #55). Server-side FCM credentials still need the owner to set them directly as a Supabase edge-function secret, never pasted into an issue.
- **New issue filed: #222** (`needs-approval`) — `android/gradle.properties` hardcodes a Windows-only `org.gradle.java.home` path (from commit `9be3eac`), breaking `flutter build`/`run` for Android on any non-Windows machine. Not caught by CI (`verify` job never does a real Android build). Awaiting approval, not yet actionable.
- **#176 closed.** Its "zero sub-issues" reading from earlier was wrong — this repo doesn't use GitHub's formal sub-issue linking (confirmed #128 shows the same false-empty result despite #129-135 being real children), only "part of #N" text in each child's body. #176's actual findings — #177/#178/#179/#180/#181 — are all merged; closed it same as #21's precedent. **Lesson for future runs**: never treat `get_sub_issues`/`has_children` as authoritative for whether a tracking issue (#21/#29/#52/#128/#176-style) has real work under it — search issue bodies for "part of #N" instead.

## Current state as of the 74th run (2026-09-15)

- **Unchanged from the 73rd run** — no new issues filed/approved, no human reply on #34 (re-checked `get_comments`). See the update note above this section for what changed afterward in an interactive session.

## Current state as of the 73rd run (2026-09-15)

- **Unchanged from the 72nd run** — no new issues filed/approved, no human reply on #34 or #47. #132 re-confirmed still not board-worker-pickable despite `todo` (owner's own 2026-09-13 comment says so explicitly).

## Current state as of the 72nd run (2026-09-15)

- **This clears the entire 2026-08-14 audit batch.** `todo`-and-unblocked is now empty aside from tracking issues.
- **`waiting-on-you` holds #34** (core tables missing migration — still genuinely blocked, no live Supabase DB access exists in any board-worker sandbox, no human reply yet to the schema-dump request from the 67th run) **and now also #47** (push notifications — needs a real Firebase/APNs project with credentials that don't exist anywhere in this environment; asked the owner to either provide project config, authorize creating one, or scope down to just the client-side permission/toggle flow as a smaller first step). #74 still blocked on #34.
- **4 issues processed and merged this run**: #44 (PR #219, onboarding CDN-image hardening — found mostly already fixed by an earlier change, added `pubspec.yaml` `assets:` section + branded error fallback; could NOT bundle the actual replacement illustrations since `lh3.googleusercontent.com` is blocked by the sandbox's network policy, flagged as an owner follow-up), #45 (PR #218, bundled real Outfit `.ttf` files locally — `fonts.gstatic.com` IS reachable unlike the image CDN above — removed the `google_fonts` dependency entirely), #46 (PR #220, Android release minify/shrink/obfuscate + proguard-rules.pro + README docs — could not run an actual release build, no Android SDK and Google's Maven repo also proxy-blocked in this sandbox), #48 (PR #217, `allowBackup="false"`, confirmed #7's secure-storage fix already covers the session-token half). One issue (#49, web/PWA branding) handled directly without subagent dispatch since it was trivial — found already mostly fixed, only `manifest.json`'s theme colors were stale.
- **New environment finding**: the outbound proxy allowlist is asset-type-specific — `fonts.gstatic.com`/`fonts.googleapis.com` reachable, `lh3.googleusercontent.com` and Google's Maven/AGP repo both blocked. See [[Multi-Agent Setup]].
- **CI (`verify` check, issue #17) still not marked as a required branch-protection status** — unchanged, still needs a human to flip that GitHub setting.
- **Remaining `todo`, not yet actionable**: none outside the tables below — re-check `list_issues` next run in case new issues were approved or filed.
- **#132 now board-worker-pickable** (see the 2026-09-15 update note above) — pick it up like any other `todo` issue. #133/#134/#135 stay blocked until it actually lands.
- **Tracking-only, no direct work**: #29, #52, #128. #176 closed 2026-09-15 (see update note above) — its findings were already done, not empty as first thought.
- **Still not fixed, belongs with #34's eventual fix**: `supabase/seed.sql` inserts `profiles(full_name, ...)` but `schema.sql` defines `firstname`/`lastname`, no `full_name` — same drift class AGENTS.md already warns about.

---

**2026-08-31 (board worker, 16th run — one issue, queue otherwise still blocked)**: `waiting-on-you` re-checked first (#8/#16/#40/#74/#78/#79/#132) — all still only bot-authored comments (posted under the owner's own account or as `claude[bot]`, each carrying the Claude Code footer), no genuine human reply on any. Only **#144** was actionable (checkout field errors should show inline everywhere, like pharmacy) — implemented and merged as **PR #166**: `DeliveryAddressCard` and the food/grocery checkout screens now set `errorText` per field instead of a generic bullet-list/banner (pharmacy's existing pattern), new widget tests added in `test/checkout_screen_test.dart`/`test/grocery_checkout_screen_test.dart`, 187/187 tests passing, `dart format`/`flutter analyze` clean. Note: the issue's file paths were stale (food checkout moved to `lib/services/food/presentation/checkout_screen.dart` after a module consolidation) — the dispatched agent caught this via a merge conflict against a stale worktree cache, re-fetched, and rebuilt against current `master`. #133/#134/#135 still blocked on #132 (unanswered); #128/#52/#29 still tracking-only, no direct work. Nothing else eligible this run. Full detail in [[Status Log]] 2026-08-31 "16th run".

**2026-08-30 (board worker, 15th run — fresh-audit-pass batch cleared)**: `waiting-on-you` re-checked first (#8/#16/#40/#78/#132 — no human reply on any; #74/#79 also unchanged since their own last agent comment, #79's last comment is already this bot's own informational follow-up so nothing further to do there). Processed the 6 oldest actionable `todo` issues, all from the #137-144 fresh-audit batch, all dispatched as parallel worktree-isolated background agents from clean `master`, all merged: **#138** (inconsistent 4s default `SnackBar` on every add-to-cart) → PR #162, new shared `showCartSnackBar()` helper in `lib/widgets/app_misc.dart` (floating, ~1.8s, margined), all 5 call sites switched over. **#139** (cart icon inconsistent/easy-to-miss across verticals) → PR #160, new shared `CartAppBarAction` widget (filled chip, solid icon) in `lib/widgets/cart_app_bar_action.dart`; food's competing bottom FAB removed since the issue explicitly disallows two entry points on one screen. **#142** (Recent Activity section cramped) → PR #159, `TwSpacing.rhythmTight`/`x3` → `x4` on the home screen. **#143** (resize search bar/promo banner to match a user-attached reference image, plus a follow-up comment to remove the greeting) → PR #161 — **could not actually view the reference screenshot**, see the dedicated note below; removed the greeting entirely regardless (that instruction didn't depend on the image) and made a text-description-only sizing pass. **#140** (grocery: browse one store at a time like food) → PR #163, `GroceryScreen` split into a store-list screen + new `GroceryStoreScreen` store-scoped catalog, mirroring food's restaurant-list→menu pattern; no schema change. **#141** (pharmacy: same store-selection restructuring, was gated on #129 which merged last run) → PR #164, same pattern via a new `PharmacyStoreListScreen` + `pharmacy_stores`-scoped `PharmacyController`, plus a store-conflict cart guard mirroring grocery's. All 6 agents correctly rebased onto each other's concurrent merges (`CartAppBarAction`/`showCartSnackBar` from #139/#138 got adopted into #140/#141's new screens rather than reverted) — no unresolved conflicts, no lost work. **Only #144 left unpicked from this batch** (next run's first pick, now done — see 16th run above). #133/#134/#135 still blocked on #132 (`waiting-on-you`, unchanged). Full detail in [[Status Log]] 2026-08-30 "15th run".

**Process/environment finding, 15th run**: a GitHub issue-comment image attachment (`github.com/user-attachments/assets/...`) is **not fetchable from a dispatched agent's sandbox** — direct `curl` is blocked by the agent proxy (only allows repo-scoped GitHub API paths, not arbitrary `github.com` hosts) and `WebFetch` 404s (unauthenticated fetch against what resolves as a private-repo attachment). This is the second time this exact limitation has been hit (issue #143's own body already flagged a prior session hitting it when trying to attach the image in the first place) — treat any future issue that hinges on a user-attached screenshot as needing either the image pasted as inline issue text/markdown description, or a human to paste the relevant measurements/colors directly into the issue body, rather than expecting a dispatched agent to fetch the attachment URL itself.

**2026-08-30 (board worker, 14th run — merchant chain kickoff + blocking checkout fix)**: processed #123 (merged, PR #152), #129 (merged, PR #151), #130 (merged, PR #153), #131 (merged, PR #154, also resolves #79's fulfilment-path question), #132 (**paused `waiting-on-you`** — issue's own text says it needs human scoping before pickup, asked the 3 questions the issue itself raises), #136 (merged, PR #157 — a real production-breaking bug, food checkout was broken for every user, now fixed), #137 (merged, PR #156). **#133/#134/#135 skipped**, all depend on #132. Merchant chain now blocked at #132 until the human answers the same-repo-vs-separate-repo question. Full detail in [[Status Log]] 2026-08-30 "14th run".

**2026-08-30 (board worker, 13th run — big backlog reload)**: the "nothing eligible" streak below is now stale — between the last run and this one the human approved/filed a large new batch: a 7-issue merchant self-service epic (#128 tracking + #129-135, decided directly with the human, see #128's body for the shape), 9 new small UI/bug issues (#137-144, plus the two follow-ups #122/#123 from the 12th run got approved to `todo`), and 5 older `todo`-without-`waiting-on-you` issues that had been sitting unlabeled/not-yet-approved now show as plain `todo` (#38, #43, #73, #74, #81 — the deploy-readiness/#52-audit tail). Processed 6 issues oldest-first (strict FIFO per the routine, skipping only the pure tracking issues #29/#52/#128): #38→PR #145, #73→PR #146, #148 (#81), #147 (#122), #149 (#43), all merged; #74 found genuinely blocked (depends on issue #34, which itself isn't `todo`-approved) and relabeled `waiting-on-you` with a comment explaining the dependency. **#79 got a real human reply this run** (2026-08-30, no bot footer) redirecting its fulfilment-model question to the new #128/#131 decision — left `waiting-on-you` as-is since the actual implementation lands via #131, not #79 directly. #16/#40/#78 still no human reply. Full detail in [[Status Log]] 2026-08-30 "13th run".

**2026-08-30 (board worker, stale entries below)**: still nothing eligible to implement — `waiting-on-you` #8/#16/#40/#78/#79 all re-checked via `get_comments`, no human reply on any (still only the bot's own footer-marked comment(s)); the only remaining `todo`-without-`waiting-on-you` issues are the umbrella/tracking pair #29/#52 (no direct work). Closed #21 directly (not via PR/`Closes`) after confirming via `list_issues` that all 7 phase issues (#22-#28) are closed — it had been left open as stale bookkeeping since the 12th run. See [[Status Log]] 2026-08-30 "(later run)".

**12th run (2026-08-29, board worker)**: only one eligible issue existed — #28 (redesign phase 7/7 closeout sweep) — everything else in the `todo`/`waiting-on-you` queues was either still unanswered (`waiting-on-you` #8/#16/#40/#78/#79) or an umbrella/tracking issue with no direct work (#21/#29/#52). Implemented and merged as PR #121, closing #28 and, with it, all 7 phases of #21. Filed two small `needs-approval` follow-ups the sweep found but didn't fix: #122 (checkout address-form input styling) and #123 (`food_home_screen.dart` wrapper indirection). Full detail in [[Status Log]] 2026-08-29 "board worker, 12th run".

**Major update 2026-08-26 ~19:20 UTC**: the human approved a huge batch of previously-`needs-approval` issues — open `needs-approval` count dropped from ~57 to 14. This ended the 11-day queue stall (stuck since 2026-08-15). The board worker processed 6 issues in its 7th run and another 6 in its 8th run that day; see [[Status Log]] 2026-08-26 for full detail on both.

**9th run (2026-08-27, early UTC morning)**: processed the next 6 oldest `todo` issues, all from the #52 audit batch: #62/#63/#64/#65/#66/#67 → PRs #107/#110/#108/#106/#105/#109. All 6 dispatched as independent worktree-isolated background agents in parallel; all opened clean/mergeable PRs with full verification (`dart format`/`flutter analyze`/`flutter test`) passing. Two agents (#63, #67) hit the session's shared API rate limit mid-task and were resumed via `SendMessage` to the same agent id once the limit reset — both picked up from their in-progress worktree state rather than restarting, see [[Status Log]] 2026-08-27 for detail. **New process note**: nested subagents spawned via the top-level `Agent` tool do NOT themselves have access to a further `Agent`/`Task` tool — all 6 agents independently reported this and implemented directly instead of fanning out to `ui-agent`/`logic-agent`/etc., while still respecting each role's declared file scope by hand. See [[Multi-Agent Setup]] for the implication this has on how `/build`-flow dispatch actually nests.

**10th run (2026-08-27, later UTC morning)**: processed the next 6 oldest `todo` issues (all from the #52 audit batch, the last of the ones not gated by `needs-approval`): #68/#69/#70/#71/#72/#75 → PRs #115/#111/#116/#114/#112/#113. Same worktree-isolated parallel-dispatch pattern as the 9th run, all 6 opened clean PRs with full DoD checks passing. See [[Status Log]] 2026-08-27 for full detail including per-issue judgment calls (#70's search/filter wiring, #71's delete-vs-keep-vs-wire route decisions, #72's finish-vs-revert call, #75's dead-table investigation).

## `waiting-on-you` — paused on a human reply

**Empty as of 2026-09-17.** **#34 cleared this table for good** — closed directly by the owner 2026-09-17 (interactive session, Supabase connector), see [[Status Log]] 2026-09-17. All other rows previously here (#8, #16, #40, #74's original block, #78, #79, #47, #132) were resolved earlier — see [[Status Log]] 2026-09-13 through 2026-09-15.

## `agent-in-progress` — open PR awaiting review

**#236/PR #237 merged 2026-09-18 same run it was opened** — no longer in this table. See the update note near the top of this file.

**Empty as of the 2026-08-29 "PR-merger run"** — that run merged every open `agent/issue-*` PR (all 19 rows previously listed here: #1/#2/#4/#5/#6/#23/#26/#33/#53/#54/#56/#57/#58/#61/#62/#63/#64/#65/#66/#67, PRs #51/#89/#92/#94-#110), in dependency order (see [[Status Log]] 2026-08-29 "PR-merger run" for the exact order and which merges needed real conflict reconciliation vs. a plain rebase). Nothing left in this table unless a new issue gets picked up and opens a fresh PR.

**Corrects a stale note from the concurrent watcher session** (its own 2026-08-29 entry, [[Status Log]]): #110's actual merged resolution does **not** add a `SessionResetRegistry.registerOwnerAware`/`notifyOwnerChanged` variant (that was the watcher's own independently-drafted, never-merged fix, discarded once it saw the PR-merger session land first). The version that actually merged instead changed `SessionResetCallback` itself to `void Function(String? nextOwnerId)`, so the *existing* `register`/`notifyAll` calls all just started carrying the owner id — see `lib/platform/session/session_reset_registry.dart` and the PR #110 comment thread for the real diff.

**Phase 7 (#28) is now unblocked**: it depended on phases 1-6 merging, and phases 2 (#23, PR #89) and 5 (#26, PR #92) — the last two still open — both merged in the 2026-08-29 PR-merger run. Ready to pick up.

## `todo` but not yet actionable (tracking issues / blocked)

| # | Title | Why not picked up |
|---|---|---|
| 29 | Deploy-readiness audit (tracking) | Umbrella/index issue — findings already filed as the `needs-approval` #30-83 batch |
| 52 | Architecture, performance & cross-layer review (tracking) | Umbrella/index issue, same pattern as #21/#29 — its 31 child issues (#53-83ish) are the real work |
| 278 | No automated tests for RLS policies and order RPCs | Explicitly depends on #276 merging first (its own issue body: "Do not start until that is merged") |

**#128 (merchant self-service tracking) closed 2026-09-15 (75th run)** — all 7 children (#129-135) merged, entire epic complete. See the update note near the top of this file and [[Status Log]] 2026-09-15 "75th run". No longer in this table.

**#74 unblocked and merged 2026-09-17** (PR #230) once #34 was resolved by the owner directly. No longer in this table — see the update note near the top of this file and [[Status Log]] 2026-09-17.

**#280 (composition-root tracking) closed 2026-10-04** — all 5 phases (#281-285) merged, see the update note near the top of this file and [[Status Log]] 2026-10-04. No longer in this table.

**#276 (baseline migration) is blocked but NOT tracking-only — it's a real, specific task genuinely stuck on a sandbox limitation** (no board-worker sandbox so far has a working Docker daemon to run `supabase db reset`), not an umbrella issue. See [[Status Log]] 2026-10-04. Re-check whether a future sandbox has Docker before assuming this is permanently stuck.

**#55 (iOS build never verified) is similarly blocked, not tracking-only — partial fix merged (PR #332, 2026-10-04 4th run), issue stays open.** The remaining work (`ios/Podfile`/`Podfile.lock` via a real `flutter build ipa`, a real `DEVELOPMENT_TEAM`) needs macOS/Xcode/CocoaPods and an Apple Developer Program Team ID — none exist in any board-worker sandbox so far (all Linux). Don't re-attempt the Podfile/team-ID half from a sandbox; only re-pick this up if a future sandbox is confirmed to be macOS-based, or the owner provides a Team ID some other way.

## Remaining `todo`, not yet picked up

**As of 2026-10-04 (4th run)**: #276 (blocked on sandbox Docker availability, PR #303 open unmerged) → #278 (blocked on #276) → #301 (now blocked only on #276/#278, since #298 closed this run). **#55** stays open too — partial fix merged (PR #332), but the Podfile/DEVELOPMENT_TEAM half needs a human on a Mac; re-picking it up won't accomplish more until that happens, so don't re-attempt it from a Linux sandbox. #32/#222/#298 all closed this run. Only #29/#52 remain pure tracking-only. Queue is down to 6 open `todo` issues total (#29, #52, #55, #276, #278, #301). Re-check via `list_issues` before assuming this list is complete.

**As of 2026-10-04 (later run)**: #276 (blocked on sandbox Docker availability, PR #303 open unmerged) → #278 (blocked on #276) → #298 (blocked on #222, still `needs-approval`) → #301 (explicitly waits on #276-299 all closing). #288 merged this run (PR #326). Only #29/#52 remain pure tracking-only. Re-check via `list_issues` before assuming this list is complete — note the queue is down to just 7 `todo` issues total now (not the 16-18 concrete ones from earlier 2026-10-04 entries), since most of the #276-301 batch besides #276/#278/#298/#301 has already been processed.

**As of 2026-10-04 (earlier run)**: #276 (blocked on sandbox Docker availability, PR #303 open unmerged) → #278 (blocked on #276) → #287 ([High] Firebase Crashlytics) → #288 through #299 (mix of medium/low UI/logic/infra cleanup from the 2026-10-03 audit batch) → #301 (explicitly waits on #276-299 all closing). Only #29/#52 remain pure tracking-only. Re-check via `list_issues` before assuming this list is complete.

**As of 2026-09-17**: none — #74 merged this run (PR #230), #34 closed by the owner directly. Only #29/#52 (tracking-only, no direct work) remain in the `todo`/`waiting-on-you` queue. Re-check via `list_issues` before assuming this list is complete — a new issue or approval could change it any time.

**As of the 75th run (2026-09-15)**: none — #47/#132/#133/#134/#135 all merged this run, #128 closed. Only #29/#52 (tracking-only, no direct work) and #74/#34 (blocked on each other) remain in the `todo`/`waiting-on-you` queue. Re-check via `list_issues` before assuming this list is complete — a further human approval pass, a reply on #34, or a new issue could change it any time.

**Empty as of the 16th run (2026-08-31) through the 69th run (2026-09-14)** — historical note, superseded by the above: #144 (the last actionable `todo` from the prior batch) merged via PR #166, and the queue then sat genuinely empty (aside from blocked/tracking issues) for 54 runs until this run's mass approval.

**11th run (2026-08-27) processed the last 6 issues from the #52 audit batch's `agent:supabase` tail: #76, 77, 78, 79, 80, 83.** #76/77/80/83 were clear mechanical fixes, implemented and merged same-run (see [[Status Log]] for detail, including the new self-merge policy). #78 and #79 both explicitly ask the reader to "decide" on an architecture/product question (a shared-platform schema shape; which fulfilment/ops model to build) rather than describing one target behavior — judged genuinely ambiguous per AGENTS.md's own criteria (affects data contracts/security/solution size), so both got a clarifying-question comment and moved to `waiting-on-you` instead of a guessed implementation. This was **the last unpicked batch from the #52 audit** — no more `todo`-and-not-`agent-in-progress` issues remain from that source as of this run. Only 14 issues remain `needs-approval`-gated as of 2026-08-26 (#9, 12, 30, 32, 38, 43, 49, 55, 59, 60, 73, 74, 81, 82) — next run has nothing left to pick up unless the human approves more of those, replies to a `waiting-on-you` issue, or a new issue is filed.

## Known in-flight / interrupted work (not yet resolved)

- The 2026-08-12 dedup-extraction interruption (RPC-unwrap helper, load/error mixin, confirm-order flow left partially wired) was tracked as **issue #72**, resolved and merged via PR #112 (10th run, 2026-08-27) which wired `LoadableState`/`confirmDemoOrder` into the grocery/pharmacy controllers — closed, no longer in-flight. PRs #108/#110's individual rebases against it were completed in the 2026-08-29 PR-merger run (both merged).
