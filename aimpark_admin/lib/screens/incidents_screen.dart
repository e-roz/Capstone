import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/incident.dart';
import '../providers/incidents_provider.dart';

const _incidentStatuses = ['Submitted', 'UnderReview', 'Resolved', 'Dismissed'];

class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(incidentsQueryNotifierProvider);
    final async = ref.watch(incidentListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Incidents & Appeals',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                DropdownButton<String?>(
                  value: query.status,
                  hint: const Text('All Status'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Status')),
                    ..._incidentStatuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) =>
                      ref.read(incidentsQueryNotifierProvider.notifier).setStatus(v),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(incidentListProvider),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load incidents: $e')),
                data: (page) => Column(
                  children: [
                    Expanded(child: _IncidentTable(page: page)),
                    const SizedBox(height: 12),
                    _Pagination(page: page),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentTable extends ConsumerWidget {
  const _IncidentTable({required this.page});

  final IncidentListPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.incidents.isEmpty) {
      return const Center(child: Text('No incidents reported yet.'));
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Reported')),
          ],
          rows: page.incidents
              .map((i) => DataRow(
                    onSelectChanged: (_) => _showDetail(context, ref, i.incidentId),
                    cells: [
                      DataCell(Text(i.category)),
                      DataCell(_StatusChip(status: i.status)),
                      DataCell(Text(
                          DateFormat('MMM d, yyyy HH:mm').format(i.createdAt.toLocal()))),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, WidgetRef ref, String incidentId) async {
    final detail = await ref.read(incidentDetailProvider(incidentId).future);
    if (!context.mounted) return;

    String status = detail.status;
    final notesCtrl = TextEditingController(text: detail.adminNotes ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Incident — ${detail.category}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.description),
                  if (detail.location != null && detail.location!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Location: ${detail.location}',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                  if (detail.evidenceUrls.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.w600)),
                    ...detail.evidenceUrls.map((url) => TextButton(
                          onPressed: () => launchUrl(Uri.parse(url)),
                          child: Text(url, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                        labelText: 'Status', border: OutlineInputBorder()),
                    items: _incidentStatuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => status = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Admin Notes', border: OutlineInputBorder()),
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
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final msg = await ref.read(incidentActionsProvider.notifier).review(
        incidentId, status, notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Incident reviewed.')));
    ref.invalidate(incidentListProvider);
    ref.invalidate(incidentDetailProvider(incidentId));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Resolved':
        color = Colors.green;
        break;
      case 'Dismissed':
        color = Colors.red;
        break;
      case 'UnderReview':
        color = Colors.orange;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.page});

  final IncidentListPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPages = (page.totalCount / page.pageSize).ceil().clamp(1, 999999);
    final currentPage = page.page;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
            'Showing ${page.incidents.length} of ${page.totalCount} incidents • Page $currentPage of $totalPages'),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1
              ? () => ref
                  .read(incidentsQueryNotifierProvider.notifier)
                  .setPage(currentPage - 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages
              ? () => ref
                  .read(incidentsQueryNotifierProvider.notifier)
                  .setPage(currentPage + 1)
              : null,
        ),
      ],
    );
  }
}
