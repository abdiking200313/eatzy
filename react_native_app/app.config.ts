import type { ConfigContext, ExpoConfig } from 'expo/config';

import { loadEnv } from './src/platform/config/env';

// Dynamic config layered on top of the static app.json (Expo passes that
// parsed config in as `config` here — see
// https://docs.expo.dev/workflow/configuration/#dynamic-configuration).
//
// This only adds the validated Supabase/environment values to `extra` so
// they're visible to `expo config` and to native tooling; app code should
// still import `env` from `src/platform/config/env.ts` directly rather than
// going through `expo-constants`.
//
// `loadEnv()` throws a clear, named error (see env.ts) when a required
// variable is missing, so running `expo start`/`expo export`/`eas build`
// without a valid `.env.development` or `.env.production` fails immediately
// instead of silently building against no backend.
export default ({ config }: ConfigContext): ExpoConfig => {
  const env = loadEnv();

  return {
    ...config,
    extra: {
      ...config.extra,
      appEnv: env.appEnv,
      supabaseUrl: env.supabaseUrl,
      supabaseAnonKey: env.supabaseAnonKey,
    },
  } as ExpoConfig;
};
