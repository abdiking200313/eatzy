/// Environment configuration for the Supabase backend (issue #42).
///
/// Reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `--dart-define` at build
/// time, falling back to the current live **production** project's values so
/// that `flutter run` / `flutter test` / `flutter build` / CI keep working
/// exactly as before when no flags are passed.
///
/// ## Per-environment config files (issue #277)
///
/// Rather than typing both `--dart-define` flags out by hand, copy
/// `config/dev.json.example` to `config/dev.json` (gitignored, never
/// committed) and fill in a non-production project's values, then run:
///
/// ```sh
/// flutter run --dart-define-from-file=config/dev.json
/// ```
///
/// `config/prod.json.example` is provided the same way for an explicit,
/// intentional production build/run (`flutter build ... --dart-define-from-file=config/prod.json`).
///
/// Passing the two `--dart-define=SUPABASE_URL=...`/`--dart-define=SUPABASE_ANON_KEY=...`
/// flags directly (as documented in `README.md`) still works identically --
/// `--dart-define-from-file` is just a convenience wrapper around the same
/// mechanism.
///
/// ## The production fallback below is temporary
///
/// No separate dev/staging Supabase project exists yet (see issue #42), so
/// the constants below still fall back to the live production project when
/// no define is passed at all -- this keeps the app runnable out of the box.
/// **Remove this fallback once a non-production project exists** so that
/// omitting the defines fails loudly instead of silently reading/writing
/// real production data. Until then, [isUsingProductionDefault] and the
/// debug-build warning in `lib/platform/startup/startup_gate.dart` are the
/// safety net.
///
/// Both defines must be provided together -- there is no "URL only" or
/// "key only" override; anything left unset falls back to the live project
/// default below.
abstract final class Env {
  /// The Supabase project URL. Override with `--dart-define=SUPABASE_URL=...`
  /// or `--dart-define-from-file=config/dev.json`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jzubookmbrtslocuzepe.supabase.co',
  );

  /// The Supabase publishable/anon key. This is the intended-public anon
  /// key, not a secret -- see issue #42. Override with
  /// `--dart-define=SUPABASE_ANON_KEY=...` or
  /// `--dart-define-from-file=config/dev.json`.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_yLgLRnh00I5zjImD-Q7R6A_uOO-l0sT',
  );

  /// True when neither `SUPABASE_URL` nor `SUPABASE_ANON_KEY` was supplied via
  /// `--dart-define`/`--dart-define-from-file`, meaning [supabaseUrl] and/or
  /// [supabaseAnonKey] above are silently falling back to the live
  /// **production** project. Not a secret itself -- a plain non-secret flag
  /// so a caller (see `lib/platform/startup/startup_gate.dart`) can warn a
  /// developer who is about to run against real production data without
  /// meaning to. Computed via [bool.hasEnvironment] (a compile-time check for
  /// whether a dart-define key was *passed at all*, independent of its
  /// value) rather than by comparing against the literal fallback strings
  /// above, so it stays correct even if those literals ever change.
  static const bool isUsingProductionDefault =
      !bool.hasEnvironment('SUPABASE_URL') ||
      !bool.hasEnvironment('SUPABASE_ANON_KEY');
}
