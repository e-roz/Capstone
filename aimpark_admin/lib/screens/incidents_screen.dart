import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import '../providers/incidents_provider.dart';
import '../providers/violations_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/appeals_panel.dart';
import '../widgets/document_viewer.dart';
import '../widgets/ui/ui.dart';

const _incidentStatuses = ['Submitted', 'UnderReview', 'Resolved', 'Dismissed'];

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

/// `UnderReview` is an enum name, not something a person should have to read.
const _statusLabels = <String, String>{
  'Submitted': 'Submitted',
  'UnderReview': 'Under review',
  'Resolved': 'Resolved',
  'Dismissed': 'Dismissed',
};

String _statusLabel(String status) => _statusLabels[status] ?? status;

class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Security reports what they see on the ground and follows their own
    // reports up. Deciding an appeal against a violation is an administrator's
    // call, and the API refuses them the endpoint anyway - so the tab is not
    // shown rather than shown and then failing.
    final canDecideAppeals =
        ref.watch(staffRoleProvider) != StaffRole.security;

    return DefaultTabController(
      length: canDecideAppeals ? 2 : 1,
      child: _IncidentsPage(showAppeals: canDecideAppeals),
    );
  }
}

/// The document treats incident reports and violation appeals as one module —
/// both are "a person disputes something and an administrator must decide" —
/// so they are two tabs of one page rather than two entries in the sidebar.
/// The appeals half lives in [AppealsPanel] because its data hangs off a
/// violation, not off an incident.
class _IncidentsPage extends ConsumerWidget {
  const _IncidentsPage({required this.showAppeals});

  final bool showAppeals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Counts on the tabs, because a queue with three untouched reports in it
    // looked exactly like an empty one until you clicked. The admin had no way
    // to know anything had arrived without going and looking at both halves.
    final openIncidents = ref.watch(openIncidentCountProvider).valueOrNull;
    // Only asked for when the tab that shows it is on screen. The endpoint is
    // Admin-only, so watching it unconditionally 403s for a guard.
    final pendingAppeals = showAppeals
        ? ref.watch(pendingAppealCountProvider).valueOrNull
        : null;

    return AppPage(
      title: showAppeals ? 'Incidents & Appeals' : 'Incident Reports',
      subtitle: showAppeals
          ? 'Reports raised by users and security staff, and appeals against '
              'issued violations.'
          : 'Reports raised by users and security staff.',
      toolbar: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _CountedTab(label: 'Incident Reports', count: openIncidents),
            if (showAppeals)
              _CountedTab(label: 'Appeals', count: pendingAppeals),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          const _IncidentsTab(),
          if (showAppeals) const AppealsPanel(),
        ],
      ),
    );
  }
}

/// A tab whose label carries how much work is waiting behind it.
///
/// The badge is hidden at zero rather than shown as "0": a queue that is
/// genuinely clear should look calm, and a row of noughts trains the eye to
/// stop reading the numbers at all.
class _CountedTab extends StatelessWidget implements PreferredSizeWidget {
  const _CountedTab({required this.label, required this.count});

  final String label;

  /// Null while the count is still loading, or if it failed — either way the
  /// tab renders as a plain label rather than guessing.
  final int? count;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final waiting = count != null && count! > 0;

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (waiting) ...[
            const SizedBox(width: AppSpacing.x2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: t.status.danger.solid,
                borderRadius: AppRadii.fullAll,
              ),
              child: Text(
                '$count',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: t.text.onDark),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IncidentsTab extends ConsumerWidget {
  const _IncidentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(incidentsQueryNotifierProvider);
    final notifier = ref.read(incidentsQueryNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppToolbar(
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
            // Security witness things on the ground - "Incident Reporting" is
            // their module in the spec, and until this button existed a guard
            // could read the queue but had no way to add to it. An
            // administrator can file one too; both are staff at the same lot.
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
            isEmpty: (page) => page.incidents.isEmpty,
            empty: AppEmptyState(
              icon: Icons.report_outlined,
              title: query.status == null
                  ? 'No incidents reported'
                  : 'No ${_statusLabel(query.status!).toLowerCase()} incidents',
              message: query.status == null
                  ? 'Reports raised from the mobile app will appear here for review.'
                  : 'Clear the filter to see every reported incident.',
            ),
            data: (page) => AppDataTable(
              minWidth: 720,
              columns: const [
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Reported')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final i in page.incidents)
                  DataRow(
                    onSelectChanged: (_) =>
                        _showDetail(context, ref, i.incidentId),
                    cells: [
                      DataCell(Text(i.category,
                          style: Theme.of(context).textTheme.titleSmall)),
                      DataCell(StatusPill.of(
                        _statusLabel(i.status),
                        intent: StatusIntents.incident(i.status),
                        dense: true,
                      )),
                      DataCell(Text(
                        DateFormat('MMM d, yyyy HH:mm')
                            .format(i.createdAt.toLocal()),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: context.tokens.text.secondary),
                      )),
                      // The whole row already opens the review dialog, but with
                      // no visual cue nobody discovered it — testers reported
                      // the review screen as missing entirely.
                      DataCell(AppRowAction(
                        label: ref.watch(staffRoleProvider) == StaffRole.security
                            ? 'Open'
                            : 'Review',
                        icon: Icons.visibility_outlined,
                        onPressed: () => _showDetail(context, ref, i.incidentId),
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

  Future<void> _showReportDialog(BuildContext context, WidgetRef ref) async {
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    // Nothing preselected. The first chip is "Vandalism", and a form that
    // accuses somebody of it on the reporter's behalf is a form that will
    // eventually be submitted unread.
    String? category;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Report an Incident'),
          content: SizedBox(
            width: context.dialogWidth(440),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      validator: (v) =>
                          v == null ? 'Pick a category' : null,
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
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final msg = await ref.read(incidentActionsProvider.notifier).report(
          category: category!,
          description: descCtrl.text.trim(),
          location: locationCtrl.text.trim(),
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Report filed.')));
    ref.invalidate(incidentListProvider);
    ref.invalidate(openIncidentCountProvider);
  }

  Future<void> _showDetail(
      BuildContext context, WidgetRef ref, String incidentId) async {
    final detail = await ref.read(incidentDetailProvider(incidentId).future);
    if (!context.mounted) return;

    // A guard reads the queue; an administrator decides on it. Shown read-only
    // rather than hidden, because knowing what has already been reported is
    // exactly what stops the same broken barrier being reported twice.
    final canReview = ref.read(staffRoleProvider) != StaffRole.security;

    String status = detail.status;
    final notesCtrl = TextEditingController(text: detail.adminNotes ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final t = ctx.tokens;
          final text = Theme.of(ctx).textTheme;

          return AlertDialog(
            title: Text('Incident — ${detail.category}'),
            content: SizedBox(
              width: context.dialogWidth(460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // What was reported is read-only evidence; separating it
                    // onto a muted well keeps it from being mistaken for one
                    // of the fields below that the admin is about to change.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.x3),
                      decoration: BoxDecoration(
                        color: t.surface.muted,
                        borderRadius: AppRadii.smAll,
                        border: Border.all(color: t.border.subtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(detail.description, style: text.bodyMedium),
                          if (detail.location case final location?
                              when location.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.x2),
                              child: Row(
                                children: [
                                  Icon(Icons.place_outlined,
                                      size: AppSizes.iconSm,
                                      color: t.text.tertiary),
                                  const SizedBox(width: AppSpacing.x1),
                                  Flexible(
                                    child: Text(
                                      location,
                                      style: text.bodySmall
                                          ?.copyWith(color: t.text.secondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.x2),
                            child: Text(
                              'Reported ${DateFormat('MMM d, yyyy HH:mm').format(detail.createdAt.toLocal())}',
                              style: text.labelSmall
                                  ?.copyWith(color: t.text.tertiary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (detail.evidenceUrls.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x4),
                      Text('Evidence', style: text.titleSmall),
                      const SizedBox(height: AppSpacing.x2),
                      for (final (index, url) in detail.evidenceUrls.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.x1),
                          // Was a straight launchUrl, so every photo threw the
                          // reviewer out into another tab and back. The same
                          // viewer the registration documents use keeps an
                          // image in a dialog on the page; a PDF still opens in
                          // a tab, since the browser renders those and Flutter
                          // Web does not.
                          child: AppRowAction(
                            label: 'Attachment ${index + 1}',
                            icon: Icons.visibility_outlined,
                            onPressed: () => viewDocument(
                              context,
                              title: 'Attachment ${index + 1}',
                              fileName: Uri.parse(url).path,
                              url: url,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: AppSpacing.x4),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: _incidentStatuses
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(_statusLabel(s))))
                          .toList(),
                      onChanged:
                          canReview ? (v) => setState(() => status = v!) : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      enabled: canReview,
                      decoration: InputDecoration(
                        labelText: 'Admin Notes',
                        helperText: canReview
                            ? 'Recorded with the decision so it can be justified later.'
                            : 'Only an administrator can decide on a report.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Close')),
              if (canReview)
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save Review'),
                ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final msg = await ref.read(incidentActionsProvider.notifier).review(
        incidentId,
        status,
        notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Incident reviewed.')));
    ref.invalidate(incidentListProvider);
    ref.invalidate(incidentDetailProvider(incidentId));
  }
}
