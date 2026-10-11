# Welcome to your Expo app 👋

This is an [Expo](https://expo.dev) project created with [`create-expo-app`](https://www.npmjs.com/package/create-expo-app).

## Get started

1. Install dependencies

   ```bash
   npm install
   ```

2. Start the app

   ```bash
   npx expo start
   ```

In the output, you'll find options to open the app in a

- [development build](https://docs.expo.dev/develop/development-builds/introduction/)
- [Android emulator](https://docs.expo.dev/workflow/android-studio-emulator/)
- [iOS simulator](https://docs.expo.dev/workflow/ios-simulator/)
- [Expo Go](https://expo.dev/go), a limited sandbox for trying out app development with Expo

You can start developing by editing the files inside the **app** directory. This project uses [file-based routing](https://docs.expo.dev/router/introduction).

## Development builds (EAS)

This app includes native modules (e.g. `expo-secure-store` today, Firebase
later) that Expo Go does not bundle, so day-to-day development uses a
**development build** instead of Expo Go. A development build is a debug
build of this app that still includes the Metro dev server / fast refresh via
`expo-dev-client`, but can also load any native module you add.

Builds are produced in the cloud with [EAS Build](https://docs.expo.dev/eas/index.md)
— no local Android Studio or Xcode install is required to *build*, but you do
still need an emulator (Android) or simulator (iOS) to *run* the result
locally. Run every EAS CLI command as `npx eas-cli@latest <command>` (not a
globally installed `eas`) so you always use a current client against the
current project.

### One-time setup

1. `npx eas-cli@latest login` — sign in with the Expo account that owns this
   project (ask a maintainer for access if you don't have one).
2. Copy `.env.example` to `.env.development` and fill in a non-production
   Supabase project's URL/anon key (see the comments in that file). Builds —
   including EAS builds — fail fast with a named error if these are missing;
   see `src/platform/config/env.ts`.

### Build profiles (`eas.json`)

| Profile | Purpose | Distribution |
| --- | --- | --- |
| `development` | Local development build with `expo-dev-client`, connects to your Metro dev server | `internal` (Android APK, iOS simulator build) |
| `preview` | Installable build for manual/QA testing, no dev client | `internal` (Android APK) |
| `production` | Store-ready build | `store` (Android App Bundle, auto-incrementing build number) |

### Building a development build

```bash
# Android (installable .apk)
npx eas-cli@latest build --profile development --platform android

# iOS (simulator build — set ios.simulator: false in eas.json's
# "development" profile first if you need a device build instead)
npx eas-cli@latest build --profile development --platform ios
```

Each command queues a cloud build and prints a URL to track progress, then a
download link when it finishes.

### Installing it

- **Android emulator**: download the `.apk` EAS gives you and drag it onto a
  running emulator window, or run
  `npx eas-cli@latest build:run --platform android` to install the latest
  development build straight onto a running emulator/device.
- **iOS simulator**: run
  `npx eas-cli@latest build:run --platform ios` to install the latest
  simulator build straight into a running simulator, or drag the downloaded
  `.app`/`.tar.gz` onto the Simulator window.
- Once installed, run `npx expo start --dev-client` and open the app — it
  connects to your local Metro server like Expo Go did.

Prefer building and installing locally instead (no EAS account/cloud build
needed)? Use `npx expo run:android` or `npx expo run:ios` — both generate the
native `android/`/`ios/` projects on the fly (Continuous Native Generation)
and install straight onto a connected emulator/simulator, but require
Android Studio / Xcode to already be installed locally.

### Bundle identifier and signing

Both platforms are configured in `app.json` with the same identifier the
Flutter app (`flutter_app/`) already ships under:

- `ios.bundleIdentifier`: `com.zivo.app`
- `android.package`: `com.zivo.app`

This is intentional, not incidental — reusing `flutter_app`'s existing
identifier means this RN app must be signed with the **same release
identities** when it ships to the stores:

- **Android**: use the **same Play Console listing** as `flutter_app`, and let
  **Play App Signing** manage the signing key (do not generate or commit a
  separate keystore for this app). EAS Build will request/store Android
  signing credentials for you (`npx eas-cli@latest credentials`) the first
  time a `store`-distribution build runs; it is only needed for `production`
  builds, not for `development`/`preview` builds, which EAS signs with an
  internal debug/ad hoc identity instead.
- **iOS**: use the **same Apple Developer Team** as `flutter_app` so
  provisioning for `com.zivo.app` resolves to the existing App Store
  Connect app record, not a new one. EAS Build manages provisioning
  profiles/certificates for you once you log in with that team's Apple ID
  (`npx eas-cli@latest credentials`).

No signing secrets (keystores, provisioning profiles, API keys) are committed
to this repository — EAS stores them for you, encrypted, once you provide
them interactively.

## End-to-end tests (Maestro)

[Maestro](https://docs.maestro.dev) flows live in `e2e/`. They drive a real
installed build of the app on an Android emulator (or device), so they are
not part of `npm test` or CI.

`e2e/customer-food-order.yaml` covers the main customer path: a brand-new
customer signs up, opens Food, orders one menu item from a seeded
restaurant, places the order (pay on delivery, so there is no payment step)
and lands on the live order-tracking screen.

### Prerequisites

1. **Maestro CLI**: `curl -Ls "https://get.maestro.mobile.dev" | bash`
   (needs Java 17+).
2. **A dev Supabase project, never production.** The build under test takes
   its project from `EXPO_PUBLIC_SUPABASE_URL` /
   `EXPO_PUBLIC_SUPABASE_ANON_KEY` (`.env.development` or the EAS build
   profile). Nothing about the project is hardcoded in the flow.
3. **Email confirmation turned off** on that dev project (Authentication >
   Sign In / Providers > Email > "Confirm email"). With it on, sign-up returns
   no session and the app shows "Confirm your email" instead of continuing.
4. **Seeded data**: an open restaurant with at least one available menu item.
   You pass their display names to the flow (see below).
5. A running Android emulator with a build of this app (`com.zivo.app`)
   installed: a `development` build with Metro running, or a `preview` APK.

### Running it

```bash
npm run e2e:customer -- \
  -e E2E_PASSWORD='<throwaway password, 6+ chars>' \
  -e E2E_RESTAURANT_NAME='<seeded restaurant name>' \
  -e E2E_MENU_ITEM_NAME='<menu item on that restaurant>'
```

Optional: `-e E2E_EMAIL_DOMAIN=...` (default `example.com`; use a domain your
dev project accepts), `E2E_FIRST_NAME`, `E2E_LAST_NAME`, `E2E_PHONE`.

Each run signs up a new `e2e+<timestamp>@<domain>` account and places one
real order on the dev project, so clean those up there periodically. Never
commit real passwords or project keys; pass them on the command line or
from your shell/CI secrets. `npm run e2e:check` validates the flow syntax
without a device.

## Get a fresh project

When you're ready, run:

```bash
npm run reset-project
```

This command will move the starter code to the **app-example** directory and create a blank **app** directory where you can start developing.

### Other setup steps

- To set up ESLint for linting, run `npx expo lint`, or follow our guide on ["Using ESLint and Prettier"](https://docs.expo.dev/guides/using-eslint/)
- If you'd like to set up unit testing, follow our guide on ["Unit Testing with Jest"](https://docs.expo.dev/develop/unit-testing/)
- Learn more about the TypeScript setup in this template in our guide on ["Using TypeScript"](https://docs.expo.dev/guides/typescript/)

## Supabase database types

`src/types/database.ts` exports the `Database` type the Supabase client at
`src/platform/supabase/client.ts` is parameterized with
(`createClient<Database>(...)`), so every `.from('...')` table/view name,
column, and `.rpc('...')` function name and argument is type-checked against
the real `public` schema — calling a table or RPC that doesn't exist is a
compile error.

**Regenerate it after every migration** lands in `supabase/migrations/`
(repo root):

```bash
npm run gen:types
```

This runs `supabase gen types typescript --project-id jzubookmbrtslocuzepe
--schema public`, which needs a `supabase login` session with network
access to the live project. If you only have the SQL locally (no CLI login,
offline, or a local Supabase stack via `supabase start`), generate from that
instead and review the diff before committing:

```bash
# Local Supabase stack (Docker) running against supabase/migrations/:
supabase gen types typescript --local --schema public > src/types/database.ts

# Or point the CLI at a schema dump / the running project's connection
# string directly — see `supabase gen types typescript --help`.
```

Commit the regenerated file. Do not hand-edit `database.ts` outside of a
regeneration — if the CLI genuinely can't reach any schema source, update it
by re-deriving it from `supabase/schema.sql` plus `supabase/migrations/` (in
timestamp order, since `schema.sql` alone is known to drift — see
`AGENTS.md` at the repo root) and leave a comment on exactly what changed and
why, the same way the current file documents its own provenance at the top.

## Merchant order flow (Maestro E2E)

`e2e/merchant-order.yaml` is a [Maestro](https://docs.maestro.dev) flow for
the main merchant path: a merchant signs in, opens an incoming order on the
**Orders** tab, accepts it, and advances it through every forward status
until it is delivered. Like any Maestro flow it drives a real installed build
on an Android emulator (or device), so it is not part of `npm test` or CI.

### Prerequisites

1. **Maestro CLI**: `curl -Ls "https://get.maestro.mobile.dev" | bash`
   (needs Java 17+).
2. **A dev Supabase project, never production.** The build under test takes
   its project from `EXPO_PUBLIC_SUPABASE_URL` /
   `EXPO_PUBLIC_SUPABASE_ANON_KEY` (`.env.development` or the EAS build
   profile). Nothing about the project is hardcoded in the flow.
3. **A merchant account** on that project: a `profiles.role` of `merchant`
   (an `admin` lands on the Accounts screen instead) that owns a store
   (food, grocery or pharmacy -- the flow only asserts labels shared by all
   three).
4. **At least one order in `confirmed` status** for that store. The easiest
   way is to place one as a customer first (for example with the customer
   E2E flow, or by hand in the app). Each run moves that order to
   `delivered`, so every run needs a fresh one.
5. A running Android emulator with a build of this app (`com.zivo.app`)
   installed: a `development` build with Metro running, or a `preview` APK.

### Running it

```bash
npm run e2e:merchant -- \
  -e E2E_MERCHANT_EMAIL='<merchant account email>' \
  -e E2E_MERCHANT_PASSWORD='<its password>'
```

Optional: `-e E2E_ORDER_ID=<full order uuid>` to work on one specific
`confirmed` order (it then also checks the list shows it as Delivered
afterwards); without it the flow opens the first order whose status is
Confirmed. Never commit real passwords or project keys; pass them on the
command line or from your shell/CI secrets.
`maestro check-syntax e2e/merchant-order.yaml` validates the flow without a
device.

## Learn more

To learn more about developing your project with Expo, look at the following resources:

- [Expo documentation](https://docs.expo.dev/): Learn fundamentals, or go into advanced topics with our [guides](https://docs.expo.dev/guides).
- [Learn Expo tutorial](https://docs.expo.dev/tutorial/introduction/): Follow a step-by-step tutorial where you'll create a project that runs on Android, iOS, and the web.

## Join the community

Join our community of developers creating universal apps.

- [Expo on GitHub](https://github.com/expo/expo): View our open source platform and contribute.
- [Discord community](https://chat.expo.dev): Chat with Expo users and ask questions.
