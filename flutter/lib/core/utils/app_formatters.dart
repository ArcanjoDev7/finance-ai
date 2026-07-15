import 'package:intl/intl.dart';

abstract final class AppFormatters {
  static String currency(
    int amountMinor, {
    String currencyCode = 'BRL',
    String locale = 'pt_BR',
  }) => NumberFormat.currency(locale: locale, name: currencyCode).format(amountMinor / 100);

  static String date(DateTime value, {String locale = 'pt_BR'}) =>
      DateFormat.yMMMd(locale).format(value);
}
