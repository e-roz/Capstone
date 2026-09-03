import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/csv_export.dart';
import '../models/audit_log_entry.dart';
import '../models/rfid_access_log.dart';
import '../models/system_log_entries.dart';
import '../models/violation.dart';
import '../providers/audit_logs_provider.dart';
import '../providers/rfid_access_logs_provider.dart';
import '../providers/system_logs_provider.dart';
import '../providers/violations_provider.dart';
import '../providers/auth_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

final _stamp = DateFormat('MMM d, yyyy HH:mm');
final _isoStamp = DateFormat('yyyy-MM-dd HH:mm');
final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

String _fileStamp() => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

/// The System Logs module.
///
/// The capstone document lists six things under this heading. Five are tabs:
/// user activity, RFID access, violations, administrative actions and system
/// errors. The sixth — "Generated Reports — allows the administrator to view and
/// export summarized logs" — is the Export CSV control on each tab, rather than
/// a tab of its own that would hold nothing but five download buttons.
///
/// Tab order follows how often a tab is opened, not the order the document
/// lists them in: user activity and gate access are the daily questions, and
/// system errors are the one you hope never to need.
class SystemLogsScreen extends ConsumerWidget {
  const SystemLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // "Access Monitoring" is the guard's module: RFID access, and nothing
    // else. The API refuses them user activity and system errors, and
    // violations and admin actions are not theirs to read either - so Security
    // gets the one tab it is entitled to rather than four that would error.
    final isSecurity = ref.watch(staffRoleProvider) == StaffRole.security;

    return DefaultTabController(
      length: isSecurity ? 1 : 5,
      child: _SystemLogsPage(isSecurity: isSecurity),
    );
  }
}

class _SystemLogsPage extends StatelessWidget {
  const _SystemLogsPage({required this.isSecurity});

  final bool isSecurity;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: isSecurity ? 'Access Monitoring' : 'System Logs',
      subtitle: isSecurity
          ? 'Every card scanned at the barrier, by reader and by hand.'
          : 'Monitor operations and verify the system is behaving.',
      toolbar: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            if (!isSecurity) const Tab(text: 'User Activity'),
            const Tab(text: 'RFID Access'),
            if (!isSecurity) ...[
              const Tab(text: 'Violations'),
              const Tab(text: 'Administrative Actions'),
              const Tab(text: 'System Errors'),
            ],
          ],
        ),
      ),
      body: TabBarView(
        children: [
          if (!isSecurity) const _UserActivityTab(),
          const _RfidAccessTab(),
          if (!isSecurity) ...[
            const _ViolationLogsTab(),
            const _AdminActionsTab(),
            const _SystemErrorsTab(),
          ],
        ],
      ),
    );
  }
}

// ── Administrative action logs ───────────────────────────────────────────────

/// Splits a stored value like `RfidTagId=ABC123, RfidStatus=Active` into a map.
///
/// Returns empty for values that are not in that shape — `Suspend` stores a
/// bare status name — which is what lets [_changeSummary] fall back cleanly.
Map<String, String> _parseFields(String? raw) {
  if (raw == null || raw.isEmpty || !raw.contains('=')) return const {};

  final fields = <String, String>{};
  for (final part in raw.split(',')) {
    final split = part.indexOf('=');
    if (split <= 0) continue;
    fields[part.substring(0, split).trim()] = part.substring(split + 1).trim();
  }
  return fields;
}

/// The name to put on an action's pill.
///
/// The API stores one word per action, which reads fine for all of them except
/// the two written by the Backup module — those have to say "backup" somewhere
/// or `RestoreBackup` sits next to the account-level `Restore` looking like a
/// typo of it.
String _actionLabel(String action) => switch (action) {
      'Backup' => 'Backup',
      'RestoreBackup' => 'Restore backup',
      'DeleteDocuments' => 'Delete documents',
      _ => action,
    };

/// Turns an audit row into a sentence instead of a field dump.
///
/// The API records changes as machine state — `IsDeleted=true`,
/// `RfidTagId=ABC123, RfidStatus=Active` — which is the right thing to *store*
/// and the wrong thing to show in a table an administrator reads. History
/// cannot be rewritten, so the translation happens here at display time and
/// covers rows written before this existed as well as after.
///
/// Returns null when there is genuinely nothing to describe, so the caller can
/// fall back to a dash rather than printing "— → —".
String? _changeSummary(AuditLogEntry entry) {
  final before = _parseFields(entry.oldValue);
  final after = _parseFields(entry.newValue);

  String? card(Map<String, String> fields) {
    final tag = fields['RfidTagId'];
    return (tag == null || tag.isEmpty) ? null : tag;
  }

  switch (entry.action) {
    case 'Backup':
      final file = after['File'];
      final rows = after['Rows'];
      if (file == null) return 'Database backed up';
      return rows == null ? 'Backed up to $file' : 'Backed up $rows rows to $file';

    case 'RestoreBackup':
      // The safety copy is the useful half of this row: it is the only way back
      // from a restore, and it is recorded nowhere else.
      final file = after['File'];
      final safety = before['SafetyBackup'];
      final from = file == null ? 'Database restored' : 'Database restored from $file';
      return safety == null ? from : '$from (previous state saved as $safety)';

    case 'Archive':
      return 'Account archived';

    case 'DeleteDocuments':
      // Before says how many images there were; after is always none. The count
      // is the whole content of the row.
      final count = before['Documents'];
      return switch (count) {
        null => 'ID documents deleted',
        '1' => '1 ID document image deleted',
        _ => '$count ID document images deleted',
      };

    case 'Restore':
      // The restore row carries the status the account came back as, which is
      // the only part of it anyone actually wants.
      final status = after['AccountStatus'] ?? before['AccountStatus'];
      return status == null ? 'Account restored' : 'Account restored to $status';

    case 'AssignRfid':
      final oldCard = card(before);
      final newCard = card(after);
      if (newCard == null) return 'Card assigned';
      return oldCard == null
          ? 'Card $newCard assigned'
          : 'Card $oldCard replaced with $newCard';

    case 'RevokeRfid':
      final oldCard = card(before);
      return oldCard == null ? 'Card revoked' : 'Card $oldCard revoked';
  }

  // Suspend, Unsuspend, Approve, Reject and the reset actions all store plain
  // status names, which already read as English.
  final oldValue = entry.oldValue;
  final newValue = entry.newValue;

  if (oldValue != null && newValue != null) return '$oldValue → $newValue';
  if (newValue != null) return newValue;
  if (oldValue != null) return oldValue;
  return null;
}

const _actions = [
  AppFilterOption('Suspend', 'Suspend'),
  AppFilterOption('Unsuspend', 'Unsuspend'),
  AppFilterOption('Archive', 'Archive'),
  AppFilterOption('DeleteDocuments', 'Delete documents'),
  AppFilterOption('Restore', 'Restore'),
  AppFilterOption('Approve', 'Approve'),
  AppFilterOption('Reject', 'Reject'),
  AppFilterOption('ResetReapply', 'Reset reapply'),
  AppFilterOption('ResetStep', 'Reset step'),
  AppFilterOption('Backup', 'Backup'),
  AppFilterOption('RestoreBackup', 'Restore backup'),
];

class _AdminActionsTab extends ConsumerWidget {
  const _AdminActionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(auditLogsQueryNotifierProvider);
    final notifier = ref.read(auditLogsQueryNotifierProvider.notifier);
    final async = ref.watch(auditLogsProvider);

    return _LogTabScaffold(
      filters: [
        AppFilterDropdown<String>(
          label: 'Action',
          value: query.action,
          options: _actions,
          allLabel: 'All actions',
          onChanged: notifier.setAction,
        ),
      ],
      onRefresh: () => ref.invalidate(auditLogsProvider),
      onExport: async.hasValue
          ? () => _export(context, async.requireValue.logs)
          : null,
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(auditLogsProvider),
        isEmpty: (page) => page.logs.isEmpty,
        empty: AppEmptyState(
          icon: Icons.history,
          title: query.action == null
              ? 'No actions recorded yet'
              : 'No ${query.action} actions',
          message: query.action == null
              ? 'Approvals, suspensions and archives are recorded here as they happen.'
              : 'Clear the filter to see every recorded action.',
        ),
        data: (page) => AppDataTable(
          minWidth: 900,
          columns: const [
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('Administrator')),
            DataColumn(label: Text('Target')),
            DataColumn(label: Text('Change')),
            DataColumn(label: Text('When')),
          ],
          rows: [for (final entry in page.logs) _row(context, entry)],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.totalCount,
            itemLabel: 'actions',
            onPage: notifier.setPage,
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, AuditLogEntry entry) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final change = _changeSummary(entry);
    final hasChange = change != null;
    final hasReason = entry.reason != null && entry.reason!.isNotEmpty;

    return DataRow(cells: [
      DataCell(StatusPill(
        label: _actionLabel(entry.action),
        intent: StatusIntents.auditAction(entry.action),
        dense: true,
      )),
      DataCell(Text(entry.adminName, style: text.titleSmall)),
      DataCell(Text(entry.targetName)),
      // The change and the reason belong to the same thought, so they share a
      // cell rather than fighting for two columns most rows leave empty.
      DataCell(SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasChange)
              Text(
                change,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: t.text.primary),
              ),
            if (hasReason)
              Text(
                entry.reason!,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: t.text.secondary),
              ),
            if (!hasChange && !hasReason)
              Text('—',
                  style: text.bodyMedium?.copyWith(color: t.text.tertiary)),
          ],
        ),
      )),
      DataCell(Text(
        _stamp.format(entry.createdAt.toLocal()),
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      )),
    ]);
  }

  void _export(BuildContext context, List<AuditLogEntry> logs) {
    CsvExport.save(
      fileName: 'aimpark-admin-actions-${_fileStamp()}.csv',
      // The readable summary leads, but the raw before/after stay in the sheet:
      // an export is evidence, and the exact stored values are what makes it
      // worth anything if the summary is ever disputed.
      headers: const [
        'When',
        'Action',
        'Administrator',
        'Target',
        'Change',
        'Reason',
        'Raw before',
        'Raw after',
      ],
      rows: [
        for (final l in logs)
          [
            _isoStamp.format(l.createdAt.toLocal()),
            l.action,
            l.adminName,
            l.targetName,
            _changeSummary(l) ?? '',
            l.reason ?? '',
            l.oldValue ?? '',
            l.newValue ?? '',
          ],
      ],
    );
    _exported(context);
  }
}

// ── RFID access logs ─────────────────────────────────────────────────────────

const _sources = [
  AppFilterOption('Device', 'Reader scan'),
  AppFilterOption('Manual', 'Logged by staff'),
];

class _RfidAccessTab extends ConsumerWidget {
  const _RfidAccessTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(rfidAccessLogsQueryNotifierProvider);
    final notifier = ref.read(rfidAccessLogsQueryNotifierProvider.notifier);
    final async = ref.watch(rfidAccessLogsProvider);

    return _LogTabScaffold(
      filters: [
        AppFilterDropdown<String>(
          label: 'Source',
          value: query.source,
          options: _sources,
          allLabel: 'All sources',
          onChanged: notifier.setSource,
        ),
      ],
      onRefresh: () => ref.invalidate(rfidAccessLogsProvider),
      onExport: async.hasValue
          ? () => _export(context, async.requireValue.logs)
          : null,
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(rfidAccessLogsProvider),
        isEmpty: (page) => page.logs.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.nfc,
          title: 'No gate activity recorded',
          message:
              'Every entry and exit — whether scanned at a reader or logged by '
              'staff — is recorded here with its timestamps.',
        ),
        data: (page) => AppDataTable(
          minWidth: 1000,
          columns: const [
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Slot')),
            DataColumn(label: Text('Entry')),
            DataColumn(label: Text('Exit')),
            DataColumn(label: Text('Duration')),
            DataColumn(label: Text('Source')),
          ],
          rows: [for (final entry in page.logs) _row(context, entry)],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.totalCount,
            itemLabel: 'gate events',
            onPage: notifier.setPage,
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, RfidAccessLogEntry entry) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return DataRow(cells: [
      DataCell(AppPrimaryCell(
        title: entry.userName,
        subtitle: entry.rfidTagId == null
            ? 'No tag on file'
            : 'Tag ${entry.rfidTagId}',
      )),
      DataCell(Text(
        entry.slotCode == null
            ? '—'
            : '${entry.slotCode}${entry.gate == null ? '' : ' · Gate ${entry.gate}'}',
        style: entry.slotCode == null
            ? text.bodyMedium?.copyWith(color: t.text.tertiary)
            : text.bodyMedium,
      )),
      DataCell(Text(
        _stamp.format(entry.entryTime.toLocal()),
        style: text.bodySmall,
      )),
      DataCell(entry.exitTime == null
          ? const StatusPill.of('Still inside',
              intent: StatusIntent.accent, dense: true)
          : Text(_stamp.format(entry.exitTime!.toLocal()),
              style: text.bodySmall)),
      DataCell(Text(
        _durationLabel(entry.duration),
        style: entry.duration == null
            ? text.bodyMedium?.copyWith(color: t.text.tertiary)
            : AppTypography.tabular(text.bodyMedium!),
      )),
      // A reader scan and a hand-keyed correction are not the same evidence,
      // and an auditor asking "did the hardware actually see this card?" needs
      // to be able to tell them apart at a glance.
      DataCell(StatusPill.of(
        entry.source == 'Device' ? 'Reader' : 'Manual',
        intent: entry.source == 'Device'
            ? StatusIntent.success
            : StatusIntent.warning,
        dense: true,
        showDot: false,
        icon: entry.source == 'Device' ? Icons.sensors : Icons.keyboard,
      )),
    ]);
  }

  static String _durationLabel(Duration? d) {
    if (d == null) return '—';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }

  void _export(BuildContext context, List<RfidAccessLogEntry> logs) {
    CsvExport.save(
      fileName: 'aimpark-rfid-access-${_fileStamp()}.csv',
      headers: const [
        'User',
        'RFID tag',
        'Slot',
        'Gate',
        'Entry',
        'Exit',
        'Duration',
        'Source',
        'Recorded by',
      ],
      rows: [
        for (final l in logs)
          [
            l.userName,
            l.rfidTagId ?? '',
            l.slotCode ?? '',
            l.gate?.toString() ?? '',
            _isoStamp.format(l.entryTime.toLocal()),
            l.exitTime == null ? '' : _isoStamp.format(l.exitTime!.toLocal()),
            _durationLabel(l.duration),
            l.source,
            l.recordedBy ?? '',
          ],
      ],
    );
    _exported(context);
  }
}

// ── Violation logs ───────────────────────────────────────────────────────────

const _violationStatuses = [
  AppFilterOption('Issued', 'Issued'),
  AppFilterOption('Appealed', 'Appealed'),
  AppFilterOption('Upheld', 'Upheld'),
  AppFilterOption('Overturned', 'Overturned'),
  AppFilterOption('Dismissed', 'Dismissed'),
];

class _ViolationLogsTab extends ConsumerWidget {
  const _ViolationLogsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(violationLogsQueryNotifierProvider);
    final notifier = ref.read(violationLogsQueryNotifierProvider.notifier);
    final async = ref.watch(violationLogListProvider);

    return _LogTabScaffold(
      filters: [
        AppFilterDropdown<String>(
          label: 'Status',
          value: query.status,
          options: _violationStatuses,
          allLabel: 'All statuses',
          onChanged: notifier.setStatus,
        ),
      ],
      onRefresh: () => ref.invalidate(violationLogListProvider),
      onExport: async.hasValue
          ? () => _export(context, async.requireValue.violations)
          : null,
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(violationLogListProvider),
        isEmpty: (page) => page.violations.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.gavel_outlined,
          title: 'No violations recorded',
          message:
              'Every violation and the penalty applied to it is recorded here. '
              'Issue and manage them under Violation Tracking.',
        ),
        data: (page) => AppDataTable(
          minWidth: 820,
          columns: const [
            DataColumn(label: Text('Rule')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Penalty'), numeric: true),
            DataColumn(label: Text('Suspension')),
            DataColumn(label: Text('Issued')),
          ],
          rows: [
            for (final v in page.violations)
              DataRow(cells: [
                DataCell(Text(v.policyRuleTitle,
                    style: Theme.of(context).textTheme.titleSmall)),
                DataCell(StatusPill.of(
                  v.status,
                  intent: StatusIntents.violation(v.status),
                  dense: true,
                )),
                DataCell(AppNumericCell(_money.format(v.penaltyAmount))),
                DataCell(Text(
                  v.suspensionType == 'None' ? '—' : v.suspensionType,
                  style: v.suspensionType == 'None'
                      ? Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: context.tokens.text.tertiary)
                      : null,
                )),
                DataCell(Text(
                  _stamp.format(v.createdAt.toLocal()),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.tokens.text.secondary),
                )),
              ]),
          ],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.totalCount,
            itemLabel: 'violations',
            onPage: notifier.setPage,
          ),
        ),
      ),
    );
  }

  void _export(BuildContext context, List<ViolationSummary> violations) {
    CsvExport.save(
      fileName: 'aimpark-violation-logs-${_fileStamp()}.csv',
      headers: const ['Issued', 'Rule', 'Status', 'Penalty', 'Suspension'],
      rows: [
        for (final v in violations)
          [
            _isoStamp.format(v.createdAt.toLocal()),
            v.policyRuleTitle,
            v.status,
            v.penaltyAmount.toStringAsFixed(2),
            v.suspensionType,
          ],
      ],
    );
    _exported(context);
  }
}

// ── Shared tab chrome ────────────────────────────────────────────────────────

void _exported(BuildContext context) {
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Log exported.')));
}

/// Filter row, refresh, export, then the table — identical on all three tabs,
/// so it is written once. The export button is what the document calls
/// "Generated Reports"; it covers the page currently on screen, which is the
/// only set of rows the administrator has actually reviewed.
class _LogTabScaffold extends StatelessWidget {
  const _LogTabScaffold({
    required this.filters,
    required this.onRefresh,
    required this.onExport,
    required this.child,
  });

  final List<Widget> filters;
  final VoidCallback onRefresh;

  /// Null while the data is still loading, which disables the button.
  final VoidCallback? onExport;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppToolbar(
          filters: filters,
          trailing: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined, size: AppSizes.iconSm),
              label: const Text('Export CSV'),
              onPressed: onExport,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: onRefresh,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        Expanded(child: child),
      ],
    );
  }
}

// ── User activity logs ───────────────────────────────────────────────────────

class _UserActivityTab extends ConsumerWidget {
  const _UserActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(userActivityQueryNotifierProvider);
    final notifier = ref.read(userActivityQueryNotifierProvider.notifier);
    final async = ref.watch(userActivityLogsProvider);

    return _LogTabScaffold(
      filters: [
        AppFilterDropdown<String>(
          label: 'Activity',
          value: query.activity,
          options: [
            for (final entry in userActivityOptions.entries)
              AppFilterOption(entry.key, entry.value),
          ],
          allLabel: 'All activity',
          onChanged: notifier.setActivity,
        ),
      ],
      onRefresh: () => ref.invalidate(userActivityLogsProvider),
      onExport: async.hasValue
          ? () => _export(context, async.requireValue.logs)
          : null,
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(userActivityLogsProvider),
        isEmpty: (page) => page.logs.isEmpty,
        empty: AppEmptyState(
          icon: Icons.manage_accounts_outlined,
          title: query.activity == null
              ? 'No account activity yet'
              : 'No matching events',
          message: query.activity == null
              ? 'Logins, failed logins, registrations and status changes are '
                  'recorded here as they happen.'
              : 'Clear the filter to see every recorded event.',
        ),
        data: (page) => AppDataTable(
          minWidth: 940,
          columns: const [
            DataColumn(label: Text('Activity')),
            DataColumn(label: Text('Account')),
            DataColumn(label: Text('Detail')),
            DataColumn(label: Text('IP')),
            DataColumn(label: Text('When')),
          ],
          rows: [for (final entry in page.logs) _row(context, entry)],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.totalCount,
            itemLabel: 'events',
            onPage: notifier.setPage,
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, UserActivityLogEntry entry) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return DataRow(cells: [
      DataCell(StatusPill.of(
        userActivityOptions[entry.activity] ?? entry.activity,
        intent: _intent(entry.activity),
        dense: true,
      )),
      DataCell(AppPrimaryCell(
        title: entry.userName,
        // A failed login against an address with no account has no name to
        // show, so the row falls back to the address that was tried — which is
        // the only useful thing about that row.
        subtitle:
            entry.emailAtTime == entry.userName ? null : entry.emailAtTime,
      )),
      DataCell(SizedBox(
        width: 280,
        child: Text(
          entry.detail ?? '—',
          overflow: TextOverflow.ellipsis,
          style: entry.detail == null
              ? text.bodyMedium?.copyWith(color: t.text.tertiary)
              : text.bodySmall?.copyWith(color: t.text.secondary),
        ),
      )),
      DataCell(Text(
        entry.ipAddress ?? '—',
        style: entry.ipAddress == null
            ? text.bodyMedium?.copyWith(color: t.text.tertiary)
            : AppTypography.tabular(text.bodySmall!),
      )),
      DataCell(Text(
        _stamp.format(entry.createdAt.toLocal()),
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      )),
    ]);
  }

  /// A failed login is the only row here that is a warning rather than a record.
  static StatusIntent _intent(String activity) => switch (activity) {
        'LoginFailed' => StatusIntent.danger,
        'Login' || 'Approved' || 'Registered' => StatusIntent.success,
        'Rejected' || 'RfidRevoked' => StatusIntent.warning,
        _ => StatusIntent.info,
      };

  void _export(BuildContext context, List<UserActivityLogEntry> logs) {
    CsvExport.save(
      fileName: 'aimpark-user-activity-${_fileStamp()}.csv',
      headers: const ['When', 'Activity', 'Account', 'Email', 'Detail', 'IP'],
      rows: [
        for (final l in logs)
          [
            _isoStamp.format(l.createdAt.toLocal()),
            l.activity,
            l.userName,
            l.emailAtTime,
            l.detail ?? '',
            l.ipAddress ?? '',
          ],
      ],
    );
    _exported(context);
  }
}

// ── System error logs ────────────────────────────────────────────────────────

class _SystemErrorsTab extends ConsumerWidget {
  const _SystemErrorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemErrorLogsProvider);
    final notifier = ref.read(errorLogsPageNotifierProvider.notifier);

    return _LogTabScaffold(
      filters: const [],
      onRefresh: () => ref.invalidate(systemErrorLogsProvider),
      onExport: async.hasValue
          ? () => _export(context, async.requireValue.logs)
          : null,
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(systemErrorLogsProvider),
        isEmpty: (page) => page.logs.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.check_circle_outline,
          title: 'No errors recorded',
          message: 'An empty table is the good outcome here — nothing has '
              'failed on the server since logging began.',
        ),
        data: (page) => AppDataTable(
          minWidth: 940,
          columns: const [
            DataColumn(label: Text('When')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Request')),
            DataColumn(label: Text('Message')),
            DataColumn(label: Text('')),
          ],
          rows: [for (final entry in page.logs) _row(context, entry)],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.totalCount,
            itemLabel: 'errors',
            onPage: notifier.setPage,
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, SystemErrorLogEntry entry) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return DataRow(cells: [
      DataCell(Text(
        _stamp.format(entry.createdAt.toLocal()),
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      )),
      DataCell(StatusPill.of(
        entry.errorType,
        intent: StatusIntent.danger,
        dense: true,
        showDot: false,
      )),
      DataCell(SizedBox(
        width: 220,
        child: Text(
          entry.path ?? '—',
          overflow: TextOverflow.ellipsis,
          style: AppTypography.tabular(text.bodySmall!),
        ),
      )),
      DataCell(SizedBox(
        width: 300,
        child: Text(
          entry.message,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall,
        ),
      )),
      DataCell(AppRowAction(
        label: 'Details',
        icon: Icons.bug_report_outlined,
        onPressed: () => _showDetail(context, entry),
      )),
    ]);
  }

  /// The stack trace is behind a dialog rather than in the table: it is the
  /// thing you need in the ten minutes you are chasing one bug, and noise for
  /// the rest of the time.
  Future<void> _showDetail(
      BuildContext context, SystemErrorLogEntry entry) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final t = ctx.tokens;
        final text = Theme.of(ctx).textTheme;

        return AlertDialog(
          title: Text(entry.errorType),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppFieldGrid(fields: [
                    AppField(
                      label: 'When',
                      value: _stamp.format(entry.createdAt.toLocal()),
                    ),
                    AppField(label: 'Request', value: entry.path ?? '—'),
                    AppField(label: 'Status', value: '${entry.statusCode}'),
                    AppField(label: 'Trace ID', value: entry.traceId ?? '—'),
                  ]),
                  const SizedBox(height: AppSpacing.x5),
                  Text('Message', style: text.titleSmall),
                  const SizedBox(height: AppSpacing.x2),
                  _CodeBlock(content: entry.message),
                  if (entry.stackTrace case final stack?
                      when stack.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x5),
                    Text('Stack trace', style: text.titleSmall),
                    const SizedBox(height: AppSpacing.x2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: SingleChildScrollView(
                        child: _CodeBlock(content: stack),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    'Quote the trace ID when reporting this — it matches what '
                    'the caller was shown.',
                    style: text.labelSmall?.copyWith(color: t.text.tertiary),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _export(BuildContext context, List<SystemErrorLogEntry> logs) {
    CsvExport.save(
      fileName: 'aimpark-system-errors-${_fileStamp()}.csv',
      headers: const [
        'When',
        'Type',
        'Request',
        'Status',
        'Message',
        'Trace ID',
      ],
      rows: [
        for (final l in logs)
          [
            _isoStamp.format(l.createdAt.toLocal()),
            l.errorType,
            l.path ?? '',
            l.statusCode,
            l.message,
            l.traceId ?? '',
          ],
      ],
    );
    _exported(context);
  }
}

/// Monospace block for an exception message or a stack trace.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: t.border.subtle),
      ),
      child: SelectableText(
        content,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Consolas', 'Menlo', 'Courier New'],
          fontSize: 12,
          height: 1.5,
          color: t.text.secondary,
        ),
      ),
    );
  }
}
