/**
 * Ports `flutter_app/lib/features/auth/data/auth_service.dart`'s
 * `AuthService`: the sign-in half landed in issue #365
 * (`signInWithEmailPassword`/`getCurrentUserId`), sign-up landed in issue
 * #366 (`signUpWithEmailPassword`), and this issue (#368) adds
 * `resetPasswordForEmail`/`updatePassword`. `signOut`/`updateEmail`/
 * `getCurrentUserEmail` remain out of scope and are deliberately not ported
 * here yet.
 *
 * This is the first module under `src/features/**` in this app -- every
 * other feature so far has lived directly under `src/app/**`/`src/stores/**`
 * (see `react_native_app/AGENTS.md`'s navigation note: non-route code stays
 * out of `src/app/**`). `src/app/(auth)/login.tsx` and
 * `src/app/(auth)/register.tsx` are this module's only production callers.
 */
import type { AuthResponse, AuthTokenResponsePassword, Session, User, UserResponse } from '@supabase/supabase-js';

import { PASSWORD_RECOVERY_REDIRECT_URL } from '@/platform/navigation/password-recovery';
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

/** The sign-up-relevant slice of `supabase.auth` -- see {@link PasswordSignInSource}'s doc comment. */
export interface PasswordSignUpSource {
  signUp(credentials: {
    email: string;
    password: string;
    options?: { data?: Record<string, unknown> };
  }): Promise<AuthResponse>;
}

/** The password-reset-request-relevant slice of `supabase.auth` -- see {@link PasswordSignInSource}'s doc comment. */
export interface PasswordResetRequestSource {
  resetPasswordForEmail(
    email: string,
    options?: { redirectTo?: string },
  ): Promise<{ data: object | null; error: Error | null }>;
}

/** The password-update-relevant slice of `supabase.auth` -- see {@link PasswordSignInSource}'s doc comment. */
export interface PasswordUpdateSource {
  updateUser(attributes: { password: string }): Promise<UserResponse>;
}

export interface AuthServiceOptions {
  /** Defaults to the real `supabase.auth`. */
  auth?: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource;
}

/** The new-account fields `register.tsx` collects beyond email/password, forwarded as Supabase sign-up metadata. Mirrors `AuthService.signUpWithEmailPassword`'s `firstName`/`lastName`/`phone`/`dob` named parameters. */
export interface SignUpDetails {
  firstName: string;
  lastName: string;
  phone: string;
  dob: Date;
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
  private readonly auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource;
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

  /**
   * Mirrors `AuthService.signUpWithEmailPassword`: wraps
   * `supabase.auth.signUp`, forwarding `firstName`/`lastName`/`phone`/`dob`
   * as the `data` sign-up metadata object GoTrue stores on the new user --
   * same `firstname`/`lastname`/`phone`/`dob` keys the Dart service sends,
   * so any Postgres trigger reading this metadata keeps working unchanged.
   *
   * Unlike {@link signInWithEmailPassword}, this does not touch
   * {@link getCurrentUserId}'s cache: the Dart original has no equivalent
   * caching at all (it re-reads `currentSession` on every call), and no
   * current call site needs the newly-created user's id back out of this
   * method -- `register.tsx` only branches on whether the response carries
   * a `session`.
   *
   * `dob` is sent as a `yyyy-MM-dd` string (matching a `date` column), built
   * from `dob`'s local year/month/day fields by {@link toDateOnlyString} --
   * deliberately not `dob.toISOString().split('T')[0]`, which converts to
   * UTC first and can shift the date by a day depending on the device's
   * timezone offset. Dart's `dob.toIso8601String()` has no such shift,
   * because an unspecified-UTC `DateTime` serializes its own local fields
   * verbatim rather than converting them.
   */
  async signUpWithEmailPassword(
    email: string,
    password: string,
    details: SignUpDetails,
  ): Promise<{ user: User | null; session: Session | null }> {
    const { firstName, lastName, phone, dob } = details;
    const { data, error } = await this.auth.signUp({
      email,
      password,
      options: {
        data: {
          firstname: firstName,
          lastname: lastName,
          phone,
          dob: toDateOnlyString(dob),
        },
      },
    });
    if (error) {
      throw error;
    }
    return data;
  }

  /**
   * Mirrors `AuthService.resetPasswordForEmail`: wraps `supabase.auth.
   * resetPasswordForEmail`, passing {@link PASSWORD_RECOVERY_REDIRECT_URL}
   * as `redirectTo` -- the same deep link `AppRoutes.resetPassword`'s
   * recovery-session handling expects (see `password-recovery.ts`'s doc
   * comment). Does not touch {@link getCurrentUserId}'s cache: requesting a
   * reset email neither signs the caller in nor out.
   */
  async resetPasswordForEmail(email: string): Promise<void> {
    const { error } = await this.auth.resetPasswordForEmail(email, {
      redirectTo: PASSWORD_RECOVERY_REDIRECT_URL,
    });
    if (error) {
      throw error;
    }
  }

  /**
   * Mirrors `AuthService.updatePassword`: wraps `supabase.auth.updateUser`
   * with just the new password. Works both for a normal signed-in session
   * (change password from Settings) and for the short-lived recovery
   * session `resetPasswordForEmail`'s link starts -- same as the Dart
   * original.
   */
  async updatePassword(newPassword: string): Promise<UserResponse> {
    const { data, error } = await this.auth.updateUser({ password: newPassword });
    if (error) {
      throw error;
    }
    return { data, error };
  }
}

/** `yyyy-MM-dd`, built from local date fields -- see {@link AuthService.signUpWithEmailPassword}'s doc comment for why not `toISOString()`. */
function toDateOnlyString(date: Date): string {
  const year = String(date.getFullYear()).padStart(4, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * The app-wide `AuthService`. `src/app/(auth)/login.tsx` imports this
 * directly (no DI at the screen level, the same posture `use-password-
 * recovery-redirect.ts` takes with the shared `supabase` singleton) --
 * tests inject their own instance via {@link AuthServiceOptions} instead.
 */
export const authService = new AuthService();
