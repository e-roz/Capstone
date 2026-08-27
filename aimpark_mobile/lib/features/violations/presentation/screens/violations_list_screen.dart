import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/violations_provider.dart';

class ViolationsListScreen extends ConsumerWidget {
  const ViolationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() =>
        ref.read(violationsNotifierProvider.notifier).refresh();

    return AppScreen(
      title: 'My Violations',
      body: AsyncView(
        value: ref.watch(violationsNotifierProvider),
        onRefresh: refresh,
        errorTitle: "Couldn't load your violations",
        loading: const Padding(
          padding: kScreenListPadding,
          child: AppRowSkeleton(),
        ),
        isEmpty: (result) => result.violations.isEmpty,
        // The one empty state in the app that is an achievement rather than an
        // absence, so it is coloured as one instead of showing the same grey
        // icon as an empty inbox.
        empty: const AppEmptyState(
          icon: Icons.verified_rounded,
          intent: StatusIntent.success,
          title: 'Squeaky clean!',
          message: 'No violations on your record.',
        ),
        data: (result) => ListView(
          padding: kScreenListPadding,
          children: [
            for (final v in result.violations) ...[
              AppListRow(
                icon: Icons.gavel_rounded,
                title: v.policyRuleTitle,
                subtitle: '${Formatters.peso(v.penaltyAmount)} · '
                    '${Formatters.date(v.createdAt)}',
                trailing: AppStatusBadge(
                  label: v.status,
                  intent: StatusIntents.violation(v.status),
                ),
                onTap: () =>
                    context.push('/home/user/violations/${v.violationId}'),
              ),
              if (v != result.violations.last) const AppRowGap(),
            ],
          ],
        ),
      ),
    );
  }
}
