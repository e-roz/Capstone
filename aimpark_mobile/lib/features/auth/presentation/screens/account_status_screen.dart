import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

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

  ({IconData icon, Color color, String title, String body}) get _presentation {
    if (_isPending) {
      return (
        icon: Icons.hourglass_top_rounded,
        color: AppColors.brandPressed,
        title: 'Waiting for approval',
        body: 'An administrator is reviewing your registration and documents. '
            "You'll be notified once a decision is made — there's nothing you "
            'need to do in the meantime.',
      );
    }

    if (_isRejected) {
      return (
        icon: Icons.cancel_rounded,
        color: AppColors.errorPressed,
        title: 'Registration not approved',
        body: 'Your registration was reviewed and could not be approved.',
      );
    }

    return (
      icon: Icons.gpp_bad_rounded,
      color: AppColors.errorPressed,
      title: 'Account suspended',
      body: message ??
          'Your account has been suspended. Please contact the administrator.',
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
    final p = _presentation;
    final reapply = _reapplyText;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p.icon, size: 64, color: p.color),
                  const SizedBox(height: AppSpacing.md),
                  Text(p.title,
                      textAlign: TextAlign.center, style: AppTextStyles.h2),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    p.body,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  if (_isRejected && rejectionReason != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      color: AppColors.errorSubtle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reason given',
                              style: AppTextStyles.labelBold
                                  .copyWith(color: AppColors.errorPressed)),
                          const SizedBox(height: 4),
                          Text(rejectionReason!,
                              style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                  if (reapply != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            reapply,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ),
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
            ),
          ),
        ),
      ),
    );
  }
}
