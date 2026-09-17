import 'package:chowflow/platform/localization/app_money.dart';
import 'package:flutter_test/flutter_test.dart';

// Unit-tests `AppMoney.parseToCents` (added alongside the merchant dashboard
// port, issue #232, from `merchant_app`'s `MerchantMoney.parseToCents`) --
// the integer-cents convention this app follows end-to-end (AGENTS.md's
// money rule): every value that comes from or goes to Supabase is integer
// cents, converted to/from a decimal-dollar string only at the UI boundary.
void main() {
  group('formatCents', () {
    test('formats a typical amount', () {
      expect(AppMoney.formatCents(1234), r'$12.34');
    });

    test('formats zero', () {
      expect(AppMoney.formatCents(0), r'$0.00');
    });
  });

  group('parseToCents', () {
    test('parses a plain decimal string', () {
      expect(AppMoney.parseToCents('12.34'), 1234);
    });

    test('parses a whole-dollar string with no decimal part', () {
      expect(AppMoney.parseToCents('5'), 500);
    });

    test('ignores a leading dollar sign and surrounding whitespace', () {
      expect(AppMoney.parseToCents(r'  $9.99 '), 999);
    });

    test('rounds to the nearest cent', () {
      expect(AppMoney.parseToCents('1.239'), 124);
    });

    test('rejects an empty string', () {
      expect(AppMoney.parseToCents(''), isNull);
    });

    test('rejects non-numeric text', () {
      expect(AppMoney.parseToCents('abc'), isNull);
    });

    test('rejects a negative amount', () {
      expect(AppMoney.parseToCents('-1.00'), isNull);
    });
  });
}
