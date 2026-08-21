import 'package:intl/intl.dart';

/// Single home for every user-facing date, time, duration and money string.
///
/// These used to be hand-rolled at each call site — `'${d.month}/${d.day}/${d.year}'`
/// appeared ten times across five screens, and `_formatTime`/`_formatDuration`
/// were byte-identical copies in the history and dashboard screens. Two problems
/// came with that: the date was unpadded and ordered `M/D/YYYY`, which is
/// genuinely ambiguous here, and money printed without a thousands separator, so
/// a ₱1500 penalty read as `₱1500.00`.
abstract class Formatters {
  // Held as statics because DateFormat parses its pattern on construction, and
  // these run inside list builders.
  static final _date = DateFormat('MMM d, y'); // Aug 5, 2026
  static final _dateShort = DateFormat('MMM d'); // Aug 5
  static final _time = DateFormat('h:mm a'); // 2:05 PM
  static final _peso = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

  /// `Aug 5, 2026`. Month-name form on purpose: no reader has to work out
  /// whether the first number is the month or the day.
  static String date(DateTime value) => _date.format(value);

  /// `Aug 5` — for rows where the year is noise because everything is recent.
  static String dateShort(DateTime value) => _dateShort.format(value);

  /// `2:05 PM`.
  static String time(DateTime value) => _time.format(value);

  /// `₱1,234.56`.
  static String peso(num value) => _peso.format(value);

  /// `45m`, `2h 5m`, `1d 3h`. Days appear because a vehicle left overnight is
  /// otherwise reported as `27h 0m`.
  static String duration(Duration value) {
    if (value.inDays >= 1) {
      return '${value.inDays}d ${value.inHours % 24}h';
    }
    if (value.inHours == 0) {
      return '${value.inMinutes}m';
    }
    return '${value.inHours}h ${value.inMinutes % 60}m';
  }

  /// `Today`, `Yesterday`, else the date. Compares calendar days rather than
  /// elapsed hours — 11pm and 1am are different days, not "2 hours ago".
  static String relativeDay(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return date(value);
  }

  /// `Just now`, `5m ago`, `3h ago`, `2d ago`, then an absolute date once
  /// "N days ago" stops being easier to picture than the date itself.
  static String relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(value);
  }

  /// Entry–exit span for one parking session, or an open-ended one while the
  /// vehicle is still inside.
  static String sessionRange(DateTime entry, DateTime? exit, Duration length) {
    if (exit == null) {
      return 'Since ${time(entry)} · ${duration(length)}';
    }
    return '${time(entry)} – ${time(exit)} · ${duration(length)}';
  }
}
