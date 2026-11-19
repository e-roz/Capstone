import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/ph_time.dart';
import '../core/utils/responsive.dart';
import '../models/admin_user.dart';
import '../models/bulk_archive.dart';
import '../theme/theme.dart';

final _day = DateFormat('MMM d, yyyy');

/// Pick archived accounts and bring them back in one go.
///
/// Same rules as restoring one: the account returns with its status as it
/// was and without a card. Returns the result, or null when cancelled.
Future<BulkRestoreResult?> showBulkRestoreDialog(BuildContext context) {
  return showDialog<BulkRestoreResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _BulkRestoreDialog(),
  );
}

class _BulkRestoreDialog extends ConsumerStatefulWidget {
  const _BulkRestoreDialog();

  @override
  ConsumerState<_BulkRestoreDialog> createState() => _BulkRestoreDialogState();
}

class _BulkRestoreDialogState extends ConsumerState<_BulkRestoreDialog> {
  /// The list endpoint's page limit. Search narrows anything past it.
  static const _pageSize = 100;

  final _search = TextEditingController();
  final _reason = TextEditingController(text: 'Archived by mistake');
  final _password = TextEditingController();

  /// Picked people, kept by id with their name so a new search doesn't drop them.
  final _picked = <String, String>{};

  List<AdminUser> _users = const [];
  int _total = 0;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final term = _search.text.trim();
      final res = await ref.read(dioProvider).get(ApiEndpoints.users, queryParameters: {
        'page': 1,
        'pageSize': _pageSize,
        'status': UserStatuses.archived,
        if (term.isNotEmpty) 'search': term,
      });
      final page = UserListPage.fromJson(res.data as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        _users = page.users.where((u) => u.isDeleted).toList();
        _total = page.totalCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageOf(e);
      });
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _toggle(AdminUser u) => setState(() {
        if (_picked.remove(u.userId) == null) _picked[u.userId] = u.fullName;
      });

  void _toggleAllShown() => setState(() {
        final allShown = _users.isNotEmpty && _users.every((u) => _picked.containsKey(u.userId));
        for (final u in _users) {
          if (allShown) {
            _picked.remove(u.userId);
          } else {
            _picked[u.userId] = u.fullName;
          }
        }
      });

  Future<void> _restore() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Give a reason for the restore.');
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
      final res = await ref.read(dioProvider).post(ApiEndpoints.bulkRestore, data: {
        'userIds': _picked.keys.toList(),
        'reason': _reason.text.trim(),
        'password': _password.text,
      });
      if (!mounted) return;
      Navigator.pop(context, BulkRestoreResult.fromJson(res.data as Map<String, dynamic>));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageOf(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final shownPicked = _users.where((u) => _picked.containsKey(u.userId)).length;
    final bool? allShown = shownPicked == 0
        ? false
        : shownPicked == _users.length
            ? true
            : null;
    final height = (MediaQuery.sizeOf(context).height * 0.6).clamp(320.0, 460.0);

    return AlertDialog(
      title: const Text('Bulk restore'),
      content: SizedBox(
        width: context.dialogWidth(520),
        height: height + 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restored accounts keep their status and come back without a card. Assign cards again afterwards.',
              style: text.bodySmall?.copyWith(color: t.text.secondary),
            ),
            const SizedBox(height: AppSpacing.x3),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: AppSizes.iconSm),
                hintText: 'Search archived by name, email, or plate',
                isDense: true,
              ),
              onChanged: _onSearch,
            ),
            const SizedBox(height: AppSpacing.x2),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(color: t.border.subtle),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: _users.isEmpty ? null : _toggleAllShown,
                      child: Container(
                        color: t.surface.muted,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
                        child: Row(
                          children: [
                            Checkbox(
                              tristate: true,
                              value: allShown,
                              onChanged: _users.isEmpty ? null : (_) => _toggleAllShown(),
                            ),
                            const SizedBox(width: AppSpacing.x1),
                            Expanded(
                              child: Text(
                                '${_picked.length} selected',
                                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (_total > _users.length)
                              Text(
                                'Showing ${_users.length} of $_total. Search to narrow.',
                                style: text.bodySmall?.copyWith(color: t.text.tertiary),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: t.border.subtle),
                    Expanded(child: _list(context)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Reason (kept in the audit log)'),
            ),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Your password'),
              onSubmitted: (_) => _picked.isEmpty || _busy ? null : _restore(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.x2),
                child: Text(_error!, style: text.bodySmall?.copyWith(color: t.status.danger.fg)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _picked.isEmpty ? null : _restore,
          child: Text(_busy ? 'Restoring…' : 'Restore ${_picked.length}'),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) {
      return Center(
        child: Text(
          _search.text.trim().isEmpty ? 'No archived accounts.' : 'No archived account matches.',
          style: text.bodyMedium?.copyWith(color: t.text.secondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: t.border.subtle),
      itemBuilder: (context, i) {
        final u = _users[i];
        final picked = _picked.containsKey(u.userId);
        return InkWell(
          onTap: () => _toggle(u),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
            child: Row(
              children: [
                Checkbox(value: picked, onChanged: (_) => _toggle(u)),
                const SizedBox(width: AppSpacing.x1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.fullName.isEmpty ? u.email : u.fullName,
                          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        '${u.email} · ${u.accountStatus} · joined ${_day.format(manila(u.createdAt))}',
                        style: text.bodySmall?.copyWith(color: t.text.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
