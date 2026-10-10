/**
 * Ports `flutter_app/lib/features/profile/models/customer_profile.dart`
 * (issue #399 / P8-03): the signed-in customer's own `profiles` row.
 */
export interface CustomerProfile {
  id: string;
  firstName: string;
  lastName: string;
  phone: string;
  avatarUrl: string | null;
  dob: Date | null;
}

/** Fallback shown wherever the customer has no name on file -- same string the Dart model and `ProfileScreen` use. */
export const DEFAULT_CUSTOMER_DISPLAY_NAME = 'Zivo customer';

/** Mirrors `CustomerProfile.displayName`. */
export function customerDisplayName(profile: Pick<CustomerProfile, 'firstName' | 'lastName'>): string {
  const name = [profile.firstName, profile.lastName].join(' ').trim();
  return name === '' ? DEFAULT_CUSTOMER_DISPLAY_NAME : name;
}

/** Thrown by {@link parseCustomerProfile} for a row missing `id` -- mirrors the Dart `FormatException`. */
export class CustomerProfileFormatError extends Error {
  constructor(key: string) {
    super(`Missing required profile field: ${key}`);
    this.name = 'CustomerProfileFormatError';
  }
}

/** Mirrors `CustomerProfile.fromMap`. */
export function parseCustomerProfile(map: Record<string, unknown>): CustomerProfile {
  return {
    id: requiredString(map, 'id'),
    firstName: optionalString(map, 'firstname') ?? '',
    lastName: optionalString(map, 'lastname') ?? '',
    phone: optionalString(map, 'phone') ?? '',
    avatarUrl: optionalString(map, 'avatar_url'),
    dob: parseDob(map.dob),
  };
}

/**
 * Mirrors Dart's `DateTime.tryParse(map['dob']?.toString() ?? '')`: `null`
 * for a missing/blank/unparsable value. A bare `yyyy-MM-dd` (what the
 * Postgres `date` column returns) is built from its local year/month/day
 * fields -- `new Date('1995-06-15')` would parse it as UTC midnight and can
 * land on the previous day in a negative-offset timezone, whereas Dart's
 * `DateTime.tryParse` treats it as a local date.
 */
function parseDob(value: unknown): Date | null {
  if (value == null) return null;
  const text = String(value).trim();
  if (text === '') return null;
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (dateOnly) {
    const [, year, month, day] = dateOnly;
    return new Date(Number(year), Number(month) - 1, Number(day));
  }
  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function requiredString(map: Record<string, unknown>, key: string): string {
  const value = optionalString(map, key);
  if (value == null) {
    throw new CustomerProfileFormatError(key);
  }
  return value;
}

function optionalString(map: Record<string, unknown>, key: string): string | null {
  const raw = map[key];
  if (raw == null) return null;
  const value = String(raw).trim();
  return value === '' ? null : value;
}
