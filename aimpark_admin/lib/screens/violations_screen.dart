import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/violation.dart';
import '../providers/violations_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';
import '../widgets/user_picker.dart';
import '../widgets/violation_detail_dialog.dart';

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

class ViolationsScreen extends ConsumerWidget {
  const ViolationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Violations',
      subtitle: 'Offences on record, who they belong to, and where each case '
          'stands. Open one to decide it.',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.add, size: AppSizes.iconSm),
          label: const Text('Issue Violation'),
          onPressed: () => _showIssueViolation(context, ref),
        ),
      ],
      // Appeals are also queued on Incidents & Appeals, but every decision —
      // here or there — is made in the same View dialog.
      body: const _ViolationsTab(),
    );
  }

  Future<void> _showIssueViolation(BuildContext context, WidgetRef ref) async {
    final descriptionCtrl = TextEditingController();
    PickedUser? picked;
    String? userError;
    String? ruleId;
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
        builder: (ctx, setState) {
          final rule = activeRules.where((r) => r.ruleId == ruleId).firstOrNull;
          return AlertDialog(
            title: const Text('Issue Violation'),
            content: SizedBox(
              width: context.dialogWidth(440),
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppRequiredNote(),
                      UserPickerField(
                        selected: picked,
                        isRequired: true,
                        errorText: userError,
                        onChanged: (u) => setState(() {
                          picked = u;
                          userError = null;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      DropdownButtonFormField<String>(
                        initialValue: ruleId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            label:
                                AppFieldLabel('Policy Rule', isRequired: true)),
                        items: activeRules
                            .map((r) => DropdownMenuItem(
                                value: r.ruleId, child: Text(r.title)))
                            .toList(),
                        onChanged: (v) => setState(() => ruleId = v),
                        validator: (v) => v == null ? 'Select a rule' : null,
                      ),
                      if (rule != null) ...[
                        const SizedBox(height: AppSpacing.x3),
                        _RuleSummary(rule: rule),
                      ],
                      const SizedBox(height: AppSpacing.x3),
                      TextFormField(
                        controller: descriptionCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            label: AppFieldLabel('What happened',
                                isRequired: true)),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Description is required'
                            : null,
                      ),
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
          );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final msg = await ref.read(violationActionsProvider.notifier).issue(
          userId: picked!.userId,
          policyRuleId: ruleId!,
          description: descriptionCtrl.text.trim(),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Violation issued.')));
    ref.invalidate(violationListProvider);
  }
}

/// What the picked rule will do — read-only, because the rule is absolute.
/// Shown so the admin knows the consequence before pressing Issue, not so
/// they can change it.
class _RuleSummary extends StatelessWidget {
  const _RuleSummary({required this.rule});

  final PolicyRule rule;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final suspension = switch (rule.defaultSuspensionType) {
      'Temporary' => '${rule.defaultSuspensionDays} day suspension',
      'Permanent' => 'Permanent suspension',
      _ => 'No suspension',
    };
    final starts = rule.defaultSuspensionType == 'None'
        ? ''
        : rule.appealWindowDays == 0
            ? ', starting immediately'
            : ', starting after ${rule.appealWindowDays} day(s)';

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
          Text('Set by the rule', style: text.labelMedium),
          const SizedBox(height: AppSpacing.labelGap),
          Text(
            '${_money.format(rule.defaultPenaltyAmount)} fine if accountable · '
            '$suspension$starts',
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
    final rules = ref.watch(policyRulesProvider).value ?? const <PolicyRule>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppToolbar(
          search: AppSearchField(
            // Picking a user clears the search; rebuilding the box is how
            // its text clears too.
            key: ValueKey(query.userId),
            hint: 'Name, student no. or RFID',
            initialValue: query.search,
            onChanged: notifier.setSearch,
          ),
          filters: [
            AppFilterDropdown<String>(
              label: 'Status',
              value: query.status,
              options: [
                for (final s in ViolationStatuses.all)
                  AppFilterOption(s, ViolationStatuses.label(s)),
              ],
              allLabel: 'All statuses',
              onChanged: notifier.setStatus,
            ),
            AppFilterDropdown<String>(
              label: 'Rule',
              value: query.ruleId,
              options: [
                for (final r in rules) AppFilterOption(r.ruleId, r.title),
              ],
              allLabel: 'All rules',
              onChanged: notifier.setRule,
            ),
            if (query.userId != null)
              InputChip(
                avatar: const Icon(Icons.person_outline, size: AppSizes.iconSm),
                label: Text('History: ${query.userName ?? 'user'}'),
                onDeleted: notifier.clearUser,
                deleteButtonTooltipMessage: 'Show all users',
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
            loading: const SkeletonTable(
              columns: 9,
              columnWidths: [160, 110, 150, 110, 90, 120, 100, 100, 70],
            ),
            isEmpty: (page) => page.violations.isEmpty,
            empty: AppEmptyState(
              icon: Icons.gavel_outlined,
              title: _isFiltered(query)
                  ? 'No matching violations'
                  : 'No violations issued',
              message: _isFiltered(query)
                  ? 'Clear the filters to see every violation on record.'
                  : 'Offences you record against a policy rule appear here.',
            ),
            data: (page) => AppDataTable(
              minWidth: 1180,
              columns: const [
                DataColumn(label: Text('User')),
                DataColumn(label: Text('RFID')),
                DataColumn(label: Text('Rule')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Penalty'), numeric: true),
                DataColumn(label: Text('Suspension')),
                DataColumn(label: Text('Issued')),
                DataColumn(label: Text('Appeal until')),
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

  static bool _isFiltered(ViolationsQuery q) =>
      q.status != null ||
      q.ruleId != null ||
      q.userId != null ||
      (q.search?.isNotEmpty ?? false);

  DataRow _row(BuildContext context, WidgetRef ref, ViolationSummary v) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: t.text.secondary);
    final dash = Text('—', style: text.bodyMedium?.copyWith(color: t.text.tertiary));

    return DataRow(cells: [
      // Clicking the name shows the user's whole history.
      DataCell(
        Tooltip(
          message: 'Show all of ${v.userFullName}\'s violations',
          child: InkWell(
            onTap: () => ref
                .read(violationsQueryNotifierProvider.notifier)
                .showUser(v.userId, v.userFullName),
            child: AppPrimaryCell(
              title: v.userFullName,
              subtitle: v.studentNumber,
            ),
          ),
        ),
      ),
      DataCell(v.rfidTagId == null
          ? dash
          : Text(v.rfidTagId!, style: text.bodyMedium)),
      DataCell(Text(v.policyRuleTitle, style: text.titleSmall)),
      DataCell(ViolationStatusPill(status: v.status)),
      DataCell(AppNumericCell(_money.format(v.penaltyAmount))),
      DataCell(v.suspensionType == 'None'
          ? dash
          : StatusPill.of(
              // A bare "Temporary" left the reviewer to open the violation to
              // find out whether it meant three days or thirty.
              v.suspensionType == 'Temporary' && v.suspensionDays != null
                  ? '${v.suspensionType} · ${v.suspensionDays} '
                      '${v.suspensionDays == 1 ? 'day' : 'days'}'
                  : v.suspensionType,
              intent: v.suspensionType == 'Permanent'
                  ? StatusIntent.danger
                  : StatusIntent.warning,
              dense: true,
              showDot: false,
            )),
      DataCell(Text(
        DateFormat('MMM d, yyyy').format(v.createdAt.toLocal()),
        style: muted,
      )),
      // Only meaningful while the user can still appeal.
      DataCell(v.status == ViolationStatuses.issued && v.appealDeadline != null
          ? Text(
              DateFormat('MMM d, h:mm a').format(v.appealDeadline!.toLocal()),
              style: muted,
            )
          : dash),
      DataCell(AppRowAction(
        label: 'View',
        icon: Icons.visibility_outlined,
        onPressed: () => showViolationDetail(context, v.violationId),
      )),
    ]);
  }
}
