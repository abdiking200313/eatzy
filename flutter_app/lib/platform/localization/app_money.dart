import 'package:intl/intl.dart';

abstract final class AppMoney {
  static const currencyCode = 'USD';

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_US',
    name: currencyCode,
    symbol: r'$',
    decimalDigits: 2,
  );

  /// Formats an integer smallest-currency-unit (cents) amount as decimal
  /// dollars. This is the only place a cents value should ever be divided by
  /// 100 — every model, controller, and RPC payload in this app reads,
  /// stores, and computes money in cents, and converts to dollars only here,
  /// at final display time.
  static String formatCents(num cents) => _formatter.format(cents / 100);

  /// Parses a user-entered decimal-dollar string (e.g. `"12.3"`, `"$12"`,
  /// `" 12.34 "`) into integer cents, rounding to the nearest cent. Returns
  /// `null` if [input] is not a valid non-negative amount. Used by the
  /// merchant dashboard's catalog/store price entry forms.
  static int? parseToCents(String input) {
    final cleaned = input.trim().replaceAll(r'$', '').replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite || value < 0) {
      return null;
    }
    return (value * 100).round();
  }
}
