/// Money formatting/parsing (issue #356).
///
/// Ports `flutter_app/lib/platform/localization/app_money.dart`'s `AppMoney`
/// to this app. Money is an integer smallest-currency-unit (cents) value
/// everywhere in this app — every model, store, and Supabase payload reads,
/// stores, and computes money in cents, and converts to decimal dollars only
/// here, at final display time (see AGENTS.md's money rule / Flutter issue
/// #8). Never store or compute with a float/decimal dollar amount.

/** The only currency this app supports today, matching `AppMoney.currencyCode`. */
export const CURRENCY_CODE = 'USD';

const currencyFormatter = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: CURRENCY_CODE,
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

/**
 * Formats an integer smallest-currency-unit (cents) amount as decimal
 * dollars, e.g. `formatCents(1234)` -> `"$12.34"`. This is the only place a
 * cents value should ever be divided by 100 — see the module doc.
 */
export function formatCents(cents: number): string {
  return currencyFormatter.format(cents / 100);
}

/**
 * Parses a user-entered decimal-dollar string (e.g. `"12.3"`, `"$12"`,
 * `" 12.34 "`) into integer cents, rounding to the nearest cent. Returns
 * `null` if `input` is not a valid non-negative amount. Ports
 * `AppMoney.parseToCents`, added for the merchant dashboard's catalog/store
 * price entry forms (Flutter issue #232).
 */
// Matches Dart's `double.tryParse` syntax closely enough for this app's
// inputs (optional sign, digits with an optional decimal point and/or
// exponent) — stricter than `Number()` alone, which also accepts things
// Dart's parser rejects, like hex literals ("0x10") or a bare "Infinity".
const DECIMAL_PATTERN = /^[+-]?(\d+(\.\d+)?|\.\d+)([eE][+-]?\d+)?$/;

export function parseToCents(input: string): number | null {
  const cleaned = input.trim().replaceAll('$', '').replaceAll(',', '');
  if (!DECIMAL_PATTERN.test(cleaned)) {
    return null;
  }

  const value = Number(cleaned);
  if (!Number.isFinite(value) || value < 0) {
    return null;
  }

  return Math.round(value * 100);
}
