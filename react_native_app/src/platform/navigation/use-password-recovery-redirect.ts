/**
 * Wires {@link handlePasswordRecoveryUrl} to the URL that opened/resumed the
 * app, and redirects to `AppRoutes.resetPassword` once a recovery session
 * has been started -- the React Native equivalent of `app_router.dart`'s
 * `_AuthStateRefresh` reacting to `AuthChangeEvent.passwordRecovery` (issue
 * #361; see `password-recovery.ts`'s top comment for why this app needs an
 * explicit URL handler that Flutter doesn't).
 *
 * `src/app/reset-callback.tsx` is the only place this is called from: it's
 * the screen Expo Router's own native deep-link handling lands on for a
 * `zivo://reset-callback...` link (Expo Router strips the `zivo://` scheme
 * itself -- see `node_modules/expo-router/build/fork/
 * extractPathFromURL.js`'s `fromDeepLink`, which turns a custom-scheme
 * URL's host into the first path segment -- so `reset-callback` becomes a
 * normal in-app route match, same as any other screen). That screen exists
 * mainly so this hook has an effect to run from; it renders nothing itself.
 */
import { useEffect, useRef } from 'react';
import * as Linking from 'expo-linking';
import { useRouter } from 'expo-router';

import { supabase } from '@/platform/supabase/client';

import { AppRoutes } from './app-routes';
import { handlePasswordRecoveryUrl } from './password-recovery';

export function usePasswordRecoveryRedirect(): void {
  const router = useRouter();
  const url = Linking.useURL();
  // `Linking.useURL()` keeps returning the same string across re-renders
  // once a URL has been seen, so without this guard every unrelated
  // re-render of the screen would re-run `setSession` against the same
  // already-consumed tokens.
  const handledUrlRef = useRef<string | null>(null);

  useEffect(() => {
    if (url == null || url === handledUrlRef.current) {
      return;
    }
    handledUrlRef.current = url;

    void handlePasswordRecoveryUrl(url, supabase.auth).then((handled) => {
      if (handled) {
        router.replace(AppRoutes.resetPassword);
      }
    });
  }, [url, router]);
}
