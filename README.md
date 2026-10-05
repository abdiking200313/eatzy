# Zivo

Zivo is a Flutter "super app" for on-demand delivery, backed by a real Supabase
project. Customers order from **food** restaurants, **grocery** stores (plus
separate **Fresh Meat** and **Electronics** storefronts running on the grocery
engine) and **pharmacies**. Store owners manage their store, catalog and orders
from a built-in **merchant dashboard**.

> Repo name: `eatzy` · Dart package name: `chowflow` · In-app brand: **Zivo**

## Features

**Customer app**
- Email/password auth with sign-up, password reset (deep-linked recovery), and
  first-run onboarding (`lib/features/auth/`, `lib/features/onboarding/`)
- Super-app home with service grid, popular stores, promos and recent activity
  (`lib/features/super_app/`)
- Food: restaurant browsing, categories, explore, menus, item details, cart and
  checkout (`lib/services/food/`)
- Grocery / Fresh Meat / Electronics: store lists, product details, and a
  separate persisted cart + checkout per storefront (`lib/services/grocery/`)
- Pharmacy: store list, catalog, cart and checkout (`lib/services/pharmacy/`)
- Order placement through `SECURITY DEFINER` RPCs that recompute prices
  server-side, with idempotency keys so retries never double-order
- Live order tracking via Supabase Realtime (`lib/features/orders/`)
- Activity feed and "order again" (`lib/platform/activity/`)
- Profile editing, saved delivery addresses, settings, notification
  preferences, support, privacy policy / terms, and self-service account
  deletion
- Push notifications (Firebase Cloud Messaging) and crash reporting (Firebase
  Crashlytics)

**Merchant dashboard** (`lib/features/merchant/`, route `/merchant`)
- Accounts with the `merchant` or `admin` role are routed here instead of the
  customer app
- Store profile, catalog management with photo upload/cropping, and incoming
  orders with status transitions
- Admins can list accounts and manage roles

**Payments:** cash on delivery only for now. Orders carry `payment_method` /
`payment_status` columns so a card processor can be added later.

## Tech stack

| Area | Choice |
| --- | --- |
| Framework | Flutter (pinned in `.fvmrc` / `.tool-versions`), Dart `^3.11.5` |
| Backend | Supabase: Postgres + RLS on every table, Auth, Storage, Realtime |
| Navigation | `go_router` with auth and role redirects (`lib/app/app_router.dart`) |
| State | `ChangeNotifier` controllers per domain, `StatefulWidget`, `FutureBuilder` (no Riverpod/Bloc, no codegen) |
| Local storage | `shared_preferences` (carts, preferences), `flutter_secure_storage` (session) |
| Firebase | `firebase_core`, `firebase_messaging`, `firebase_crashlytics` |
| Money | Integer cents end-to-end; formatted only for display with `AppMoney.formatCents` |
| Typography | Outfit, bundled locally in `assets/fonts/` |

See `pubspec.yaml` for the full dependency list.

## Getting started

### Prerequisites
- Flutter 3.41.9 (see `.fvmrc`)
- JDK 17 for Android builds (CI uses Temurin 17)

### Run

```bash
git clone https://github.com/abdiking200313/eatzy.git
cd eatzy
flutter pub get
flutter run
```

### Supabase configuration

The Supabase URL and anon key come from `lib/config/env.dart` via
`String.fromEnvironment`. If you pass no `--dart-define` flags, they **default
to the live production project**, so `flutter run` works out of the box. It
also means an unconfigured local run reads and writes real production data. In
debug builds a startup warning is logged when this happens
(`lib/platform/startup/startup_gate.dart`).

To point at another project, use a per-environment config file:

```bash
cp config/dev.json.example config/dev.json   # fill in URL + anon key
flutter run --dart-define-from-file=config/dev.json
```

Or pass `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
directly. `config/*.json` is gitignored; only the `*.example` templates are
committed. The same flags work with `flutter build` and `flutter test`.

## Project structure

The layout is domain-based, not layer-based. Most folders contain some subset
of `data/`, `models/` and `presentation/`. `presentation/` also holds the
`*_controller.dart` state files next to their screens.

```
lib/
├── main.dart            # Entry point: Firebase + Supabase init, startup gate
├── app/                 # go_router config, routes, app shell, service registry,
│                        #   merchant session gate
├── config/              # env.dart, theme.dart, tailwind.dart (design tokens),
│                        #   per-service theming
├── features/            # addresses, auth, legal, merchant, onboarding, orders,
│                        #   profile, settings, super_app, support
├── services/            # Delivery verticals: food, grocery, pharmacy, plus
│                        #   shared/ (cart storage, pricing, RPC helpers,
│                        #   idempotency, confirm-order flow)
├── platform/            # Cross-cutting: activity, cache, discovery, error
│                        #   reporting, localization (money), notifications,
│                        #   session, startup, system UI
└── widgets/             # Shared UI components

supabase/                # Supabase CLI project: migrations/, seed.sql, schema.sql
test/                    # Unit and widget tests
vault/                   # Project knowledge base (architecture, decisions, status)
docs/legal/              # Privacy policy and terms source text
config/                  # *.json.example dart-define templates
```

Shared platform code (identity, addresses, sessions, money) stays free of
vertical-specific assumptions. Each vertical's behavior lives inside its own
`services/<vertical>/` module.

## Database

- `supabase/migrations/` holds the ordered migration chain and is the source of
  truth for schema changes.
- `supabase/schema.sql` is a reference snapshot of the live public schema. It
  is documentation, not a bootstrap script.
- Building a fresh database from this repo alone isn't supported yet, because
  some core tables predate the migration chain (issue #276).
- See [`supabase/README.md`](supabase/README.md) for the local CLI workflow.

## Development

Run these before opening a PR. CI (`.github/workflows/ci.yml`) runs the same
checks plus a debug Android build:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Run a single test file with `flutter test test/cart_controller_test.dart`.

Contributor and agent conventions (scope, labels, branch naming, definition of
done) are in [`AGENTS.md`](AGENTS.md). Architecture notes, the decisions log and
the status log are in [`vault/`](vault/00-Index.md).

## Building for release

### Android

Release builds use R8 shrinking and obfuscation. Signing reads
`android/key.properties`; copy it from `android/key.properties.example` and see
[`android/SIGNING.md`](android/SIGNING.md) for keystore generation and backup.

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
flutter build apk --release --obfuscate --split-debug-info=build/symbols --split-per-abi
```

Archive `build/symbols` (gitignored) outside git for every release you ship.
Without it, obfuscated crash reports can't be symbolicated.

### Other platforms

- **Web:** `flutter build web`
- **iOS:** not yet verified end to end. Signing team and Pods setup are still
  open (issue #55).
- Desktop runners exist in the repo but aren't a supported target.

## Status and known gaps

Open work is tracked in [GitHub Issues](https://github.com/abdiking200313/eatzy/issues).
Notable open items:
- Baseline migration for core tables (#276)
- Automated pgTAP tests for RLS policies and order RPCs (#278)
- iOS build verification (#55)
- Restricting Firebase API keys in Google Cloud (#300)

Check the issue tracker for current status. Don't rely on this list staying
up to date.
