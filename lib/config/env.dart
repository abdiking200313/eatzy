/// Environment configuration for the Supabase backend (issue #42).
///
/// Reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `--dart-define` at build
/// time, falling back to the current live project's values so that
/// `flutter run` / `flutter test` / `flutter build` / CI keep working exactly
/// as before when no flags are passed.
///
/// To point the app at a different Supabase project (a future dev or
/// staging project once one is provisioned -- provisioning that project is
/// out of scope for this abstraction), pass both defines on any Flutter
/// command, for example:
///
/// ```sh
/// flutter run \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your-anon-key
/// ```
///
/// Both defines must be provided together -- there is no "URL only" or
/// "key only" override; anything left unset falls back to the live project
/// default below.
abstract final class Env {
  /// The Supabase project URL. Override with `--dart-define=SUPABASE_URL=...`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jzubookmbrtslocuzepe.supabase.co',
  );

  /// The Supabase publishable/anon key. This is the intended-public anon
  /// key, not a secret -- see issue #42. Override with
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_yLgLRnh00I5zjImD-Q7R6A_uOO-l0sT',
  );
}
