/**
 * Ports `flutter_app/test/auth_service_test.dart`'s sign-in cases (issue
 * #365), sign-up cases (issue #366, this file's own `signUp...` describe
 * block below), the `resetPasswordForEmail`/`updatePassword` cases (issue
 * #368, this file's own `resetPasswordForEmail`/`updatePassword` describe
 * blocks below), and the `passwordRecoveryRedirectUrl` deep-link-scheme
 * assertion (issue #369, this file's own top-level test below).
 * `signOut`/`updateEmail`/`getCurrentUserEmail` remain out of scope and are
 * not ported here (see this file's sibling `auth-service.ts`'s top
 * comment) -- `AuthService` has no `signOut` method yet, so there is
 * nothing to exercise; a future issue implementing it should add the
 * matching test then.
 */
import type { AuthApiError, AuthError, AuthResponse, AuthTokenResponsePassword, UserResponse } from '@supabase/supabase-js';

import { PASSWORD_RECOVERY_REDIRECT_URL } from '@/platform/navigation/password-recovery';

import {
  AuthService,
  type PasswordResetRequestSource,
  type PasswordSignInSource,
  type PasswordSignUpSource,
  type PasswordUpdateSource,
} from './auth-service';

// `auth-service.ts` imports the real `@/platform/supabase/client` as its
// default `auth` dependency, used only when a test doesn't inject its own
// (every test below does) -- see `merchant-role-service.test.ts`'s own
// top comment for why that module needs a stub rather than a bare `{}`
// under Jest (it loads env vars at import time, which aren't set here).
jest.mock('@/platform/supabase/client', () => ({ supabase: { auth: {} } }));

function okResponse(userId: string, email: string): AuthTokenResponsePassword {
  const user = {
    id: userId,
    aud: 'authenticated',
    email,
    app_metadata: {},
    user_metadata: {},
    created_at: new Date().toISOString(),
  };
  const session = {
    access_token: 'mock-access-token',
    refresh_token: 'mock-refresh-token',
    expires_in: 3600,
    token_type: 'bearer',
    user,
  };
  return { data: { user, session }, error: null } as unknown as AuthTokenResponsePassword;
}

function errorResponse(code: string, status: number): AuthTokenResponsePassword {
  return {
    data: { user: null, session: null },
    error: { name: 'AuthApiError', message: 'Invalid login credentials', status, code } as AuthApiError,
  } as unknown as AuthTokenResponsePassword;
}

describe('AuthService', () => {
  test('getCurrentUserId is null before any sign-in', () => {
    const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
      signInWithPassword: jest.fn(),
      signUp: jest.fn(),
      resetPasswordForEmail: jest.fn(),
      updateUser: jest.fn(),
    };
    const service = new AuthService({ auth });

    expect(service.getCurrentUserId()).toBeNull();
  });

  // Ports `auth_service_test.dart`'s `'passwordRecoveryRedirectUrl matches
  // the configured deep link scheme'`. The Dart original asserts a static
  // `AuthService.passwordRecoveryRedirectUrl` constant; this app's
  // equivalent value lives on `password-recovery.ts` instead (see that
  // module's own doc comment) and is asserted the same way here, cross-
  // checked against `app.json`'s registered scheme the same way `deep-
  // link-scheme.test.ts` does for the track-order deep link.
  test('PASSWORD_RECOVERY_REDIRECT_URL matches the configured deep link scheme', () => {
    expect(PASSWORD_RECOVERY_REDIRECT_URL).toBe('zivo://reset-callback');
  });

  test('signInWithEmailPassword establishes a session on valid credentials', async () => {
    const signInWithPassword = jest.fn().mockResolvedValue(okResponse('mock-user-id', 'user@example.com'));
    const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
      signInWithPassword,
      signUp: jest.fn(),
      resetPasswordForEmail: jest.fn(),
      updateUser: jest.fn(),
    };
    const service = new AuthService({ auth });

    const response = await service.signInWithEmailPassword('user@example.com', 'correct-password');

    expect(response.session).not.toBeNull();
    expect(response.user.id).toBe('mock-user-id');
    expect(signInWithPassword).toHaveBeenCalledWith({
      email: 'user@example.com',
      password: 'correct-password',
    });
    expect(service.getCurrentUserId()).toBe('mock-user-id');
  });

  test('signInWithEmailPassword throws the Supabase error for invalid credentials and leaves no session behind', async () => {
    const signInWithPassword = jest.fn().mockResolvedValue(errorResponse('invalid_credentials', 400));
    const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
      signInWithPassword,
      signUp: jest.fn(),
      resetPasswordForEmail: jest.fn(),
      updateUser: jest.fn(),
    };
    const service = new AuthService({ auth });

    await expect(service.signInWithEmailPassword('user@example.com', 'wrong-password')).rejects.toMatchObject({
      code: 'invalid_credentials',
      status: 400,
    });
    expect(service.getCurrentUserId()).toBeNull();
  });

  test('a failed sign-in after a previously successful one clears the cached user id', async () => {
    const signInWithPassword = jest
      .fn()
      .mockResolvedValueOnce(okResponse('mock-user-id', 'user@example.com'))
      .mockResolvedValueOnce(errorResponse('invalid_credentials', 400));
    const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
      signInWithPassword,
      signUp: jest.fn(),
      resetPasswordForEmail: jest.fn(),
      updateUser: jest.fn(),
    };
    const service = new AuthService({ auth });

    await service.signInWithEmailPassword('user@example.com', 'correct-password');
    expect(service.getCurrentUserId()).toBe('mock-user-id');

    await expect(service.signInWithEmailPassword('user@example.com', 'wrong-password')).rejects.toBeTruthy();
    expect(service.getCurrentUserId()).toBeNull();
  });

  describe('signUpWithEmailPassword', () => {
    function signUpOkResponse(userId: string, email: string): AuthResponse {
      const user = {
        id: userId,
        aud: 'authenticated',
        email,
        app_metadata: {},
        user_metadata: {},
        created_at: new Date().toISOString(),
      };
      const session = {
        access_token: 'mock-access-token',
        refresh_token: 'mock-refresh-token',
        expires_in: 3600,
        token_type: 'bearer',
        user,
      };
      return { data: { user, session }, error: null } as unknown as AuthResponse;
    }

    function signUpNoSessionResponse(userId: string, email: string): AuthResponse {
      // A brand-new sign-up when email confirmation is required: GoTrue
      // returns the created user but no session until the confirmation
      // link is tapped.
      const user = {
        id: userId,
        aud: 'authenticated',
        email,
        app_metadata: {},
        user_metadata: {},
        created_at: new Date().toISOString(),
      };
      return { data: { user, session: null }, error: null } as unknown as AuthResponse;
    }

    function signUpErrorResponse(code: string, status: number): AuthResponse {
      return {
        data: { user: null, session: null },
        error: { name: 'AuthApiError', message: 'User already registered', status, code } as AuthApiError,
      } as unknown as AuthResponse;
    }

    test('establishes a session for a brand-new user', async () => {
      const signUp = jest.fn().mockResolvedValue(signUpOkResponse('new-user-id', 'new@example.com'));
      const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
        signInWithPassword: jest.fn(),
        signUp,
        resetPasswordForEmail: jest.fn(),
        updateUser: jest.fn(),
      };
      const service = new AuthService({ auth });

      const response = await service.signUpWithEmailPassword('new@example.com', 'a-strong-password', {
        firstName: 'Jane',
        lastName: 'Doe',
        phone: '+15551234567',
        dob: new Date(1995, 5, 15),
      });

      expect(response.session).not.toBeNull();
      expect(response.user?.id).toBe('new-user-id');
    });

    test('forwards first/last name, phone, and dob as signup metadata', async () => {
      const signUp = jest.fn().mockResolvedValue(signUpOkResponse('new-user-id', 'new@example.com'));
      const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
        signInWithPassword: jest.fn(),
        signUp,
        resetPasswordForEmail: jest.fn(),
        updateUser: jest.fn(),
      };
      const service = new AuthService({ auth });

      await service.signUpWithEmailPassword('new@example.com', 'a-strong-password', {
        firstName: 'Jane',
        lastName: 'Doe',
        phone: '+15551234567',
        dob: new Date(1995, 5, 15),
      });

      expect(signUp).toHaveBeenCalledWith({
        email: 'new@example.com',
        password: 'a-strong-password',
        options: {
          data: {
            firstname: 'Jane',
            lastname: 'Doe',
            phone: '+15551234567',
            dob: '1995-06-15',
          },
        },
      });
    });

    test('returns a null session (pending email confirmation) without throwing', async () => {
      const signUp = jest.fn().mockResolvedValue(signUpNoSessionResponse('new-user-id', 'new@example.com'));
      const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
        signInWithPassword: jest.fn(),
        signUp,
        resetPasswordForEmail: jest.fn(),
        updateUser: jest.fn(),
      };
      const service = new AuthService({ auth });

      const response = await service.signUpWithEmailPassword('new@example.com', 'a-strong-password', {
        firstName: 'Jane',
        lastName: 'Doe',
        phone: '+15551234567',
        dob: new Date(1995, 5, 15),
      });

      expect(response.session).toBeNull();
      expect(response.user?.id).toBe('new-user-id');
    });

    test('throws the Supabase error for a duplicate email', async () => {
      const signUp = jest.fn().mockResolvedValue(signUpErrorResponse('user_already_exists', 422));
      const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
        signInWithPassword: jest.fn(),
        signUp,
        resetPasswordForEmail: jest.fn(),
        updateUser: jest.fn(),
      };
      const service = new AuthService({ auth });

      await expect(
        service.signUpWithEmailPassword('existing@example.com', 'a-strong-password', {
          firstName: 'Jane',
          lastName: 'Doe',
          phone: '+15551234567',
          dob: new Date(1995, 5, 15),
        }),
      ).rejects.toMatchObject({ code: 'user_already_exists', status: 422 });
    });
  });

  describe('resetPasswordForEmail', () => {
    test('requests a password reset with the recovery redirect URL', async () => {
      const resetPasswordForEmail = jest.fn().mockResolvedValue({ data: {}, error: null });
      const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
        signInWithPassword: jest.fn(),
        signUp: jest.fn(),
        resetPasswordForEmail,
        updateUser: jest.fn(),
      };
      const service = new AuthService({ auth });

      await service.resetPasswordForEmail('user@example.com');

      expect(resetPasswordForEmail).toHaveBeenCalledWith('user@example.com', {
        redirectTo: PASSWORD_RECOVERY_REDIRECT_URL,
      });
    });

    test('propagates the Supabase error', async () => {
      const error = { name: 'AuthApiError', message: 'Too many requests', status: 429 } as AuthError;
      const resetPasswordForEmail = jest.fn().mockResolvedValue({ data: null, error });
      const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
        signInWithPassword: jest.fn(),
        signUp: jest.fn(),
        resetPasswordForEmail,
        updateUser: jest.fn(),
      };
      const service = new AuthService({ auth });

      await expect(service.resetPasswordForEmail('user@example.com')).rejects.toBe(error);
    });
  });

  describe('updatePassword', () => {
    function updateUserOkResponse(userId: string, email: string): UserResponse {
      const user = {
        id: userId,
        aud: 'authenticated',
        email,
        app_metadata: {},
        user_metadata: {},
        created_at: new Date().toISOString(),
      };
      return { data: { user }, error: null } as unknown as UserResponse;
    }

    test('updates the password for the current session', async () => {
      const updateUser = jest.fn().mockResolvedValue(updateUserOkResponse('mock-user-id', 'user@example.com'));
      const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
        signInWithPassword: jest.fn(),
        signUp: jest.fn(),
        resetPasswordForEmail: jest.fn(),
        updateUser,
      };
      const service = new AuthService({ auth });

      const response = await service.updatePassword('a-new-password');

      expect(updateUser).toHaveBeenCalledWith({ password: 'a-new-password' });
      expect(response.data.user?.id).toBe('mock-user-id');
    });

    test('propagates the Supabase error (e.g. no active session)', async () => {
      const error = { name: 'AuthSessionMissingException', message: 'Auth session missing', status: 400 } as AuthError;
      const updateUser = jest.fn().mockResolvedValue({ data: { user: null }, error });
      const auth: PasswordSignInSource & PasswordSignUpSource & PasswordResetRequestSource & PasswordUpdateSource = {
        signInWithPassword: jest.fn(),
        signUp: jest.fn(),
        resetPasswordForEmail: jest.fn(),
        updateUser,
      };
      const service = new AuthService({ auth });

      await expect(service.updatePassword('a-new-password')).rejects.toBe(error);
    });
  });
});
