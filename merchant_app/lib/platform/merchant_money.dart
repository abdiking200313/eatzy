/// Money helpers for the merchant app (issue #133).
///
/// This mirrors the root app's integer-smallest-currency-unit (cents)
/// convention documented in `lib/platform/localization/app_money.dart` and
/// `AGENTS.md`: every money value that comes from or goes to Supabase is an
/// integer number of cents, converted to/from a decimal-dollar string only
/// at the UI boundary. It intentionally does not import `intl` (not a
/// dependency of this independent project's `pubspec.yaml` -- see
/// issue #133's PR notes) since a fixed two-decimal USD amount does not need
/// locale-aware number formatting.
abstract final class MerchantMoney {
  /// Formats integer [cents] as a `$d.dd` string for display, e.g. `1234` ->
  /// `$12.34`. This is the only place a cents value should be divided by
  /// 100 -- every model/controller/repository in this feature reads and
  /// writes cents.
  static String formatCents(int cents) {
    final isNegative = cents < 0;
    final absCents = cents.abs();
    final dollars = absCents ~/ 100;
    final remainder = (absCents % 100).toString().padLeft(2, '0');
    return '${isNegative ? '-' : ''}\$$dollars.$remainder';
  }

  /// Parses a user-entered decimal-dollar string (e.g. `"12.3"`, `"$12"`,
  /// `" 12.34 "`) into integer cents, rounding to the nearest cent. Returns
  /// `null` if [input] is not a valid non-negative amount.
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
