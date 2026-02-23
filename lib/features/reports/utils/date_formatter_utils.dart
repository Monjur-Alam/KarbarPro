import 'package:intl/intl.dart';

class DateFormatterUtils {
  static String formatTransactionDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  static String formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  static String formatBengaliDate(DateTime date) {
    final bengaliMonths = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ];
    final month = bengaliMonths[date.month - 1];
    final year = _toBengaliNumber(date.year);
    return '$month $year';
  }

  static String formatDayDate(DateTime date) {
    final day = _toBengaliNumber(date.day);
    final monthNames = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ];
    final month = monthNames[date.month - 1];
    final year = _toBengaliNumber(date.year);
    return '$day $month $year';
  }

  static String _toBengaliNumber(int number) {
    const bengaliDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return number
        .toString()
        .split('')
        .map((digit) => bengaliDigits[int.parse(digit)])
        .join('');
  }

  static String toBengaliNumber(double number) {
    const bengaliDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    final formattedNumber = number.toStringAsFixed(0);

    // Add commas for thousands (simplified Bengali format)
    final parts = <String>[];
    String remaining = formattedNumber;

    while (remaining.length > 3) {
      parts.insert(0, remaining.substring(remaining.length - 3));
      remaining = remaining.substring(0, remaining.length - 3);
    }
    if (remaining.isNotEmpty) {
      parts.insert(0, remaining);
    }

    final withCommas = parts.join(',');

    return withCommas
        .split('')
        .map((char) {
          if (char == ',') return char;
          final digit = int.tryParse(char);
          return digit != null ? bengaliDigits[digit] : char;
        })
        .join('');
  }

  /// Formats a number for display. Uses Bengali digits when [languageCode] is 'bn', otherwise Western digits.
  static String formatNumberForLocale(double number, String languageCode) {
    if (languageCode == 'bn') {
      return toBengaliNumber(number);
    }
    final n = number.toStringAsFixed(0);
    final parts = <String>[];
    String remaining = n.startsWith('-') ? n.substring(1) : n;
    final negative = n.startsWith('-');
    while (remaining.length > 3) {
      parts.insert(0, remaining.substring(remaining.length - 3));
      remaining = remaining.substring(0, remaining.length - 3);
    }
    if (remaining.isNotEmpty) parts.insert(0, remaining);
    return (negative ? '-' : '') + parts.join(',');
  }
}
