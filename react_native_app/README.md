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

## Learn more

To learn more about developing your project with Expo, look at the following resources:

- [Expo documentation](https://docs.expo.dev/): Learn fundamentals, or go into advanced topics with our [guides](https://docs.expo.dev/guides).
- [Learn Expo tutorial](https://docs.expo.dev/tutorial/introduction/): Follow a step-by-step tutorial where you'll create a project that runs on Android, iOS, and the web.

## Join the community

Join our community of developers creating universal apps.

- [Expo on GitHub](https://github.com/expo/expo): View our open source platform and contribute.
- [Discord community](https://chat.expo.dev): Chat with Expo users and ask questions.
