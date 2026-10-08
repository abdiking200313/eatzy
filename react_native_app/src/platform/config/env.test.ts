import { InvalidAppEnvError, MissingEnvVarError, PRODUCTION_SUPABASE_URL, loadEnv } from './env';

/// Exercises `loadEnv` directly against an explicit source object, exactly as
/// its own doc comment recommends — never the ambient `process.env` (which
/// `jest.setup.ts` only seeds with harmless placeholders so merely
/// *importing* this module doesn't throw; it isn't meant to be asserted on).
describe('loadEnv', () => {
  it('reads a complete, valid environment', () => {
    const env = loadEnv({
      APP_ENV: 'development',
      EXPO_PUBLIC_SUPABASE_URL: 'https://dev-project.supabase.co',
      EXPO_PUBLIC_SUPABASE_ANON_KEY: 'dev-anon-key',
    } as unknown as NodeJS.ProcessEnv);

    expect(env).toEqual({
      appEnv: 'development',
      supabaseUrl: 'https://dev-project.supabase.co',
      supabaseAnonKey: 'dev-anon-key',
      isUsingProductionUrlInDevelopment: false,
    });
  });

  it('defaults APP_ENV to "development" when unset', () => {
    const env = loadEnv({
      EXPO_PUBLIC_SUPABASE_URL: 'https://dev-project.supabase.co',
      EXPO_PUBLIC_SUPABASE_ANON_KEY: 'dev-anon-key',
    } as unknown as NodeJS.ProcessEnv);

    expect(env.appEnv).toBe('development');
  });

  it('throws InvalidAppEnvError for an unrecognized APP_ENV', () => {
    expect(() =>
      loadEnv({
        APP_ENV: 'staging',
        EXPO_PUBLIC_SUPABASE_URL: 'https://dev-project.supabase.co',
        EXPO_PUBLIC_SUPABASE_ANON_KEY: 'dev-anon-key',
      } as unknown as NodeJS.ProcessEnv),
    ).toThrow(InvalidAppEnvError);
  });

  it('throws MissingEnvVarError when the Supabase URL is missing', () => {
    expect(() =>
      loadEnv({ EXPO_PUBLIC_SUPABASE_ANON_KEY: 'dev-anon-key' } as unknown as NodeJS.ProcessEnv),
    ).toThrow(MissingEnvVarError);
  });

  it('throws MissingEnvVarError when the Supabase URL is blank', () => {
    expect(() =>
      loadEnv({
        EXPO_PUBLIC_SUPABASE_URL: '   ',
        EXPO_PUBLIC_SUPABASE_ANON_KEY: 'dev-anon-key',
      } as unknown as NodeJS.ProcessEnv),
    ).toThrow(MissingEnvVarError);
  });

  it('flags a development build pointed at the production Supabase URL', () => {
    const env = loadEnv({
      APP_ENV: 'development',
      EXPO_PUBLIC_SUPABASE_URL: PRODUCTION_SUPABASE_URL,
      EXPO_PUBLIC_SUPABASE_ANON_KEY: 'dev-anon-key',
    } as unknown as NodeJS.ProcessEnv);

    expect(env.isUsingProductionUrlInDevelopment).toBe(true);
  });

  it('does not flag a production build pointed at the production Supabase URL', () => {
    const env = loadEnv({
      APP_ENV: 'production',
      EXPO_PUBLIC_SUPABASE_URL: PRODUCTION_SUPABASE_URL,
      EXPO_PUBLIC_SUPABASE_ANON_KEY: 'prod-anon-key',
    } as unknown as NodeJS.ProcessEnv);

    expect(env.isUsingProductionUrlInDevelopment).toBe(false);
  });
});
