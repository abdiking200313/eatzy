import { formatCents, parseToCents } from './format';

// Ports `flutter_app/test/app_money_test.dart`'s cases for
// `AppMoney.formatCents` / `AppMoney.parseToCents` -- the integer-cents
// convention this app follows end-to-end (AGENTS.md's money rule): every
// value that comes from or goes to Supabase is integer cents, converted
// to/from a decimal-dollar string only at the UI boundary.
describe('formatCents', () => {
  it('formats a typical amount', () => {
    expect(formatCents(1234)).toBe('$12.34');
  });

  it('formats zero', () => {
    expect(formatCents(0)).toBe('$0.00');
  });
});

describe('parseToCents', () => {
  it('parses a plain decimal string', () => {
    expect(parseToCents('12.34')).toBe(1234);
  });

  it('parses a whole-dollar string with no decimal part', () => {
    expect(parseToCents('5')).toBe(500);
  });

  it('ignores a leading dollar sign and surrounding whitespace', () => {
    expect(parseToCents('  $9.99 ')).toBe(999);
  });

  it('rounds to the nearest cent', () => {
    expect(parseToCents('1.239')).toBe(124);
  });

  it('rejects an empty string', () => {
    expect(parseToCents('')).toBeNull();
  });

  it('rejects non-numeric text', () => {
    expect(parseToCents('abc')).toBeNull();
  });

  it('rejects a negative amount', () => {
    expect(parseToCents('-1.00')).toBeNull();
  });
});
