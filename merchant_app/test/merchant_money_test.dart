import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/platform/merchant_money.dart';

// Unit-tests the integer-cents convention this app must follow end-to-end
// (issue #133 / AGENTS.md's money rule): every value that comes from or
// goes to Supabase is integer cents, converted to/from a decimal-dollar
// string only at the UI boundary.
void main() {
  group('formatCents', () {
    test('formats a typical amount', () {
      expect(MerchantMoney.formatCents(1234), r'$12.34');
    });

    test('pads a single-digit cents remainder', () {
      expect(MerchantMoney.formatCents(1205), r'$12.05');
    });

    test('formats zero', () {
      expect(MerchantMoney.formatCents(0), r'$0.00');
    });

    test('formats a negative amount', () {
      expect(MerchantMoney.formatCents(-150), r'-$1.50');
    });
  });

  group('parseToCents', () {
    test('parses a plain decimal string', () {
      expect(MerchantMoney.parseToCents('12.34'), 1234);
    });

    test('parses a whole-dollar string with no decimal part', () {
      expect(MerchantMoney.parseToCents('5'), 500);
    });

    test('ignores a leading dollar sign and surrounding whitespace', () {
      expect(MerchantMoney.parseToCents(r'  $9.99 '), 999);
    });

    test('rounds to the nearest cent', () {
      expect(MerchantMoney.parseToCents('1.239'), 124);
    });

    test('rejects an empty string', () {
      expect(MerchantMoney.parseToCents(''), isNull);
    });

    test('rejects non-numeric text', () {
      expect(MerchantMoney.parseToCents('abc'), isNull);
    });

    test('rejects a negative amount', () {
      expect(MerchantMoney.parseToCents('-1.00'), isNull);
    });
  });
}
