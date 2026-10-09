/**
 * Ports the sign-in-relevant cases of `flutter_app/test/auth_service_test.dart`
 * (issue #365). Sign-up/reset/other methods are out of this issue's scope
 * (not ported here, see this file's sibling `auth-service.ts`'s top
 * comment).
 */
import type { AuthApiError, AuthTokenResponsePassword } from '@supabase/supabase-js';

import { AuthService, type PasswordSignInSource } from './auth-service';

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
    const auth: PasswordSignInSource = { signInWithPassword: jest.fn() };
    const service = new AuthService({ auth });

    expect(service.getCurrentUserId()).toBeNull();
  });

  test('signInWithEmailPassword establishes a session on valid credentials', async () => {
    const signInWithPassword = jest.fn().mockResolvedValue(okResponse('mock-user-id', 'user@example.com'));
    const auth: PasswordSignInSource = { signInWithPassword };
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
    const auth: PasswordSignInSource = { signInWithPassword };
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
    const auth: PasswordSignInSource = { signInWithPassword };
    const service = new AuthService({ auth });

    await service.signInWithEmailPassword('user@example.com', 'correct-password');
    expect(service.getCurrentUserId()).toBe('mock-user-id');

    await expect(service.signInWithEmailPassword('user@example.com', 'wrong-password')).rejects.toBeTruthy();
    expect(service.getCurrentUserId()).toBeNull();
  });
});
