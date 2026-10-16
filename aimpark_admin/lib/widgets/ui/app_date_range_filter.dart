import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/theme.dart';
import 'app_range_picker.dart';

final _dateOnly = DateFormat('MMM d, yyyy');

/// A date-range trigger for a toolbar: a button that opens the picker, and a
/// small clear control once a range is set.
///
/// [onChanged] gets the first picked day at midnight and the last picked day at
/// 23:59:59, so a one-day range still covers the whole day.
class AppDateRangeFilter extends StatelessWidget {
  const AppDateRangeFilter({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onChanged;

  String get _label {
    if (from == null && to == null) return 'All dates';
    if (from != null && to != null) {
      return '${_dateOnly.format(from!)} – ${_dateOnly.format(to!)}';
    }
    return from != null
        ? 'From ${_dateOnly.format(from!)}'
        : 'Until ${_dateOnly.format(to!)}';
  }

  bool get _active => from != null || to != null;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showAppDateRange(
      context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initial: from != null && to != null
          ? DateTimeRange(start: from!, end: to!)
          : null,
    );
    if (picked == null) return;
    // Inclusive of the whole end day — a picked range of Sep 1–Sep 1 should
    // not filter out everything created after midnight.
    onChanged(
      picked.start,
      DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range_outlined, size: AppSizes.iconSm),
          label: Text(_label),
          onPressed: () => _pick(context),
        ),
        if (_active)
          IconButton(
            icon: const Icon(Icons.close, size: AppSizes.iconSm),
            tooltip: 'Clear date range',
            onPressed: () => onChanged(null, null),
          ),
      ],
    );
  }
}
