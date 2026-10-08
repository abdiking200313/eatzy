/// The shared Supabase client (issue #347).
///
/// Ports the wiring `flutter_app/lib/main.dart` does around
/// `Supabase.initialize` — one client for the whole app, a persisted and
/// auto-refreshing session — to this app's root. Every feature should import
/// `supabase` from here rather than constructing its own client.
import 'react-native-url-polyfill/auto';

import { createClient } from '@supabase/supabase-js';
import { AppState, type AppStateStatus } from 'react-native';

import { env } from '../config/env';
import { EncryptedAsyncStorage } from '../session/secure-session-storage';
import type { Database } from '../../types/database';

export const supabase = createClient<Database>(env.supabaseUrl, env.supabaseAnonKey, {
  auth: {
    storage: new EncryptedAsyncStorage(),
    autoRefreshToken: true,
    persistSession: true,
    // There is no browser-style URL for an OAuth redirect to land in on
    // native, so leave this off — matches Supabase's own React Native setup
    // guidance. A deep-link-based OAuth flow (if/when one is added) handles
    // the redirect explicitly instead of through this.
    detectSessionInUrl: false,
  },
});

/**
 * Starts (when the app is foregrounded) and stops (when it isn't)
 * `supabase.auth.startAutoRefresh()` / `stopAutoRefresh()` as `AppState`
 * changes.
 *
 * Per `@supabase/auth-js`'s own docs for these methods: a backgrounded app
 * has no business refreshing tokens on a timer nobody is going to use, and
 * on native (unlike the browser) nothing does this automatically — the
 * calling app is expected to wire it up itself, which is what this does.
 *
 * Called once below, at module load, so it is active for the lifetime of
 * the app; returns an unsubscribe function mainly so a test can tear it
 * down.
 */
export function startSupabaseAutoRefreshOnAppStateChange(): () => void {
  const handleAppStateChange = (state: AppStateStatus) => {
    if (state === 'active') {
      void supabase.auth.startAutoRefresh();
    } else {
      void supabase.auth.stopAutoRefresh();
    }
  };

  const subscription = AppState.addEventListener('change', handleAppStateChange);
  // Prime it for the current state too — `AppState`'s `change` event only
  // fires on a *transition*, so without this, an app launched straight into
  // the foreground (the common case) would never call `startAutoRefresh()`
  // until the next background/foreground cycle.
  handleAppStateChange(AppState.currentState);

  return () => subscription.remove();
}

startSupabaseAutoRefreshOnAppStateChange();
