import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/ph_time.dart';
import '../providers/overview_provider.dart';
import '../theme/theme.dart';
import 'ui/app_range_picker.dart';

/// One control for the history side of a page: a few shortcuts, a single day,
/// or any range. Shared by the Overview and Reports so both mean the same by
/// "Last 7 days".
class PeriodPicker extends ConsumerWidget {
  const PeriodPicker({super.key, required this.provider});

  /// Where the chosen period lives, so each page keeps its own.
  final StateProvider<OverviewPeriod> provider;

  static final _shortcuts = <(String, OverviewPeriod)>[
    ('Today', OverviewPeriod.today),
    ('Yesterday', const OverviewPeriod(OverviewPreset.yesterday)),
    ('Last 7 days', const OverviewPeriod(OverviewPreset.last7)),
    ('Last 30 days', const OverviewPeriod(OverviewPreset.last30)),
    ('All time', const OverviewPeriod(OverviewPreset.allTime)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(provider);
    void set(OverviewPeriod p) =>
        ref.read(provider.notifier).state = p;

    return MenuAnchor(
      menuChildren: [
        for (final (label, p) in _shortcuts)
          MenuItemButton(
            leadingIcon: Icon(
              p == period ? Icons.check : null,
              size: AppSizes.iconSm,
            ),
            onPressed: () => set(p),
            child: Text(label),
          ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.today_outlined, size: AppSizes.iconSm),
          onPressed: () async {
            final day = await _pickDay(context, period);
            if (day != null) {
              set(OverviewPeriod(OverviewPreset.day, from: day, to: day));
            }
          },
          child: const Text('Pick a day…'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(
            Icons.date_range_outlined,
            size: AppSizes.iconSm,
          ),
          onPressed: () async {
            final range = await _pickRange(context, period);
            if (range != null) {
              set(
                OverviewPeriod(
                  OverviewPreset.range,
                  from: range.start,
                  to: range.end,
                ),
              );
            }
          },
          child: const Text('Custom range…'),
        ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today_outlined, size: AppSizes.iconSm),
        label: Text(period.label),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  static DateTime get _today {
    final m = manilaNow();
    return DateTime(m.year, m.month, m.day);
  }

  static Future<DateTime?> _pickDay(
    BuildContext context,
    OverviewPeriod current,
  ) async {
    final today = _today;
    final shown = current.days?.from ?? today;
    final shownDay = shown.isAfter(today) ? today : shown;
    final picked = await showAppDateRange(
      context,
      singleDay: true,
      firstDate: DateTime(today.year - 5),
      // A day that has not happened has nothing in it.
      lastDate: today,
      initial: DateTimeRange(start: shownDay, end: shownDay),
    );
    return picked?.start;
  }

  static Future<DateTimeRange?> _pickRange(
    BuildContext context,
    OverviewPeriod current,
  ) {
    final today = _today;
    final d = current.days;
    return showAppDateRange(
      context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initial: d == null ? null : DateTimeRange(start: d.from, end: d.to),
    );
  }
}
