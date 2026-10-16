import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/theme.dart';

final _monthYear = DateFormat('MMMM yyyy');
final _short = DateFormat('MMM d, yyyy');

/// A small date picker for ranges and single days.
///
/// Flutter's own `showDateRangePicker` fills the whole window on a short or
/// narrow screen, sets the dates in tiny type and parks an edit pencil in the
/// corner. This one is a fixed-size card: a month grid, two taps for a range,
/// and a "Whole month" shortcut so a month does not take 30 clicks.
///
/// Returns the first and last picked day at midnight, or null when cancelled.
/// For a single day both are the same day.
Future<DateTimeRange?> showAppDateRange(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initial,
  bool singleDay = false,
  String? title,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _RangeDialog(
      firstDate: DateUtils.dateOnly(firstDate),
      lastDate: DateUtils.dateOnly(lastDate),
      initial: initial,
      singleDay: singleDay,
      title: title ?? (singleDay ? 'Pick a day' : 'Pick a date range'),
    ),
  );
}

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({
    required this.firstDate,
    required this.lastDate,
    required this.initial,
    required this.singleDay,
    required this.title,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initial;
  final bool singleDay;
  final String title;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late DateTime _month;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _start = DateUtils.dateOnly(initial.start);
      _end = DateUtils.dateOnly(initial.end);
    }
    final anchor = _end ?? widget.lastDate;
    _month = DateTime(anchor.year, anchor.month);
  }

  bool get _canGoBack => DateTime(
    _month.year,
    _month.month,
  ).isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));

  bool get _canGoForward => DateTime(
    _month.year,
    _month.month,
  ).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  bool _inBounds(DateTime d) =>
      !d.isBefore(widget.firstDate) && !d.isAfter(widget.lastDate);

  void _tap(DateTime day) {
    setState(() {
      if (widget.singleDay) {
        _start = day;
        _end = day;
      } else if (_start == null || _end != null) {
        // A third tap starts a new range.
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _end = _start;
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  void _wholeMonth() {
    final first = DateTime(_month.year, _month.month);
    final last = DateTime(_month.year, _month.month + 1, 0);
    setState(() {
      _start = first.isBefore(widget.firstDate) ? widget.firstDate : first;
      _end = last.isAfter(widget.lastDate) ? widget.lastDate : last;
    });
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  String get _summary {
    if (_start == null) {
      return widget.singleDay ? 'Tap a day' : 'Tap the first day';
    }
    if (_end == null) return '${_short.format(_start!)} to ...';
    if (_start == _end) return _short.format(_start!);
    return '${_short.format(_start!)} to ${_short.format(_end!)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final lead = first.weekday % 7; // Sunday first
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    final ready = _start != null && _end != null;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.x4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: text.titleMedium),
              const SizedBox(height: AppSpacing.x1),
              Text(
                _summary,
                style: text.bodyMedium?.copyWith(color: t.text.secondary),
              ),
              const SizedBox(height: AppSpacing.x3),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                    onPressed: _canGoBack ? () => _shift(-1) : null,
                  ),
                  Expanded(
                    child: Text(
                      _monthYear.format(_month),
                      textAlign: TextAlign.center,
                      style: text.titleSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                    onPressed: _canGoForward ? () => _shift(1) : null,
                  ),
                ],
              ),
              Row(
                children: [
                  for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: text.labelSmall?.copyWith(
                            color: t.text.tertiary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.x1),
              for (var r = 0; r < rows; r++)
                Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: _cell(
                          r * 7 + c - lead + 1,
                          daysInMonth,
                          scheme,
                          text,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.x2),
              if (!widget.singleDay)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(
                      Icons.calendar_view_month_outlined,
                      size: AppSizes.iconSm,
                    ),
                    label: Text('Whole ${DateFormat('MMMM').format(_month)}'),
                    onPressed: _wholeMonth,
                  ),
                ),
              const SizedBox(height: AppSpacing.x2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  FilledButton(
                    onPressed: ready
                        ? () => Navigator.pop(
                            context,
                            DateTimeRange(start: _start!, end: _end!),
                          )
                        : null,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(
    int dayNumber,
    int daysInMonth,
    ColorScheme scheme,
    TextTheme text,
  ) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 36);
    }
    final day = DateTime(_month.year, _month.month, dayNumber);
    final enabled = _inBounds(day);
    final isStart = _start != null && day == _start;
    final isEnd = _end != null && day == _end;
    final inside =
        _start != null &&
        _end != null &&
        day.isAfter(_start!) &&
        day.isBefore(_end!);
    final selected = isStart || isEnd;

    return InkWell(
      onTap: enabled ? () => _tap(day) : null,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : inside
              ? scheme.primary.withValues(alpha: 0.14)
              : null,
          borderRadius: BorderRadius.circular(selected ? 18 : 0),
        ),
        child: Text(
          '$dayNumber',
          style: text.bodyMedium?.copyWith(
            color: selected
                ? scheme.onPrimary
                : enabled
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
