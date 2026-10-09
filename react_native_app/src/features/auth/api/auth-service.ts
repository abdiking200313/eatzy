/**
 * Ports the sign-in/sign-up-relevant half of
 * `flutter_app/lib/features/auth/data/auth_service.dart`'s `AuthService`
 * (issues #365, #366). `signOut`/`resetPasswordForEmail`/`updatePassword`/
 * `updateEmail`/`getCurrentUserEmail` are out of this issue's scope (reset
 * and later lands with later issues) and are deliberately not ported here.
 *
 * This is the first module under `src/features/**` in this app -- every
 * other feature so far has lived directly under `src/app/**`/`src/stores/**`
 * (see `react_native_app/AGENTS.md`'s navigation note: non-route code stays
 * out of `src/app/**`). `src/app/(auth)/login.tsx` and `src/app/(auth)/
 * register.tsx` are this module's only production callers.
 */
import type { AuthResponse, AuthTokenResponsePassword, Session, User } from '@supabase/supabase-js';

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

/**
 * The sign-up sibling of {@link PasswordSignInSource}, narrowed the same
 * way off `supabase.auth.signUp`.
 */
export interface SignUpSource {
  signUp(credentials: {
    email: string;
    password: string;
    options?: { data?: Record<string, unknown> };
  }): Promise<AuthResponse>;
}

export interface AuthServiceOptions {
  /** Defaults to the real `supabase.auth`. */
  auth?: PasswordSignInSource & SignUpSource;
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
  private readonly auth: PasswordSignInSource & SignUpSource;
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

  /**
   * Mirrors `AuthService.signUpWithEmailPassword`: wraps
   * `supabase.auth.signUp`, same throw-on-error posture as
   * {@link signInWithEmailPassword}. `@supabase/supabase-js` nests the
   * user-metadata payload under `options.data` (unlike `supabase_flutter`'s
   * top-level `data` param) -- the metadata keys themselves
   * (`firstname`/`lastname`/`phone`/`dob`) are left exactly as the Dart
   * original has them since the `handle_new_user` DB trigger reads those
   * literal keys. `dob` is sent as a `'yyyy-MM-dd'` date-only string via
   * `toISOString().split('T')[0]`, the direct JS equivalent of Dart's
   * `dob.toIso8601String().split('T').first` (both always UTC).
   *
   * `session` is `null` in the response when email confirmation is
   * required (Supabase's documented sign-up behavior) and non-null when
   * it's disabled and the user is auto-signed-in; callers branch on that.
   * Mirroring {@link signInWithEmailPassword}, the cached
   * {@link getCurrentUserId} is only updated for the auto-signed-in case
   * (a non-null session) -- there is no session to speak of otherwise.
   */
  async signUpWithEmailPassword(
    email: string,
    password: string,
    details: { firstName: string; lastName: string; phone: string; dob: Date },
  ): Promise<{ user: User; session: Session | null }> {
    const { data, error } = await this.auth.signUp({
      email,
      password,
      options: {
        data: {
          firstname: details.firstName,
          lastname: details.lastName,
          phone: details.phone,
          dob: details.dob.toISOString().split('T')[0],
        },
      },
    });
    if (error) {
      throw error;
    }
    if (data.session) {
      this.currentUserId = data.user!.id;
    }
    return { user: data.user!, session: data.session };
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
