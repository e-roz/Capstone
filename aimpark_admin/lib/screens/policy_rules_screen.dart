import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/responsive.dart';
import '../models/violation.dart';
import '../providers/violations_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

/// The categories the API accepts, with the wording an administrator reads.
/// Mirrors `PolicyCategory` on the server.
const _categories = <String, String>{
  'Parking': 'Parking',
  'Access': 'Access & RFID',
  'Conduct': 'Conduct',
  'Documentation': 'Documentation',
  'Other': 'Other',
};

String _categoryLabel(String value) => _categories[value] ?? value;

/// Categories are kinds, not severities, so the colours separate them rather
/// than ranking them.
StatusIntent _categoryIntent(String value) => switch (value) {
      'Parking' => StatusIntent.info,
      'Access' => StatusIntent.accent,
      'Conduct' => StatusIntent.warning,
      'Documentation' => StatusIntent.success,
      _ => StatusIntent.neutral,
    };

class PolicyRulesScreen extends ConsumerWidget {
  const PolicyRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Policy & Rule Management',
      subtitle:
          'The regulations violations are issued against, and what each one costs.',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.add, size: AppSizes.iconSm),
          label: const Text('Add Rule'),
          onPressed: () => _showRuleDialog(context, ref, null),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(policyRulesProvider),
        ),
      ],
      body: AsyncView(
        value: ref.watch(policyRulesProvider),
        onRetry: () => ref.invalidate(policyRulesProvider),
        loading: const SkeletonList(),
        isEmpty: (rules) => rules.isEmpty,
        empty: AppEmptyState(
          icon: Icons.rule_outlined,
          title: 'No policy rules yet',
          message:
              'A violation can only be issued against a rule, so add the first '
              'one before enforcement can begin.',
          action: FilledButton.icon(
            icon: const Icon(Icons.add, size: AppSizes.iconSm),
            label: const Text('Add Rule'),
            onPressed: () => _showRuleDialog(context, ref, null),
          ),
        ),
        data: (rules) => ListView.separated(
          itemCount: rules.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.gutter),
          itemBuilder: (context, i) => _RuleCard(
            rule: rules[i],
            onEdit: () => _showRuleDialog(context, ref, rules[i]),
          ),
        ),
      ),
    );
  }

  Future<void> _showRuleDialog(
      BuildContext context, WidgetRef ref, PolicyRule? existing) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final penaltyCtrl = TextEditingController(
        text: existing?.defaultPenaltyAmount.toString() ?? '0');
    final daysCtrl = TextEditingController(
        text: existing?.defaultSuspensionDays?.toString() ?? '');
    final windowCtrl = TextEditingController(
        text: (existing?.appealWindowDays ?? 3).toString());
    String suspensionType = existing?.defaultSuspensionType ?? 'None';
    String category = existing?.category ?? 'Parking';
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Policy Rule' : 'Edit Policy Rule'),
          content: SizedBox(
            width: context.dialogWidth(420),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppRequiredNote(),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                          label: AppFieldLabel('Title', isRequired: true)),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          label: AppFieldLabel('Description')),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        helperText: 'Groups the rule in reports and filters.',
                      ),
                      items: [
                        for (final entry in _categories.entries)
                          DropdownMenuItem(
                              value: entry.key, child: Text(entry.value)),
                      ],
                      onChanged: (v) => setState(() => category = v!),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: penaltyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          label: AppFieldLabel('Default Penalty Amount',
                              isRequired: true)),
                      validator: (v) => double.tryParse(v ?? '') == null
                          ? 'Enter a number'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    DropdownButtonFormField<String>(
                      initialValue: suspensionType,
                      decoration: const InputDecoration(
                          labelText: 'Default Suspension Type'),
                      items: const [
                        DropdownMenuItem(value: 'None', child: Text('None')),
                        DropdownMenuItem(
                            value: 'Temporary', child: Text('Temporary')),
                        DropdownMenuItem(
                            value: 'Permanent', child: Text('Permanent')),
                      ],
                      onChanged: (v) => setState(() => suspensionType = v!),
                    ),
                    if (suspensionType == 'Temporary') ...[
                      const SizedBox(height: AppSpacing.x3),
                      TextFormField(
                        controller: daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Default Suspension Days'),
                        validator: (v) => suspensionType == 'Temporary' &&
                                (int.tryParse(v ?? '') == null ||
                                    int.parse(v!) <= 0)
                            ? 'Enter a positive number of days'
                            : null,
                      ),
                    ],
                    // Only where there is a suspension to hold off. On a
                    // fee-only rule the field would be asking about something
                    // that never happens.
                    if (suspensionType != 'None') ...[
                      const SizedBox(height: AppSpacing.x3),
                      TextFormField(
                        controller: windowCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Appeal window (days)',
                          helperText:
                              'The card keeps working this long so the user can '
                              'appeal first. Enter 0 to suspend immediately — '
                              'for rules where waiting is the unfair option.',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 0) return 'Enter 0 or more days';
                          if (n > 30) return '30 days at most';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x3),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      subtitle: const Text(
                          'Inactive rules cannot be picked when issuing a violation.'),
                      value: isActive,
                      onChanged: (v) => setState(() => isActive = v),
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
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(policyRuleActionsProvider.notifier);
    final days =
        suspensionType == 'Temporary' ? int.tryParse(daysCtrl.text.trim()) : null;
    final window = suspensionType == 'None'
        ? 3
        : int.tryParse(windowCtrl.text.trim()) ?? 3;

    final msg = existing == null
        ? await notifier.create(
            title: titleCtrl.text.trim(),
            description: descCtrl.text.trim(),
            category: category,
            defaultPenaltyAmount: double.parse(penaltyCtrl.text.trim()),
            defaultSuspensionType: suspensionType,
            defaultSuspensionDays: days,
            appealWindowDays: window,
            isActive: isActive,
          )
        : await notifier.update(
            ruleId: existing.ruleId,
            title: titleCtrl.text.trim(),
            description: descCtrl.text.trim(),
            category: category,
            defaultPenaltyAmount: double.parse(penaltyCtrl.text.trim()),
            defaultSuspensionType: suspensionType,
            defaultSuspensionDays: days,
            appealWindowDays: window,
            isActive: isActive,
          );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Rule saved.')));
    ref.invalidate(policyRulesProvider);
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.onEdit});

  final PolicyRule rule;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    // A rule's penalty and its suspension are two separate consequences, so
    // they read as two pills rather than one run-on sentence the eye has to
    // parse for the number it came looking for.
    final suspension = switch (rule.defaultSuspensionType) {
      'Temporary' when rule.defaultSuspensionDays != null =>
        'Suspends ${rule.defaultSuspensionDays} days',
      'Temporary' => 'Suspends temporarily',
      'Permanent' => 'Suspends permanently',
      _ => null,
    };

    // Worth its own pill, and a red one. A rule that suspends on the spot is
    // the harshest thing an admin can write here, and it should not be
    // discoverable only by opening the edit dialog.
    final immediate =
        suspension != null && rule.appealWindowDays == 0 ? 'Immediate' : null;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(rule.title, style: text.titleSmall)),
                    if (!rule.isActive) ...[
                      const SizedBox(width: AppSpacing.x2),
                      const StatusPill.of('Inactive',
                          intent: StatusIntent.neutral, dense: true),
                    ],
                  ],
                ),
                if (rule.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.labelGap),
                    child: Text(
                      rule.description,
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ),
                const SizedBox(height: AppSpacing.x3),
                Wrap(
                  spacing: AppSpacing.controlGap,
                  runSpacing: AppSpacing.controlGap,
                  children: [
                    StatusPill.of(
                      _categoryLabel(rule.category),
                      intent: _categoryIntent(rule.category),
                      dense: true,
                      showDot: false,
                      icon: Icons.folder_outlined,
                    ),
                    StatusPill.of(
                      '₱${rule.defaultPenaltyAmount.toStringAsFixed(2)} penalty',
                      intent: rule.defaultPenaltyAmount > 0
                          ? StatusIntent.warning
                          : StatusIntent.neutral,
                      dense: true,
                      showDot: false,
                      icon: Icons.payments_outlined,
                    ),
                    if (suspension != null)
                      StatusPill.of(
                        suspension,
                        intent: rule.defaultSuspensionType == 'Permanent'
                            ? StatusIntent.danger
                            : StatusIntent.info,
                        dense: true,
                        showDot: false,
                        icon: Icons.block_outlined,
                      ),
                    if (immediate != null)
                      StatusPill.of(
                        immediate,
                        intent: StatusIntent.danger,
                        dense: true,
                        showDot: false,
                        icon: Icons.bolt_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          AppRowAction(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}
