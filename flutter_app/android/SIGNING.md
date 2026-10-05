# Android release signing

Fixes issue #32: release builds signed with the debug keystore, which Google
Play rejects outright.

## Why this has to happen on your own machine

Generating the real upload keystore is **not something an automated agent
should do**: the keystore and its passwords are the single credential that
lets you publish updates to this app ever again on Google Play. If it's
generated inside a disposable cloud sandbox and the container is destroyed
before you've copied it out and backed it up, the key is gone forever and
the app can never be updated under its current Play Store listing. This has
to be generated and backed up by a human, on a machine you control.

This change only wires up the *infrastructure* — `android/app/build.gradle.kts`
now signs release builds with a real key automatically once you've done the
steps below, and keeps falling back to the debug key (today's behavior) if
you haven't. No keystore or secret was generated or committed as part of
this change.

## One-time setup

1. **Generate the upload keystore**, on your own machine (needs a JDK on
   `PATH`):

   ```sh
   keytool -genkey -v -keystore ~/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   You'll be prompted for a store password, a key password (can be the same
   value), and some certificate metadata (name/org, not security-sensitive).

2. **Back up `upload-keystore.jks` and both passwords immediately**, before
   doing anything else — e.g. a password manager entry plus an encrypted
   copy of the `.jks` file in at least one other location. If you lose this
   keystore, Google Play has no recovery path: you cannot update the app
   under its existing listing ever again, only publish a new one from
   scratch. Treat it with the same care as a root credential.

3. **Create `android/key.properties`** (copy `android/key.properties.example`
   and fill in real values):

   ```properties
   storePassword=<the store password from step 1>
   keyPassword=<the key password from step 1>
   keyAlias=upload
   storeFile=/absolute/path/to/upload-keystore.jks
   ```

   `key.properties` and `*.jks`/`*.keystore` are already gitignored
   (`android/.gitignore`) — never commit either.

4. Build a release artifact as usual (`flutter build appbundle` /
   `flutter build apk --release`). `build.gradle.kts` picks up
   `key.properties` automatically and signs with the real key; without the
   file present it keeps signing with the debug key exactly as before, so
   `flutter run --release` still works with no setup.

## Verifying a build is signed with the upload key, not debug

```sh
jarsigner -verify -verbose -certs app-release.aab
# or
apksigner verify --print-certs app-release.apk
```

The certificate fingerprint should match the one `keytool -list -v
-keystore upload-keystore.jks -alias upload` prints — not Flutter's shared
debug certificate.
