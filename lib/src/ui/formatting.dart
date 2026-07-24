import 'package:intl/intl.dart';

/// Compact timestamp for list tiles: time for today, month/day for this
/// year, full date otherwise.
String formatListTime(DateTime dt) {
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return DateFormat.Hm().format(dt);
  }
  if (dt.year == now.year) {
    return DateFormat.MMMd().format(dt);
  }
  return DateFormat.yMMMd().format(dt);
}

/// Full timestamp for the detail header.
String formatFullTime(DateTime dt) =>
    DateFormat.yMMMd().add_Hms().format(dt);
