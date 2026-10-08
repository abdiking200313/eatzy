/// Global Jest setup (issue #349).
///
/// Runs once before every test file (wired up via `setupFiles` in
/// `package.json`'s `jest` config), *after* `jest-expo`'s own `setupFiles`
/// entry (Jest concatenates `preset.setupFiles` ahead of project-level
/// `setupFiles` — see `jest-config`'s `normalize.js` — so this augments
/// jest-expo's native-module mocks rather than replacing them).
///
/// ## Why this exists: `src/platform/config/env.ts` throws on import
///
/// `env.ts` validates and reads `EXPO_PUBLIC_SUPABASE_URL` /
/// `EXPO_PUBLIC_SUPABASE_ANON_KEY` at *module load time*
/// (`export const env: Env = loadEnv();`), by design (issue #346) — a
/// missing value fails loudly rather than silently talking to the wrong
/// project. Real builds get these from a git-ignored `.env.development` /
/// `.env.production` file (see `.env.example`), which does not exist in a
/// fresh checkout or in CI. Without something setting these first, *any*
/// test that imports `env.ts` — directly, or transitively through
/// `src/platform/supabase/client.ts` — would throw `MissingEnvVarError`
/// before the test body ever runs.
///
/// Setting harmless placeholder values here, once, for every test run,
/// means individual tests don't each need to stub `process.env`
/// themselves, and keeps `env.ts` able to fail loudly on a *real* missing
/// value outside of tests. A test that cares about `loadEnv`'s behavior for
/// a specific input should still call `loadEnv({ ...customSource })`
/// directly (see `src/platform/config/env.ts`'s own doc comment) rather
/// than relying on these process-wide defaults.
process.env.APP_ENV ??= 'development';
process.env.EXPO_PUBLIC_SUPABASE_URL ??= 'https://test-project.supabase.co';
process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ??= 'test-anon-key';
