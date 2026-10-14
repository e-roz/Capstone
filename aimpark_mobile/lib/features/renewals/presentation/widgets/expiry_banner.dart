import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/expiry.dart';
import '../providers/renewals_provider.dart';

/// On Home when a licence or registration is within 30 days of running out, has
/// run out, or has a renewal that is waiting or came back.
///
/// Draws nothing otherwise, and carries its own gap below so the caller does not
/// leave a hole when there is nothing to say.
class ExpiryBanner extends ConsumerWidget {
  const ExpiryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(documentItemsProvider).where((i) => i.needsAttention).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[
          _notice(context, item),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _notice(BuildContext context, DocumentItem item) {
    final title = item.target.title;

    if (item.isPending) {
      return AppNotice(
        intent: StatusIntent.info,
        icon: Icons.hourglass_top_rounded,
        title: '$title is waiting for review',
        message:
            'An admin is checking your renewed document. Your access stays as it '
            'is until it is approved.',
      );
    }

    final upload = AppButton(
      label: 'Upload renewed document',
      style: AppButtonStyle.secondary,
      icon: const Icon(Icons.upload_rounded),
      onPressed: () => context.push('/home/user/renew', extra: item.target),
    );

    if (item.isRejected) {
      final reason = item.renewal?.rejectReason ?? '';
      return AppNotice(
        intent: StatusIntent.danger,
        title: '$title was not accepted',
        message: reason.isEmpty ? 'Upload it again.' : '$reason Upload it again.',
        action: upload,
      );
    }

    final info = item.info;
    final expired = info.level == ExpiryLevel.expired;

    return AppNotice(
      intent: expired ? StatusIntent.danger : StatusIntent.warning,
      title: expired
          ? '$title has expired'
          : info.days == 0
              ? '$title expires today'
              : '$title expires in ${info.days} ${info.days == 1 ? 'day' : 'days'}',
      message: 'Renew it, then upload the new one so an admin can review it.',
      action: upload,
    );
  }
}
