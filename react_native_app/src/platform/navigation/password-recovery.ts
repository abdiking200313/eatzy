/**
 * Ports the password-recovery deep link handling split between
 * `flutter_app/lib/features/auth/data/auth_service.dart`
 * (`passwordRecoveryRedirectUrl`) and `flutter_app/lib/app/app_router.dart`'s
 * `_AuthStateRefresh` (`AuthChangeEvent.passwordRecovery` -> `go(AppRoutes.
 * resetPassword)`) (issue #361).
 *
 * On Flutter, `supabase_flutter` registers its own native deep-link
 * listener and parses `passwordRecoveryRedirectUrl` itself -- by the time
 * `app_router.dart` sees anything, Supabase has already started the
 * recovery session and all `_AuthStateRefresh` has to do is redirect once it
 * observes the resulting `AuthChangeEvent.passwordRecovery` event.
 * `@supabase/supabase-js` has no native URL listener on React Native
 * (`detectSessionInUrl` is web-only -- see `src/platform/supabase/
 * client.ts`'s comment on why it's off here), so this module does both
 * halves of that job itself: parse the tokens Supabase appended to the
 * redirect URL, and start the session with them. `use-password-recovery-
 * redirect.ts` is what actually wires this to an incoming URL and redirects
 * to `AppRoutes.resetPassword` -- this file is the pure, testable half.
 */

/**
 * The deep link Supabase redirects the user to after tapping a
 * password-recovery email link. Must exactly match `AuthService.
 * passwordRecoveryRedirectUrl` on the Flutter side and the `zivo` scheme
 * registered in `app.json`. Whoever wires up the "forgot password" form's
 * `supabase.auth.resetPasswordForEmail(email, { redirectTo })` call should
 * pass this constant as `redirectTo`.
 */
export const PASSWORD_RECOVERY_REDIRECT_URL = 'zivo://reset-callback';

// The host segment of `PASSWORD_RECOVERY_REDIRECT_URL` once parsed as a URL
// -- for a custom-scheme URL like `zivo://reset-callback`, `reset-callback`
// is what `new URL(...)` (and Expo Router's own native deep-link path
// extraction -- see `node_modules/expo-router/build/fork/
// extractPathFromURL.js`'s `fromDeepLink`) parses as the host, not the path.
const RECOVERY_CALLBACK_HOST = new URL(PASSWORD_RECOVERY_REDIRECT_URL).hostname;

export interface PasswordRecoveryTokens {
  accessToken: string;
  refreshToken: string;
}

/**
 * Parses a `PASSWORD_RECOVERY_REDIRECT_URL` deep link, returning the
 * access/refresh tokens to start a session with, or `null` when `url` isn't
 * a recognizable password-recovery link (wrong host, not a recovery link,
 * or missing tokens).
 *
 * Supabase's implicit auth flow (this app's default -- `client.ts` sets no
 * `flowType`) appends the tokens as a URL *fragment*
 * (`#access_token=...&refresh_token=...&type=recovery`), the same shape a
 * browser-based `detectSessionInUrl` would consume. A query string
 * (`?access_token=...`) is accepted too, in case a future change switches
 * to the PKCE flow's redirect shape.
 */
export function parsePasswordRecoveryUrl(url: string): PasswordRecoveryTokens | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }

  if (parsed.hostname !== RECOVERY_CALLBACK_HOST) {
    return null;
  }

  const fragment = parsed.hash.startsWith('#') ? parsed.hash.slice(1) : parsed.hash;
  const params = new URLSearchParams(fragment.length > 0 ? fragment : parsed.search);

  if (params.get('type') !== 'recovery') {
    return null;
  }

  const accessToken = params.get('access_token');
  const refreshToken = params.get('refresh_token');
  if (!accessToken || !refreshToken) {
    return null;
  }

  return { accessToken, refreshToken };
}

/**
 * The slice of `supabase.auth` {@link handlePasswordRecoveryUrl} depends
 * on, narrowed the same way `session-store.ts`'s `AuthStateSource` is --
 * lets a test inject a fake instead of the real client.
 */
export interface PasswordRecoverySessionSource {
  setSession(tokens: { access_token: string; refresh_token: string }): Promise<unknown>;
}

/**
 * Parses `url` with {@link parsePasswordRecoveryUrl} and, when it's a
 * recovery link, starts the session Supabase created for it via `auth.
 * setSession`. Returns `true` when a session was started (the caller should
 * then navigate to `AppRoutes.resetPassword`), `false` otherwise (`url` was
 * not a password-recovery link).
 */
export async function handlePasswordRecoveryUrl(
  url: string,
  auth: PasswordRecoverySessionSource,
): Promise<boolean> {
  const tokens = parsePasswordRecoveryUrl(url);
  if (tokens == null) {
    return false;
  }

  await auth.setSession({
    access_token: tokens.accessToken,
    refresh_token: tokens.refreshToken,
  });
  return true;
}
