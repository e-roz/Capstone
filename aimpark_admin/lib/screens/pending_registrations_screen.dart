import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/pending_registration.dart';
import '../providers/registrations_provider.dart';
import '../theme/theme.dart';
import '../providers/renewals_provider.dart';
import '../widgets/checks_panel.dart';
import '../widgets/renewals_panel.dart';
import '../widgets/ui/ui.dart';

/// The three lists an applicant moves through. Pending is the queue; the
/// other two are where a decision leaves them.
const _statuses = ['Pending', 'Approved', 'Rejected', 'Renewals'];

/// What the checks found, as an admin would say it. "No warnings" is the
/// applications whose documents agreed with what was typed; "With warnings"
/// is everything the checks asked a person to look at, flagged or unreadable.
const _clearFilter = 'clear';
const _warningFilter = 'warnings';

const _verdictFilters = [
  AppFilterOption(_clearFilter, 'No warnings'),
  AppFilterOption(_warningFilter, 'With warnings'),
];

/// Search, sort and the checks filter all run in the widget, not the
/// provider, because this endpoint returns the whole queue in one response —
/// there is no page to be misled about. The paginated screens deliberately
/// do *not* copy this.
class PendingRegistrationsScreen extends ConsumerStatefulWidget {
  const PendingRegistrationsScreen({super.key});

  @override
  ConsumerState<PendingRegistrationsScreen> createState() =>
      _PendingRegistrationsScreenState();
}

class _PendingRegistrationsScreenState
    extends ConsumerState<PendingRegistrationsScreen> {
  // Named because the sort switch below reads them back, and a bare `3` there
  // silently means the wrong column the moment a column is inserted.
  static const _nameColumn = 0;
  static const _checksColumn = 1;
  static const _affiliationColumn = 2;
  static const _emailColumn = 3;
  static const _waitingColumn = 5;

  String _search = '';

  /// Which list is showing: Pending, Approved or Rejected.
  String _status = 'Pending';

  /// Null shows everything. Set from the Checks filter to work one kind of
  /// finding at a time — clearing an "Unreadable" backlog without the
  /// "Look closer" ones resorting back to the top of the list every refresh.
  String? _verdictFilter;

  /// Opens on what the checks found rather than on the date. An admin working a
  /// queue wants the applications that need a person first; the date is how you
  /// break the tie, not how you choose.
  int _sortColumn = _checksColumn;

  /// Newest first: the queue is worked from the top, and an admin opening this
  /// screen wants what just arrived, not what arrived in September.
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Registrations',
      subtitle: switch (_status) {
        'Approved' => 'Applications that became users.',
        'Rejected' => 'Applications that were turned down.',
        'Renewals' =>
          'Renewed licences and registrations from approved users, waiting on a decision.',
        _ => 'Applications waiting on a decision.',
      },
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(pendingRegistrationsProvider);
            ref.invalidate(decidedRegistrationsProvider);
            ref.invalidate(pendingRenewalsProvider);
          },
        ),
      ],
      toolbar: AppToolbar(
        search: AppSearchField(
          hint: 'Search name or email',
          onChanged: (value) => setState(() => _search = value.toLowerCase()),
        ),
        filters: [
          _StatusChips(
            value: _status,
            onChanged: (value) => setState(() {
              _status = value;
              _verdictFilter = null;
            }),
          ),
          // The checks only mean something while the application is still
          // waiting; once it is decided there is nothing left to look at.
          if (_status == 'Pending')
            AppFilterDropdown<String>(
              label: 'Checks',
              value: _verdictFilter,
              options: _verdictFilters,
              allLabel: 'All',
              onChanged: (value) => setState(() => _verdictFilter = value),
            ),
        ],
      ),
      body: _status == 'Renewals'
          ? RenewalsPanel(search: _search)
          : _status != 'Pending' ? _decidedBody(context) : AsyncView(
        value: ref.watch(pendingRegistrationsProvider),
        onRetry: () => ref.invalidate(pendingRegistrationsProvider),
        loading: const SkeletonTable(
          columns: 7,
          columnWidths: [160, 180, 80, 200, 140, 100, 100],
        ),
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
              message: _search.isEmpty
                  ? 'Nothing in the queue is currently marked '
                      '"${_verdictFilters.firstWhere((o) => o.value == _verdictFilter).label}".'
                  : 'Nothing in the queue matches “$_search”.',
            );
          }

          return AppDataTable(
            sortColumnIndex: _sortColumn,
            sortAscending: _sortAscending,
            columns: [
              DataColumn(label: const Text('Name'), onSort: _sort),
              DataColumn(label: const Text('Checks'), onSort: _sort),
              DataColumn(label: const Text('Affiliation'), onSort: _sort),
              DataColumn(label: const Text('Email'), onSort: _sort),
              DataColumn(label: const Text('Submitted'), onSort: _sort),
              DataColumn(label: const Text('Waiting'), onSort: _sort),
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
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(reg.fullName,
                  style: text.titleSmall, overflow: TextOverflow.ellipsis),
            ),
            if (reg.isEBike) ...[
              const SizedBox(width: AppSpacing.x2),
              const StatusPill(
                label: 'E-bike',
                intent: StatusIntent.accent,
                dense: true,
                showDot: false,
              ),
            ],
          ],
        )),
        // The worst finding in words, not a count: "Name mismatch" says
        // what to look for, "2 need attention" only that something is there.
        //
        // An e-bike has nothing to read off paper; what the reviewer is waiting
        // on is the applicant turning up, so that is what the cell says.
        DataCell(reg.isEBike
            ? _EBikeDueCell(deadline: reg.eBikeInspectionDeadline)
            : TopFindingCell(
                verdict: reg.checksVerdict,
                summary: reg.checksSummary,
                topFinding: reg.topFinding,
                severity: reg.topFindingSeverity,
                count: reg.flaggedCount,
              )),
        DataCell(Text(reg.affiliation)),
        DataCell(Text(reg.email)),
        DataCell(Text(_fmt(reg.createdAt),
            style: text.bodyMedium?.copyWith(color: t.text.secondary))),
        DataCell(Text(
          _waited(reg.waitingDays),
          style: text.bodyMedium?.copyWith(
            // An application nobody has touched in a fortnight is a problem
            // with the queue, not with the applicant.
            color: reg.waitingDays >= 7 ? t.status.warning.fg : t.text.secondary,
          ),
        )),
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

  /// The Approved and Rejected lists. One table shape each: they only differ
  /// in what the last two columns say about the decision.
  Widget _decidedBody(BuildContext context) {
    final approved = _status == 'Approved';

    return AsyncView(
      value: ref.watch(decidedRegistrationsProvider(_status)),
      onRetry: () => ref.invalidate(decidedRegistrationsProvider(_status)),
      loading: const SkeletonTable(
        columns: 6,
        columnWidths: [160, 100, 200, 140, 180, 100],
      ),
      isEmpty: (list) => list.isEmpty,
      empty: AppEmptyState(
        icon: approved ? Icons.how_to_reg_outlined : Icons.block_outlined,
        title: approved ? 'Nobody approved yet' : 'Nobody rejected',
        message: approved
            ? 'Applicants you approve show up here, and in Users.'
            : 'Applicants you turn down show up here.',
      ),
      data: (all) {
        final rows = _search.isEmpty
            ? all
            : all
                .where((r) =>
                    r.fullName.toLowerCase().contains(_search) ||
                    r.email.toLowerCase().contains(_search))
                .toList();

        if (rows.isEmpty) {
          return AppEmptyState(
            icon: Icons.search_off,
            title: 'No matches',
            message: 'Nothing here matches \u201c$_search\u201d.',
          );
        }

        final t = context.tokens;
        final text = Theme.of(context).textTheme;

        return AppDataTable(
          columns: [
            const DataColumn(label: Text('Name')),
            const DataColumn(label: Text('Affiliation')),
            const DataColumn(label: Text('Email')),
            DataColumn(label: Text(approved ? 'Approved on' : 'Rejected on')),
            DataColumn(label: Text(approved ? 'Approved by' : 'Reason')),
            const DataColumn(label: Text('')),
          ],
          rows: [
            for (final reg in rows)
              DataRow(
                onSelectChanged: (_) => context.go(
                  approved ? '/users/${reg.userId}' : '/pending/${reg.userId}',
                ),
                cells: [
                  DataCell(Text(reg.fullName, style: text.titleSmall)),
                  DataCell(Text(reg.affiliation)),
                  DataCell(Text(reg.email)),
                  DataCell(Text(
                    reg.decidedAt == null ? '-' : _fmt(reg.decidedAt!),
                    style: text.bodyMedium?.copyWith(color: t.text.secondary),
                  )),
                  DataCell(approved
                      ? Text(reg.decidedByName ?? 'Automatic',
                          style: text.bodyMedium
                              ?.copyWith(color: t.text.secondary))
                      : _RejectedCell(reg: reg)),
                  DataCell(AppRowAction(
                    icon: Icons.open_in_new,
                    label: 'View',
                    onPressed: () => context.go(approved
                        ? '/users/${reg.userId}'
                        : '/pending/${reg.userId}'),
                  )),
                ],
              ),
          ],
          footer: Text(
            rows.length == all.length
                ? '${all.length} ${_status.toLowerCase()}'
                : '${rows.length} of ${all.length} ${_status.toLowerCase()}',
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        );
      },
    );
  }

  void _sort(int column, bool ascending) => setState(() {
        _sortColumn = column;
        _sortAscending = ascending;
      });

  List<PendingRegistration> _visible(List<PendingRegistration> all) {
    var filtered = _search.isEmpty
        ? [...all]
        : all
            .where((r) =>
                r.fullName.toLowerCase().contains(_search) ||
                r.email.toLowerCase().contains(_search))
            .toList();

    if (_verdictFilter == _clearFilter) {
      filtered = filtered.where((r) => r.checksVerdict == 'Clear').toList();
    } else if (_verdictFilter == _warningFilter) {
      filtered = filtered
          .where((r) =>
              r.checksVerdict == 'LookCloser' ||
              r.checksVerdict == 'Unreadable')
          .toList();
    }

    filtered.sort((a, b) {
      // Nothing to review yet, so never ahead of an application that has
      // documents — whichever way the column is sorted.
      if (a.hasNoDocuments != b.hasNoDocuments) {
        return a.hasNoDocuments ? 1 : -1;
      }

      final order = switch (_sortColumn) {
        _nameColumn =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        // Ranked, not alphabetical: sorting "2 need attention" against "All 6
        // passed" as text puts them in an order that means nothing.
        _checksColumn => a.concernRank.compareTo(b.concernRank),
        _affiliationColumn => a.affiliation.compareTo(b.affiliation),
        _emailColumn => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        _waitingColumn => a.waitingDays.compareTo(b.waitingDays),
        _ => a.createdAt.compareTo(b.createdAt),
      };
      return _sortAscending ? order : -order;
    });

    return filtered;
  }

  String _fmt(DateTime dt) =>
      DateFormat('MMM d, yyyy HH:mm').format(dt.toLocal());

  String _waited(int days) => switch (days) {
        0 => 'Today',
        1 => '1 day',
        _ => '$days days',
      };
}

/// Why somebody was rejected, and how many times it has happened. Someone
/// turned down twice for the same thing is a different conversation from a
/// first-time typo.
class _RejectedCell extends StatelessWidget {
  const _RejectedCell({required this.reg});

  final PendingRegistration reg;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final reason = (reg.rejectionReason ?? '').trim();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reason.isEmpty ? 'No reason recorded' : reason,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(color: t.text.secondary),
        ),
        if (reg.timesRejected > 1)
          Text(
            'Rejected ${reg.timesRejected} times',
            style: text.bodySmall?.copyWith(color: t.status.danger.fg),
          ),
      ],
    );
  }
}

/// Pending, Approved and Rejected. Styled like the Users screen's status chips
/// so the two pages read as one family.
class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Wrap(
      spacing: AppSpacing.controlGap,
      runSpacing: AppSpacing.controlGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final status in _statuses)
          ChoiceChip(
            label: Text(status),
            selected: value == status,
            onSelected: (_) => onChanged(status),
            side: BorderSide(
              color: value == status ? t.brand.primary : t.border.normal,
            ),
            labelStyle: text.labelMedium?.copyWith(
              color: value == status ? t.brand.subtleText : t.text.primary,
            ),
          ),
      ],
    );
  }
}

/// What an e-bike application is waiting on: the applicant bringing it in.
class _EBikeDueCell extends StatelessWidget {
  const _EBikeDueCell({required this.deadline});

  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final due = deadline?.toLocal();
    if (due == null) {
      return Text('Waiting for inspection',
          style: text.bodyMedium?.copyWith(color: t.text.secondary));
    }

    final today = DateTime.now();
    final days = DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final overdue = days < 0;

    return Text(
      overdue
          ? 'Inspection overdue by ${-days} ${-days == 1 ? 'day' : 'days'}'
          : days == 0
              ? 'Inspection due today'
              : 'Inspection due in $days ${days == 1 ? 'day' : 'days'}',
      style: text.bodyMedium?.copyWith(
        color: overdue ? t.status.danger.fg : t.text.secondary,
      ),
    );
  }
}
