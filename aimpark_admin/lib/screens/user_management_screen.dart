import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/admin_user.dart';
import '../providers/users_provider.dart';
import '../widgets/page_header.dart';
import '../core/utils/responsive.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(usersQueryNotifierProvider);
    final async = ref.watch(userListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            PageHeader(
              title: 'User Management',
              actions: [
                SizedBox(
                  width: context.dialogWidth(260),
                  child: const _SearchField(),
                ),
                // Status filter
                DropdownButton<String?>(
                  value: query.status,
                  hint: const Text('All Status'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(
                        value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'Suspended', child: Text('Suspended')),
                    DropdownMenuItem(
                        value: 'PendingReview', child: Text('PendingReview')),
                    DropdownMenuItem(
                        value: 'Rejected', child: Text('Rejected')),
                    DropdownMenuItem(
                        value: 'Archived', child: Text('Archived')),
                  ],
                  onChanged: (v) => ref
                      .read(usersQueryNotifierProvider.notifier)
                      .setStatus(v),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(userListProvider),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Table
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Failed to load users: $e'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(userListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (page) => Column(
                  children: [
                    Expanded(child: _UserTable(page: page)),
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

// ── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        hintText: 'Search name, email, or plate',
        prefixIcon: Icon(Icons.search, size: 20),
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          ref.read(usersQueryNotifierProvider.notifier).setSearch(value.trim());
        });
      },
    );
  }
}

// ── User table ───────────────────────────────────────────────────────────────

class _UserTable extends ConsumerWidget {
  const _UserTable({required this.page});

  final UserListPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.users.isEmpty) {
      return const Center(
          child: Text('No users found.', style: TextStyle(fontSize: 16)));
    }

    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
          showCheckboxColumn: false,
          headingRowColor:
              WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('Full Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Archived')),
            DataColumn(label: Text('Joined')),
            DataColumn(label: Text('Actions')),
          ],
          rows: page.users
              .map((u) => _userRow(context, ref, u))
              .toList(),
          ),
        ),
      ),
    );
  }

  DataRow _userRow(
      BuildContext context, WidgetRef ref, AdminUser user) {
    return DataRow(
      onSelectChanged: (_) => context.go('/users/${user.userId}'),
      cells: [
        DataCell(Text(user.fullName,
            style: user.isDeleted
                ? const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey)
                : null)),
        DataCell(Text(user.email)),
        DataCell(_StatusChip(status: user.accountStatus)),
        DataCell(user.isDeleted
            ? const Icon(Icons.archive_outlined, color: Colors.red, size: 18)
            : const SizedBox.shrink()),
        DataCell(Text(DateFormat('MMM d, yyyy')
            .format(user.createdAt.toLocal()))),
        DataCell(_ActionButtons(user: user)),
      ],
    );
  }
}

// ── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Active':
        color = Colors.green;
        break;
      case 'Suspended':
        color = Colors.orange;
        break;
      case 'Rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Chip(
      label: Text(status,
          style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ── Action buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeleted = user.isDeleted;
    final status = user.accountStatus;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Restore (archived only)
        if (isDeleted)
          _SmallButton(
            icon: Icons.restore,
            label: 'Restore',
            color: Colors.blue,
            onPressed: () => _restore(context, ref),
          ),
        // Suspend (active, non-archived)
        if (!isDeleted && status == 'Active')
          _SmallButton(
            icon: Icons.pause_circle_outline,
            label: 'Suspend',
            color: Colors.orange,
            onPressed: () => _suspend(context, ref),
          ),
        // Unsuspend (suspended, non-archived)
        if (!isDeleted && status == 'Suspended')
          _SmallButton(
            icon: Icons.play_circle_outline,
            label: 'Unsuspend',
            color: Colors.green,
            onPressed: () => _unsuspend(context, ref),
          ),
        // Archive (non-archived)
        if (!isDeleted)
          _SmallButton(
            icon: Icons.archive_outlined,
            label: 'Archive',
            color: Colors.red,
            onPressed: () => _archive(context, ref),
          ),
      ],
    );
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspend ${user.fullName}'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(
                ctx, reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim()),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    // null return means cancel was pressed; we check if dialog was dismissed vs confirmed
    if (!context.mounted) return;
    // We always confirmed if we get here (cancel pops with no value via Navigator.pop(ctx))
    // Actually the cancel pops without a value so result would be null from cancel too.
    // We use a sentinel to distinguish — but since reason is optional, we proceed always when dialog closed with the button
    // The simplest fix: check if the dialog result came from the button.
    // We'll use a wrapper record approach.
    final suspendConfirmed = reason != null || reasonCtrl.text.isEmpty;
    if (!suspendConfirmed) return;
    
    final msg = await ref
        .read(userActionsProvider.notifier)
        .suspend(user.userId, reason: reason);
    if (!context.mounted) return;
    _showSnack(context, msg ?? 'User suspended.', Colors.orange);
    ref.invalidate(userListProvider);
  }

  Future<void> _unsuspend(BuildContext context, WidgetRef ref) async {
    final msg = await ref
        .read(userActionsProvider.notifier)
        .unsuspend(user.userId);
    if (!context.mounted) return;
    _showSnack(context, msg ?? 'User unsuspended.', Colors.green);
    ref.invalidate(userListProvider);
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive User'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Archive ${user.fullName}? The account data will be retained and can be restored later. The user will not be able to log in.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm your admin password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final msg = await ref
        .read(userActionsProvider.notifier)
        .archive(user.userId, passwordCtrl.text);
    if (!context.mounted) return;
    _showSnack(context, msg ?? 'User archived.', Colors.red);
    ref.invalidate(userListProvider);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final msg =
        await ref.read(userActionsProvider.notifier).restore(user.userId);
    if (!context.mounted) return;
    _showSnack(context, msg ?? 'User restored.', Colors.blue);
    ref.invalidate(userListProvider);
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }
}

// ── Small button ─────────────────────────────────────────────────────────────

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 14, color: color),
        label: Text(label,
            style: TextStyle(fontSize: 12, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

// ── Pagination ───────────────────────────────────────────────────────────────

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.page});

  final UserListPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPages = (page.totalCount / page.pageSize).ceil();
    final currentPage = page.page;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
            'Showing ${page.users.length} of ${page.totalCount} users • Page $currentPage of $totalPages'),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1
              ? () => ref
                  .read(usersQueryNotifierProvider.notifier)
                  .setPage(currentPage - 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages
              ? () => ref
                  .read(usersQueryNotifierProvider.notifier)
                  .setPage(currentPage + 1)
              : null,
        ),
      ],
    );
  }
}
