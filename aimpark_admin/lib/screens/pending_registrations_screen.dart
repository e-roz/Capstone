import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/pending_registration.dart';
import '../providers/registrations_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

/// Search and sort run in the widget, not the provider, because this endpoint
/// returns the whole queue in one response — there is no page to be misled
/// about. The paginated screens deliberately do *not* copy this.
class PendingRegistrationsScreen extends ConsumerStatefulWidget {
  const PendingRegistrationsScreen({super.key});

  @override
  ConsumerState<PendingRegistrationsScreen> createState() =>
      _PendingRegistrationsScreenState();
}

class _PendingRegistrationsScreenState
    extends ConsumerState<PendingRegistrationsScreen> {
  static const _submittedColumn = 2;

  String _search = '';
  int _sortColumn = _submittedColumn;

  /// Newest first: the queue is worked from the top, and an admin opening this
  /// screen wants what just arrived, not what arrived in September.
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Pending Registrations',
      subtitle: 'Applications waiting on a decision.',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(pendingRegistrationsProvider),
        ),
      ],
      toolbar: AppToolbar(
        search: AppSearchField(
          hint: 'Search name or email',
          onChanged: (value) => setState(() => _search = value.toLowerCase()),
        ),
      ),
      body: AsyncView(
        value: ref.watch(pendingRegistrationsProvider),
        onRetry: () => ref.invalidate(pendingRegistrationsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.check_circle_outline,
          title: 'Nothing waiting',
          message: 'New applications appear here as students submit them.',
        ),
        data: (all) {
          final rows = _visible(all);

          // An empty result from a filter is a different situation from an
          // empty queue, and saying so saves the "is it broken?" question.
          if (rows.isEmpty) {
            return AppEmptyState(
              icon: Icons.search_off,
              title: 'No matches',
              message: 'Nothing in the queue matches “$_search”.',
            );
          }

          return AppDataTable(
            sortColumnIndex: _sortColumn,
            sortAscending: _sortAscending,
            columns: [
              DataColumn(label: const Text('Full Name'), onSort: _sort),
              DataColumn(label: const Text('Email'), onSort: _sort),
              DataColumn(label: const Text('Submitted'), onSort: _sort),
              DataColumn(label: const Text('Last Updated'), onSort: _sort),
              const DataColumn(label: Text('')),
            ],
            rows: [for (final reg in rows) _row(context, reg)],
            footer: Text(
              rows.length == all.length
                  ? '${all.length} waiting'
                  : '${rows.length} of ${all.length} waiting',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.tokens.text.secondary),
            ),
          );
        },
      ),
    );
  }

  DataRow _row(BuildContext context, PendingRegistration reg) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return DataRow(
      onSelectChanged: (_) => context.go('/pending/${reg.userId}'),
      cells: [
        DataCell(Text(reg.fullName, style: text.titleSmall)),
        DataCell(Text(reg.email)),
        DataCell(Text(_fmt(reg.createdAt),
            style: text.bodyMedium?.copyWith(color: t.text.secondary))),
        DataCell(Text(_fmt(reg.updatedAt),
            style: text.bodyMedium?.copyWith(color: t.text.secondary))),
        // Row click alone gave no hint the review screen existed — same
        // discoverability gap as Incidents.
        DataCell(AppRowAction(
          icon: Icons.fact_check_outlined,
          label: 'Review',
          onPressed: () => context.go('/pending/${reg.userId}'),
        )),
      ],
    );
  }

  void _sort(int column, bool ascending) => setState(() {
        _sortColumn = column;
        _sortAscending = ascending;
      });

  List<PendingRegistration> _visible(List<PendingRegistration> all) {
    final filtered = _search.isEmpty
        ? [...all]
        : all
            .where((r) =>
                r.fullName.toLowerCase().contains(_search) ||
                r.email.toLowerCase().contains(_search))
            .toList();

    filtered.sort((a, b) {
      final order = switch (_sortColumn) {
        0 => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        1 => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        3 => a.updatedAt.compareTo(b.updatedAt),
        _ => a.createdAt.compareTo(b.createdAt),
      };
      return _sortAscending ? order : -order;
    });

    return filtered;
  }

  String _fmt(DateTime dt) =>
      DateFormat('MMM d, yyyy HH:mm').format(dt.toLocal());
}
