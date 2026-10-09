/**
 * Exercises {@link parsePasswordRecoveryUrl}/{@link handlePasswordRecoveryUrl}
 * against the exact deep link shapes Supabase sends (issue #361). There's no
 * Flutter test to port here -- `AuthService`'s half of this is a thin
 * wrapper around `supabase_flutter`'s own URL parsing, which this app has to
 * reimplement itself (see this file's top comment) -- so these cases are
 * written directly from Supabase's documented implicit-flow redirect shape.
 */
import {
  PASSWORD_RECOVERY_REDIRECT_URL,
  handlePasswordRecoveryUrl,
  parsePasswordRecoveryUrl,
  type PasswordRecoverySessionSource,
} from './password-recovery';

describe('parsePasswordRecoveryUrl', () => {
  it('parses the access/refresh tokens from the implicit flow fragment', () => {
    const url = `${PASSWORD_RECOVERY_REDIRECT_URL}#access_token=abc&refresh_token=def&expires_in=3600&token_type=bearer&type=recovery`;

    expect(parsePasswordRecoveryUrl(url)).toEqual({
      accessToken: 'abc',
      refreshToken: 'def',
    });
  });

  it('also accepts the tokens as a query string', () => {
    const url = `${PASSWORD_RECOVERY_REDIRECT_URL}?access_token=abc&refresh_token=def&type=recovery`;

    expect(parsePasswordRecoveryUrl(url)).toEqual({
      accessToken: 'abc',
      refreshToken: 'def',
    });
  });

  it('returns null for a link to a different host', () => {
    const url = 'zivo://track-order/food/order-1#access_token=abc&refresh_token=def&type=recovery';

    expect(parsePasswordRecoveryUrl(url)).toBeNull();
  });

  it('returns null when type is not recovery (e.g. an email-change confirmation)', () => {
    const url = `${PASSWORD_RECOVERY_REDIRECT_URL}#access_token=abc&refresh_token=def&type=signup`;

    expect(parsePasswordRecoveryUrl(url)).toBeNull();
  });

  it('returns null when a token is missing', () => {
    const url = `${PASSWORD_RECOVERY_REDIRECT_URL}#access_token=abc&type=recovery`;

    expect(parsePasswordRecoveryUrl(url)).toBeNull();
  });

  it('returns null for a malformed URL', () => {
    expect(parsePasswordRecoveryUrl('not a url')).toBeNull();
  });
});

describe('handlePasswordRecoveryUrl', () => {
  function fakeAuth(): PasswordRecoverySessionSource & { setSession: jest.Mock } {
    return { setSession: jest.fn().mockResolvedValue(undefined) };
  }

  it('starts the session and returns true for a valid recovery link', async () => {
    const auth = fakeAuth();
    const url = `${PASSWORD_RECOVERY_REDIRECT_URL}#access_token=abc&refresh_token=def&type=recovery`;

    const handled = await handlePasswordRecoveryUrl(url, auth);

    expect(handled).toBe(true);
    expect(auth.setSession).toHaveBeenCalledWith({ access_token: 'abc', refresh_token: 'def' });
  });

  it('does nothing and returns false for an unrelated link', async () => {
    const auth = fakeAuth();

    const handled = await handlePasswordRecoveryUrl('zivo://track-order/food/order-1', auth);

    expect(handled).toBe(false);
    expect(auth.setSession).not.toHaveBeenCalled();
  });
});
