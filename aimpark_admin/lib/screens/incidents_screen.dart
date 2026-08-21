import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/responsive.dart';
import '../providers/incidents_provider.dart';
import '../theme/theme.dart';
import '../widgets/appeals_panel.dart';
import '../widgets/ui/ui.dart';

const _incidentStatuses = ['Submitted', 'UnderReview', 'Resolved', 'Dismissed'];

/// `UnderReview` is an enum name, not something a person should have to read.
const _statusLabels = <String, String>{
  'Submitted': 'Submitted',
  'UnderReview': 'Under review',
  'Resolved': 'Resolved',
  'Dismissed': 'Dismissed',
};

String _statusLabel(String status) => _statusLabels[status] ?? status;

class IncidentsScreen extends StatelessWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(length: 2, child: _IncidentsPage());
  }
}

/// The document treats incident reports and violation appeals as one module —
/// both are "a person disputes something and an administrator must decide" —
/// so they are two tabs of one page rather than two entries in the sidebar.
/// The appeals half lives in [AppealsPanel] because its data hangs off a
/// violation, not off an incident.
class _IncidentsPage extends StatelessWidget {
  const _IncidentsPage();

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Incidents & Appeals',
      subtitle: 'Reports raised by users and security staff, and appeals '
          'against issued violations.',
      toolbar: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [Tab(text: 'Incident Reports'), Tab(text: 'Appeals')],
        ),
      ),
      body: TabBarView(
        children: [_IncidentsTab(), AppealsPanel()],
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
                        label: 'Review',
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

  Future<void> _showDetail(
      BuildContext context, WidgetRef ref, String incidentId) async {
    final detail = await ref.read(incidentDetailProvider(incidentId).future);
    if (!context.mounted) return;

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
                          child: AppRowAction(
                            label: 'Attachment ${index + 1}',
                            icon: Icons.open_in_new,
                            onPressed: () => launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
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
                      onChanged: (v) => setState(() => status = v!),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Admin Notes',
                        helperText:
                            'Recorded with the decision so it can be justified later.',
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
