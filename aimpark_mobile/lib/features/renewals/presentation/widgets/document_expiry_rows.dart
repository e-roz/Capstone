import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/renewal.dart';
import '../providers/renewals_provider.dart';

/// The user's licence and each vehicle's registration, with how long each has
/// left. Tapping one starts a renewal unless one is already waiting.
///
/// Shown on the Account tab and on its own Documents screen, so the dates are
/// always one place away from wherever the user is looking for them.
class DocumentExpiryRows extends ConsumerWidget {
  const DocumentExpiryRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(documentItemsProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    return AppRowGroup(
      children: [for (final item in items) _DocumentRow(item: item)],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.item});

  final DocumentItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final info = item.info;
    final expiry = item.expiry;

    final (label, intent) = item.isPending
        ? ('In review', StatusIntent.info)
        : item.isRejected
            ? ('Not accepted', StatusIntent.danger)
            : (info.phrase, info.intent);

    return AppListRow(
      icon: item.target.kind == RenewalKind.license
          ? Icons.badge_outlined
          : Icons.description_outlined,
      intent: item.needsAttention ? intent : null,
      title: item.target.title,
      subtitle: expiry == null
          ? 'No expiry date on file'
          : 'Expires ${Formatters.date(expiry.toLocal())}',
      note: item.isRejected && (item.renewal?.rejectReason ?? '').isNotEmpty
          ? Text(
              item.renewal!.rejectReason!,
              style: context.text.bodySmall?.copyWith(color: t.status.danger.fg),
            )
          : null,
      trailing: AppStatusBadge(label: label, intent: intent),
      showChevron: item.canRenew,
      onTap: item.canRenew
          ? () => context.push('/home/user/renew', extra: item.target)
          : null,
    );
  }
}
