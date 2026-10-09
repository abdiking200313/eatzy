/**
 * Ports the sign-in/sign-up-relevant cases of
 * `flutter_app/test/auth_service_test.dart` (issues #365, #366).
 * Reset/other methods are out of scope (not ported here, see this file's
 * sibling `auth-service.ts`'s top comment).
 */
import type { AuthApiError, AuthResponse, AuthTokenResponsePassword } from '@supabase/supabase-js';

import { AuthService, type PasswordSignInSource, type SignUpSource } from './auth-service';

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

function okSignUpResponse(userId: string, email: string, session: boolean): AuthResponse {
  const user = {
    id: userId,
    aud: 'authenticated',
    email,
    app_metadata: {},
    user_metadata: {},
    created_at: new Date().toISOString(),
  };
  return {
    data: {
      user,
      session: session
        ? {
            access_token: 'mock-access-token',
            refresh_token: 'mock-refresh-token',
            expires_in: 3600,
            token_type: 'bearer',
            user,
          }
        : null,
    },
    error: null,
  } as unknown as AuthResponse;
}

function errorSignUpResponse(code: string, status: number): AuthResponse {
  return {
    data: { user: null, session: null },
    error: { name: 'AuthApiError', message: 'User already registered', status, code } as AuthApiError,
  } as unknown as AuthResponse;
}

describe('AuthService', () => {
  test('getCurrentUserId is null before any sign-in', () => {
    const auth: PasswordSignInSource & SignUpSource = { signInWithPassword: jest.fn(), signUp: jest.fn() };
    const service = new AuthService({ auth });

    expect(service.getCurrentUserId()).toBeNull();
  });

  test('signInWithEmailPassword establishes a session on valid credentials', async () => {
    const signInWithPassword = jest.fn().mockResolvedValue(okResponse('mock-user-id', 'user@example.com'));
    const auth: PasswordSignInSource & SignUpSource = { signInWithPassword, signUp: jest.fn() };
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
    const auth: PasswordSignInSource & SignUpSource = { signInWithPassword, signUp: jest.fn() };
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
    const auth: PasswordSignInSource & SignUpSource = { signInWithPassword, signUp: jest.fn() };
    const service = new AuthService({ auth });

    await service.signInWithEmailPassword('user@example.com', 'correct-password');
    expect(service.getCurrentUserId()).toBe('mock-user-id');

    await expect(service.signInWithEmailPassword('user@example.com', 'wrong-password')).rejects.toBeTruthy();
    expect(service.getCurrentUserId()).toBeNull();
  });

  test('signUpWithEmailPassword sends the exact metadata keys the handle_new_user trigger reads, dob as yyyy-MM-dd', async () => {
    const signUp = jest.fn().mockResolvedValue(okSignUpResponse('mock-user-id', 'new@example.com', true));
    const auth: PasswordSignInSource & SignUpSource = { signInWithPassword: jest.fn(), signUp };
    const service = new AuthService({ auth });

    const response = await service.signUpWithEmailPassword('new@example.com', 'correct-password', {
      firstName: 'Ada',
      lastName: 'Lovelace',
      phone: '+15551234567',
      dob: new Date('1990-06-15T12:34:56Z'),
    });

    expect(signUp).toHaveBeenCalledWith({
      email: 'new@example.com',
      password: 'correct-password',
      options: {
        data: {
          firstname: 'Ada',
          lastname: 'Lovelace',
          phone: '+15551234567',
          dob: '1990-06-15',
        },
      },
    });
    expect(response.user.id).toBe('mock-user-id');
    expect(response.session).not.toBeNull();
    expect(service.getCurrentUserId()).toBe('mock-user-id');
  });

  test('signUpWithEmailPassword returns a null session when email confirmation is required, and does not cache a user id', async () => {
    const signUp = jest.fn().mockResolvedValue(okSignUpResponse('mock-user-id', 'new@example.com', false));
    const auth: PasswordSignInSource & SignUpSource = { signInWithPassword: jest.fn(), signUp };
    const service = new AuthService({ auth });

    const response = await service.signUpWithEmailPassword('new@example.com', 'correct-password', {
      firstName: 'Ada',
      lastName: 'Lovelace',
      phone: '+15551234567',
      dob: new Date('1990-06-15T12:34:56Z'),
    });

    expect(response.session).toBeNull();
    expect(response.user.id).toBe('mock-user-id');
    expect(service.getCurrentUserId()).toBeNull();
  });

  test('signUpWithEmailPassword throws the Supabase error for an already-registered email', async () => {
    const signUp = jest.fn().mockResolvedValue(errorSignUpResponse('user_already_exists', 422));
    const auth: PasswordSignInSource & SignUpSource = { signInWithPassword: jest.fn(), signUp };
    const service = new AuthService({ auth });

    await expect(
      service.signUpWithEmailPassword('new@example.com', 'correct-password', {
        firstName: 'Ada',
        lastName: 'Lovelace',
        phone: '+15551234567',
        dob: new Date('1990-06-15T12:34:56Z'),
      }),
    ).rejects.toMatchObject({ code: 'user_already_exists', status: 422 });
    expect(service.getCurrentUserId()).toBeNull();
  });
});
