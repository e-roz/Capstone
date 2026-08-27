import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/parking_history_provider.dart';

class ParkingHistoryScreen extends ConsumerWidget {
  const ParkingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() =>
        ref.read(parkingHistoryNotifierProvider.notifier).refresh();

    return AppScreen.tab(
      body: AsyncView(
        value: ref.watch(parkingHistoryNotifierProvider),
        onRefresh: refresh,
        errorTitle: "Couldn't load your history",
        loading: const Padding(
          padding: kScreenListPadding,
          child: AppRowSkeleton(),
        ),
        isEmpty: (result) => result.logs.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.local_parking_rounded,
          title: 'No parking history yet',
          message: 'Your entries and exits will show up here.',
        ),
        data: (result) => ListView(
          padding: kScreenListPadding,
          children: [
            const AppSectionHeader(
              title: 'History',
              padding: EdgeInsets.only(bottom: AppSpacing.lg),
            ),
            for (final log in result.logs) ...[
              AppListRow(
                icon: log.isOpen ? Icons.login_rounded : Icons.logout_rounded,
                intent: log.isOpen ? StatusIntent.success : null,
                title: log.slotCode ?? 'Unassigned slot',
                subtitle: Formatters.sessionRange(
                  log.entryTime,
                  log.exitTime,
                  log.duration,
                ),
                trailing: log.isOpen
                    ? const AppStatusBadge(
                        label: 'Parked now',
                        intent: StatusIntent.success,
                      )
                    : null,
              ),
              if (log != result.logs.last) const AppRowGap(),
            ],
          ],
        ),
      ),
    );
  }
}
