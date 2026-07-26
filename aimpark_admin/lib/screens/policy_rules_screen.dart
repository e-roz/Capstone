import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/violation.dart';
import '../providers/violations_provider.dart';

class PolicyRulesScreen extends ConsumerWidget {
  const PolicyRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(policyRulesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Policy & Rule Management',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Rule'),
                  onPressed: () => _showRuleDialog(context, ref, null),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(policyRulesProvider),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load rules: $e')),
                data: (rules) => rules.isEmpty
                    ? const Center(child: Text('No policy rules yet.'))
                    : ListView.separated(
                        itemCount: rules.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _RuleCard(rule: rules[i], onEdit: () => _showRuleDialog(context, ref, rules[i])),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRuleDialog(BuildContext context, WidgetRef ref, PolicyRule? existing) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final penaltyCtrl =
        TextEditingController(text: existing?.defaultPenaltyAmount.toString() ?? '0');
    final daysCtrl =
        TextEditingController(text: existing?.defaultSuspensionDays?.toString() ?? '');
    String suspensionType = existing?.defaultSuspensionType ?? 'None';
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Policy Rule' : 'Edit Policy Rule'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Title', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Description', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: penaltyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Default Penalty Amount',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Enter a number' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: suspensionType,
                      decoration: const InputDecoration(
                          labelText: 'Default Suspension Type',
                          border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'None', child: Text('None')),
                        DropdownMenuItem(value: 'Temporary', child: Text('Temporary')),
                        DropdownMenuItem(value: 'Permanent', child: Text('Permanent')),
                      ],
                      onChanged: (v) => setState(() => suspensionType = v!),
                    ),
                    if (suspensionType == 'Temporary') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Default Suspension Days',
                            border: OutlineInputBorder()),
                        validator: (v) => suspensionType == 'Temporary' &&
                                (int.tryParse(v ?? '') == null || int.parse(v!) <= 0)
                            ? 'Enter a positive number of days'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
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
    final days = suspensionType == 'Temporary' ? int.tryParse(daysCtrl.text.trim()) : null;

    final msg = existing == null
        ? await notifier.create(
            title: titleCtrl.text.trim(),
            description: descCtrl.text.trim(),
            defaultPenaltyAmount: double.parse(penaltyCtrl.text.trim()),
            defaultSuspensionType: suspensionType,
            defaultSuspensionDays: days,
            isActive: isActive,
          )
        : await notifier.update(
            ruleId: existing.ruleId,
            title: titleCtrl.text.trim(),
            description: descCtrl.text.trim(),
            defaultPenaltyAmount: double.parse(penaltyCtrl.text.trim()),
            defaultSuspensionType: suspensionType,
            defaultSuspensionDays: days,
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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(rule.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (!rule.isActive)
                        const Chip(
                          label: Text('Inactive', style: TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: Colors.grey,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                  if (rule.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(rule.description, style: const TextStyle(fontSize: 13)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Penalty ₱${rule.defaultPenaltyAmount.toStringAsFixed(2)} • '
                      'Suspension: ${rule.defaultSuspensionType}'
                      '${rule.defaultSuspensionDays != null ? ' (${rule.defaultSuspensionDays} days)' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onEdit, child: const Text('Edit')),
          ],
        ),
      ),
    );
  }
}
