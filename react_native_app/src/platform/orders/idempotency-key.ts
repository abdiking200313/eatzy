/**
 * Ports `flutter_app/lib/services/shared/data/idempotency_key.dart`'s
 * `generateIdempotencyKey` (issue #378 / P5-03).
 */
import { getRandomBytes } from 'expo-crypto';

/**
 * Generates a random idempotency token for a single checkout attempt.
 *
 * Not a full RFC 4122 UUID -- just 128 bits of randomness rendered as a
 * 32-character lowercase hex string, which is all `place_food_order`,
 * `place_grocery_order`, and `place_pharmacy_order` need to collapse a
 * retried submission into the original order instead of creating a
 * duplicate.
 *
 * Callers should generate this once per checkout *attempt* -- e.g. when a
 * checkout screen is first mounted -- and keep reusing the same value for
 * every retry of that same attempt (a failed submission the user retries
 * without leaving the screen), so a lost response followed by a retry
 * collapses server-side instead of creating a second order. Generate a new
 * key only once a fresh checkout attempt begins (a new visit to the
 * checkout screen after a prior order succeeded or was abandoned).
 */
export function generateIdempotencyKey(): string {
  const bytes = getRandomBytes(16);
  let hex = '';
  for (const byte of bytes) {
    hex += byte.toString(16).padStart(2, '0');
  }
  return hex;
}
