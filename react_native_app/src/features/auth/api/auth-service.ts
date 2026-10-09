/**
 * Ports the sign-in-relevant half of
 * `flutter_app/lib/features/auth/data/auth_service.dart`'s `AuthService`
 * (issue #365). `signUpWithEmailPassword`/`signOut`/`resetPasswordForEmail`/
 * `updatePassword`/`updateEmail`/`getCurrentUserEmail` are out of this
 * issue's scope (sign-up/reset land with #366 and later) and are
 * deliberately not ported here.
 *
 * This is the first module under `src/features/**` in this app -- every
 * other feature so far has lived directly under `src/app/**`/`src/stores/**`
 * (see `react_native_app/AGENTS.md`'s navigation note: non-route code stays
 * out of `src/app/**`). `src/app/(auth)/login.tsx` is this module's only
 * production caller.
 */
import type { AuthTokenResponsePassword, Session, User } from '@supabase/supabase-js';

import { supabase } from '@/platform/supabase/client';

/**
 * The slice of `supabase.auth` {@link AuthService} depends on, narrowed the
 * same way `session-store.ts`'s `AuthStateSource` / `merchant-role-
 * service.ts`'s `ProfileRoleSource` narrow their own Supabase dependencies
 * -- lets a test inject a fake instead of the real client.
 */
export interface PasswordSignInSource {
  signInWithPassword(credentials: {
    email: string;
    password: string;
  }): Promise<AuthTokenResponsePassword>;
}

export interface AuthServiceOptions {
  /** Defaults to the real `supabase.auth`. */
  auth?: PasswordSignInSource;
}

/**
 * Submits a sign-in request and remembers the signed-in user's id for
 * {@link getCurrentUserId}, the way Dart's `AuthService.getCurrentUserId`
 * reads it back off the Supabase SDK's own in-memory `currentSession`.
 * `@supabase/supabase-js` (unlike `supabase_flutter`) has no synchronous
 * session getter -- only the async `auth.getSession()` -- so this caches
 * the id itself off the sign-in response instead of re-querying the SDK,
 * keeping {@link getCurrentUserId} synchronous like the Dart original.
 */
export class AuthService {
  private readonly auth: PasswordSignInSource;
  private currentUserId: string | null = null;

  constructor(options: AuthServiceOptions = {}) {
    this.auth = options.auth ?? supabase.auth;
  }

  /**
   * Mirrors `AuthService.signInWithEmailPassword`: wraps
   * `supabase.auth.signInWithPassword`. `@supabase/supabase-js` resolves
   * with `{ data, error }` rather than throwing (unlike
   * `supabase_flutter`'s `AuthException`-throwing equivalent) -- this
   * throws `error` itself on failure so call sites (in particular
   * `describeAuthError`'s `catch` pattern) can stay a 1:1 port of the Dart
   * screen's try/catch.
   */
  async signInWithEmailPassword(email: string, password: string): Promise<{ user: User; session: Session }> {
    const { data, error } = await this.auth.signInWithPassword({ email, password });
    if (error) {
      this.currentUserId = null;
      throw error;
    }
    this.currentUserId = data.user.id;
    return data;
  }

  /** Mirrors `AuthService.getCurrentUserId` -- see this class's doc comment for why it's cached rather than re-queried. */
  getCurrentUserId(): string | null {
    return this.currentUserId;
  }
}

/**
 * The app-wide `AuthService`. `src/app/(auth)/login.tsx` imports this
 * directly (no DI at the screen level, the same posture `use-password-
 * recovery-redirect.ts` takes with the shared `supabase` singleton) --
 * tests inject their own instance via {@link AuthServiceOptions} instead.
 */
export const authService = new AuthService();
