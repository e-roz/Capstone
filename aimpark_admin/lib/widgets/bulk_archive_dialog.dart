import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

class _BulkArchiveDialog extends ConsumerStatefulWidget {
  const _BulkArchiveDialog();

  @override
  ConsumerState<_BulkArchiveDialog> createState() => _BulkArchiveDialogState();
}

class _BulkArchiveDialogState extends ConsumerState<_BulkArchiveDialog> {
  static const _affiliations = ['Student', 'Faculty', 'Staff'];

  String? _affiliation;
  DateTime? _inactiveBefore;
  final _reason = TextEditingController(text: 'End of semester');
  final _password = TextEditingController();

  BulkArchiveResult? _preview;
  final _picked = <String>{};
  bool _busy = false;
  String? _error;

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
      helpText: 'No activity since',
    );
    if (picked != null) setState(() => _inactiveBefore = picked);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

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
          FilledButton(
            onPressed: _busy || _picked.isEmpty ? null : _archive,
            child: Text(_busy ? 'Archiving…' : 'Archive ${_picked.length}'),
          ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose who, then preview. Nothing changes until you confirm.',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
        const SizedBox(height: AppSpacing.x4),
        DropdownButtonFormField<String?>(
          initialValue: _affiliation,
          decoration: const InputDecoration(labelText: 'Affiliation'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Everyone')),
            for (final a in _affiliations) DropdownMenuItem(value: a, child: Text(a)),
          ],
          onChanged: (v) => setState(() => _affiliation = v),
        ),
        const SizedBox(height: AppSpacing.x3),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event, size: AppSizes.iconSm),
                label: Text(_inactiveBefore == null
                    ? 'No activity since: any time'
                    : 'No activity since ${_day.format(_inactiveBefore!)}'),
                onPressed: _pickDate,
              ),
            ),
            if (_inactiveBefore != null)
              IconButton(
                tooltip: 'Clear date',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _inactiveBefore = null),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Counts the last parking session or gate tap. An account never used counts from the day it was made. '
          'Staff and administrators are never included.',
          style: text.bodySmall?.copyWith(color: t.text.tertiary),
        ),
        if (_error != null) _ErrorText(_error!),
      ],
    );
  }

  Widget _review(BuildContext context, BulkArchiveResult preview) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final cards = preview.users.where((u) => _picked.contains(u.userId) && u.hasCard).length;

    return SizedBox(
      height: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_picked.length} of ${preview.users.length} selected'
            '${preview.skipped.isEmpty ? '' : ' · ${preview.skipped.length} skipped'}'
            '${cards == 0 ? '' : ' · $cards card${cards == 1 ? '' : 's'} will be handed back'}',
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.x2),
          Expanded(
            child: ListView(
              children: [
                if (preview.users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
                    child: Text('Nobody matches.',
                        style: text.bodyMedium?.copyWith(color: t.text.secondary)),
                  ),
                for (final u in preview.users)
                  CheckboxListTile(
                    dense: true,
                    value: _picked.contains(u.userId),
                    title: Text(u.fullName),
                    subtitle: Text(
                      '${u.email} · ${u.affiliation} · last active ${_day.format(manila(u.lastActiveAt))}'
                      '${u.hasCard ? ' · has card' : ''}',
                    ),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _picked.add(u.userId);
                      } else {
                        _picked.remove(u.userId);
                      }
                    }),
                  ),
                if (preview.skipped.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x3),
                  Text('Left alone',
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.x1),
                  for (final s in preview.skipped)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
                      child: Row(
                        children: [
                          Expanded(child: Text(s.fullName, style: text.bodyMedium)),
                          Flexible(
                            child: Text(s.reason,
                                textAlign: TextAlign.end,
                                style: text.bodySmall?.copyWith(color: t.text.secondary)),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
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
