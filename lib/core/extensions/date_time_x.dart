import 'package:intl/intl.dart';

/// Date helpers shared across features.
extension DateTimeX on DateTime {
  /// Midnight at the start of this day, in local time.
  DateTime get startOfDay => DateTime(year, month, day);

  /// The last representable instant of this day, in local time.
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool get isToday => isSameDay(DateTime.now());

  bool get isYesterday =>
      isSameDay(DateTime.now().subtract(const Duration(days: 1)));

  /// A short, human readable label such as `14:32`, `Yesterday` or `12 Mar`.
  String get relativeLabel {
    if (isToday) return DateFormat.Hm().format(this);
    if (isYesterday) return 'Yesterday';
    if (DateTime.now().difference(this).inDays < 365) {
      return DateFormat('d MMM').format(this);
    }
    return DateFormat('d MMM y').format(this);
  }

  String get fullLabel => DateFormat('d MMM y, HH:mm').format(this);

  String get dayKey => DateFormat('yyyy-MM-dd').format(this);
}
