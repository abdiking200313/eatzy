/// Environment configuration for the Supabase backend (issue #346).
///
/// Ports `flutter_app/lib/config/env.dart` to this app: unlike the Flutter
/// client, there is no bundled production fallback here — every environment
/// (development and production) must supply its own Supabase project via env
/// vars, so a missing value fails loudly instead of silently reading/writing
/// real data.
///
/// ## Per-environment config files
///
/// Copy `.env.example` to `.env.development` (for local work against a
/// non-production Supabase project) or `.env.production` (for an explicit,
/// intentional production build), then fill in real values. Both files are
/// git-ignored and must never be committed. Expo's CLI automatically loads
/// `EXPO_PUBLIC_`-prefixed variables from the `.env.<NODE_ENV>` file matching
/// the command you ran (`development` for `expo start`, `production` for
/// `expo export` / EAS builds) — see
/// https://docs.expo.dev/guides/environment-variables/.
///
/// `APP_ENV` is this app's own `development`/`production` flag (independent
/// of Expo/Metro's `NODE_ENV`), used below to decide whether to warn about a
/// development build pointing at production data.
///
/// Only `EXPO_PUBLIC_`-prefixed variables are readable from app code (Expo
/// inlines them into the client bundle at build time) — see
/// https://docs.expo.dev/versions/v57.0.0/config/metro/. Do not put secrets
/// in them: like the Flutter app's anon key, `EXPO_PUBLIC_SUPABASE_ANON_KEY`
/// is the intended-public anon key, not a secret.
export type AppEnvironment = 'development' | 'production';

export interface Env {
  /** Which Supabase project this build targets: `development` or `production`. */
  appEnv: AppEnvironment;
  /** The Supabase project URL for this environment. */
  supabaseUrl: string;
  /** The Supabase anon/publishable key for this environment (public, not a secret). */
  supabaseAnonKey: string;
  /**
   * True when this is a development build (`APP_ENV=development`) whose
   * `EXPO_PUBLIC_SUPABASE_URL` matches the known **production** project,
   * i.e. local development is about to read/write real production data.
   * Mirrors `Env.isUsingProductionDefault` in `flutter_app/lib/config/env.dart`.
   */
  isUsingProductionUrlInDevelopment: boolean;
}

/**
 * The live production Supabase project URL (see
 * `flutter_app/lib/config/env.dart`). A project URL alone is not a secret —
 * it identifies the project, not a credential — but it is used here purely
 * to detect a development build that is accidentally pointed at production.
 */
export const PRODUCTION_SUPABASE_URL = 'https://jzubookmbrtslocuzepe.supabase.co';

/** Thrown by {@link loadEnv} when a required environment variable is missing or blank. */
export class MissingEnvVarError extends Error {
  constructor(public readonly variableName: string) {
    super(
      `Missing required environment variable "${variableName}". Copy ` +
        '.env.example to .env.development (or .env.production), fill in real ' +
        'Supabase project values, and restart the dev server so Expo reloads them.',
    );
    this.name = 'MissingEnvVarError';
  }
}

/** Thrown by {@link loadEnv} when `APP_ENV` is set to something other than a known value. */
export class InvalidAppEnvError extends Error {
  constructor(public readonly value: string) {
    super(`Invalid APP_ENV "${value}" — expected "development" or "production".`);
    this.name = 'InvalidAppEnvError';
  }
}

function requireEnvVar(source: NodeJS.ProcessEnv, name: string): string {
  const value = source[name];
  if (value === undefined || value.trim() === '') {
    throw new MissingEnvVarError(name);
  }
  return value;
}

function parseAppEnv(source: NodeJS.ProcessEnv): AppEnvironment {
  const raw = source.APP_ENV;
  if (raw === undefined || raw === '') {
    // No separate dev/prod flag set — default to development so a plain
    // `expo start` with env values configured still runs.
    return 'development';
  }
  if (raw === 'development' || raw === 'production') {
    return raw;
  }
  throw new InvalidAppEnvError(raw);
}

/**
 * Builds the typed {@link Env} from a `process.env`-shaped source. Pure
 * (aside from throwing) and takes an explicit source so each case can be
 * exercised directly in tests, without mocking the global `process.env` or
 * resetting modules between cases — ports the cases in
 * `flutter_app/test/env_test.dart`.
 */
export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const appEnv = parseAppEnv(source);
  const supabaseUrl = requireEnvVar(source, 'EXPO_PUBLIC_SUPABASE_URL');
  const supabaseAnonKey = requireEnvVar(source, 'EXPO_PUBLIC_SUPABASE_ANON_KEY');

  return {
    appEnv,
    supabaseUrl,
    supabaseAnonKey,
    isUsingProductionUrlInDevelopment:
      appEnv === 'development' && supabaseUrl === PRODUCTION_SUPABASE_URL,
  };
}

/** The app's validated environment config, read once at module load. */
export const env: Env = loadEnv();

if (env.isUsingProductionUrlInDevelopment) {
  // Visible, impossible-to-miss warning — mirrors the debug-build warning in
  // flutter_app's `lib/platform/startup/startup_gate.dart`.
  console.warn(
    '\n⚠️  [env] This development build (APP_ENV=development) has ' +
      'EXPO_PUBLIC_SUPABASE_URL set to the production Supabase project.\n' +
      '    Local development will read and write real production data.\n' +
      '    Point .env.development at a separate, non-production project ' +
      'instead, or set APP_ENV=production if this is intentional.\n',
  );
}
