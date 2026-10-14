import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/widgets/scanned_field.dart';
import '../../data/expiry.dart';
import '../../data/renewal.dart';
import '../providers/renewals_provider.dart';

/// The date the renewed document shows, for the user to check, and the step that
/// sends it to an admin.
///
/// Pops with `true` once sent, so the screen behind it can close too.
class ConfirmRenewalScreen extends ConsumerStatefulWidget {
  const ConfirmRenewalScreen({
    super.key,
    required this.scan,
    required this.target,
  });

  final RenewalScan scan;
  final RenewalTarget target;

  @override
  ConsumerState<ConfirmRenewalScreen> createState() =>
      _ConfirmRenewalScreenState();
}

class _ConfirmRenewalScreenState extends ConsumerState<ConfirmRenewalScreen> {
  DateTime? _expiry;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _expiry = widget.scan.extractedExpiry;
  }

  Future<void> _submit() async {
    final expiry = _expiry;
    if (expiry == null) {
      showAppMessage(context, 'Enter the new expiry date.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(renewalsRepositoryProvider)
          .submit(widget.scan.renewalId, expiry);

      // The list now carries one more thing waiting.
      ref.invalidate(myRenewalsProvider);

      if (!mounted) return;

      await CelebrationDialog.show(
        context,
        title: 'Sent for review',
        message:
            'An admin will check it. Your access stays as it is until it is '
            'approved, and we will tell you either way.',
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = !_isSubmitting;
    final status = ExpiryInfo.of(_expiry);

    return AppScreen(
      title: 'Check the date',
      body: ListView(
        padding: kScreenListPadding,
        children: [
          AppNotice(
            title: 'Is this right?',
            message: 'This is the expiry date we read from your '
                '${widget.target.kind == RenewalKind.license ? 'licence' : 'receipt'}. '
                'If it looks wrong, tap it to change it. The admin sees any '
                'change you make.',
            intent: StatusIntent.info,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(title: widget.target.title),
          ScannedDateField(
            label: 'New expiry date',
            value: _expiry,
            enabled: live,
            onChanged: (d) => setState(() => _expiry = d),
          ),
          if (_expiry != null && status.level == ExpiryLevel.expired) ...[
            const SizedBox(height: AppSpacing.sm),
            const AppNotice(
              intent: StatusIntent.danger,
              message: 'That date has already passed. Check you photographed '
                  'the renewed document, not the old one.',
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Send for review',
            isLoading: _isSubmitting,
            onPressed: live ? _submit : null,
          ),
        ],
      ),
    );
  }
}
