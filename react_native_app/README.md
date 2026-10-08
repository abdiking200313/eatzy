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

## Learn more

To learn more about developing your project with Expo, look at the following resources:

- [Expo documentation](https://docs.expo.dev/): Learn fundamentals, or go into advanced topics with our [guides](https://docs.expo.dev/guides).
- [Learn Expo tutorial](https://docs.expo.dev/tutorial/introduction/): Follow a step-by-step tutorial where you'll create a project that runs on Android, iOS, and the web.

## EAS builds and development builds (issue #350)

This app ships native modules (e.g. Firebase, added in a follow-up issue), so
Expo Go can no longer run it — use a **development build** instead. `eas.json`
defines three build profiles:

- `development` — a debug build with `expo-dev-client` baked in. Installs
  like a normal app and connects to your local Metro bundler, so you iterate
  without rebuilding the native shell for every JS change. The iOS side is
  configured with `ios.simulator: true`, so it produces a build for the **iOS
  Simulator**, not a physical device (see "Physical devices" below).
- `preview` — an internal-distribution release-mode build (no dev client),
  for sharing a close-to-production build with testers without going through
  a store.
- `production` — the store-distribution build (Google Play / App Store
  Connect).

### Bundle identifier / package name

Both platforms are pinned to `com.zivo.app` in `app.json`
(`ios.bundleIdentifier` / `android.package`), matching the existing Flutter
app's identity (`flutter_app/android/app/build.gradle.kts`,
`flutter_app/ios/Runner.xcodeproj/project.pbxproj`) so this app can eventually
replace it as the same listing rather than a new one.

**Signing — process note, not something this sandbox can configure:** matching
the bundle ID in `app.json` is necessary but not sufficient. For the Play
Store listing, the app signing key must be the Flutter app's existing key —
in practice, the one Google holds under **Play App Signing** for the current
`com.zivo.app` listing, so a human with access to that Play Console project
must either let EAS generate/upload a new upload key under the same
app-signing key, or supply the existing upload key. For iOS, the build must
be signed with the **same Apple Developer Team** that owns the existing
`com.zivo.app` App Store Connect app record, or App Store Connect will reject
it as a mismatched bundle ID. Neither of these can be set up here: this
sandbox has no EAS login, no Apple Developer account, and no Play Console
access. `eas build` normally manages credentials for you interactively
(`eas credentials`) once a human has logged in with `eas login` and has
access to both developer accounts.

### Building and installing a development build

One-time setup (requires a human with an Expo/EAS account):

```bash
npx eas-cli@latest login
npx eas-cli@latest build:configure   # links this app to an EAS project, writes extra.eas.projectId to app.json
```

Then, to build and install on an emulator/simulator:

```bash
# Android — builds an installable .apk (development profile uses internal distribution)
npx eas-cli@latest build --profile development --platform android
# once the build finishes, install it on a running/booted emulator:
npx eas-cli@latest build:run --platform android --latest
# (or download the .apk from the build's URL/Expo dashboard and `adb install path/to.apk`)

# iOS — builds for the Simulator (not a device, since eas.json sets ios.simulator: true)
npx eas-cli@latest build --profile development --platform ios
# once the build finishes, install it on a booted Simulator:
npx eas-cli@latest build:run --platform ios --latest
```

`eas build:run` boots the emulator/simulator for you if one isn't already
running. After installing, launch the app once from the home screen/launcher
to start the dev-client, which then prompts for the Metro dev server URL —
run `npx expo start --dev-client` alongside it.

Alternative without EAS (requires local Android Studio / Xcode, not available
in this sandbox): `npx expo run:android` / `npx expo run:ios`, which uses
Continuous Native Generation to build and install directly from source.

### Physical devices

The `development` profile above targets the iOS **Simulator** specifically.
To install a development build on a **physical** iPhone instead, a human
with Apple Developer credentials needs to either drop `ios.simulator` from
the `development` profile (requiring an ad hoc/development provisioning
profile for that device, which `eas build` can manage once logged in) or add
a separate profile for that purpose. Android development builds are a plain
`.apk` and already install on either a physical device or an emulator as-is.

### What could and couldn't be verified in this sandbox

This sandbox has no EAS login, no Apple/Google developer credentials, and no
Android/iOS emulator or simulator — so no build could actually be run,
installed, or started here. What was verified instead:

- `eas.json` is schema-valid: `npx eas-cli@latest config --profile <development|preview|production> --platform <android|ios>` parses it successfully for all six combinations and gets only as far as requiring an Expo account login (confirming the profile/platform shape itself, not any build content).
- `expo-dev-client` is installed via `npx expo install` version-pinning (see below) and listed in `app.json`'s `plugins`.
- `npm run lint` and `npx tsc --noEmit` both pass.
- No signing secrets, keys, or credentials were added anywhere — `eas.json`
  only has build-profile shape, no credential values.

**Known pre-existing blocker found while verifying (not introduced by this
change, and left unfixed as out of scope for this issue):** `npx expo config`,
`npx expo-doctor`, and `npx expo install` all currently fail on this branch's
base (`master`) with `Cannot find module './src/platform/config/env'` —
`app.config.ts`'s nested import of `src/platform/config/env.ts` isn't
resolvable by Node when Expo's CLI reads the dynamic config (it resolves the
top-level `app.config.ts` file itself, but not its *nested* relative
imports — see `@expo/require-utils/build/load.js`). This also means
`eas build`'s local config-read step, and plain `npx expo start`, fail the
same way today. Reproduce with `npx expo config --json` from
`react_native_app/`. `expo-dev-client`'s exact version (`~57.0.19`, matching
this project's installed Expo SDK 57) was therefore confirmed by reading
`node_modules/expo/bundledNativeModules.json` directly and added with
`npm install` rather than `npx expo install`, since the latter needs this
same broken config read. This should be filed as a follow-up against whoever
owns `app.config.ts`/`env.ts` (issues #346/#347).

## Join the community

Join our community of developers creating universal apps.

- [Expo on GitHub](https://github.com/expo/expo): View our open source platform and contribute.
- [Discord community](https://chat.expo.dev): Chat with Expo users and ask questions.
