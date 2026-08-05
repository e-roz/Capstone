import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/violation.dart';
import '../providers/violations_provider.dart';
import '../widgets/user_picker.dart';
import '../core/utils/responsive.dart';

const _violationStatuses = ['Issued', 'Appealed', 'Upheld', 'Overturned', 'Dismissed'];
const _appealStatuses = ['Pending', 'Approved', 'Denied'];

class ViolationsScreen extends StatelessWidget {
  const ViolationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Violations',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const TabBar(
                isScrollable: true,
                tabs: [Tab(text: 'Violations'), Tab(text: 'Appeals')],
              ),
              const SizedBox(height: 12),
              const Expanded(
                child: TabBarView(
                  children: [_ViolationsTab(), _AppealsTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Violations tab ───────────────────────────────────────────────────────────

class _ViolationsTab extends ConsumerWidget {
  const _ViolationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(violationsQueryNotifierProvider);
    final async = ref.watch(violationListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DropdownButton<String?>(
              value: query.status,
              hint: const Text('All Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Status')),
                ..._violationStatuses
                    .map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) =>
                  ref.read(violationsQueryNotifierProvider.notifier).setStatus(v),
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Issue Violation'),
              onPressed: () => _showIssueViolation(context, ref),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(violationListProvider),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load violations: $e')),
            data: (page) => Column(
              children: [
                Expanded(child: _ViolationTable(page: page)),
                const SizedBox(height: 12),
                _PageBar(
                  label: 'violations',
                  count: page.violations.length,
                  total: page.totalCount,
                  page: page.page,
                  pageSize: page.pageSize,
                  onPage: (p) =>
                      ref.read(violationsQueryNotifierProvider.notifier).setPage(p),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showIssueViolation(BuildContext context, WidgetRef ref) async {
    final descriptionCtrl = TextEditingController();
    final penaltyCtrl = TextEditingController();
    final daysCtrl = TextEditingController();
    PickedUser? picked;
    String? userError;
    String? ruleId;
    String? suspensionOverride;
    final formKey = GlobalKey<FormState>();
    final rules = await ref.read(policyRulesProvider.future);
    final activeRules = rules.where((r) => r.isActive).toList();

    if (!context.mounted) return;

    if (activeRules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No active policy rules. Create one under Policy Rules first.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Issue Violation'),
          content: SizedBox(
            width: context.dialogWidth(400),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserPickerField(
                    selected: picked,
                    errorText: userError,
                    onChanged: (u) => setState(() {
                      picked = u;
                      userError = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: ruleId,
                    decoration: const InputDecoration(
                        labelText: 'Policy Rule', border: OutlineInputBorder()),
                    items: activeRules
                        .map((r) =>
                            DropdownMenuItem(value: r.ruleId, child: Text(r.title)))
                        .toList(),
                    onChanged: (v) => setState(() => ruleId = v),
                    validator: (v) => v == null ? 'Select a rule' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Description', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 16),
                  // The API has always accepted these; leaving them out of the
                  // dialog meant every violation silently took the rule default.
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Leave blank to use the policy rule defaults.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: penaltyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Penalty amount (override)',
                        prefixText: '₱',
                        border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty)
                        ? null
                        : (double.tryParse(v) == null ? 'Enter a valid amount' : null),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: suspensionOverride,
                    decoration: const InputDecoration(
                        labelText: 'Suspension (override)',
                        border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Use rule default')),
                      DropdownMenuItem(value: 'None', child: Text('None')),
                      DropdownMenuItem(value: 'Temporary', child: Text('Temporary')),
                      DropdownMenuItem(value: 'Permanent', child: Text('Permanent')),
                    ],
                    onChanged: (v) => setState(() => suspensionOverride = v),
                  ),
                  if (suspensionOverride == 'Temporary') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: daysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Suspension days',
                          border: OutlineInputBorder()),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return (n == null || n <= 0)
                            ? 'Enter a positive number of days'
                            : null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final formOk = formKey.currentState!.validate();
                if (picked == null) {
                  setState(() => userError = 'Select a user');
                  return;
                }
                if (formOk) Navigator.pop(ctx, true);
              },
              child: const Text('Issue'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final msg = await ref.read(violationActionsProvider.notifier).issue(
          userId: picked!.userId,
          policyRuleId: ruleId!,
          description: descriptionCtrl.text.trim(),
          penaltyAmountOverride: double.tryParse(penaltyCtrl.text.trim()),
          suspensionTypeOverride: suspensionOverride,
          suspensionDaysOverride: suspensionOverride == 'Temporary'
              ? int.tryParse(daysCtrl.text.trim())
              : null,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Violation issued.')));
    ref.invalidate(violationListProvider);
  }
}

class _ViolationTable extends ConsumerWidget {
  const _ViolationTable({required this.page});

  final ViolationListPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.violations.isEmpty) {
      return const Center(child: Text('No violations found.'));
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('Rule')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Penalty')),
            DataColumn(label: Text('Suspension')),
            DataColumn(label: Text('Issued')),
            DataColumn(label: Text('Actions')),
          ],
          rows: page.violations.map((v) => _row(context, ref, v)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, WidgetRef ref, ViolationSummary v) => DataRow(
        cells: [
          DataCell(Text(v.policyRuleTitle)),
          DataCell(_StatusChip(status: v.status)),
          DataCell(Text('₱${v.penaltyAmount.toStringAsFixed(2)}')),
          DataCell(Text(v.suspensionType)),
          DataCell(Text(DateFormat('MMM d, yyyy').format(v.createdAt.toLocal()))),
          DataCell(
            (v.status == 'Issued' || v.status == 'Appealed')
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Editable only while Issued — once appealed, this record
                      // is what both sides are arguing about.
                      if (v.status == 'Issued') ...[
                        OutlinedButton(
                          style: _compactButton,
                          onPressed: () => _showEdit(context, ref, v),
                          child: const Text('Edit',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      OutlinedButton(
                        style: _compactButton,
                        onPressed: () async {
                          final msg = await ref
                              .read(violationActionsProvider.notifier)
                              .dismiss(v.violationId);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg ?? 'Violation dismissed.')));
                          ref.invalidate(violationListProvider);
                        },
                        child: const Text('Dismiss',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      );

  static final _compactButton = OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Future<void> _showEdit(
      BuildContext context, WidgetRef ref, ViolationSummary v) async {
    final descriptionCtrl = TextEditingController();
    final penaltyCtrl =
        TextEditingController(text: v.penaltyAmount.toStringAsFixed(2));
    final daysCtrl = TextEditingController();
    var suspensionType = v.suspensionType;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Violation'),
          content: SizedBox(
            width: context.dialogWidth(400),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(v.policyRuleTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Description is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: penaltyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Penalty amount',
                          prefixText: '₱',
                          border: OutlineInputBorder()),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return (n == null || n < 0)
                            ? 'Enter a valid amount'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _violationSuspensions.contains(suspensionType)
                          ? suspensionType
                          : 'None',
                      decoration: const InputDecoration(
                          labelText: 'Suspension', border: OutlineInputBorder()),
                      items: _violationSuspensions
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => suspensionType = val ?? 'None'),
                    ),
                    if (suspensionType == 'Temporary') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Suspension days',
                            border: OutlineInputBorder()),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return (n == null || n <= 0)
                              ? 'Enter a positive number of days'
                              : null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final msg = await ref.read(violationActionsProvider.notifier).update(
          violationId: v.violationId,
          description: descriptionCtrl.text.trim(),
          penaltyAmount: double.parse(penaltyCtrl.text.trim()),
          suspensionType: suspensionType,
          suspensionDays: suspensionType == 'Temporary'
              ? int.tryParse(daysCtrl.text.trim())
              : null,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Violation updated.')));
    ref.invalidate(violationListProvider);
  }
}

const _violationSuspensions = ['None', 'Temporary', 'Permanent'];

// ── Appeals tab ──────────────────────────────────────────────────────────────

class _AppealsTab extends ConsumerWidget {
  const _AppealsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(appealsQueryNotifierProvider);
    final async = ref.watch(appealListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DropdownButton<String?>(
              value: query.status,
              hint: const Text('All Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Status')),
                ..._appealStatuses
                    .map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) =>
                  ref.read(appealsQueryNotifierProvider.notifier).setStatus(v),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(appealListProvider),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load appeals: $e')),
            data: (page) => Column(
              children: [
                Expanded(child: _AppealList(page: page)),
                const SizedBox(height: 12),
                _PageBar(
                  label: 'appeals',
                  count: page.appeals.length,
                  total: page.totalCount,
                  page: page.page,
                  pageSize: page.pageSize,
                  onPage: (p) =>
                      ref.read(appealsQueryNotifierProvider.notifier).setPage(p),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppealList extends ConsumerWidget {
  const _AppealList({required this.page});

  final ViolationAppealListPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.appeals.isEmpty) {
      return const Center(child: Text('No appeals found.'));
    }

    return ListView.separated(
      itemCount: page.appeals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _AppealCard(appeal: page.appeals[i]),
    );
  }
}

class _AppealCard extends ConsumerWidget {
  const _AppealCard({required this.appeal});

  final ViolationAppeal appeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusChip(status: appeal.status),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Violation ${appeal.violationId.substring(0, 8)}…',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(appeal.reasonText, style: const TextStyle(fontSize: 13)),
                  ),
                  if (appeal.adminNotes != null && appeal.adminNotes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Admin notes: ${appeal.adminNotes}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        DateFormat('MMM d, yyyy HH:mm').format(appeal.createdAt.toLocal()),
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                ],
              ),
            ),
            if (appeal.status == 'Pending')
              Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                    onPressed: () => _decide(context, ref, true),
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _decide(context, ref, false),
                    child: const Text('Deny'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve Appeal' : 'Deny Appeal'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Admin notes (optional)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Approve' : 'Deny'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final msg = await ref.read(violationActionsProvider.notifier).decideAppeal(
        appeal.appealId, approve, notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Appeal decided.')));
    ref.invalidate(appealListProvider);
    ref.invalidate(violationListProvider);
  }
}

// ── Shared widgets ───────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Approved':
      case 'Overturned':
      case 'Dismissed':
        color = Colors.green;
        break;
      case 'Denied':
      case 'Upheld':
        color = Colors.red;
        break;
      case 'Appealed':
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

class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.label,
    required this.count,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.onPage,
  });

  final String label;
  final int count;
  final int total;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final totalPages = (total / pageSize).ceil().clamp(1, 999999);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Showing $count of $total $label • Page $page of $totalPages'),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: page > 1 ? () => onPage(page - 1) : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: page < totalPages ? () => onPage(page + 1) : null,
        ),
      ],
    );
  }
}
