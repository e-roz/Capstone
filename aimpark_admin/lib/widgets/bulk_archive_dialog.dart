import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/ph_time.dart';
import '../core/utils/responsive.dart';
import '../models/bulk_archive.dart';
import '../theme/theme.dart';

final _day = DateFormat('MMM d, yyyy');

/// The end-of-semester sweep. Pick who, look at exactly who would go and who
/// is left alone, then confirm with the administrator's password.
///
/// Returns the result of the archive, or null when the administrator backed out.
Future<BulkArchiveResult?> showBulkArchiveDialog(BuildContext context) {
  return showDialog<BulkArchiveResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _BulkArchiveDialog(),
  );
}

/// The quick choices for "Hasn't parked since". [custom] is a date picked
/// from the calendar.
enum _Since { anyTime, days30, days90, months6, custom }

class _BulkArchiveDialog extends ConsumerStatefulWidget {
  const _BulkArchiveDialog();

  @override
  ConsumerState<_BulkArchiveDialog> createState() => _BulkArchiveDialogState();
}

class _BulkArchiveDialogState extends ConsumerState<_BulkArchiveDialog> {
  static const _affiliations = ['Student', 'Faculty', 'Staff'];

  String? _affiliation;

  // Starts at 90 days so a straight "Preview" never lists everyone,
  // including people who parked today. "Any time" is still one tap away.
  _Since _since = _Since.days90;
  late DateTime? _inactiveBefore = _dateFor(_Since.days90);

  final _reason = TextEditingController(text: 'End of semester');
  final _password = TextEditingController();

  BulkArchiveResult? _preview;
  final _picked = <String>{};
  bool _showSkipped = false;
  bool _copied = false;
  bool _busy = false;
  String? _error;

  BulkArchiveLastRun? _lastRun;

  @override
  void initState() {
    super.initState();
    _loadLastRun();
  }

  /// Fetches the "Last run" hint. It is only a reminder, so a failure just
  /// leaves the box hidden instead of blocking the dialog.
  Future<void> _loadLastRun() async {
    try {
      final res = await ref.read(dioProvider).get(ApiEndpoints.bulkArchiveLastRun);
      // No run yet comes back as an empty body (204).
      if (!mounted || res.data is! Map<String, dynamic>) return;
      setState(() => _lastRun = BulkArchiveLastRun.fromJson(res.data as Map<String, dynamic>));
    } catch (_) {}
  }

  /// "Review →" on the hint: skip the filters and go straight to the review,
  /// with only the people who have become clear ticked.
  void _reviewReady(BulkArchiveLastRun run) {
    setState(() {
      _preview = run.ready;
      _showSkipped = false;
      _error = null;
      _picked
        ..clear()
        ..addAll(run.ready.users.map((u) => u.userId));
      // Marks these in the audit log as late archives, not the main sweep.
      _reason.text = 'Cleared after semester end';
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    _password.dispose();
    super.dispose();
  }

  String _messageOf(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      return e.message ?? 'Something went wrong.';
    }
    return 'Something went wrong.';
  }

  /// The cut-off date for a quick choice, counted back from today in Manila.
  static DateTime? _dateFor(_Since since) {
    final now = manilaNow();
    final today = DateTime(now.year, now.month, now.day);
    return switch (since) {
      _Since.anyTime => null,
      _Since.days30 => today.subtract(const Duration(days: 30)),
      _Since.days90 => today.subtract(const Duration(days: 90)),
      // DateTime rolls a negative month back into the previous year.
      _Since.months6 => DateTime(today.year, today.month - 6, today.day),
      _Since.custom => null,
    };
  }

  void _choose(_Since since) {
    if (since == _Since.custom) {
      _pickDate();
      return;
    }
    setState(() {
      _since = since;
      _inactiveBefore = _dateFor(since);
    });
  }

  Future<void> _loadPreview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(dioProvider).post(ApiEndpoints.bulkArchive, data: {
        'dryRun': true,
        'affiliation': _affiliation,
        'inactiveBefore': _inactiveBefore?.toUtc().toIso8601String(),
      });
      final result = BulkArchiveResult.fromJson(res.data as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        _preview = result;
        _showSkipped = false;
        _picked
          ..clear()
          ..addAll(result.users.map((u) => u.userId));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageOf(e);
      });
    }
  }

  Future<void> _archive() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Give a reason for the archive.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(dioProvider).post(ApiEndpoints.bulkArchive, data: {
        'dryRun': false,
        'userIds': _picked.toList(),
        // Saved with the run so the next "Last run" check can tell who has
        // since become clear.
        'leftAloneUserIds': [for (final s in _preview?.skipped ?? const <BulkArchiveSkip>[]) s.userId],
        'reason': _reason.text.trim(),
        'password': _password.text,
      });
      if (!mounted) return;
      Navigator.pop(context, BulkArchiveResult.fromJson(res.data as Map<String, dynamic>));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageOf(e);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = manilaNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: _inactiveBefore ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: "Hasn't parked since",
    );
    if (picked != null) {
      setState(() {
        _since = _Since.custom;
        _inactiveBefore = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final t = context.tokens;

    return AlertDialog(
      title: Text(preview == null ? 'Bulk archive' : 'Review before archiving'),
      content: SizedBox(
        width: context.dialogWidth(560),
        child: preview == null ? _form(context) : _review(context, preview),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (preview != null)
          TextButton(
            onPressed: _busy ? null : () => setState(() {
              _preview = null;
              _error = null;
            }),
            child: const Text('Back'),
          ),
        if (preview == null)
          FilledButton(
            onPressed: _busy ? null : _loadPreview,
            child: const Text('Preview'),
          )
        else
          // Red, because this revokes cards and locks accounts.
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.status.danger.solid),
            onPressed: _busy || _picked.isEmpty ? null : _archive,
            child: Text(_busy ? 'Archiving…' : 'Archive ${_picked.length}'),
          ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final date = _inactiveBefore;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose who, then preview. Nothing changes until you confirm.',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
        const SizedBox(height: AppSpacing.x4),
        if (_lastRun case final run?
            when run.ready.users.isNotEmpty || run.ready.skipped.isNotEmpty) ...[
          _lastRunBox(context, run),
          const SizedBox(height: AppSpacing.x4),
        ],
        DropdownButtonFormField<String?>(
          initialValue: _affiliation,
          decoration: const InputDecoration(labelText: 'Affiliation'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Everyone')),
            for (final a in _affiliations) DropdownMenuItem(value: a, child: Text(a)),
          ],
          onChanged: (v) => setState(() => _affiliation = v),
        ),
        const SizedBox(height: AppSpacing.x4),
        // Looks like the Affiliation field above it; tapping opens the calendar.
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: "Hasn't parked since",
              prefixIcon: const Icon(Icons.event, size: AppSizes.iconSm),
              suffixIcon: date == null
                  ? null
                  : IconButton(
                      tooltip: 'Any time',
                      icon: const Icon(Icons.close, size: AppSizes.iconSm),
                      onPressed: () => _choose(_Since.anyTime),
                    ),
            ),
            child: Text(date == null ? 'Any time (everyone)' : _day.format(date)),
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: [
            for (final (since, label) in const [
              (_Since.anyTime, 'Any time'),
              (_Since.days30, '30 days'),
              (_Since.days90, '90 days'),
              (_Since.months6, '6 months'),
              (_Since.custom, 'Pick a date'),
            ])
              // Solid brand fill when chosen, so the active choice is obvious
              // at a glance instead of a faint tint.
              ChoiceChip(
                label: Text(label),
                selected: _since == since,
                showCheckmark: false,
                selectedColor: t.brand.primary,
                backgroundColor: t.surface.card,
                side: BorderSide(color: _since == since ? t.brand.primary : t.border.normal),
                shape: const StadiumBorder(),
                labelStyle: text.bodyMedium?.copyWith(
                  color: _since == since ? t.text.onBrand : t.text.primary,
                  fontWeight: _since == since ? FontWeight.w600 : FontWeight.w400,
                ),
                onSelected: (_) => _choose(since),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Last parking session or gate tap.',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
        if (_error != null) _ErrorText(_error!),
      ],
    );
  }

  /// "Last run Nov 19 · 14 archived · 7 left alone", and under it a live
  /// count of those 7 who would now pass the rules.
  Widget _lastRunBox(BuildContext context, BulkArchiveLastRun run) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final ready = run.ready.users.length;

    return Container(
      decoration: BoxDecoration(
        color: t.surface.muted,
        border: Border.all(color: t.border.subtle),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: AppSizes.iconSm, color: t.text.secondary),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Last run '),
                    TextSpan(
                      text: _day.format(manila(run.ranAt)),
                      style: TextStyle(color: t.text.primary),
                    ),
                    TextSpan(text: ' · ${run.archivedCount} archived · '),
                    TextSpan(
                      text: '${run.leftAloneCount} left alone',
                      style: TextStyle(color: t.status.warning.fg),
                    ),
                  ]),
                  style: text.bodyMedium?.copyWith(color: t.text.secondary),
                ),
              ),
            ],
          ),
          Divider(height: AppSpacing.x4, color: t.border.subtle),
          if (ready == 0)
            Text('None ready yet', style: text.bodyMedium?.copyWith(color: t.text.tertiary))
          else
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: AppSizes.iconSm, color: t.status.success.solid),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    '$ready now ready to archive',
                    style: text.bodyMedium?.copyWith(
                        color: t.status.success.fg, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _reviewReady(run),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: AppSizes.iconSm),
                  label: const Text('Review'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _review(BuildContext context, BulkArchiveResult preview) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final cards = preview.users.where((u) => _picked.contains(u.userId) && u.hasCard).length;

    // All ticked → true, none → false, some → null (the "–" box).
    final bool? allPicked = _picked.isEmpty
        ? false
        : _picked.length == preview.users.length
            ? true
            : null;

    // Follows the screen so the reason, password and buttons always fit;
    // only the list in the middle scrolls.
    final height = (MediaQuery.sizeOf(context).height * 0.6).clamp(320.0, 460.0);

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border.subtle)),
            ),
            child: Row(
              children: [
                _Tab(
                  label: 'Will archive',
                  count: preview.users.length,
                  selected: !_showSkipped,
                  onTap: () => setState(() => _showSkipped = false),
                ),
                const SizedBox(width: AppSpacing.x5),
                _Tab(
                  label: 'Left alone',
                  count: preview.skipped.length,
                  warn: preview.skipped.isNotEmpty,
                  selected: _showSkipped,
                  onTap: () => setState(() => _showSkipped = true),
                ),
                const Spacer(),
                if (_showSkipped && preview.skipped.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _copySkipped(preview),
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: AppSizes.iconSm),
                    label: Text(_copied ? 'Copied' : 'Copy list'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          // The list sits in its own bordered box so it reads as one block,
          // separate from the reason and password below.
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: t.border.subtle),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Column(
                children: [
                  if (!_showSkipped && preview.users.isNotEmpty) ...[
                    // Select-all sits on top, like a table header.
                    InkWell(
                      onTap: () => _toggleAll(preview),
                      child: Container(
                        color: t.surface.muted,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
                        child: Row(
                          children: [
                            Checkbox(
                              tristate: true,
                              value: allPicked,
                              onChanged: (_) => _toggleAll(preview),
                            ),
                            const SizedBox(width: AppSpacing.x1),
                            Expanded(
                              child: Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                    text: '${_picked.length} of ${preview.users.length} selected',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  if (cards > 0)
                                    TextSpan(
                                      text: '  ·  $cards card${cards == 1 ? '' : 's'} handed back',
                                      style: TextStyle(color: t.text.secondary),
                                    ),
                                ]),
                                style: text.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: t.border.subtle),
                  ],
                  Expanded(
                    child: _showSkipped
                        ? _skippedList(context, preview)
                        : _userList(context, preview),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: t.text.tertiary),
              const SizedBox(width: AppSpacing.x1),
              Text(
                'Staff and administrators are never included.',
                style: text.bodySmall?.copyWith(color: t.text.tertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(labelText: 'Reason (kept in the audit log)'),
          ),
          const SizedBox(height: AppSpacing.x2),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Your password'),
            onSubmitted: (_) => _picked.isEmpty || _busy ? null : _archive(),
          ),
          if (_error != null) _ErrorText(_error!),
        ],
      ),
    );
  }

  Widget _userList(BuildContext context, BulkArchiveResult preview) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (preview.users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
        child: Text('Nobody matches.', style: text.bodyMedium?.copyWith(color: t.text.secondary)),
      );
    }

    return ListView.separated(
      itemCount: preview.users.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: t.border.subtle),
      itemBuilder: (context, i) {
        final u = preview.users[i];
        final picked = _picked.contains(u.userId);
        void toggle() => setState(() => picked ? _picked.remove(u.userId) : _picked.add(u.userId));

        return InkWell(
          onTap: toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
            child: Row(
              children: [
                Checkbox(value: picked, onChanged: (_) => toggle()),
                const SizedBox(width: AppSpacing.x1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email stays reachable on hover, without crowding the row.
                      Tooltip(
                        message: u.email,
                        child: Text(u.fullName,
                            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${u.affiliation} · last active ${_day.format(manila(u.lastActiveAt))}',
                        style: text.bodySmall?.copyWith(color: t.text.secondary),
                      ),
                    ],
                  ),
                ),
                if (u.hasCard) _Pill(label: 'Has card', colors: t.status.info),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Puts the "Left alone" list on the clipboard, one person per line, so the
  /// admin can paste it into a message or a clearance report.
  Future<void> _copySkipped(BulkArchiveResult preview) async {
    final lines = [
      'Not archived (${preview.skipped.length}):',
      for (final s in preview.skipped) '${s.fullName} — ${s.reason}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    // A snackbar would sit behind the dialog, so the button itself says "Copied".
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _toggleAll(BulkArchiveResult preview) {
    // A full or partial box clears everyone; an empty box ticks everyone.
    setState(() {
      if (_picked.isEmpty) {
        _picked.addAll(preview.users.map((u) => u.userId));
      } else {
        _picked.clear();
      }
    });
  }

  Widget _skippedList(BuildContext context, BulkArchiveResult preview) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (preview.skipped.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
        child: Text('Nobody was left alone.',
            style: text.bodyMedium?.copyWith(color: t.text.secondary)),
      );
    }

    return ListView.separated(
      itemCount: preview.skipped.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: t.border.subtle),
      itemBuilder: (context, i) {
        final s = preview.skipped[i];
        // Name on top, reason right under it, so the eye doesn't have to
        // jump across the dialog to match them up.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
          child: Row(
            children: [
              Icon(Icons.pause_circle_outline, size: 20, color: t.status.warning.solid),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.fullName,
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(s.reason, style: text.bodySmall?.copyWith(color: t.status.warning.fg)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One tab label with a count bubble and an underline when selected.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.warn = false,
  });

  final String label;
  final int count;
  final bool selected;
  final bool warn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bubble = warn ? t.status.warning : t.status.neutral;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: AppSpacing.x2, bottom: AppSpacing.x2 + 1),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? t.brand.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? t.text.primary : t.text.secondary,
                  ),
            ),
            const SizedBox(width: AppSpacing.x2),
            _Pill(label: '$count', colors: bubble),
          ],
        ),
      ),
    );
  }
}

/// A small rounded tag, tinted by a status colour.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.colors});

  final String label;
  final StatusColors colors;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2, vertical: 2),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.fg),
        ),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x2),
        child: Text(message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.tokens.status.danger.solid)),
      );
}
