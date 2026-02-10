import 'package:intl/intl.dart';

class BengaliFormatter {
  static const Map<String, String> _englishToBengaliDigits = {
    '0': '০',
    '1': '১',
    '2': '২',
    '3': '৩',
    '4': '৪',
    '5': '৫',
    '6': '৬',
    '7': '৭',
    '8': '৮',
    '9': '৯',
  };

  /// Converts English numbers to Bengali digits
  /// Example: 1234.50 -> ১,২৩৪.৫০
  static String formatNumber(double number, {int decimalDigits = 2}) {
    String formatted = NumberFormat.decimalPattern('en_US').format(number);
    
    // If we need specific decimal digits
    if (decimalDigits >= 0) {
      formatted = number.toStringAsFixed(decimalDigits);
    }

    return formatted.split('').map((char) => _englishToBengaliDigits[char] ?? char).join('');
  }

  /// Formats currency with Bengali Taka symbol
  /// Example: ৳ ৫,০০০.০০
  static String formatCurrency(double amount) {
    return '৳ ${formatNumber(amount)}';
  }

  /// Formats Date to Bengali (Simple version)
  static String formatDate(DateTime date) {
    // For full localization, use intl's DateFormat with 'bn' locale
    return DateFormat.yMMMMd('bn').format(date);
  }
}
