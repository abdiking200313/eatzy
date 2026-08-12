import 'package:intl/intl.dart';

abstract final class AppMoney {
  static const currencyCode = 'USD';

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_US',
    name: currencyCode,
    symbol: r'$',
    decimalDigits: 2,
  );

  static String format(num amount) => _formatter.format(amount);
}
