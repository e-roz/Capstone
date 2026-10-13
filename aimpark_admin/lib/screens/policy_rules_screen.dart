import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/responsive.dart';
import '../models/violation.dart';
import '../providers/violations_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

/// The two kinds of rule the API accepts. Mirrors `PolicyCategory` on the
/// server: where the car was left, and how the person behaved.
const _categories = <String, ({String label, IconData icon, StatusIntent intent})>{
  'Parking': (
    label: 'Parking',
    icon: Icons.local_parking_outlined,
    intent: StatusIntent.info,
  ),
  'Conduct': (
    label: 'Conduct',
    icon: Icons.gavel_outlined,
    intent: StatusIntent.warning,
  ),
};

/// The smallest fine the payment provider will take. Mirrors the server.
const _minimumFine = 20;

String _categoryLabel(String value) => _categories[value]?.label ?? value;

String _money(double amount) => '₱${amount.toStringAsFixed(2)}';

/// How hard a rule hits the card, so "Harshest first" can order them: a revoke
/// beats any suspension, a longer suspension beats a shorter one, and a legacy
/// rule that does nothing sorts last.
int _harshness(PolicyRule r) => switch (r.defaultSuspensionType) {
      'Permanent' => 1 << 30,
      'Temporary' => r.defaultSuspensionHours ?? 0,
      _ => -1,
    };

enum _Sort {
  harshest('Harshest first'),
  name('Name'),
  mostIssued('Most issued');

  const _Sort(this.label);
  final String label;
}

class PolicyRulesScreen extends ConsumerWidget {
  const PolicyRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Policy Rules',
      subtitle: 'What\'s banned, and what it costs the person.',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.add, size: AppSizes.iconSm),
          label: const Text('Add rule'),
          onPressed: () => _openRuleDialog(context, ref, null),
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
        loading: const _RulesSkeleton(),
        isEmpty: (rules) => rules.isEmpty,
        empty: AppEmptyState(
          icon: Icons.rule_outlined,
          title: 'No policy rules yet',
          message:
              'A violation can only be issued against a rule, so add the first '
              'one before enforcement can begin.',
          action: FilledButton.icon(
            icon: const Icon(Icons.add, size: AppSizes.iconSm),
            label: const Text('Add rule'),
            onPressed: () => _openRuleDialog(context, ref, null),
          ),
        ),
        data: (rules) => _RulesBody(rules: rules),
      ),
    );
  }
}

// ── Actions ──────────────────────────────────────────────────────────────────

Future<void> _openRuleDialog(
    BuildContext context, WidgetRef ref, PolicyRule? existing) async {
  final draft = await showDialog<_RuleDraft>(
    context: context,
    builder: (_) => _RuleDialog(existing: existing),
  );
  if (draft == null || !context.mounted) return;

  final notifier = ref.read(policyRuleActionsProvider.notifier);
  final msg = existing == null
      ? await notifier.create(
          title: draft.title,
          description: draft.description,
          category: draft.category,
          defaultPenaltyAmount: draft.fine,
          defaultSuspensionType: draft.type,
          defaultSuspensionHours: draft.hours,
          appealWindowDays: draft.windowDays,
          isActive: draft.isActive,
        )
      : await notifier.update(
          ruleId: existing.ruleId,
          title: draft.title,
          description: draft.description,
          category: draft.category,
          defaultPenaltyAmount: draft.fine,
          defaultSuspensionType: draft.type,
          defaultSuspensionHours: draft.hours,
          appealWindowDays: draft.windowDays,
          isActive: draft.isActive,
        );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg ?? 'Rule saved.')));
  ref.invalidate(policyRulesProvider);
}

/// Flips a rule on or off from its card. A rule written before every rule had
/// to act on the card can always be switched off, but cannot be switched on
/// until it has an action, so that case opens the editor instead of failing
/// with a message about a field the admin has not seen.
Future<void> _toggleActive(
    BuildContext context, WidgetRef ref, PolicyRule rule, bool value) async {
  if (rule.defaultSuspensionType == 'None' && value) {
    await _openRuleDialog(context, ref, rule);
    return;
  }

  final msg = await ref.read(policyRuleActionsProvider.notifier).update(
        ruleId: rule.ruleId,
        title: rule.title,
        description: rule.description,
        category: rule.category,
        defaultPenaltyAmount: rule.defaultPenaltyAmount,
        defaultSuspensionType: rule.defaultSuspensionType,
        defaultSuspensionHours: rule.defaultSuspensionHours,
        appealWindowDays: rule.appealWindowDays,
        isActive: value,
      );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg == 'Policy rule updated.'
          ? (value ? 'Rule is active.' : 'Rule is inactive.')
          : msg ?? 'Rule saved.')));
  ref.invalidate(policyRulesProvider);
}

// ── List ─────────────────────────────────────────────────────────────────────

class _RulesBody extends ConsumerStatefulWidget {
  const _RulesBody({required this.rules});

  final List<PolicyRule> rules;

  @override
  ConsumerState<_RulesBody> createState() => _RulesBodyState();
}

class _RulesBodyState extends ConsumerState<_RulesBody> {
  String _query = '';
  String? _category;
  _Sort _sort = _Sort.harshest;
  bool _hideInactive = false;

  List<PolicyRule> get _visible {
    final q = _query.toLowerCase();
    final list = widget.rules.where((r) {
      if (_category != null && r.category != _category) return false;
      if (_hideInactive && !r.isActive) return false;
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      // An inactive rule cannot be issued, so however hard it would hit it
      // does not belong above the rules that are actually in force.
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;

      final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return switch (_sort) {
        _Sort.name => byTitle,
        _Sort.mostIssued => b.issuedCount != a.issuedCount
            ? b.issuedCount.compareTo(a.issuedCount)
            : byTitle,
        _Sort.harshest => _harshness(b) != _harshness(a)
            ? _harshness(b).compareTo(_harshness(a))
            : byTitle,
      };
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;
    final active = rules.where((r) => r.isActive).toList();
    final revoking = active.where((r) => r.defaultSuspensionType == 'Permanent');
    final noWindow = active.where((r) => r.appealWindowDays == 0);
    final visible = _visible;

    return ListView(
      children: [
        Wrap(
          spacing: AppSpacing.gutter,
          runSpacing: AppSpacing.gutter,
          children: [
            MetricCard(
              label: 'Active rules',
              value: '${active.length}',
              icon: Icons.rule_outlined,
              intent: StatusIntent.success,
            ),
            MetricCard(
              label: 'Revoke the card',
              value: '${revoking.length}',
              icon: Icons.block_outlined,
              intent: StatusIntent.danger,
            ),
            MetricCard(
              label: 'No appeal window',
              value: '${noWindow.length}',
              icon: Icons.bolt_outlined,
              intent: StatusIntent.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x5),
        AppToolbar(
          search: AppSearchField(
            hint: 'Search rules',
            onChanged: (v) => setState(() => _query = v),
          ),
          filters: [
            AppFilterDropdown<_Sort>(
              label: 'Sort',
              value: _sort,
              allowAll: false,
              options: [
                for (final s in _Sort.values) AppFilterOption(s, s.label),
              ],
              onChanged: (v) => setState(() => _sort = v ?? _sort),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Wrap(
          spacing: AppSpacing.controlGap,
          runSpacing: AppSpacing.controlGap,
          children: [
            _FilterChip(
              label: 'All',
              icon: Icons.list_alt_outlined,
              count: rules.length,
              selected: _category == null,
              onTap: () => setState(() => _category = null),
            ),
            for (final entry in _categories.entries)
              _FilterChip(
                label: entry.value.label,
                icon: entry.value.icon,
                count: rules.where((r) => r.category == entry.key).length,
                selected: _category == entry.key,
                onTap: () => setState(() => _category = entry.key),
              ),
            _FilterChip(
              label: 'Hide inactive',
              icon: Icons.visibility_off_outlined,
              selected: _hideInactive,
              onTap: () => setState(() => _hideInactive = !_hideInactive),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x4),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
            child: AppEmptyState(
              icon: Icons.search_off_outlined,
              title: 'No rules match',
              message: 'Clear the search or pick another category.',
              action: OutlinedButton(
                onPressed: () => setState(() {
                  _category = null;
                  _hideInactive = false;
                }),
                child: const Text('Show all rules'),
              ),
            ),
          )
        else
          for (final rule in visible) ...[
            _RuleCard(rule: rule),
            const SizedBox(height: AppSpacing.gutter),
          ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fg = selected ? t.brand.subtleText : t.text.secondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3, vertical: AppSpacing.x1 + 2),
          decoration: BoxDecoration(
            color: selected ? t.brand.subtle : t.surface.card,
            borderRadius: AppRadii.fullAll,
            border: Border.all(
              color: selected ? t.brand.primary : t.border.normal,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.iconSm, color: fg),
                const SizedBox(width: AppSpacing.x1 + 2),
              ],
              Text(label,
                  style: text.labelMedium
                      ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
              if (count != null) ...[
                const SizedBox(width: AppSpacing.x1 + 2),
                Text('$count',
                    style: text.labelSmall?.copyWith(color: fg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule});

  final PolicyRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final cat = _categories[rule.category];

    final hours = rule.defaultSuspensionHours;
    final (cardIcon, cardValue, cardIntent) = switch (rule.defaultSuspensionType) {
      'Permanent' => (Icons.block_outlined, 'Revoked', StatusIntent.danger),
      'Temporary' => (
          Icons.pause_circle_outline,
          hours == null ? 'Suspended' : 'Suspended ${formatHours(hours)}',
          StatusIntent.info,
        ),
      // Written before every rule had to act on the card. It still works for
      // violations already issued, but cannot be saved again as it is.
      _ => (Icons.help_outline, 'Choose an action', StatusIntent.warning),
    };

    final noAppeal = rule.appealWindowDays == 0;

    return Opacity(
      opacity: rule.isActive ? 1 : 0.65,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Expanded, not Flexible beside a Spacer: the two would split
                // the free space and leave the switch floating mid-card at a
                // different spot on every row.
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.x2,
                    runSpacing: AppSpacing.x1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(rule.title, style: text.titleSmall),
                      StatusPill.of(
                        _categoryLabel(rule.category),
                        intent: cat?.intent ?? StatusIntent.neutral,
                        dense: true,
                        showDot: false,
                        icon: cat?.icon ?? Icons.folder_outlined,
                      ),
                      if (!rule.isActive)
                        const StatusPill.of('Inactive',
                            intent: StatusIntent.neutral, dense: true),
                    ],
                  ),
                ),
                Tooltip(
                  message: rule.isActive ? 'Active' : 'Inactive',
                  child: Switch(
                    value: rule.isActive,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => _toggleActive(context, ref, rule, v),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                AppRowAction(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: () => _openRuleDialog(context, ref, rule),
                ),
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
                if (rule.defaultPenaltyAmount > 0)
                  _ConsequenceCell(
                    icon: Icons.receipt_long_outlined,
                    label: 'Fine',
                    value: _money(rule.defaultPenaltyAmount),
                    intent: StatusIntent.warning,
                  )
                else
                  const _ConsequenceCell(
                    icon: Icons.money_off_outlined,
                    label: 'Fine',
                    value: 'No fine',
                    intent: StatusIntent.neutral,
                  ),
                _ConsequenceCell(
                  icon: cardIcon,
                  label: 'RFID card',
                  value: cardValue,
                  intent: cardIntent,
                ),
                _ConsequenceCell(
                  icon: noAppeal
                      ? Icons.bolt_outlined
                      : Icons.hourglass_empty_outlined,
                  label: 'Appeal window',
                  value: noAppeal
                      ? 'None, acts at once'
                      : '${rule.appealWindowDays} ${rule.appealWindowDays == 1 ? 'day' : 'days'}',
                  intent: noAppeal ? StatusIntent.danger : StatusIntent.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            Row(
              children: [
                Icon(Icons.history, size: 14, color: t.text.tertiary),
                const SizedBox(width: AppSpacing.x1 + 2),
                Text(
                  rule.issuedCount == 0
                      ? 'Never issued'
                      : 'Issued ${rule.issuedCount} ${rule.issuedCount == 1 ? 'time' : 'times'}',
                  style: text.labelSmall?.copyWith(color: t.text.tertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One consequence of breaking a rule — fine, card action or appeal window —
/// tinted by what kind of consequence it is.
class _ConsequenceCell extends StatelessWidget {
  const _ConsequenceCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.intent,
  });

  final IconData icon;
  final String label;
  final String value;
  final StatusIntent intent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);
    final text = Theme.of(context).textTheme;
    final neutral = intent == StatusIntent.neutral;
    final fg = neutral ? t.text.secondary : c.fg;

    // One fixed width so the three cells line up in columns down the list,
    // instead of each being as wide as its own text.
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        color: neutral ? t.surface.muted : c.bg,
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: AppSizes.iconMd, color: fg),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelSmall?.copyWith(color: fg)),
                Text(value, style: text.titleSmall?.copyWith(color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stands in for the loaded screen: the metric row, then a few rule cards with
/// the same three-cell rhythm.
class _RulesSkeleton extends StatelessWidget {
  const _RulesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SkeletonMetricRow(count: 3),
        const SizedBox(height: AppSpacing.x5),
        for (var i = 0; i < 3; i++) ...[
          AppCard(
            child: AppShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonBone(width: 160 - (i % 2) * 30, height: 14),
                      const SizedBox(width: AppSpacing.x3),
                      const SkeletonBone(width: 70, height: 18),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  const SkeletonBone(width: 260, height: 10),
                  const SizedBox(height: AppSpacing.x3),
                  const Row(
                    children: [
                      SkeletonBone(width: 170, height: 40),
                      SizedBox(width: AppSpacing.controlGap),
                      SkeletonBone(width: 170, height: 40),
                      SizedBox(width: AppSpacing.controlGap),
                      SkeletonBone(width: 170, height: 40),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
        ],
      ],
    );
  }
}

// ── Add / edit dialog ────────────────────────────────────────────────────────

/// What the dialog hands back when the admin saves.
class _RuleDraft {
  const _RuleDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.fine,
    required this.type,
    required this.hours,
    required this.windowDays,
    required this.isActive,
  });

  final String title;
  final String description;
  final String category;
  final double fine;

  /// `Temporary` or `Permanent`; `None` only for an inactive legacy rule.
  final String type;
  final int? hours;
  final int windowDays;
  final bool isActive;
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({required this.existing});

  final PolicyRule? existing;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  static const _presets = <(int, String)>[
    (6, '6 h'),
    (24, '24 h'),
    (48, '48 h'),
    (168, '7 days'),
    (720, '30 days'),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _fine;
  late final TextEditingController _hours;
  late final TextEditingController _window;

  late String _category;
  late bool _isActive;

  /// `Temporary`, `Permanent`, or null on a legacy rule that has to be given
  /// an action before it can be saved.
  String? _action;
  bool _actionMissing = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _title = TextEditingController(text: r?.title ?? '');
    _description = TextEditingController(text: r?.description ?? '');
    _fine = TextEditingController(text: _fineText(r?.defaultPenaltyAmount ?? 0));
    _hours = TextEditingController(text: (r?.defaultSuspensionHours ?? 24).toString());
    _window = TextEditingController(text: (r?.appealWindowDays ?? 3).toString());
    _category = _categories.containsKey(r?.category) ? r!.category : 'Parking';
    _isActive = r?.isActive ?? true;
    _action = switch (r?.defaultSuspensionType) {
      'Temporary' || 'Permanent' => r!.defaultSuspensionType,
      null => 'Temporary',
      _ => null,
    };

    for (final c in [_fine, _hours, _window]) {
      c.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _fine, _hours, _window]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fineText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _refresh() => setState(() {});

  void _setAction(String action) {
    setState(() {
      _action = action;
      _actionMissing = false;
      // A revoked card has no end date, and paying a fine never gives it back,
      // so there is nothing for a fine to buy.
      if (action == 'Permanent') _fine.text = '0';
    });
  }

  int get _hoursValue => int.tryParse(_hours.text.trim()) ?? 0;
  int get _windowValue => int.tryParse(_window.text.trim()) ?? 0;
  double get _fineValue => double.tryParse(_fine.text.trim()) ?? 0;

  void _save() {
    final valid = _formKey.currentState!.validate();
    // An inactive rule is never issued, so it may stay without an action. It
    // only has to choose one to be switched on.
    if (_action == null && _isActive) {
      setState(() => _actionMissing = true);
      return;
    }
    if (!valid) return;

    Navigator.pop(
      context,
      _RuleDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        fine: _action == 'Permanent' ? 0 : _fineValue,
        type: _action ?? 'None',
        hours: _action == 'Temporary' ? _hoursValue : null,
        windowDays: _windowValue,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final revoke = _action == 'Permanent';
    final cardIntent = revoke ? StatusIntent.danger : StatusIntent.info;
    final isNew = widget.existing == null;

    return AlertDialog(
      title: Row(
        children: [
          _IconBox(icon: Icons.gavel_outlined, intent: StatusIntent.accent),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isNew ? 'Add policy rule' : 'Edit policy rule'),
                Text(
                  'What\'s banned, and what it costs the person',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: context.dialogWidth(520),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppRequiredNote(),
                _Section(
                  icon: Icons.description_outlined,
                  intent: StatusIntent.neutral,
                  title: 'The rule',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(
                            label: AppFieldLabel('Title', isRequired: true)),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      TextFormField(
                        controller: _description,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            label: AppFieldLabel('Description')),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      Text('Category',
                          style: text.labelMedium
                              ?.copyWith(color: t.text.secondary)),
                      const SizedBox(height: AppSpacing.x1),
                      Wrap(
                        spacing: AppSpacing.controlGap,
                        children: [
                          for (final entry in _categories.entries)
                            _ChoiceChip(
                              label: entry.value.label,
                              icon: entry.value.icon,
                              intent: entry.value.intent,
                              selected: _category == entry.key,
                              onTap: () =>
                                  setState(() => _category = entry.key),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.x1),
                        child: Text(
                          'Only for reports and filters. It doesn\'t change the penalty.',
                          style: text.bodySmall
                              ?.copyWith(color: t.text.tertiary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                _Section(
                  icon: Icons.receipt_long_outlined,
                  intent: StatusIntent.warning,
                  title: 'Fine',
                  subtitle: 'Billed once the violation is final',
                  child: TextFormField(
                    controller: _fine,
                    enabled: !revoke,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      label:
                          const AppFieldLabel('Fine amount', isRequired: true),
                      prefixText: '₱ ',
                      helperText:
                          revoke ? 'No fine when the card is revoked.' : null,
                    ),
                    validator: (v) {
                      if (revoke) return null;
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0) return 'Enter 0 or more';
                      if (n > 0 && n < _minimumFine) {
                        return 'At least ₱$_minimumFine, or 0 for no fine';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                _Section(
                  icon: Icons.badge_outlined,
                  intent: cardIntent,
                  title: 'RFID card',
                  subtitle: 'Every violation does something to the card',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ActionChoice(
                              icon: Icons.pause_circle_outline,
                              title: 'Suspend card',
                              caption: 'For a set number of hours',
                              intent: StatusIntent.info,
                              selected: _action == 'Temporary',
                              onTap: () => _setAction('Temporary'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.controlGap),
                          Expanded(
                            child: _ActionChoice(
                              icon: Icons.block_outlined,
                              title: 'Revoke card',
                              caption: 'Taken away, no end date',
                              intent: StatusIntent.danger,
                              selected: _action == 'Permanent',
                              onTap: () => _setAction('Permanent'),
                            ),
                          ),
                        ],
                      ),
                      if (_actionMissing)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.x2),
                          child: Text(
                            'Choose what happens to the card.',
                            style: text.bodySmall?.copyWith(
                                color: t.status.danger.fg),
                          ),
                        ),
                      if (_action == 'Temporary') ...[
                        const SizedBox(height: AppSpacing.x4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 210,
                              child: TextFormField(
                                controller: _hours,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  label: AppFieldLabel('Suspended for (hours)',
                                      isRequired: true),
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v?.trim() ?? '');
                                  if (n == null || n < 1) {
                                    return 'At least 1 hour';
                                  }
                                  if (n > 8760) return 'One year at most';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x3),
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                _hoursValue >= 24
                                    ? '= ${formatHours(_hoursValue)}'
                                    : _hoursValue >= 1
                                        ? 'less than a day'
                                        : '',
                                style: text.titleSmall?.copyWith(
                                    color: t.status.info.fg),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        Wrap(
                          spacing: AppSpacing.controlGap,
                          runSpacing: AppSpacing.controlGap,
                          children: [
                            for (final (hours, label) in _presets)
                              _ChoiceChip(
                                label: label,
                                intent: StatusIntent.info,
                                selected: _hoursValue == hours,
                                onTap: () => _hours.text = '$hours',
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                _Section(
                  icon: Icons.hourglass_empty_outlined,
                  intent: StatusIntent.success,
                  title: 'Appeal window',
                  subtitle: 'The card keeps working while they can appeal',
                  child: TextFormField(
                    controller: _window,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      label: AppFieldLabel('Appeal window (days)',
                          isRequired: true),
                      helperText: '0 means it acts at once.',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0) return 'Enter 0 or more days';
                      if (n > 30) return '30 days at most';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                _Timeline(
                  action: _action,
                  hours: _hoursValue,
                  windowDays: _windowValue,
                  fine: _fineValue,
                ),
                const SizedBox(height: AppSpacing.x2),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text(
                      'Inactive rules can\'t be picked when issuing a violation.'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
          icon: const Icon(Icons.check, size: AppSizes.iconSm),
          label: const Text('Save rule'),
          onPressed: _save,
        ),
      ],
    );
  }
}

/// A tinted block with an icon, a title and a line of context. The colour says
/// what kind of consequence is being set inside it.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.intent,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final StatusIntent intent;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);
    final text = Theme.of(context).textTheme;
    final neutral = intent == StatusIntent.neutral;

    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: neutral ? t.surface.muted : c.bg,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: neutral ? t.border.subtle : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBox(icon: icon, intent: intent),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.titleSmall?.copyWith(
                            color: neutral ? t.text.primary : c.fg)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: text.bodySmall?.copyWith(
                              color: neutral ? t.text.secondary : c.fg)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          child,
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.intent});

  final IconData icon;
  final StatusIntent intent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);
    final neutral = intent == StatusIntent.neutral;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: neutral ? t.surface.card : c.bg,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: neutral ? t.border.normal : c.border),
      ),
      child: Icon(icon,
          size: AppSizes.iconMd, color: neutral ? t.text.secondary : c.fg),
    );
  }
}

/// A selectable pill tinted by [intent] when picked.
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.intent,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final StatusIntent intent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);
    final text = Theme.of(context).textTheme;
    final fg = selected ? c.fg : t.text.secondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3, vertical: AppSpacing.x1 + 2),
          decoration: BoxDecoration(
            color: selected ? c.bg : t.surface.card,
            borderRadius: AppRadii.fullAll,
            border: Border.all(
                color: selected ? c.solid : t.border.normal,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.iconSm, color: fg),
                const SizedBox(width: AppSpacing.x1 + 2),
              ],
              Text(label,
                  style: text.labelMedium
                      ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two things a rule can do to the card.
class _ActionChoice extends StatelessWidget {
  const _ActionChoice({
    required this.icon,
    required this.title,
    required this.caption,
    required this.intent,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final StatusIntent intent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);
    final text = Theme.of(context).textTheme;
    final fg = selected ? c.fg : t.text.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: BoxDecoration(
            color: t.surface.card,
            borderRadius: AppRadii.mdAll,
            border: Border.all(
                color: selected ? c.solid : t.border.normal,
                width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 22, color: selected ? c.solid : t.text.secondary),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.titleSmall?.copyWith(color: fg)),
                    Text(caption,
                        style: text.bodySmall
                            ?.copyWith(color: t.text.secondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "When someone breaks this rule": the steps the person goes through, redrawn
/// as the admin types so the numbers never have to be worked out in their head.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.action,
    required this.hours,
    required this.windowDays,
    required this.fine,
  });

  final String? action;
  final int hours;
  final int windowDays;
  final double fine;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final revoke = action == 'Permanent';
    final steps = <(Color, String, String)>[];

    steps.add((
      t.status.success.solid,
      'Day 0',
      windowDays > 0
          ? ' — violation issued. The card still works while they can appeal.'
          : ' — violation issued. No appeal window, so it acts at once.',
    ));

    if (action != null) {
      final what = revoke
          ? 'the card is revoked.'
          : 'the card is suspended for ${formatHours(hours < 1 ? 1 : hours)}.';
      steps.add((
        revoke ? t.status.danger.solid : t.status.info.solid,
        windowDays > 0 ? 'Day $windowDays, if they don\'t appeal' : 'Right away',
        ' — $what',
      ));
      if (!revoke && fine > 0) {
        steps.add((
          t.status.warning.solid,
          'Fine',
          ' — ${_money(fine)} is billed. Paying it doesn\'t shorten the suspension.',
        ));
      }
      steps.add((
        t.text.tertiary,
        'After that',
        revoke
            ? ' — only an admin can give the card back.'
            : fine > 0
                ? ' — back in once the suspension ends and the fine is paid.'
                : ' — back in once the suspension ends.',
      ));
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: t.surface.card,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: t.border.strong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_outlined,
                  size: AppSizes.iconMd, color: t.brand.primary),
              const SizedBox(width: AppSpacing.x2),
              Text('When someone breaks this rule', style: text.titleSmall),
            ],
          ),
          for (final (color, bold, rest) in steps)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: bold,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: rest),
                      ]),
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (action == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x2),
              child: Text(
                'Choose what happens to the card to see the steps.',
                style: text.bodySmall?.copyWith(color: t.text.secondary),
              ),
            ),
        ],
      ),
    );
  }
}
