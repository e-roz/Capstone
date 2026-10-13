import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_card.dart';
import 'app_skeleton.dart';
import 'app_status_badge.dart';
import 'app_text_link.dart';

/// Whether the RFID card in the user's hand will open the gate.
///
/// Deliberately a small closed set rather than the server's status string: the
/// card has to say something different, and look different, for a suspension
/// that is only *scheduled* (the card still works, and the user can still
/// appeal) than for one that is in force, and a status string cannot tell those
/// apart. The mapping from the API lives with the account feature, where the
/// model is; this widget only draws.
enum AccessCardState {
  /// The card works.
  active,

  /// A suspension is on the books but has not started. The card still works and
  /// the appeal window is open.
  scheduled,

  /// The gate would refuse the card right now.
  suspended,

  /// The card itself is fine, but entry is refused until a bill is paid. Exit is
  /// not. Distinct from [suspended]: paying lifts it at once, so it is drawn as
  /// a warning, not a block. "Blocked" is kept for what an admin did.
  entryBlocked,

  /// Access was taken after the violation limit.
  revoked,

  /// No card has been assigned to this account yet.
  noCard,

  /// The status could not be read. Never drawn as "active": a card that cannot
  /// be checked is not a card known to work.
  unavailable;

  /// The card is, or is about to be, refused at the gate. Home moves the card to
  /// the top of the screen for these; a card that merely could not be checked, or
  /// has not been issued, is not a restriction and stays where it is.
  ///
  /// [entryBlocked] is left out on purpose: Home already shows the amount owed in
  /// the payment card, with the button to settle it, so a second card at the top
  /// saying the same thing would only crowd it.
  bool get isRestricted => switch (this) {
        AccessCardState.scheduled ||
        AccessCardState.suspended ||
        AccessCardState.revoked =>
          true,
        _ => false,
      };

  /// Anything other than a card that simply works. These states are drawn as
  /// alerts, with a coloured edge.
  bool get needsAttention => switch (this) {
        AccessCardState.active || AccessCardState.noCard => false,
        _ => true,
      };

  StatusIntent get intent => switch (this) {
        AccessCardState.active => StatusIntent.success,
        AccessCardState.scheduled ||
        AccessCardState.entryBlocked =>
          StatusIntent.warning,
        AccessCardState.suspended || AccessCardState.revoked =>
          StatusIntent.danger,
        AccessCardState.noCard || AccessCardState.unavailable =>
          StatusIntent.neutral,
      };

  String get badge => switch (this) {
        AccessCardState.active => 'Active',
        AccessCardState.scheduled => 'Suspending soon',
        AccessCardState.suspended => 'Suspended',
        AccessCardState.entryBlocked => 'Payment required',
        AccessCardState.revoked => 'Revoked',
        AccessCardState.noCard => 'No card',
        AccessCardState.unavailable => 'Unknown',
      };
}

/// The RFID card, drawn as a card.
///
/// A mini card on the left carries the state's colour; the title, tag number and
/// a status pill sit beside it. When something is wrong the whole tile switches
/// to the alert treatment — coloured edge and outline, white fill — so it can be
/// told apart from a card that is fine at a glance.
///
/// [tagId] is shown in full, as the account screen has always shown it. [message]
/// is the sentence under it for any state that has something to explain.
class AppAccessCard extends StatelessWidget {
  const AppAccessCard({
    super.key,
    required AccessCardState this.state,
    this.tagId,
    this.message,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  /// The loading shape: same footprint, so nothing moves when the answer lands.
  const AppAccessCard.loading({super.key})
      : state = null,
        tagId = null,
        message = null,
        onRetry = null,
        actionLabel = null,
        onAction = null;

  final AccessCardState? state;
  final String? tagId;
  final String? message;

  /// Offered when [state] is [AccessCardState.unavailable].
  final VoidCallback? onRetry;

  /// An optional link under the message, e.g. "Pay now" on [AccessCardState.entryBlocked].
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) return const AppSkeleton.block(height: 88);

    final t = context.tokens;
    final intent = s.intent;
    final c = t.status.of(intent);

    // The mini card is brand indigo when all is well and takes the status colour
    // when it is not, so the picture and the pill never disagree.
    final cardFill =
        s == AccessCardState.active ? t.brand.primary : c.solid;

    final tagLine = tagId == null || tagId!.isEmpty ? null : 'Tag $tagId';
    final hasRetry = s == AccessCardState.unavailable && onRetry != null;

    final semantics = [
      'RFID access card',
      ?tagLine,
      s.badge,
      ?message,
    ].join('. ');

    // One spoken sentence for the card. The exception is the retry link: hiding
    // it inside the card's own description would leave a screen-reader user
    // reading "could not check" with no way to act on it, so a card that has one
    // keeps its children separately reachable.
    return Semantics(
      container: true,
      label: hasRetry ? null : semantics,
      excludeSemantics: !hasRetry,
      child: AppCard(
          borderColor: s.needsAttention ? c.border : null,
          edgeColor: s.needsAttention ? c.solid : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cardFill,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Icon(
                      Icons.contactless_rounded,
                      size: AppSizes.iconLg,
                      color: t.brand.onSolid,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RFID access card',
                          style: context.text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (tagLine != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            tagLine,
                            style: AppTypography.tabular(context.text.bodySmall!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppStatusBadge(label: s.badge, intent: intent, showDot: true),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm + 4),
                Text(
                  message!,
                  style: context.text.bodySmall?.copyWith(
                    color: s.needsAttention ? c.fg : null,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Transform.translate(
                    offset: const Offset(-AppSpacing.sm, 0),
                    child: AppTextLink(label: actionLabel!, onTap: onAction!),
                  ),
                ),
              if (hasRetry)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Transform.translate(
                    // The link carries 8dp of side padding for its touch
                    // target; pulled back so its text lines up with the message.
                    offset: const Offset(-AppSpacing.sm, 0),
                    child: AppTextLink(label: 'Try again', onTap: onRetry!),
                  ),
                ),
            ],
          ),
        ),
    );
  }
}
