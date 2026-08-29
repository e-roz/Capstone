import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// The one status chip for the whole panel.
///
/// It replaces seven near-identical private `_StatusChip` / `_RfidStatusChip` /
/// `_ActionChip` classes that each re-decided what green meant. The visual
/// treatment — tinted background, saturated text, hairline border — reads far
/// better in a dense table than the previous solid-colour chips, which drew
/// more attention than the data they were labelling.
///
/// ```dart
/// StatusPill(label: user.status, intent: StatusIntents.user(user.status))
/// ```
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.intent,
    this.dense = false,
    this.showDot = true,
    this.icon,
  });

  /// Convenience for the common case where the raw string is also the label.
  const StatusPill.of(
    this.label, {
    super.key,
    required this.intent,
    this.dense = false,
    this.showDot = true,
    this.icon,
  });

  final String label;
  final StatusIntent intent;

  /// Tighter padding for use inside a table cell.
  final bool dense;

  /// The leading dot carries the status at a glance for anyone who cannot
  /// separate the tints; drop it only when an [icon] says the same thing.
  final bool showDot;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.x2 : AppSpacing.x3,
        vertical: dense ? 2 : AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.fullAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.fg),
            const SizedBox(width: AppSpacing.x1),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c.solid, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.x2 - 2),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.fg),
          ),
        ],
      ),
    );
  }
}

/// Maps each domain's status strings onto a [StatusIntent].
///
/// These live here, not inside [StatusPill], because the domains genuinely
/// disagree: an *appeal* that is `Dismissed` went the admin's way, while an
/// *incident* that is `Dismissed` was closed without action. A single global
/// string→colour map would have to pick one and be wrong on the other screen —
/// which is exactly the bug the old duplicated chips had.
///
/// When you add a status to the API, add it here. Anything unlisted degrades to
/// [StatusIntent.neutral] rather than throwing, so a new backend value shows up
/// as a grey pill instead of crashing the table.
class StatusIntents {
  StatusIntents._();

  /// Account status on User Management and User Detail.
  static StatusIntent user(String status) => switch (status) {
        'Active' => StatusIntent.success,
        'Suspended' => StatusIntent.warning,
        'Rejected' => StatusIntent.danger,
        'Pending' || 'PendingReview' => StatusIntent.info,
        _ => StatusIntent.neutral,
      };

  /// RFID card state.
  static StatusIntent rfid(String status) => switch (status) {
        'Active' => StatusIntent.success,
        'Suspended' => StatusIntent.warning,
        'Lost' || 'Revoked' => StatusIntent.danger,
        _ => StatusIntent.info,
      };

  /// Registration review state — the `VerificationStatus` enum on the API.
  ///
  /// `Approved`/`Rejected` are kept as aliases for the wording the queue used
  /// before it moved onto the enum; the rest are the values the API actually
  /// sends, which previously all fell through to a grey `neutral` pill.
  static StatusIntent registration(String status) => switch (status) {
        'Passed' || 'Approved' => StatusIntent.success,
        'Failed' || 'Rejected' => StatusIntent.danger,
        'ManualReview' || 'Pending' => StatusIntent.warning,
        _ => StatusIntent.neutral,
      };

  /// Violation and appeal outcomes. Note `Dismissed` is a *good* outcome here.
  static StatusIntent violation(String status) => switch (status) {
        'Approved' || 'Overturned' || 'Dismissed' => StatusIntent.success,
        'Denied' || 'Upheld' => StatusIntent.danger,
        'Appealed' => StatusIntent.warning,
        'Pending' => StatusIntent.info,
        _ => StatusIntent.neutral,
      };

  /// Incident triage state. Note `Dismissed` is *not* a good outcome here.
  static StatusIntent incident(String status) => switch (status) {
        'Resolved' => StatusIntent.success,
        'Dismissed' => StatusIntent.danger,
        'UnderReview' => StatusIntent.warning,
        _ => StatusIntent.info,
      };

  /// Payment settlement state.
  static StatusIntent payment(String status) => switch (status) {
        'Paid' => StatusIntent.success,
        'Waived' => StatusIntent.info,
        'Overdue' || 'Failed' => StatusIntent.danger,
        _ => StatusIntent.warning,
      };

  /// Parking slot occupancy. Occupied is deliberately *not* a warning — a full
  /// lot is normal operation, not a problem to flag.
  static StatusIntent slot(String status) => switch (status) {
        'Available' => StatusIntent.success,
        'Occupied' => StatusIntent.accent,
        'Reserved' => StatusIntent.info,
        'OutOfService' => StatusIntent.danger,
        _ => StatusIntent.neutral,
      };

  /// Broadcast notification categories. These are *kinds*, not states, so the
  /// colours separate them rather than ranking them — only `System` carries
  /// urgency, because it is the one an admin did not choose to send.
  static StatusIntent notificationType(String type) => switch (type) {
        'Announcement' => StatusIntent.info,
        'PolicyUpdate' => StatusIntent.accent,
        'ParkingAvailability' => StatusIntent.success,
        'System' => StatusIntent.warning,
        _ => StatusIntent.neutral,
      };

  /// Audit-log actions, coloured by whether they granted or removed access.
  ///
  /// `RestoreBackup` is the database-level restore and is deliberately red
  /// while the account-level `Restore` is green: one gives an account back, the
  /// other replaces every row in the system.
  static StatusIntent auditAction(String action) => switch (action) {
        'Approve' || 'Unsuspend' || 'Restore' => StatusIntent.success,
        'Reject' || 'Suspend' || 'Archive' || 'Delete' => StatusIntent.danger,
        'RestoreBackup' => StatusIntent.danger,
        'Backup' => StatusIntent.info,
        _ => StatusIntent.info,
      };
}
