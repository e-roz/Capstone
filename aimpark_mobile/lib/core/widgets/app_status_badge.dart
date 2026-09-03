import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The one status pill for the whole app.
///
/// It replaces the `AppBadgeTone` enum plus the four separate places that each
/// re-decided what a status colour meant: `_tone` getters on the violation and
/// account screens, and a private `_colorsFor(String)` in the parking slots
/// screen that had drifted to a different green.
///
/// ```dart
/// AppStatusBadge(label: payment.status, intent: StatusIntents.payment(payment.status))
/// ```
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.intent,
    this.showDot = false,
    this.icon,
  });

  final String label;
  final StatusIntent intent;

  /// A leading dot carries the status for anyone who cannot separate the tints.
  /// Off by default — these badges are already labelled in words, and the dot
  /// earns its place mainly in a legend, where the word is the only other cue.
  final bool showDot;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(intent);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c.fg),
            const SizedBox(width: AppSpacing.xs),
          ] else if (showDot) ...[
            StatusDot(intent: intent),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
          Text(label, style: context.text.labelSmall?.copyWith(color: c.fg)),
        ],
      ),
    );
  }
}

/// The solid dot on its own, for legends and dense rows where a full pill would
/// crowd the line.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.intent, this.size = 8});

  final StatusIntent intent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.tokens.status.of(intent).solid,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Maps each domain's status strings onto a [StatusIntent].
///
/// These live here, not inside [AppStatusBadge], because the domains genuinely
/// disagree: a *violation* that is `Dismissed` went the user's way, while an
/// *incident* that is `Dismissed` was closed without anyone acting on it. A
/// single global string-to-colour map would have to pick one and be wrong on
/// the other screen — which is exactly the bug the duplicated `_tone` getters
/// had, where a dismissed incident showed green.
///
/// When the API grows a status, add it here. Anything unlisted degrades to
/// [StatusIntent.neutral] rather than throwing, so a new backend value shows up
/// as a grey pill instead of crashing the list.
///
/// Every lookup lower-cases first. The API is inconsistent about casing between
/// endpoints, and matching on the exact string is how the old code ended up
/// with a `switch` that quietly fell through to its default.
abstract class StatusIntents {
  /// Violation and appeal outcomes. `Dismissed` is a *good* outcome here.
  static StatusIntent violation(String status) => switch (status.toLowerCase()) {
        // `Paid` arrives here because a settled violation shows its payment
        // state in place of its appeal state. Without it the badge fell through
        // to the default and a fine the user had just paid stayed red.
        'resolved' || 'dismissed' || 'overturned' || 'paid' =>
          StatusIntent.success,
        'appealed' => StatusIntent.warning,
        'upheld' || 'denied' => StatusIntent.danger,
        'pending' => StatusIntent.info,
        _ => StatusIntent.danger,
      };

  /// Payment settlement state.
  static StatusIntent payment(String status) => switch (status.toLowerCase()) {
        'paid' => StatusIntent.success,
        'waived' => StatusIntent.info,
        // Neither settled nor outstanding: the payer is at the provider and the
        // answer is on its way.
        'processing' => StatusIntent.info,
        'overdue' || 'failed' => StatusIntent.danger,
        _ => StatusIntent.warning,
      };

  /// Incident triage state. `Dismissed` is *not* a good outcome here.
  static StatusIntent incident(String status) => switch (status.toLowerCase()) {
        'resolved' => StatusIntent.success,
        'dismissed' => StatusIntent.danger,
        'underreview' || 'under review' => StatusIntent.warning,
        _ => StatusIntent.info,
      };

  /// Parking slot occupancy. Occupied is deliberately *not* an error — a full
  /// bay is normal operation, and colouring it red made a healthy car park look
  /// like a fault report.
  static StatusIntent slot(String status) => switch (status.toLowerCase()) {
        'available' => StatusIntent.success,
        'occupied' => StatusIntent.brand,
        'reserved' => StatusIntent.info,
        'outofservice' || 'out of service' => StatusIntent.neutral,
        _ => StatusIntent.neutral,
      };

  /// RFID card state — what stands between the user and the gate opening.
  static StatusIntent rfid(String status) => switch (status.toLowerCase()) {
        'active' => StatusIntent.success,
        'suspended' => StatusIntent.danger,
        'lost' || 'revoked' => StatusIntent.danger,
        _ => StatusIntent.warning,
      };

  /// The account's own review state.
  static StatusIntent account(String status) => switch (status.toLowerCase()) {
        'active' => StatusIntent.success,
        'suspended' => StatusIntent.warning,
        'rejected' => StatusIntent.danger,
        'pending' || 'pendingreview' => StatusIntent.info,
        _ => StatusIntent.neutral,
      };

  /// Broadcast notification categories. These are *kinds*, not states, so the
  /// colours separate them rather than ranking them.
  static StatusIntent notificationType(String type) =>
      switch (type.toLowerCase()) {
        'announcement' => StatusIntent.info,
        'policyupdate' => StatusIntent.brand,
        'parkingavailability' => StatusIntent.success,
        'violation' => StatusIntent.danger,
        'payment' => StatusIntent.warning,
        // The outcome of something the user reported, not something they did
        // wrong — so warning rather than danger, whichever way it went.
        'incident' => StatusIntent.warning,
        _ => StatusIntent.neutral,
      };
}
