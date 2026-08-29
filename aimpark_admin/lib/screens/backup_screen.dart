import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/browser_files.dart';
import '../models/backup.dart';
import '../providers/auth_provider.dart';
import '../providers/backup_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

String _stamp(DateTime dt) =>
    DateFormat('MMM d, yyyy HH:mm').format(dt.toLocal());

/// Data Backup &amp; Restore — the maintenance module.
///
/// Two halves that deliberately do not look alike. Taking a backup is one
/// button and cannot hurt anybody. Restoring one replaces every row in the
/// database, so it is gated behind a preview of what would change, the
/// administrator's own password, and a word they have to type — and it says
/// what it is going to do before it does it, rather than after.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// What the administrator has to type before the restore button lights up.
  static const _confirmationWord = 'RESTORE';

  PickedFile? _picked;
  RestorePreview? _preview;
  bool _working = false;
  bool _showAllTables = false;

  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Backup & Restore',
      subtitle: 'Save a copy of the database, and put a saved copy back.',
      scrollable: true,
      actions: [
        FilledButton.icon(
          onPressed: _working ? null : _create,
          icon: const Icon(Icons.download_outlined, size: AppSizes.iconSm),
          label: const Text('Create backup'),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh history',
          onPressed: () => ref.invalidate(backupListProvider),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCreateCard(context),
          const SizedBox(height: AppSpacing.sectionGap),
          _buildRestoreCard(context),
          const SizedBox(height: AppSpacing.sectionGap),
          _buildHistoryCard(context),
        ],
      ),
    );
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Widget _buildCreateCard(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppSectionCard(
      title: 'Create a backup',
      icon: Icons.save_outlined,
      subtitle: 'Exports every table to one JSON file you can keep.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The file downloads to this computer, and a copy is kept in storage '
            'so it appears in the history below. Nothing on the system changes.',
            style: text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          const SizedBox(height: AppSpacing.x4),
          const _Bullet(
            included: true,
            text: 'Every table: accounts, vehicles, parking logs, payments, '
                'violations, incidents, notifications and the audit trail.',
          ),
          const SizedBox(height: AppSpacing.x2),
          const _Bullet(
            included: false,
            text: 'Not the uploaded document photographs. Those stay in file '
                'storage, which keeps the backup small enough to download.',
          ),
          const SizedBox(height: AppSpacing.x5),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _working ? null : _create,
              icon: const Icon(Icons.download_outlined, size: AppSizes.iconSm),
              label: const Text('Create backup now'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _working = true);
    try {
      final name = await ref.read(backupActionsProvider.notifier).create();
      _say('Backup created and downloaded as $name.');
    } on BackupException catch (e) {
      _say(e.message, danger: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ── Restore ────────────────────────────────────────────────────────────────

  Widget _buildRestoreCard(BuildContext context) {
    final preview = _preview;

    return AppSectionCard(
      title: 'Restore from a backup',
      icon: Icons.restore,
      subtitle: 'Replaces everything currently in the database.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Banner(
            intent: StatusIntent.danger,
            icon: Icons.warning_amber_rounded,
            text: 'A restore deletes every row and writes the backup in its '
                'place. A copy of the current database is saved automatically '
                'first, so there is a way back — but everything recorded since '
                'the backup was taken will be gone.',
          ),
          const SizedBox(height: AppSpacing.x5),
          _buildFilePicker(context),
          if (preview != null) ...[
            const SizedBox(height: AppSpacing.x5),
            _buildPreview(context, preview),
          ],
        ],
      ),
    );
  }

  Widget _buildFilePicker(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final picked = _picked;

    return Wrap(
      spacing: AppSpacing.controlGap,
      runSpacing: AppSpacing.controlGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _working ? null : _choose,
          icon: const Icon(Icons.upload_file_outlined, size: AppSizes.iconSm),
          label: Text(picked == null ? 'Choose backup file' : 'Choose another'),
        ),
        if (picked != null)
          Text(
            '${picked.name} · ${picked.readableSize}',
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        if (picked != null)
          TextButton(onPressed: _working ? null : _clear, child: const Text('Clear')),
        if (_working)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, RestorePreview preview) {
    final backup = preview.backup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.problem != null) ...[
          _Banner(
            intent: StatusIntent.danger,
            icon: Icons.block,
            text: preview.problem!,
          ),
          const SizedBox(height: AppSpacing.x2),
        ],
        for (final warning in preview.warnings) ...[
          _Banner(
            intent: StatusIntent.warning,
            icon: Icons.info_outline,
            text: warning,
          ),
          const SizedBox(height: AppSpacing.x2),
        ],
        if (preview.problem != null || preview.warnings.isNotEmpty)
          const SizedBox(height: AppSpacing.x3),
        Wrap(
          spacing: AppSpacing.gutter,
          runSpacing: AppSpacing.gutter,
          children: [
            MetricCard(
              label: 'Rows in this file',
              value: NumberFormat.decimalPattern().format(backup.totalRows),
              icon: Icons.inventory_2_outlined,
              intent: StatusIntent.info,
              caption: backup.createdAt == null
                  ? 'Date unknown'
                  : 'Taken ${_stamp(backup.createdAt!)}',
            ),
            MetricCard(
              label: 'Rows in the database now',
              value:
                  NumberFormat.decimalPattern().format(preview.currentTotalRows),
              icon: Icons.storage_outlined,
              intent: StatusIntent.warning,
              caption: 'These would be replaced',
            ),
            MetricCard(
              label: 'Tables in this file',
              value: backup.tables.length.toString(),
              icon: Icons.table_chart_outlined,
              intent: StatusIntent.neutral,
              caption: backup.createdByEmail.isEmpty
                  ? 'Taken by an unknown account'
                  : 'Taken by ${backup.createdByEmail}',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x4),
        _buildTableDetail(context, backup),
        if (preview.canRestore) ...[
          const SizedBox(height: AppSpacing.x5),
          _buildConfirmation(context),
        ],
      ],
    );
  }

  /// The per-table comparison.
  ///
  /// Collapsed to the rows that actually change, because twenty-three lines of
  /// "0 → 0" buries the two that matter. The full list is one click away for
  /// anyone who wants to check the whole thing.
  Widget _buildTableDetail(BuildContext context, BackupSummary backup) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final changed = backup.tables.where((c) => c.delta != 0).toList();
    final shown = _showAllTables ? backup.tables : changed;

    return Container(
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: t.border.subtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  changed.isEmpty
                      ? 'Every table matches what is already in the database.'
                      : '${changed.length} of ${backup.tables.length} tables would change.',
                  style: text.labelMedium?.copyWith(color: t.text.secondary),
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _showAllTables = !_showAllTables),
                child: Text(_showAllTables ? 'Show changes only' : 'Show all tables'),
              ),
            ],
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            _TableCountRow(
              table: 'Table',
              inFile: 'In file',
              now: 'Now',
              isHeader: true,
            ),
            for (final count in shown)
              _TableCountRow(
                table: count.table,
                inFile: count.rows.toString(),
                now: count.currentRows?.toString() ?? '—',
                delta: count.delta,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    final t = context.tokens;
    final armed = _passwordCtrl.text.isNotEmpty &&
        _confirmCtrl.text.trim().toUpperCase() == _confirmationWord;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: t.border.subtle),
        const SizedBox(height: AppSpacing.x4),
        Text('Confirm the restore', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.x3),
        Wrap(
          spacing: AppSpacing.x4,
          runSpacing: AppSpacing.x4,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _passwordCtrl,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  label: AppFieldLabel('Your admin password', isRequired: true),
                ),
              ),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _confirmCtrl,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  label: AppFieldLabel('Type $_confirmationWord', isRequired: true),
                  helperText: 'Typed out in full, so this cannot be a slip.',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x5),
        FilledButton.icon(
          onPressed: (!armed || _working) ? null : _restore,
          style: FilledButton.styleFrom(
            backgroundColor: t.status.danger.solid,
            disabledBackgroundColor: t.surface.muted,
          ),
          icon: const Icon(Icons.restore, size: AppSizes.iconSm),
          label: const Text('Restore database'),
        ),
      ],
    );
  }

  Future<void> _choose() async {
    // Not wrapped in the busy flag: a cancelled file dialog fires no event, so
    // this future would never complete and the screen would sit disabled.
    final file = await BrowserFiles.pick();
    if (file == null || !mounted) return;

    setState(() {
      _picked = file;
      _preview = null;
      _working = true;
      _passwordCtrl.clear();
      _confirmCtrl.clear();
    });

    try {
      final preview =
          await ref.read(backupActionsProvider.notifier).preview(file);
      if (mounted) setState(() => _preview = preview);
    } on BackupException catch (e) {
      if (!mounted) return;
      setState(() => _picked = null);
      _say(e.message, danger: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _clear() => setState(() {
        _picked = null;
        _preview = null;
        _showAllTables = false;
        _passwordCtrl.clear();
        _confirmCtrl.clear();
      });

  Future<void> _restore() async {
    final file = _picked;
    final preview = _preview;
    if (file == null || preview == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore the database?'),
        content: SizedBox(
          width: 460,
          child: Text(
            'This replaces all ${NumberFormat.decimalPattern().format(preview.currentTotalRows)} '
            'rows currently in the database with the '
            '${NumberFormat.decimalPattern().format(preview.backup.totalRows)} rows in '
            '${file.name}.\n\n'
            'A copy of the current database is saved first. You will be signed '
            'out when it finishes.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ctx.tokens.status.danger.solid),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final result = await ref.read(backupActionsProvider.notifier).restore(
            file: file,
            password: _passwordCtrl.text,
            confirmation: _confirmCtrl.text.trim().toUpperCase(),
          );
      if (!mounted) return;
      await _showResult(result);
    } on BackupException catch (e) {
      if (mounted) _say(e.message, danger: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// The end of the flow: what happened, where the way back is, and out.
  ///
  /// Signing out is not optional. Every provider in the panel is now holding
  /// rows that no longer exist, and the account behind the current token may
  /// itself have been replaced — a session left running here produces 401s and
  /// stale screens that read as bugs.
  Future<void> _showResult(RestoreResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore complete'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message),
              const SizedBox(height: AppSpacing.x4),
              _Banner(
                intent: StatusIntent.info,
                icon: Icons.history_toggle_off,
                text: 'The database as it was a moment ago was saved as '
                    '${result.safetyBackupName}. Restore that file to undo this.',
              ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Sign in again to carry on. The panel is holding data that has '
                'just been replaced.',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ctx.tokens.text.secondary),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  // ── History ────────────────────────────────────────────────────────────────

  Widget _buildHistoryCard(BuildContext context) {
    return AppSectionCard(
      title: 'Backup history',
      icon: Icons.folder_outlined,
      subtitle: 'Copies kept in storage. Download one to restore it later.',
      child: SizedBox(
        height: 320,
        child: AsyncView<List<BackupFile>>(
          value: ref.watch(backupListProvider),
          onRetry: () => ref.invalidate(backupListProvider),
          isEmpty: (list) => list.isEmpty,
          empty: const AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No backups yet',
            message: 'Backups you create will be listed here, newest first.',
          ),
          data: (list) => AppDataTable(
            minWidth: 560,
            columns: const [
              DataColumn(label: Text('File')),
              DataColumn(label: Text('Taken')),
              DataColumn(label: Text('Size')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final backup in list)
                DataRow(cells: [
                  DataCell(Row(
                    children: [
                      Text(backup.name),
                      if (backup.isPreRestore) ...[
                        const SizedBox(width: AppSpacing.x2),
                        const StatusPill(
                          label: 'Auto',
                          intent: StatusIntent.info,
                          dense: true,
                        ),
                      ],
                    ],
                  )),
                  DataCell(Text(backup.createdAt == null
                      ? '—'
                      : _stamp(backup.createdAt!))),
                  DataCell(Text(backup.readableSize)),
                  DataCell(IconButton(
                    icon: const Icon(Icons.download_outlined,
                        size: AppSizes.iconSm),
                    tooltip: 'Download',
                    onPressed:
                        _working ? null : () => _downloadExisting(backup.name),
                  )),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadExisting(String fileName) async {
    setState(() => _working = true);
    try {
      await ref.read(backupActionsProvider.notifier).downloadExisting(fileName);
      _say('$fileName downloaded.');
    } on BackupException catch (e) {
      _say(e.message, danger: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ── Shared ─────────────────────────────────────────────────────────────────

  void _say(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: danger ? context.tokens.status.danger.solid : null,
    ));
  }
}

/// One line of "this is in / this is not in" the backup.
class _Bullet extends StatelessWidget {
  const _Bullet({required this.included, required this.text});

  final bool included;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(included ? StatusIntent.success : StatusIntent.neutral);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          included ? Icons.check_circle_outline : Icons.remove_circle_outline,
          size: AppSizes.iconSm,
          color: c.fg,
        ),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: t.text.secondary),
          ),
        ),
      ],
    );
  }
}

/// A tinted note. Same colour language as [StatusPill], at paragraph size.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.intent,
    required this.icon,
    required this.text,
  });

  final StatusIntent intent;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(intent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: c.fg),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              text,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: c.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the per-table comparison.
class _TableCountRow extends StatelessWidget {
  const _TableCountRow({
    required this.table,
    required this.inFile,
    required this.now,
    this.delta,
    this.isHeader = false,
  });

  final String table;
  final String inFile;
  final String now;
  final int? delta;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final style = isHeader
        ? text.labelSmall?.copyWith(color: t.text.tertiary)
        : text.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        children: [
          Expanded(child: Text(table, style: style)),
          SizedBox(
            width: 72,
            child: Text(inFile, style: style, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 72,
            child: Text(now, style: style, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 76,
            child: delta == null || delta == 0
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerRight,
                    child: StatusPill(
                      label: delta! > 0 ? '+$delta' : '$delta',
                      intent: delta! > 0
                          ? StatusIntent.success
                          : StatusIntent.danger,
                      dense: true,
                      showDot: false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
