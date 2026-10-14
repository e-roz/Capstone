import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/registration_detail.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// More than this many days left is fine.
const expiringSoonDays = 60;

/// This many days or fewer, or already past, is urgent.
///
/// Matches the 30 days the registration review already warns on, so the two
/// places never disagree about what "close" means.
const expiryUrgentDays = 30;

enum ExpiryLevel { valid, soon, urgent, expired, unknown }

/// How far off an expiry date is, said in days and a level.
class ExpiryStatus {
  const ExpiryStatus._(this.level, this.days);

  final ExpiryLevel level;

  /// Whole calendar days from today. Negative once the date has passed. Zero
  /// when [level] is unknown.
  final int days;

  /// Compared on the calendar date, not the instant: an expiry is a day, and
  /// "expires in 0 days" should mean today, not fourteen hours.
  factory ExpiryStatus.of(DateTime? date, {DateTime? now}) {
    if (date == null) return const ExpiryStatus._(ExpiryLevel.unknown, 0);

    final today = now ?? DateTime.now();
    final days = DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

    final level = days < 0
        ? ExpiryLevel.expired
        : days <= expiryUrgentDays
            ? ExpiryLevel.urgent
            : days <= expiringSoonDays
                ? ExpiryLevel.soon
                : ExpiryLevel.valid;

    return ExpiryStatus._(level, days);
  }

  StatusIntent get intent => switch (level) {
        ExpiryLevel.valid => StatusIntent.success,
        ExpiryLevel.soon => StatusIntent.warning,
        ExpiryLevel.urgent || ExpiryLevel.expired => StatusIntent.danger,
        ExpiryLevel.unknown => StatusIntent.neutral,
      };

  IconData get icon => switch (level) {
        ExpiryLevel.valid => Icons.check_circle_outline,
        ExpiryLevel.soon => Icons.schedule,
        ExpiryLevel.urgent || ExpiryLevel.expired => Icons.warning_amber_rounded,
        ExpiryLevel.unknown => Icons.help_outline,
      };

  String get label {
    String n(int d) => '$d ${d == 1 ? 'day' : 'days'}';

    return switch (level) {
      ExpiryLevel.valid => 'Valid, ${n(days)} left',
      ExpiryLevel.soon => 'Expiring soon, ${n(days)} left',
      ExpiryLevel.urgent =>
        days == 0 ? 'Expires today' : 'Urgent, ${n(days)} left',
      ExpiryLevel.expired => 'Expired ${n(-days)} ago',
      ExpiryLevel.unknown => 'No date on file',
    };
  }

  /// How much of a year is left, for the bar. Empty once expired.
  double get remaining => level == ExpiryLevel.unknown
      ? 0
      : (days / 365).clamp(0.0, 1.0).toDouble();
}

/// When this user's licence and each vehicle's registration run out.
///
/// An e-bike has no registration, so for one only the licence is shown, with a
/// line saying why. Nothing here is stored for the purpose: the dates are the
/// ones read from the documents when they were confirmed, which the review
/// already returns, so showing them costs no new column or endpoint.
class ExpiryCard extends StatelessWidget {
  const ExpiryCard({super.key, required this.detail});

  final RegistrationDetail detail;

  /// Nothing to show for an applicant who never submitted documents.
  static bool hasData(RegistrationDetail detail) => detail.checks != null;

  static String _plate(String? plate) =>
      (plate ?? '').replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final facts = detail.checks!.facts;

    final rows = <_ExpiryRowData>[
      _ExpiryRowData(
        icon: Icons.badge_outlined,
        label: "Driver's licence",
        // What is on file now, which a renewal replaces. The reading from the
        // original documents is only the fallback for an account that has none.
        date: detail.licenseValidThrough ?? facts.licenseExpiry,
      ),
      for (final vehicle in detail.vehicles.where((v) => !v.isEBike))
        _ExpiryRowData(
          icon: Icons.description_outlined,
          label: 'Registration (OR) · ${vehicle.plateNumber ?? 'no plate'}',
          date: vehicle.registrationValidThrough ??
              facts.vehicles
                  .where((f) =>
                      _plate(f.plateNumber) == _plate(vehicle.plateNumber))
                  .map((f) => f.registrationExpiry)
                  .firstOrNull,
        ),
    ];

    final statuses = [for (final r in rows) ExpiryStatus.of(r.date)];
    final expired = statuses.where((s) => s.level == ExpiryLevel.expired).length;
    final urgent = statuses.where((s) => s.level == ExpiryLevel.urgent).length;
    final soon = statuses.where((s) => s.level == ExpiryLevel.soon).length;
    final unknown = statuses.where((s) => s.level == ExpiryLevel.unknown).length;

    final (summary, summaryIntent, summaryIcon) = expired > 0
        ? ('$expired expired', StatusIntent.danger, Icons.warning_amber_rounded)
        : urgent > 0
            ? ('$urgent urgent', StatusIntent.danger, Icons.warning_amber_rounded)
            : soon > 0
                ? ('$soon expiring soon', StatusIntent.warning, Icons.schedule)
                : unknown > 0
                    ? ('Check dates', StatusIntent.neutral, Icons.help_outline)
                    : ('All valid', StatusIntent.success, Icons.check_circle_outline);

    final hasEBike = detail.isEBike || detail.vehicles.any((v) => v.isEBike);

    return AppSectionCard(
      title: 'Expiry dates',
      icon: Icons.event_outlined,
      actions: [
        if (detail.hasPendingRenewal)
          const StatusPill(
            label: 'Renewal waiting',
            intent: StatusIntent.accent,
            icon: Icons.hourglass_top,
          ),
        StatusPill(label: summary, intent: summaryIntent, icon: summaryIcon),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: AppSpacing.x6),
            _ExpiryRow(data: row, status: statuses[i]),
          ],
          if (hasEBike) ...[
            const Divider(height: AppSpacing.x6),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: AppSizes.iconSm, color: t.text.secondary),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    'E-bikes are not registered with the LTO, so there is no '
                    'registration to expire.',
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.x3),
          Text(
            'As of the last time the documents were confirmed. Warns at '
            '$expiringSoonDays days, urgent at $expiryUrgentDays.',
            style: text.bodySmall?.copyWith(color: t.text.tertiary),
          ),
        ],
      ),
    );
  }
}

class _ExpiryRowData {
  const _ExpiryRowData({
    required this.icon,
    required this.label,
    required this.date,
  });

  final IconData icon;
  final String label;
  final DateTime? date;
}

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({required this.data, required this.status});

  final _ExpiryRowData data;
  final ExpiryStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tone = t.status.of(status.intent);

    return Wrap(
      spacing: AppSpacing.x4,
      runSpacing: AppSpacing.x2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tone.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(data.icon, color: tone.fg, size: AppSizes.iconMd),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.label,
                  style: text.labelSmall?.copyWith(color: t.text.tertiary)),
              const SizedBox(height: 2),
              Text(
                data.date == null
                    ? '—'
                    : DateFormat('MMM d, yyyy').format(data.date!),
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.x2),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: status.remaining,
                  minHeight: 6,
                  backgroundColor: t.surface.muted,
                  valueColor: AlwaysStoppedAnimation(tone.fg),
                ),
              ),
            ],
          ),
        ),
        StatusPill(label: status.label, intent: status.intent, icon: status.icon),
      ],
    );
  }
}
