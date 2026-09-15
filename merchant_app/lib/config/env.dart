/// Environment configuration for the Supabase backend (issue #132).
///
/// This is a second, independent client app for the *same* Supabase
/// project the customer app (`chowflow`) already uses -- same URL/anon key,
/// same live data, gated to merchant/admin accounts only. It follows the
/// customer app's `lib/config/env.dart` config-pattern style
/// (`String.fromEnvironment` with a live-project default, overridable via
/// `--dart-define`) but is not imported across the two independent Flutter
/// projects, since each has its own `pubspec.yaml`/dependency set.
///
/// To point this app at a different Supabase project, pass both defines on
/// any Flutter command, for example:
///
/// ```sh
/// flutter run \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your-anon-key
/// ```
///
/// Both defines must be provided together -- there is no "URL only" or
/// "key only" override; anything left unset falls back to the live project
/// default below (matching the customer app's default project).
abstract final class Env {
  /// The Supabase project URL. Override with `--dart-define=SUPABASE_URL=...`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jzubookmbrtslocuzepe.supabase.co',
  );

  /// The Supabase publishable/anon key. This is the intended-public anon
  /// key, not a secret. Override with
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_yLgLRnh00I5zjImD-Q7R6A_uOO-l0sT',
  );
}
