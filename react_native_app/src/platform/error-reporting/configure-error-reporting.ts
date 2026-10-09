/**
 * Wires {@link ErrorReporting.instance} to a real {@link CrashlyticsErrorReporter}
 * (issue #351) once, at app startup -- this app has no `startup_gate`/
 * `runStartupSequence` equivalent yet (unlike
 * `flutter_app/lib/platform/startup/startup_gate.dart`), so for now this is
 * called unconditionally rather than being gated by build type/environment;
 * revisit once this app has an equivalent startup sequence to hook into.
 *
 * Falls back to (and leaves in place) the default {@link LoggingErrorReporter}
 * when the native Crashlytics module isn't available -- notably in Expo Go,
 * which only bundles Expo's own native modules, not `@react-native-firebase`'s.
 * A custom development build (`expo-dev-client`, issue #350) does bundle it,
 * so a forced test crash there still reports to the same Firebase project as
 * the Flutter app.
 */
import { CrashlyticsErrorReporter, FirebaseCrashlyticsClient } from './crashlytics-error-reporter';
import { ErrorReporting } from './error-reporter';

let configured = false;

export async function configureErrorReporting(): Promise<void> {
  if (configured) {
    return;
  }
  configured = true;

  try {
    const client = new FirebaseCrashlyticsClient();
    // Collection is enabled unconditionally for now (no per-environment
    // startup policy exists yet in this app -- see this function's doc
    // comment) so a forced test crash is actually visible in the Firebase
    // console from a development build, per issue #351's acceptance
    // criteria.
    await client.setCrashlyticsCollectionEnabled(true);
    ErrorReporting.instance = new CrashlyticsErrorReporter(client);
  } catch (error) {
    console.warn(
      '[error-reporting] Crashlytics native module unavailable (expected in Expo Go); ' +
        'keeping the default LoggingErrorReporter.',
      error,
    );
  }
}
