import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/theme.dart';

final _dateOnly = DateFormat('MMM d, yyyy');

/// A one-day picker for a toolbar: today by default, any earlier day on
/// request, and a way straight back to today.
///
/// For a guard watching the gates, a range is the wrong question - they ask
/// "what happened on this day", and a range makes them pick the same day twice.
/// [onChanged] gets the day picked; the caller turns it into the span it needs.
class AppDayFilter extends StatelessWidget {
  const AppDayFilter({super.key, required this.day, required this.onChanged});

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  bool get _isToday => DateUtils.isSameDay(day, DateTime.now());

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: day.isAfter(now) ? now : day,
      firstDate: DateTime(now.year - 5),
      // A day that has not happened has nothing in it.
      lastDate: now,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined, size: AppSizes.iconSm),
          label: Text(
            _isToday ? 'Today · ${_dateOnly.format(day)}' : _dateOnly.format(day),
          ),
          onPressed: () => _pick(context),
        ),
        if (!_isToday)
          TextButton(
            onPressed: () => onChanged(DateTime.now()),
            child: const Text('Back to today'),
          ),
      ],
    );
  }
}
