/**
 * No equivalent test exists in `flutter_app` for `generateIdempotencyKey`
 * (checked `flutter_app/test/` directly -- it is untested there too), so
 * this is a new test covering the one real contract callers rely on: a
 * 32-character lowercase hex string, fresh on every call.
 */
import { generateIdempotencyKey } from './idempotency-key';

describe('generateIdempotencyKey', () => {
  it('returns a 32-character lowercase hex string', () => {
    const key = generateIdempotencyKey();

    expect(key).toMatch(/^[0-9a-f]{32}$/);
  });

  it('returns a different key on every call', () => {
    const keys = new Set(Array.from({ length: 20 }, () => generateIdempotencyKey()));

    expect(keys.size).toBe(20);
  });
});
