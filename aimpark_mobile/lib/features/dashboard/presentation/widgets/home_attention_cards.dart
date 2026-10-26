import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../parking/data/models/parking_history_entry.dart';
import '../../../payments/data/models/payment.dart';
import '../../../violations/data/models/violation.dart';

/// Shown only when something is owed. One alert, built from the shared card.
///
/// The card says what the bill is for, so nobody has to open it to find out:
///
/// * **A fine:** the rule that was broken and when it was issued.
/// * **A parking fee:** the slot and how long the car was parked.
///
/// With several bills the card describes the one that has waited longest and
/// says how many others there are. Describing
/// all of them would turn one card into a list, and the Payments tab is that.
///
/// What the button does depends on what is owed, and says so:
///
/// * **One bill:** "Pay now" goes to that bill and straight on to the payment
///   page. Paying should not need a trip through a list first.
/// * **A bill already being processed:** "View payment", because a checkout is
///   open and starting another would replace it. The bill's own screen says what
///   is happening.
/// * **Several bills:** "Review and pay" opens the Payments tab. Checkout is per
///   bill, so one button cannot pay a total — and a button reading "Pay ₱140.00"
///   that then opened a list was promising something it did not do.
///
/// Nothing here says an unpaid bill affects the gate. That is a rule the
/// backend has to enforce; this card states the amount and the deadline, and
/// will say more when the server does.
class PaymentDueCard extends StatelessWidget {
  const PaymentDueCard({
    super.key,
    required this.unpaid,
    required this.onReviewAll,
    this.violations = const [],
    this.entryBlocked = false,
  });

  /// Every bill that is neither paid nor waived. Never empty — the caller shows
  /// this card only when something is owed.
  final List<Payment> unpaid;

  /// The user's violations, used to name the rule behind a fine. A bill only
  /// carries the violation's id, and the card falls back to a generic label
  /// while this has not loaded rather than waiting for it.
  final List<ViolationSummary> violations;

  /// The server says unpaid bills are currently stopping this account at the
  /// gate. Only ever true when the server has told us so — this card never
  /// asserts a gate rule the app has not been given.
  final bool entryBlocked;

  /// Switches to the Payments tab.
  final VoidCallback onReviewAll;

  /// The bill that has waited longest. Every unpaid bill stops entry alike, so
  /// there is no deadline to rank them by.
  static Payment mostUrgent(List<Payment> bills) {
    final sorted = [...bills]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final balance = unpaid.fold<double>(0, (sum, p) => sum + p.amountDue);
    final single = unpaid.length == 1 ? unpaid.first : null;
    final featured = mostUrgent(unpaid);
    final others = unpaid.length - 1;

    final label = single == null
        ? 'Review and pay'
        : single.isProcessing
            ? 'View payment'
            : 'Pay now';

    void onPressed() {
      if (single == null) {
        onReviewAll();
      } else {
        context.push('/home/user/payments/${single.paymentId}');
      }
    }

    return AppAlertCard(
      // Red when the server says this is what is stopping entry.
      intent: entryBlocked ? StatusIntent.danger : StatusIntent.warning,
      eyebrow: 'Payment due',
      message: entryBlocked
          ? "You can't enter until this is paid. You can still leave the lot."
          : null,
      action: AppButton(label: label, onPressed: onPressed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap, so at a large text size the caption drops under the amount
          // instead of pushing it off the card.
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                Formatters.peso(balance),
                style: AppTypography.tabular(context.text.headlineLarge!),
              ),
              Text(
                unpaid.length == 1 ? 'for 1 bill' : 'across ${unpaid.length} bills',
                style: context.text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _BillDetails(
            bill: featured,
            violation: _violationFor(featured),
            heading: single == null ? 'Most urgent' : null,
          ),
          if (others > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              others == 1 ? '+ 1 more bill' : '+ $others more bills',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  ViolationSummary? _violationFor(Payment bill) {
    final id = bill.violationId;
    if (id == null) return null;
    for (final v in violations) {
      if (v.violationId == id) return v;
    }
    return null;
  }
}

/// The part of the Payment Due card that says what one bill is for.
class _BillDetails extends StatelessWidget {
  const _BillDetails({required this.bill, this.violation, this.heading});

  final Payment bill;

  /// The violation behind a fine, when it is known.
  final ViolationSummary? violation;

  /// A small line above the bill, used when the card has several to choose from.
  final String? heading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = context.text;

    final title = bill.isViolation
        ? (violation?.policyRuleTitle ?? 'Violation fine')
        : 'Parking fee';

    final lines = <String>[
      if (bill.isViolation)
        'Issued ${Formatters.date(violation?.createdAt ?? bill.createdAt)}'
      else ...[
        'Parked ${Formatters.duration(Duration(minutes: bill.durationMinutes))}'
            ' at ${Formatters.peso(bill.ratePerHourApplied)}/hr',
        if (bill.entryTime != null)
          Formatters.sessionRange(
            bill.entryTime!.toLocal(),
            bill.exitTime?.toLocal(),
            Duration(minutes: bill.durationMinutes),
          ),
      ],
    ];

    final due = bill.dueLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null) Text(heading!, style: text.labelSmall),
          Text(title, style: text.titleSmall),
          for (final line in lines) Text(line, style: text.bodySmall),
          if (due != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                due,
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown only when a violation is open. The whole card is the way in, and the
/// deadline is the point: an appeal that is missed cannot be made later.
class OpenViolationsCard extends StatelessWidget {
  const OpenViolationsCard({super.key, required this.open});

  /// The violations that are issued or under appeal. Never empty.
  final List<ViolationSummary> open;

  @override
  Widget build(BuildContext context) {
    final count = open.length;

    // The soonest deadline the user can still beat.
    final deadlines = open
        .where((v) => v.canAppeal && v.appealDeadline != null)
        .map((v) => v.appealDeadline!)
        .toList()
      ..sort();
    final next = deadlines.isEmpty ? null : deadlines.first;

    return AppAlertCard(
      intent: StatusIntent.danger,
      eyebrow: count == 1 ? '1 open violation' : '$count open violations',
      title: 'Review and appeal',
      message: next == null
          ? 'Waiting on the parking office to decide your appeal.'
          : 'Appeal by ${Formatters.date(next)} · ${appealTimeLeft(next)}',
      onTap: () => context.push('/home/user/violations'),
    );
  }
}

/// How many strikes the user has, out of [kStrikeLimit]. Always shown, so a clean
/// record reads as good news rather than as a missing card.
///
/// Counts only violations that are final (see [ViolationSummary.isStrike]).
/// Ones still being appealed are mentioned underneath but not counted, because
/// they may yet be won. Tapping opens the full list.
class ViolationStrikesCard extends StatelessWidget {
  const ViolationStrikesCard({super.key, required this.violations});

  final List<ViolationSummary> violations;

  @override
  Widget build(BuildContext context) {
    final strikes = violations.where((v) => v.isStrike).length;
    final underReview = violations.where((v) => v.isOpen).length;
    final capped = strikes.clamp(0, kStrikeLimit);
    final left = kStrikeLimit - capped;

    final (intent, title, message) = switch (capped) {
      0 => (
          StatusIntent.success,
          'No violations',
          'Very good. Keep it up.',
        ),
      1 => (
          StatusIntent.info,
          '1 of $kStrikeLimit violations',
          '$left more and your account is suspended.',
        ),
      2 => (
          StatusIntent.warning,
          '2 of $kStrikeLimit violations',
          'Be careful. One more and your account is suspended.',
        ),
      _ => (
          StatusIntent.danger,
          "You're suspended",
          'Your RFID card is revoked. Please see the parking office.',
        ),
    };

    final colors = context.tokens.status.of(intent);

    return AppAlertCard(
      intent: intent,
      eyebrow: 'Violations',
      title: title,
      message: message,
      onTap: () => context.push('/home/user/violations'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < kStrikeLimit; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs + 2),
                _StrikeDot(
                  filled: i < capped,
                  fill: colors.solid,
                  outline: context.tokens.border.normal,
                ),
              ],
            ],
          ),
          if (underReview > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              underReview == 1
                  ? '1 more is still open or under appeal. It does not count yet.'
                  : '$underReview more are still open or under appeal. They do not count yet.',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StrikeDot extends StatelessWidget {
  const _StrikeDot({
    required this.filled,
    required this.fill,
    required this.outline,
  });

  final bool filled;
  final Color fill;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? fill : Colors.transparent,
        border: Border.all(color: filled ? fill : outline, width: 2),
      ),
    );
  }
}

/// Shown while the driver has not said which bay they parked in.
///
/// Asking is the whole point: the sensors only know a bay has something in it,
/// never whose car, and a guard looking into a violation or an incident needs
/// to know who was where. A session that has ended is still asked about until
/// midnight, which is as long as the server takes an answer.
///
/// One tap, to the map on the Parking screen, where the driver picks the bay.
class ConfirmSlotCard extends StatelessWidget {
  const ConfirmSlotCard({super.key, required this.session});

  /// The session still waiting for a bay. Never one already confirmed.
  final ParkingHistoryEntry session;

  @override
  Widget build(BuildContext context) {
    return AppAlertCard(
      intent: StatusIntent.info,
      eyebrow: 'Where did you park?',
      icon: Icons.local_parking_rounded,
      title: session.isOpen
          ? 'Tell us which bay is yours'
          : 'You left today. Which bay did you use?',
      message:
          'Tap your bay on the map and confirm it, so the guards know it was '
          'you if something happens there.',
      onTap: () => context.push('/home/user/parking-slots'),
    );
  }
}
