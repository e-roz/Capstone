import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../payments/data/models/payment.dart';
import '../../../vehicles/data/models/vehicle.dart';
import '../../data/models/parking_history_entry.dart';

/// One parking session, drawn the same way on Home and on the History screen.
///
/// Answers the questions someone asks of a past visit, in the order they ask
/// them: *when* (the day), *how long* (the bold figure on the right), *which
/// vehicle* (the plate), and *what did it
/// cost* (the amount under the duration). Entry and exit are both spelled out
/// rather than squeezed into a dash.
///
/// The fee is looked up from the bills already loaded, by the session's
/// `paymentId`, so a person who wonders why they owe money can see which visit
/// it came from. A session still in progress has no fee yet — the bill is only
/// raised on exit — and says "Parked now" instead.
///
/// Tapping a session that raised a bill opens that bill. One that did not has
/// nowhere to go, so it is not tappable and shows no chevron.
class ParkingSessionRow extends StatelessWidget {
  const ParkingSessionRow({
    super.key,
    required this.entry,
    this.payment,
    this.plate,
    this.onTap,
  });

  final ParkingHistoryEntry entry;

  /// The bill this session raised, if it is in hand.
  final Payment? payment;

  /// The vehicle's plate, if it is known.
  final String? plate;

  final VoidCallback? onTap;

  /// The plate to show: the account's own vehicle when the server tied the
  /// session to one, else the plate the camera read, else nothing. A session
  /// that cannot be tied to any vehicle shows no plate rather than a guess.
  static String? plateFor(ParkingHistoryEntry entry, List<Vehicle> vehicles) {
    for (final v in vehicles) {
      if (v.id == entry.vehicleId) return v.plateNumber;
    }
    final read = entry.alprPlateNumber;
    return read == null || read.isEmpty ? null : read;
  }

  /// How this visit stands, or null for one with nothing to say — no bill, or a
  /// bill for nothing.
  static StatusIntent? _toneFor(bool open, Payment? bill) {
    if (open) return StatusIntent.success;
    if (bill == null || bill.amountDue <= 0) return null;
    if (bill.status.toLowerCase() == 'waived') return StatusIntent.info;
    if (bill.isPaid) return StatusIntent.success;
    return StatusIntent.warning;
  }

  /// `3:40 PM`, or `Aug 6, 1:10 AM` when the exit is on a different day from the
  /// entry — a visit that ran past midnight would otherwise read as ending
  /// before it began.
  static String _exitLabel(DateTime entry, DateTime exit) {
    final sameDay = entry.year == exit.year &&
        entry.month == exit.month &&
        entry.day == exit.day;
    return sameDay
        ? Formatters.time(exit)
        : '${Formatters.dateShort(exit)}, ${Formatters.time(exit)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final open = entry.isOpen;
    final bill = payment;

    final subtitle = open
        ? 'Entered ${Formatters.time(entry.entryTime)} · Still parked'
        : 'Entered ${Formatters.time(entry.entryTime)} · '
            'Exited ${_exitLabel(entry.entryTime, entry.exitTime!)}';

    // The slot's circle is tinted by how the visit stands, so a list of visits
    // can be read at a glance: green is settled (or you are parked right now),
    // amber is owed, red is overdue. A visit with no fee stays neutral. The
    // amount beside it says the same in words, so colour is never the only cue.
    final tone = _toneFor(open, bill);
    final c = tone == null ? null : t.status.of(tone);

    return AppListRow(
      leading: Container(
        width: AppSizes.rowIcon,
        height: AppSizes.rowIcon,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c?.bg ?? t.surface.muted,
          shape: BoxShape.circle,
        ),
        // A car, not a bay code: the lot cannot say which bay a visit used.
        child: Icon(
          Icons.directions_car_rounded,
          size: 18,
          color: c?.fg ?? t.text.secondary,
        ),
      ),
      title: Formatters.relativeDay(entry.entryTime),
      subtitle: subtitle,
      note: plate == null
          ? null
          : Text(
              plate!,
              style: AppTypography.tabular(context.text.bodySmall!).copyWith(
                color: t.text.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.duration(entry.duration),
            style: AppTypography.tabular(context.text.titleSmall!),
          ),
          if (open) ...[
            const SizedBox(height: 4),
            const AppStatusBadge(
              label: 'Parked now',
              intent: StatusIntent.success,
            ),
          ] else if (bill != null && bill.amountDue > 0) ...[
            const SizedBox(height: 2),
            _Fee(payment: bill),
          ],
        ],
      ),
      // A chevron only where it leads somewhere: a bill.
      onTap: onTap,
      showChevron: onTap != null,
    );
  }
}

/// The amount a session cost, with its state in words as well as colour: a paid
/// amount is plain, one still owed says so.
class _Fee extends StatelessWidget {
  const _Fee({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final owed = !payment.isPaid && payment.status.toLowerCase() != 'waived';
    final c = t.status.warning;
    final amount = Formatters.peso(payment.amountDue);

    return Text(
      payment.status.toLowerCase() == 'waived'
          ? 'Waived'
          : owed
              ? '$amount due'
              : amount,
      style: AppTypography.tabular(context.text.bodySmall!).copyWith(
        color: owed ? c.fg : t.text.secondary,
        fontWeight: owed ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}
