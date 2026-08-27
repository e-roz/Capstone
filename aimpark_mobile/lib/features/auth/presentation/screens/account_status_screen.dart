import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Explains why a login was refused.
///
/// The API always returned this detail — status, rejection reason, when the user
/// may re-apply — but the app discarded it into a two-second toast, so a user
/// waiting on approval simply appeared locked out with no explanation.
class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({
    super.key,
    required this.accountStatus,
    this.message,
    this.rejectionReason,
    this.canReapplyAt,
  });

  /// `PendingReview`, `Rejected`, `Suspended` — as returned by the API.
  final String accountStatus;
  final String? message;
  final String? rejectionReason;
  final DateTime? canReapplyAt;

  bool get _isPending => accountStatus == 'PendingReview';
  bool get _isRejected => accountStatus == 'Rejected';
  bool get _isSuspended => accountStatus == 'Suspended';

  /// Carries a [StatusIntent] rather than a `Color`: waiting for approval is
  /// *informational*, not orange, and stating the intent means dark mode
  /// follows without this screen knowing about it.
  ({IconData icon, StatusIntent intent, String title, String body})
      get _presentation {
    if (_isPending) {
      return (
        icon: Icons.hourglass_top_rounded,
        intent: StatusIntent.info,
        title: 'Waiting for approval',
        body: 'An administrator is reviewing your registration and documents. '
            "You'll be notified once a decision is made — there's nothing you "
            'need to do in the meantime.',
      );
    }

    if (_isRejected) {
      return (
        icon: Icons.cancel_rounded,
        intent: StatusIntent.danger,
        title: 'Registration not approved',
        body: 'Your registration was reviewed and could not be approved.',
      );
    }

    if (_isSuspended) {
      return (
        icon: Icons.gpp_bad_rounded,
        intent: StatusIntent.danger,
        title: 'Account suspended',
        body: message ??
            'Your account has been suspended. Please contact the administrator.',
      );
    }

    // A status this build does not recognise. Suspension used to be the
    // fallback, which made it the thing an unrecognised value said — and it
    // said it to people whose accounts were merely waiting for approval, after
    // the API sent `0` where the name was expected. An accusation is the worst
    // possible default: it names a punishment nobody has issued, and the user
    // cannot tell it apart from a real one.
    //
    // The server's own sentence is shown instead, which is right whatever the
    // status turns out to be.
    return (
      icon: Icons.info_outline_rounded,
      intent: StatusIntent.info,
      title: "You can't sign in yet",
      body: message ??
          'Your account is not ready to be used yet. Please contact the '
              'administrator.',
    );
  }

  /// Whole days remaining, rounded up — "in 1 day" reads better than "in 4 hours"
  /// for a cooldown measured in days.
  String? get _reapplyText {
    if (canReapplyAt == null) return null;

    final remaining = canReapplyAt!.difference(DateTime.now());
    if (remaining.isNegative) return 'You can now re-apply.';

    if (remaining.inHours < 1) return 'You can re-apply in under an hour.';
    if (remaining.inHours < 24) return 'You can re-apply in ${remaining.inHours} hour(s).';

    final days = (remaining.inHours / 24).ceil();
    return 'You can re-apply in $days day(s).';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = _presentation;
    final c = t.status.of(p.intent);
    final reapply = _reapplyText;

    return AppScreen.tab(
      body: AppFormBody(
        maxWidth: 420,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
            child: Icon(p.icon, size: 52, color: c.fg),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            p.title,
            textAlign: TextAlign.center,
            style: context.text.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            p.body,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          if (_isRejected && rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              color: c.bg,
              borderColor: c.border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason given',
                    style: context.text.labelLarge?.copyWith(color: c.fg),
                  ),
                  const SizedBox(height: 4),
                  Text(rejectionReason!, style: context.text.bodyMedium),
                ],
              ),
            ),
          ],
          if (reapply != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: AppSizes.iconSm,
                  color: t.text.secondary,
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(reapply, style: context.text.bodySmall)),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Back to login',
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}
