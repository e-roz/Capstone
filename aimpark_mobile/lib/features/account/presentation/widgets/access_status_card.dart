import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/my_profile.dart';
import '../providers/account_provider.dart';

/// The user's RFID card and whether it will open the gate, read live from
/// `/api/account/access-status`.
///
/// The one place that turns the API's answer into an [AppAccessCard], so Home
/// and Account cannot describe the same card differently.
///
/// While loading it holds the card's footprint so nothing jumps, and when the
/// lookup fails it says so and offers a retry. It never falls back to showing an
/// active card: this is the one status on the phone with a consequence at the
/// gate, and "could not check" is not the same answer as "fine".
class AccessStatusCard extends ConsumerWidget {
  const AccessStatusCard({super.key, this.onGoToPayments});

  /// Where "Go to payments" leads. Home passes a tab switch, so the user lands on
  /// the Payments tab and Back is not needed. Without it the link opens the
  /// payments list as its own page, which has a Back to wherever the card is.
  final VoidCallback? onGoToPayments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accessStatusProvider);

    return async.when(
      // Keeps showing the last answer while a pull-to-refresh asks again, so the
      // card does not flash to a skeleton and back on every refresh.
      skipLoadingOnReload: true,
      data: (status) {
        final view = AccessCardView.from(status);
        return AppAccessCard(
          state: view.state,
          tagId: status.rfidTagId,
          message: view.message,
          actionLabel: view.state == AccessCardState.entryBlocked
              ? 'Go to payments'
              : null,
          onAction: view.state == AccessCardState.entryBlocked
              ? onGoToPayments ?? () => context.push('/home/user/payments')
              : null,
        );
      },
      loading: () => const AppAccessCard.loading(),
      error: (_, _) => AppAccessCard(
        state: AccessCardState.unavailable,
        message: "We couldn't check your card right now.",
        onRetry: () => ref.invalidate(accessStatusProvider),
      ),
    );
  }
}

/// What to draw for one [AccessStatus]: the state and the sentence under it.
///
/// A top-level class rather than private to the widget so the mapping — which is
/// the part with the business rules in it — can be read, and tested, on its own.
class AccessCardView {
  const AccessCardView(this.state, this.message);

  final AccessCardState state;
  final String? message;

  /// Order matters, most serious first:
  ///
  /// 1. Revoked outranks everything.
  /// 2. A suspension in force. A *scheduled* one is not: the API reports
  ///    `Suspended` for the whole appeal window while the card still opens the
  ///    gate, and drawing that as a flat suspension would tell the user the
  ///    fight is already lost.
  /// 3. No card at all — there is nothing for a bill to block.
  /// 4. Entry refused until a bill is paid. Before the scheduled case, because
  ///    "refused now" is the more urgent thing to say than "refused later".
  /// 5. A scheduled suspension, then a card that simply works.
  factory AccessCardView.from(AccessStatus s) {
    final rfid = s.rfidStatus.toLowerCase();

    if (rfid == 'revoked') {
      return const AccessCardView(
        AccessCardState.revoked,
        'Revoked after 3 accountable violations. Please see the parking '
        'office.',
      );
    }

    if (s.isSuspendedNow || (rfid == 'suspended' && !s.hasPendingSuspension)) {
      final until = s.suspensionEndsAt;
      final owed = s.isEntryBlockedByBalance ? s.outstandingBalance : null;

      // Two separate things, said separately. The suspension is a time-out that
      // paying does not shorten; the balance is a second block that only paying
      // lifts, and it takes over the moment the suspension ends. Both are known
      // now, so the user is told now, and can pay while they wait.
      final fee = owed == null
          ? ''
          : ' You will also need to pay ${Formatters.peso(owed)} before you can '
                'enter once it ends. Paying now does not end the suspension.';

      return AccessCardView(
        AccessCardState.suspended,
        until == null
            ? 'Suspended until further notice. Please see the parking office.'
            : 'Suspended until ${Formatters.date(until)}. The gate will not '
                  'open for this card.$fee',
      );
    }

    if (rfid == 'unassigned' || s.rfidTagId == null || s.rfidTagId!.isEmpty) {
      return const AccessCardView(
        AccessCardState.noCard,
        'Go to the administrator to get your card.',
      );
    }

    if (s.isEntryBlockedByBalance) {
      // Not a suspension: the card itself is active, and paying lifts this at
      // once. The word "suspended" is kept for what an admin put in place.
      final owed = s.outstandingBalance;
      return AccessCardView(
        AccessCardState.entryBlocked,
        owed == null
            ? 'Your card is active, but you have an unpaid balance. Pay it to '
                  'enter.'
            : 'Your card is active, but you have an unpaid balance. Pay '
                  '${Formatters.peso(owed)} to enter.',
      );
    }

    if (s.hasPendingSuspension) {
      return AccessCardView(
        AccessCardState.scheduled,
        'Still works until ${Formatters.date(s.suspensionStartsAt!)}. '
        'Appeal your violation before then.',
      );
    }

    if (rfid == 'active') {
      return const AccessCardView(AccessCardState.active, null);
    }

    // A status this app does not know. Said as it is, rather than guessed at.
    return AccessCardView(
      AccessCardState.unavailable,
      'Card status: ${s.rfidStatus}. Please see the parking office.',
    );
  }
}
