import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/violation.dart';
import '../providers/violations_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';
import '../widgets/user_picker.dart';

const _violationStatuses = [
  'Issued',
  'Appealed',
  'Upheld',
  'Overturned',
  'Dismissed'
];
const _violationSuspensions = ['None', 'Temporary', 'Permanent'];

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

class ViolationsScreen extends ConsumerWidget {
  const ViolationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Violation Tracking',
      subtitle: 'Offences on record, and the penalties and suspensions '
          'attached to them.',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.add, size: AppSizes.iconSm),
          label: const Text('Issue Violation'),
          onPressed: () => _showIssueViolation(context, ref),
        ),
      ],
      // Appeals used to be a second tab here. They now live on Incidents &
      // Appeals, which is where the capstone document puts them and where an
      // administrator looking for "things to decide" would go. A violation that
      // has been contested still shows up below with an `Appealed` status.
      body: const _ViolationsTab(),
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
            width: context.dialogWidth(420),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
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
                    const SizedBox(height: AppSpacing.x3),
                    DropdownButtonFormField<String>(
                      initialValue: ruleId,
                      decoration:
                          const InputDecoration(labelText: 'Policy Rule'),
                      items: activeRules
                          .map((r) => DropdownMenuItem(
                              value: r.ruleId, child: Text(r.title)))
                          .toList(),
                      onChanged: (v) => setState(() => ruleId = v),
                      validator: (v) => v == null ? 'Select a rule' : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Description is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x5),
                    // The API has always accepted these; leaving them out of the
                    // dialog meant every violation silently took the rule default.
                    _OverrideHeading(),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: penaltyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Penalty amount (override)',
                        prefixText: '₱',
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? null
                          : (double.tryParse(v) == null
                              ? 'Enter a valid amount'
                              : null),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    DropdownButtonFormField<String?>(
                      initialValue: suspensionOverride,
                      decoration: const InputDecoration(
                          labelText: 'Suspension (override)'),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('Use rule default')),
                        DropdownMenuItem(value: 'None', child: Text('None')),
                        DropdownMenuItem(
                            value: 'Temporary', child: Text('Temporary')),
                        DropdownMenuItem(
                            value: 'Permanent', child: Text('Permanent')),
                      ],
                      onChanged: (v) => setState(() => suspensionOverride = v),
                    ),
                    if (suspensionOverride == 'Temporary') ...[
                      const SizedBox(height: AppSpacing.x3),
                      TextFormField(
                        controller: daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Suspension days'),
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

/// The divider between "what happened" and "what to do differently from the
/// rule", so the override fields do not read as required.
class _OverrideHeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overrides', style: text.titleSmall),
          const SizedBox(height: AppSpacing.labelGap),
          Text(
            'Leave blank to use the policy rule defaults.',
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ],
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
    final notifier = ref.read(violationsQueryNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppToolbar(
          filters: [
            AppFilterDropdown<String>(
              label: 'Status',
              value: query.status,
              options: [
                for (final s in _violationStatuses) AppFilterOption(s, s),
              ],
              allLabel: 'All statuses',
              onChanged: notifier.setStatus,
            ),
          ],
          trailing: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(violationListProvider),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        Expanded(
          child: AsyncView(
            value: ref.watch(violationListProvider),
            onRetry: () => ref.invalidate(violationListProvider),
            isEmpty: (page) => page.violations.isEmpty,
            empty: AppEmptyState(
              icon: Icons.gavel_outlined,
              title: query.status == null
                  ? 'No violations issued'
                  : 'No ${query.status!.toLowerCase()} violations',
              message: query.status == null
                  ? 'Offences you record against a policy rule appear here.'
                  : 'Clear the filter to see every violation on record.',
            ),
            data: (page) => AppDataTable(
              minWidth: 900,
              columns: const [
                DataColumn(label: Text('Rule')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Penalty'), numeric: true),
                DataColumn(label: Text('Suspension')),
                DataColumn(label: Text('Issued')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final v in page.violations) _row(context, ref, v),
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
        ),
      ],
    );
  }

  DataRow _row(BuildContext context, WidgetRef ref, ViolationSummary v) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final actionable = v.status == 'Issued' || v.status == 'Appealed';

    return DataRow(cells: [
      DataCell(Text(v.policyRuleTitle, style: text.titleSmall)),
      DataCell(StatusPill.of(
        v.status,
        intent: StatusIntents.violation(v.status),
        dense: true,
      )),
      DataCell(AppNumericCell(_money.format(v.penaltyAmount))),
      DataCell(v.suspensionType == 'None'
          ? Text('—', style: text.bodyMedium?.copyWith(color: t.text.tertiary))
          : StatusPill.of(
              v.suspensionType,
              intent: v.suspensionType == 'Permanent'
                  ? StatusIntent.danger
                  : StatusIntent.warning,
              dense: true,
              showDot: false,
            )),
      DataCell(Text(
        DateFormat('MMM d, yyyy').format(v.createdAt.toLocal()),
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      )),
      DataCell(
        !actionable
            ? const SizedBox.shrink()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Editable only while Issued — once appealed, this record
                  // is what both sides are arguing about.
                  if (v.status == 'Issued') ...[
                    AppRowAction(
                      label: 'Edit',
                      onPressed: () => _showEdit(context, ref, v),
                    ),
                    const SizedBox(width: AppSpacing.controlGap),
                  ],
                  AppRowAction(
                    label: 'Dismiss',
                    intent: StatusIntent.danger,
                    onPressed: () => _dismiss(context, ref, v),
                  ),
                ],
              ),
      ),
    ]);
  }

  Future<void> _dismiss(
      BuildContext context, WidgetRef ref, ViolationSummary v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss Violation'),
        content: SizedBox(
          width: 420,
          child: Text(
              'Dismiss the "${v.policyRuleTitle}" violation? Any penalty and '
              'suspension it carries are lifted.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ctx.tokens.status.danger.solid),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final msg = await ref
        .read(violationActionsProvider.notifier)
        .dismiss(v.violationId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Violation dismissed.')));
    ref.invalidate(violationListProvider);
  }

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
            width: context.dialogWidth(420),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.policyRuleTitle,
                        style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Description is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: penaltyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Penalty amount',
                        prefixText: '₱',
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return (n == null || n < 0)
                            ? 'Enter a valid amount'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _violationSuspensions.contains(suspensionType)
                              ? suspensionType
                              : 'None',
                      decoration:
                          const InputDecoration(labelText: 'Suspension'),
                      items: _violationSuspensions
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => suspensionType = val ?? 'None'),
                    ),
                    if (suspensionType == 'Temporary') ...[
                      const SizedBox(height: AppSpacing.x3),
                      TextFormField(
                        controller: daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Suspension days'),
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
