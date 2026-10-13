import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/browser_files.dart';
import '../core/utils/responsive.dart';
import '../models/incident.dart';
import '../providers/auth_provider.dart';
import '../providers/incidents_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/document_viewer.dart';
import '../widgets/ui/ui.dart';

const _incidentStatuses = [
  'Submitted',
  'UnderReview',
  'Resolved',
  'Dismissed',
  'Withdrawn',
];

/// The API's `IncidentCategory` names, mapped to what a person reads.
///
/// The key is what gets sent. Sending the label instead is what made every
/// category except "Other" fail validation when the mobile app first shipped -
/// so this panel uses the same keys rather than inventing a second list.
const _reportCategories = <String, String>{
  'Vandalism': 'Vandalism',
  'Theft': 'Theft',
  'Accident': 'Accident',
  'BlockedSlot': 'Blocked slot',
  'SuspiciousActivity': 'Suspicious activity',
  'Other': 'Other',
};

/// Every category a stored report can carry. The two extras are no longer
/// offered when filing, but older reports still have them.
const _categoryLabels = <String, String>{
  ..._reportCategories,
  'Safety': 'Safety',
  'VehicleDamage': 'Vehicle damage',
};

String _categoryLabel(String category) => _categoryLabels[category] ?? category;

/// `UnderReview` is an enum name, not something a person should have to read.
const _statusLabels = <String, String>{
  'Submitted': 'Submitted',
  'UnderReview': 'Under review',
  'Resolved': 'Resolved',
  'Dismissed': 'Dismissed',
  'Withdrawn': 'Withdrawn',
};

String _statusLabel(String status) => _statusLabels[status] ?? status;

final _dateTime = DateFormat('MMM d, yyyy HH:mm');

/// Same limits as the API and the phone app: five files, 5 MB each, and under
/// 10 MB for the whole request - so the total is checked here too, or a few
/// large photos would pass the per-file check and fail on the server.
const _maxFiles = 5;
const _maxFileBytes = 5 * 1024 * 1024;
const _maxTotalBytes = 9 * 1024 * 1024;
const _allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];

class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppPage(
      title: 'Incidents',
      subtitle: 'Reports raised by users and security staff.',
      body: _IncidentsTab(),
    );
  }
}

class _IncidentsTab extends ConsumerWidget {
  const _IncidentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(incidentsQueryNotifierProvider);
    final notifier = ref.read(incidentsQueryNotifierProvider.notifier);
    final isSecurity = ref.watch(staffRoleProvider) == StaffRole.security;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppToolbar(
          search: AppSearchField(
            hint: 'Reporter name',
            initialValue: query.search,
            onChanged: notifier.setSearch,
          ),
          filters: [
            AppFilterDropdown<String>(
              label: 'Status',
              value: query.status,
              options: [
                for (final s in _incidentStatuses)
                  AppFilterOption(s, _statusLabel(s)),
              ],
              allLabel: 'All statuses',
              onChanged: notifier.setStatus,
            ),
          ],
          trailing: [
            // Users and security report. An administrator decides reports, so
            // one filing their own would only be reviewing themselves - the API
            // refuses it, and the button is not shown.
            if (isSecurity)
              FilledButton.icon(
                icon: const Icon(Icons.add, size: AppSizes.iconSm),
                label: const Text('Report an incident'),
                onPressed: () => _showReportDialog(context, ref),
              ),
            const SizedBox(width: AppSpacing.x2),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(incidentListProvider),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        Expanded(
          child: AsyncView(
            value: ref.watch(incidentListProvider),
            onRetry: () => ref.invalidate(incidentListProvider),
            loading: const SkeletonTable(
              columns: 6,
              columnWidths: [160, 120, 120, 150, 150, 100],
            ),
            isEmpty: (page) => page.incidents.isEmpty,
            empty: AppEmptyState(
              icon: Icons.report_outlined,
              title: query.search.isNotEmpty
                  ? 'No reports match "${query.search}"'
                  : query.status == null
                      ? 'No incidents reported'
                      : 'No ${_statusLabel(query.status!).toLowerCase()} incidents',
              message: query.search.isNotEmpty || query.status != null
                  ? 'Clear the search or filter to see every reported incident.'
                  : 'Reports raised from the mobile app will appear here for review.',
            ),
            data: (page) => AppDataTable(
              minWidth: 900,
              columns: const [
                DataColumn(label: Text('Reported by')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Reported')),
                DataColumn(label: Text('Decided')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final i in page.incidents)
                  DataRow(
                    onSelectChanged: (_) => _open(context, ref, i),
                    cells: [
                      DataCell(_ReporterCell(
                        name: i.reportedByName,
                        role: i.reportedByRole,
                      )),
                      DataCell(Text(_categoryLabel(i.category),
                          style: Theme.of(context).textTheme.titleSmall)),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusPill.of(
                            _statusLabel(i.status),
                            intent: StatusIntents.incident(i.status),
                            dense: true,
                          ),
                          // Only the administrator needs pointing at it: the
                          // follow-up is addressed to them.
                          if (!isSecurity && i.hasNewFollowUp) ...[
                            const SizedBox(width: AppSpacing.x2),
                            const _NewFollowUpTag(),
                          ],
                        ],
                      )),
                      DataCell(_DateText(i.createdAt)),
                      // Blank until an administrator decides. Withdrawn reports
                      // are closed by the reporter, not decided, so they stay
                      // blank too.
                      DataCell(_DateText(i.reviewedAt)),
                      // The whole row already opens the report, but with no
                      // visual cue nobody discovered it - testers reported the
                      // review screen as missing entirely.
                      DataCell(AppRowAction(
                        label: _canReview(isSecurity, i.status)
                            ? 'Review'
                            : 'View',
                        icon: Icons.visibility_outlined,
                        onPressed: () => _open(context, ref, i),
                      )),
                    ],
                  ),
              ],
              footer: AppPagination(
                page: page.page,
                pageSize: page.pageSize,
                total: page.totalCount,
                itemLabel: 'incidents',
                onPage: notifier.setPage,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An administrator can act on a report that is still open; everything else,
/// and everything for a guard, is read-only.
bool _canReview(bool isSecurity, String status) =>
    !isSecurity && (status == 'Submitted' || status == 'UnderReview');

class _ReporterCell extends StatelessWidget {
  const _ReporterCell({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name.isEmpty ? '—' : name, style: text.titleSmall),
        if (role.isNotEmpty)
          Text(role,
              style: text.labelSmall?.copyWith(color: t.text.tertiary)),
      ],
    );
  }
}

class _DateText extends StatelessWidget {
  const _DateText(this.value);

  final DateTime? value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      value == null ? '—' : _dateTime.format(value!.toLocal()),
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: t.text.secondary),
    );
  }
}

/// Opens a report. For an administrator, opening a fresh one is the act of
/// starting the review: it becomes Under review and the reporter is told.
Future<void> _open(
    BuildContext context, WidgetRef ref, IncidentSummary summary) async {
  final isSecurity = ref.read(staffRoleProvider) == StaffRole.security;

  if (!isSecurity && summary.status == 'Submitted') {
    final error = await ref
        .read(incidentActionsProvider.notifier)
        .startReview(summary.incidentId);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ref.invalidate(incidentListProvider);
    ref.invalidate(openIncidentCountProvider);
    ref.invalidate(incidentDetailProvider(summary.incidentId));
  }

  if (!context.mounted) return;
  await _showDetail(context, ref, summary.incidentId);
}

Future<void> _showReportDialog(BuildContext context, WidgetRef ref) async {
  final descCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  // Nothing preselected. The first chip is "Vandalism", and a form that
  // accuses somebody of it on the reporter's behalf is a form that will
  // eventually be submitted unread.
  String? category;
  final files = <PickedFile>[];
  String? fileError;
  final formKey = GlobalKey<FormState>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final t = ctx.tokens;
        final text = Theme.of(ctx).textTheme;
        final totalBytes = files.fold<int>(0, (sum, f) => sum + f.bytes.length);

        Future<void> attach() async {
          final file = await BrowserFiles.pick(
            accept: _allowedExtensions.map((e) => '.$e').join(','),
          );
          if (file == null) return;

          final ext = file.name.contains('.')
              ? file.name.split('.').last.toLowerCase()
              : '';
          String? problem;
          if (!_allowedExtensions.contains(ext)) {
            problem = 'Only JPG, PNG or PDF files can be attached.';
          } else if (file.bytes.length > _maxFileBytes) {
            problem = '${file.name} is over 5 MB.';
          } else if (totalBytes + file.bytes.length > _maxTotalBytes) {
            problem = 'The files together must stay under 9 MB.';
          }

          setState(() {
            fileError = problem;
            if (problem == null) files.add(file);
          });
        }

        return AlertDialog(
          title: const Text('Report an Incident'),
          content: SizedBox(
            width: context.dialogWidth(440),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppRequiredNote(),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Category', isRequired: true),
                      ),
                      hint: const Text('What kind of incident?'),
                      items: [
                        for (final entry in _reportCategories.entries)
                          DropdownMenuItem(
                              value: entry.key, child: Text(entry.value)),
                      ],
                      onChanged: (v) => setState(() => category = v),
                      validator: (v) => v == null ? 'Pick a category' : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('What happened?', isRequired: true),
                        helperText:
                            'Plates, times and names are worth writing down '
                            'now - they are hard to recover later.',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Describe what happened'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: locationCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Location'),
                        helperText: 'A slot code or a landmark.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    Text('Photos or PDFs', style: text.titleSmall),
                    const SizedBox(height: AppSpacing.x2),
                    Wrap(
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final (index, file) in files.indexed)
                          InputChip(
                            avatar: Icon(
                              file.name.toLowerCase().endsWith('.pdf')
                                  ? Icons.picture_as_pdf_outlined
                                  : Icons.image_outlined,
                              size: AppSizes.iconSm,
                            ),
                            label: Text('${file.name} · ${file.readableSize}'),
                            onDeleted: () =>
                                setState(() => files.removeAt(index)),
                          ),
                        OutlinedButton.icon(
                          onPressed: files.length >= _maxFiles ? null : attach,
                          icon: const Icon(Icons.attach_file,
                              size: AppSizes.iconSm),
                          label: Text(files.isEmpty ? 'Attach' : 'Attach another'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      fileError ??
                          'Up to $_maxFiles files, JPG, PNG or PDF, 5 MB each. '
                              'Photos need the internet to upload.',
                      style: text.bodySmall?.copyWith(
                        color: fileError != null
                            ? t.status.danger.solid
                            : t.text.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('File report'),
            ),
          ],
        );
      },
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final msg = await ref.read(incidentActionsProvider.notifier).report(
        category: category!,
        description: descCtrl.text.trim(),
        location: locationCtrl.text.trim(),
        evidence: files,
      );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg ?? 'Report filed.')));
  ref.invalidate(incidentListProvider);
  ref.invalidate(openIncidentCountProvider);
}

/// A decision made in the dialog: the status to set and the note behind it.
typedef _Decision = ({String status, String notes});

Future<void> _showDetail(
    BuildContext context, WidgetRef ref, String incidentId) async {
  IncidentDetail detail;
  try {
    detail = await ref.read(incidentDetailProvider(incidentId).future);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't open this report. Try again.")),
    );
    return;
  }
  if (!context.mounted) return;

  // Only an administrator decides, and only while the report is still open.
  // A guard reads the queue read-only - knowing what has already been reported
  // is exactly what stops the same broken barrier being reported twice - and a
  // decided report is final for everyone.
  final isSecurity = ref.read(staffRoleProvider) == StaffRole.security;
  final canDecide = !isSecurity && !detail.isClosed;

  // Security adds what they found out while the report is open; once it is
  // decided, what was written about it is final too.
  final canFollowUp = isSecurity && !detail.isClosed;

  // Opening the report is reading what Security wrote. The dialog keeps the
  // copy fetched above, so the "New" marks still show for this visit.
  if (!isSecurity && detail.hasNewFollowUp) {
    ref
        .read(incidentActionsProvider.notifier)
        .markFollowUpsSeen(incidentId)
        .then((_) => ref.invalidate(incidentListProvider));
  }

  final notesCtrl = TextEditingController();
  String? notesError;

  final followUpCtrl = TextEditingController();
  PickedFile? followUpFile;
  String? followUpError;
  var sendingFollowUp = false;
  var showAllFindings = false;

  final decision = await showDialog<_Decision>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final t = ctx.tokens;
        final text = Theme.of(ctx).textTheme;

        Future<void> decide(String status) async {
          final notes = notesCtrl.text.trim();
          if (notes.isEmpty) {
            setState(() => notesError = 'Write a note explaining the decision');
            return;
          }

          final verb = status == 'Resolved' ? 'Resolve' : 'Dismiss';
          final sure = await showDialog<bool>(
            context: ctx,
            builder: (c) => AlertDialog(
              title: Text('$verb this report?'),
              content: Text(
                'This cannot be changed afterwards. '
                '${detail.reportedByName.isEmpty ? 'The reporter' : detail.reportedByName} '
                'will be told, and will see your note.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(verb),
                ),
              ],
            ),
          );

          if (sure == true && ctx.mounted) {
            Navigator.pop(ctx, (status: status, notes: notes));
          }
        }

        void openAttachment(IncidentEvidenceItem item) => viewDocument(
              ctx,
              title: item.fileName.isEmpty ? 'Attachment' : item.fileName,
              fileName: item.fileName,
              url: item.url,
            );

        Future<void> attachToFollowUp() async {
          final file = await BrowserFiles.pick(
            accept: _allowedExtensions.map((e) => '.$e').join(','),
          );
          if (file == null) return;

          final ext = file.name.contains('.')
              ? file.name.split('.').last.toLowerCase()
              : '';
          String? problem;
          if (!_allowedExtensions.contains(ext)) {
            problem = 'Only a JPG, PNG or PDF can be attached.';
          } else if (file.bytes.length > _maxFileBytes) {
            problem = '${file.name} is over 5 MB.';
          }

          setState(() {
            followUpError = problem;
            if (problem == null) followUpFile = file;
          });
        }

        Future<void> sendFollowUp() async {
          final note = followUpCtrl.text.trim();
          if (note.isEmpty) {
            setState(() => followUpError = 'Write what you found out');
            return;
          }

          setState(() {
            sendingFollowUp = true;
            followUpError = null;
          });

          final error = await ref
              .read(incidentActionsProvider.notifier)
              .addFollowUp(incidentId, note, attachment: followUpFile);
          if (!ctx.mounted) return;

          if (error != null) {
            setState(() {
              sendingFollowUp = false;
              followUpError = error;
            });
            return;
          }

          // Reload so the new note shows in the list straight away.
          try {
            detail = await ref.refresh(incidentDetailProvider(incidentId).future);
          } catch (_) {
            // The note is saved; it shows the next time the report is opened.
          }
          if (!ctx.mounted) return;

          followUpCtrl.clear();
          setState(() {
            sendingFollowUp = false;
            followUpFile = null;
          });
          ref.invalidate(incidentListProvider);
        }

        final sc = t.status.of(StatusIntents.incident(detail.status));
        final accent = t.status.of(StatusIntent.accent);
        final bold = FontWeight.w700;

        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(
              AppSpacing.x6, AppSpacing.x5, AppSpacing.x6, 0),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: sc.bg, shape: BoxShape.circle),
                child: Icon(_categoryIcon(detail.category), color: sc.fg),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _categoryLabel(detail.category),
                      style: text.titleLarge?.copyWith(fontWeight: bold),
                    ),
                    Text(
                      'Incident report',
                      style: text.labelSmall?.copyWith(color: t.text.tertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              StatusPill.of(
                _statusLabel(detail.status),
                intent: StatusIntents.incident(detail.status),
              ),
            ],
          ),
          content: SizedBox(
            width: context.dialogWidth(500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Who reported it, first: it decides how much weight the rest
                  // carries and is what an administrator follows up on.
                  if (detail.reportedByName.isNotEmpty)
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: accent.bg, shape: BoxShape.circle),
                          child: Text(
                            detail.reportedByName.characters.first
                                .toUpperCase(),
                            style: text.titleSmall
                                ?.copyWith(color: accent.fg, fontWeight: bold),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.reportedByName,
                                style: text.titleMedium
                                    ?.copyWith(fontWeight: bold),
                              ),
                              Text(
                                'Reported ${_dateTime.format(detail.createdAt.toLocal())}',
                                style: text.labelSmall
                                    ?.copyWith(color: t.text.secondary),
                              ),
                            ],
                          ),
                        ),
                        if (detail.reportedByRole.isNotEmpty)
                          StatusPill.of(
                            detail.reportedByRole,
                            intent: StatusIntent.accent,
                            dense: true,
                            showDot: false,
                          ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.x4),
                  if (!isSecurity && detail.followUps.isNotEmpty) ...[
                    _FindingsBanner(
                      followUps: detail.followUps,
                      expanded: showAllFindings,
                      onToggle: () =>
                          setState(() => showAllFindings = !showAllFindings),
                      onOpenAttachment: openAttachment,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                  ],
                  // What was reported is read-only evidence; the coloured edge
                  // follows the report's status, and the muted well keeps it
                  // from being mistaken for the field the admin fills in.
                  ClipRRect(
                    borderRadius: AppRadii.smAll,
                    child: Container(
                      width: double.infinity,
                      color: t.surface.muted,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 4, color: sc.solid),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.x3),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.description,
                                      style: text.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (detail.location
                                        case final location?
                                        when location.isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.x2),
                                      Row(
                                        children: [
                                          Icon(Icons.place,
                                              size: AppSizes.iconSm,
                                              color: t.status.danger.solid),
                                          const SizedBox(width: AppSpacing.x1),
                                          Flexible(
                                            child: Text(
                                              location,
                                              style: text.bodyMedium?.copyWith(
                                                  color: t.text.secondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (detail.evidence.isNotEmpty ||
                      detail.evidenceUnavailable > 0) ...[
                    const SizedBox(height: AppSpacing.x5),
                    _SectionLabel(
                      icon: Icons.attach_file,
                      label: 'Evidence',
                      count: detail.evidence.length,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    for (final item in detail.evidence)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                        // The same viewer the registration documents use keeps
                        // an image in a dialog on the page; a PDF still opens
                        // in a tab, since the browser renders those and Flutter
                        // Web does not.
                        child: _EvidenceRow(
                          item: item,
                          onOpen: () => viewDocument(
                            ctx,
                            title: item.fileName.isEmpty
                                ? 'Attachment'
                                : item.fileName,
                            fileName: item.fileName,
                            url: item.url,
                          ),
                        ),
                      ),
                    // At the guard post with no internet the files are out of
                    // reach. Saying so beats listing fewer attachments than
                    // the reporter sent.
                    if (detail.evidenceUnavailable > 0)
                      Text(
                        detail.evidenceUnavailable == 1
                            ? '1 attachment can be viewed when the internet is back.'
                            : '${detail.evidenceUnavailable} attachments can be viewed when the internet is back.',
                        style:
                            text.bodySmall?.copyWith(color: t.text.tertiary),
                      ),
                  ],
                  if (isSecurity && (detail.followUps.isNotEmpty || canFollowUp)) ...[
                    const SizedBox(height: AppSpacing.x5),
                    _SectionLabel(
                      icon: Icons.notes,
                      label: 'Security follow-up',
                      count: detail.followUps.length,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    for (final f in detail.followUps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                        child: _FollowUpTile(
                          item: f,
                          onOpenAttachment: openAttachment,
                        ),
                      ),
                    if (canFollowUp) ...[
                      TextField(
                        controller: followUpCtrl,
                        maxLines: 3,
                        maxLength: 2000,
                        enabled: !sendingFollowUp,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (followUpError != null) {
                            setState(() => followUpError = null);
                          }
                        },
                        decoration: InputDecoration(
                          label: const AppFieldLabel('Add a follow-up'),
                          helperText:
                              'Who, where, which plate. The administrator reads this before deciding.',
                          errorText: followUpError,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Row(
                        children: [
                          if (followUpFile != null)
                            Flexible(
                              child: InputChip(
                                avatar: Icon(
                                  followUpFile!.name.toLowerCase().endsWith('.pdf')
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.image_outlined,
                                  size: AppSizes.iconSm,
                                ),
                                label: Text(
                                  '${followUpFile!.name} · ${followUpFile!.readableSize}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onDeleted: sendingFollowUp
                                    ? null
                                    : () => setState(() => followUpFile = null),
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: sendingFollowUp ? null : attachToFollowUp,
                              icon: const Icon(Icons.attach_file,
                                  size: AppSizes.iconSm),
                              label: const Text('Attach'),
                            ),
                          const Spacer(),
                          FilledButton(
                            onPressed: sendingFollowUp ? null : sendFollowUp,
                            child: Text(sendingFollowUp ? 'Adding…' : 'Add follow-up'),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.x5),
                  if (canDecide) ...[
                    const _SectionLabel(
                      icon: Icons.gavel,
                      label: 'Your decision',
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) {
                        if (notesError != null) {
                          setState(() => notesError = null);
                        }
                      },
                      decoration: InputDecoration(
                        label: const AppFieldLabel('Decision note',
                            isRequired: true),
                        errorText: notesError,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    _Callout(
                      intent: StatusIntent.warning,
                      icon: Icons.info_outline,
                      text: 'The reporter will see this note. '
                          'A decision cannot be changed.',
                    ),
                  ] else if (detail.isClosed) ...[
                    _VerdictBanner(detail: detail),
                  ] else
                    const _Callout(
                      intent: StatusIntent.info,
                      icon: Icons.lock_outline,
                      text: 'Only an administrator can decide on a report. '
                          'Your follow-ups go to the administrator, not the reporter.',
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
            if (canDecide) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.status.danger.fg,
                  side: BorderSide(color: t.status.danger.solid),
                ),
                icon: const Icon(Icons.close, size: AppSizes.iconSm),
                onPressed: () => decide('Dismissed'),
                label: const Text('Dismiss'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.status.success.solid,
                  foregroundColor: t.text.onDark,
                ),
                icon: const Icon(Icons.check, size: AppSizes.iconSm),
                onPressed: () => decide('Resolved'),
                label: const Text('Resolve'),
              ),
            ],
          ],
        );
      },
    ),
  );

  if (decision == null || !context.mounted) return;

  final msg = await ref
      .read(incidentActionsProvider.notifier)
      .review(incidentId, decision.status, decision.notes);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg ?? 'Incident reviewed.')));
  ref.invalidate(incidentListProvider);
  ref.invalidate(openIncidentCountProvider);
  ref.invalidate(incidentDetailProvider(incidentId));
}

/// "New follow-up" beside a status in the queue.
class _NewFollowUpTag extends StatelessWidget {
  const _NewFollowUpTag();

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(StatusIntent.accent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.bg, borderRadius: AppRadii.fullAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 12, color: c.fg),
          const SizedBox(width: 4),
          Text(
            'New follow-up',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: c.fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One note: what was found out, who wrote it and when, and its photo or PDF
/// if it has one.
class _FollowUpTile extends StatelessWidget {
  const _FollowUpTile({
    required this.item,
    required this.onOpenAttachment,
    this.showNew = false,
  });

  final IncidentFollowUp item;
  final void Function(IncidentEvidenceItem) onOpenAttachment;

  /// Mark a note the administrator has not read before this visit.
  final bool showNew;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final accent = t.status.of(StatusIntent.accent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: AppRadii.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.note, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.x1),
          Row(
            children: [
              Flexible(
                child: Text(
                  '${item.authorName.isEmpty ? 'Security' : item.authorName}'
                  ' · ${_dateTime.format(item.createdAt.toLocal())}',
                  style: text.labelSmall?.copyWith(color: t.text.tertiary),
                ),
              ),
              if (showNew && item.isNew) ...[
                const SizedBox(width: AppSpacing.x2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: accent.bg, borderRadius: AppRadii.fullAll),
                  child: Text('New',
                      style: text.labelSmall?.copyWith(
                          color: accent.fg, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          if (item.attachment case final attachment?) ...[
            const SizedBox(height: AppSpacing.x2),
            _EvidenceRow(
              item: attachment,
              onOpen: () => onOpenAttachment(attachment),
            ),
          ],
        ],
      ),
    );
  }
}

/// What Security found out, on top of the report so the administrator reads it
/// first. Labelled as Security's word, not as verified.
class _FindingsBanner extends StatelessWidget {
  const _FindingsBanner({
    required this.followUps,
    required this.expanded,
    required this.onToggle,
    required this.onOpenAttachment,
  });

  final List<IncidentFollowUp> followUps;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(IncidentEvidenceItem) onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.tokens.status.of(StatusIntent.accent);

    // Folded, only the latest note: it is the last word on the matter.
    final shown = expanded ? followUps : [followUps.last];
    final count = followUps.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: c.solid, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  size: AppSizes.iconSm, color: c.fg),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  'Security findings',
                  style: text.titleSmall
                      ?.copyWith(color: c.fg, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                count == 1 ? '1 note' : '$count notes',
                style: text.labelSmall?.copyWith(color: c.fg),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          for (final f in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x2),
              child: _FollowUpTile(
                item: f,
                showNew: true,
                onOpenAttachment: onOpenAttachment,
              ),
            ),
          Text(
            'Written by Security. Not verified by an administrator.',
            style: text.labelSmall?.copyWith(color: c.fg),
          ),
          if (count > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onToggle,
                child: Text(
                    expanded ? 'Show latest only' : 'Show all $count notes'),
              ),
            ),
        ],
      ),
    );
  }
}

/// One attachment: what it is called, what kind of file it is, and a way to
/// open it. The kind matters because a PDF opens in a new tab while a photo
/// stays in a dialog, so each type gets its own colour and the reviewer knows
/// which before clicking.
class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.item, required this.onOpen});

  final IncidentEvidenceItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(item.isPdf ? StatusIntent.danger : StatusIntent.info);

    return Material(
      color: c.bg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.smAll,
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: AppRadii.smAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
          child: Row(
            children: [
              Icon(
                item.isPdf ? Icons.picture_as_pdf : Icons.image,
                color: c.solid,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  item.fileName.isEmpty ? 'Attachment' : item.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.solid,
                  borderRadius: AppRadii.fullAll,
                ),
                child: Text(
                  item.typeLabel,
                  style: text.labelSmall?.copyWith(
                    color: t.text.onDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Icon(Icons.open_in_new, size: AppSizes.iconSm, color: c.fg),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) => switch (category) {
      'Vandalism' => Icons.format_paint_outlined,
      'Theft' => Icons.lock_open_outlined,
      'Accident' => Icons.car_crash_outlined,
      'BlockedSlot' => Icons.block,
      'SuspiciousActivity' => Icons.visibility_outlined,
      'VehicleDamage' => Icons.car_repair,
      _ => Icons.report_outlined,
    };

/// A bold heading with a coloured icon, so each part of the dialog is
/// findable at a glance instead of every block reading as the same grey.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label, this.count});

  final IconData icon;
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = t.status.of(StatusIntent.accent);

    return Row(
      children: [
        Icon(icon, size: AppSizes.iconSm, color: accent.solid),
        const SizedBox(width: AppSpacing.x2),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: AppSpacing.x2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration:
                BoxDecoration(color: accent.bg, borderRadius: AppRadii.fullAll),
            child: Text(
              '$count',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: accent.fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

/// A short tinted note: a warning before something permanent, or a hint.
class _Callout extends StatelessWidget {
  const _Callout({required this.intent, required this.icon, required this.text});

  final StatusIntent intent;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(intent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconSm, color: c.fg),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// How a closed report ended: the verdict, when, and the note behind it, in the
/// colour of the outcome so a resolved report and a dismissed one look
/// different before anything is read.
class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.detail});

  final IncidentDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(StatusIntents.incident(detail.status));

    final (icon, headline) = switch (detail.status) {
      'Resolved' => (Icons.check_circle, 'Resolved'),
      'Dismissed' => (Icons.cancel, 'Dismissed'),
      _ => (Icons.undo, 'Withdrawn by the reporter'),
    };
    final decided = detail.reviewedAt;
    final note = detail.adminNotes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c.solid),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  decided == null
                      ? headline
                      : '$headline · ${_dateTime.format(decided.toLocal())}',
                  style: text.titleSmall
                      ?.copyWith(color: c.fg, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            Text('Admin note',
                style: text.labelSmall?.copyWith(color: c.fg)),
            const SizedBox(height: 2),
            Text(note,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          ],
          if (detail.status != 'Withdrawn') ...[
            const SizedBox(height: AppSpacing.x2),
            Text(
              'This decision is final.',
              style: text.labelSmall?.copyWith(color: c.fg),
            ),
          ],
        ],
      ),
    );
  }
}
