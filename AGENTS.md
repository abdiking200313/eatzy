# Eatzy agent guide

## Repository authority

- The Flutter project at the repository root is the canonical application.
- Do not edit `chowflow_flutter/**`. It is a tracked starter/duplicate project and
  is out of scope unless the user explicitly names it.
- Zivo is intended to be a modular super app. Food delivery is the first
  implemented service, not the complete product.
- Planned service modules are food delivery, grocery delivery, and pharmacy
  ordering. Booking home-cleaning professionals was removed (issue #50); do
  not reintroduce a `cleaning` vertical without a fresh product decision.
- The repository name is Eatzy, the Dart package is `chowflow`, and the product
  UI is branded Zivo. Ask for the intended scope before any broad rename or
  rebrand.
- Treat the code and tests as more current than `README.md`; parts of the README
  describe an older structure and link to missing documents.

## Super-app architecture

- Separate shared platform capabilities from service modules.
- Shared platform candidates include identity, profile, addresses, payments,
  wallet, rewards, notifications, support, discovery, and order history.
- Service-specific behavior belongs inside the food, grocery, pharmacy, or
  cleaning module. Do not make shared components depend on restaurant concepts.
- Reuse shared capabilities through stable interfaces, but do not force every
  service into one identical cart, order, pricing, or fulfillment model.
- Treat pharmacy requirements such as prescriptions, regulated products, age
  checks, privacy, and jurisdiction as unresolved until the user defines them.
- Grocery may require inventory, substitutions, weighted items, and delivery
  slots. Cleaning is a service booking flow that may require provider
  availability, scheduling, duration, location, and access instructions.
- For cross-service changes, identify which behavior is platform-wide and which
  remains module-specific before assigning implementation.
- The current codebase is food-first. New work should improve module boundaries
  incrementally rather than attempting an unrequested full rewrite.

## Main agent: requirements lead and dispatcher

The main user-facing agent owns requirements, questions, delegation,
integration, verification, and the final answer. Spawned agents report to the
main agent; they do not replace the clarification conversation with the user.

For every non-trivial task:

1. Inspect the smallest relevant part of the repository before asking questions.
   Do not ask the user for facts that can be discovered locally.
2. Turn the request into a task brief containing:
   - goal and user outcome;
   - in-scope and out-of-scope behavior;
   - constraints and explicit assumptions;
   - observable acceptance criteria;
   - verification commands.
3. Identify material ambiguity. If an answer could change UX, data contracts,
   security, destructive actions, or the size of the solution, ask one concise
   group of at most three high-value questions before editing. When useful,
   show the user a short **Refined task** so they can correct it. Ask one
   targeted follow-up only if an answer reveals a new material blocker.
4. Do not block on low-risk, reversible details. State the assumption and
   proceed. If the user says to use best judgment or not ask questions, proceed
   with documented assumptions.
5. Select only the agents needed for the brief. Give each agent a bounded goal,
   relevant context, an explicit file allowlist, acceptance criteria, validation
   commands, and a required summary of changes, tests, and risks.
6. Integrate all results, review the combined diff, run proportionate checks,
   and remain accountable for the final outcome.

For bugs, first reproduce or trace the failure and ask only for reproduction
details that are unavailable in the repository. For review or explanation
requests, remain read-only unless the user also asks for implementation.

## Delegation map

Project custom agents are defined in `.codex/agents/`.

| Need | Agent | Normal scope |
| --- | --- | --- |
| Refine a fuzzy or cross-feature request | `product_analyst` | Read-only analysis and task brief |
| Decide shared-platform versus service-module boundaries | `super_app_architect` | Read-only architecture and impact analysis |
| Build Flutter UI or client behavior | `flutter_engineer` | Assigned root `lib/**` files |
| Change Supabase, auth, data access, or domain contracts | `supabase_engineer` | Assigned `supabase/**` and data/model files |
| Independently check the integrated result | `quality_reviewer` | Read-only review and validation |
| Quickly map unfamiliar code | built-in `explorer` | Read-only repository exploration |

Delegation rules:

- Do not spawn agents for a trivial, localized change where coordination costs
  more than the work.
- Use `super_app_architect` before implementing a change that affects two or
  more services, the global shell, or a shared platform contract.
- Prefer parallel agents for independent exploration, analysis, and review.
- Allow parallel implementation only when file ownership is disjoint.
- One agent owns a file at a time. The main agent resolves cross-cutting or
  overlapping changes.
- The main agent normally owns high-conflict files: `lib/main.dart`,
  `lib/app/**`, `pubspec.yaml`, `pubspec.lock`, and platform directories.
- Wait for all required agents, examine their output, and do not forward an
  unreviewed subagent result as the final answer.
- The read-only quality reviewer may be unable to run Flutter commands that
  write caches. The main agent remains responsible for executable checks.

## Project map

- `lib/main.dart`: Supabase initialization, auth/cart lifecycle, app entrypoint.
- `lib/app/**`: GoRouter routes, auth redirects, and main navigation shell.
- `lib/features/**`: preferred feature-first code, with `data`, `models`, and
  `presentation` layers where applicable.
- `lib/screens/**`: older screens that have not yet moved into feature folders.
- `lib/config/**` and `lib/widgets/**`: shared design tokens, theme, and widgets.
- `supabase/**`: local database schema documentation and SQL.
- `test/**`: unit and widget tests. Tests use injected clients/storage where
  possible.

The app currently uses `StatefulWidget`, `setState`, `FutureBuilder`, and a
singleton `ChangeNotifier` cart controller. Do not introduce a new state
management framework for a localized task without an explicit architectural
reason and user agreement.

## Flutter conventions

- Follow the existing feature-first layout for new work.
- Keep presentation, models, and data access separate when a feature needs all
  three.
- Preserve dependency injection for repositories, Supabase clients, storage,
  and controllers so behavior remains testable.
- Reuse tokens from `lib/config/**` and components from `lib/widgets/**`.
- Prefer focused widgets, meaningful names, `const` constructors, and explicit
  loading, empty, success, and error states.
- Keep route names and protection rules centralized in `lib/app/**`.
- Avoid unrelated redesigns, dependency upgrades, or broad formatting.

## Supabase and security conventions

- For any Supabase work, use the available Supabase skill. Also use the
  Supabase Postgres best-practices skill for SQL, schema, RLS, query, or database
  configuration work.
- Do not assume `supabase/schema.sql` matches the live project. Current code
  queries `item_categories`, `icon_url`, `logo_url`, and
  `menu_items.categorie_id`. The local SQL instead defines
  `categories.icon_name` and `restaurants.image_url`, uses
  `restaurants.category_id`, and defines no menu-item category foreign key.
  Dart also uses decimal display values for prices while the SQL describes
  integer smallest-currency units.
- Before changing a database or data model, identify the intended source of
  truth and reconcile drift deliberately. Do not silently make the Dart client
  fit an unverified schema.
- Preserve or strengthen row-level security for user-owned data. Add indexes
  needed by new foreign keys or common policy/query paths.
- Never add service-role keys, private credentials, or secrets to the client or
  repository. Treat remote database mutations as explicit-scope actions.
- Prefer reviewable, incremental migrations for database evolution once a
  migration workflow is in scope.

## Verification and definition of done

Use the smallest relevant check during development, then broaden it in
proportion to the change:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Use targeted tests such as `flutter test test/cart_controller_test.dart` while
iterating. Run `flutter build web` or `flutter build apk` only when the task
affects that delivery target or specifically requests a build.

A task is done when the acceptance criteria are met, existing relevant tests
pass, tests are added or updated when behavior changes or risk warrants them,
formatting and analysis pass where available, security/data effects were
considered, and the final response states changed files, checks run, and any
remaining risk. Never claim a check passed if it was not run.
