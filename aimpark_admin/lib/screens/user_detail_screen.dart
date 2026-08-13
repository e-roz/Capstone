import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/registration_detail.dart';
import '../providers/registrations_provider.dart';
import '../providers/users_provider.dart';
import '../widgets/document_viewer.dart';

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(registrationDetailProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (detail) => _UserDetailView(userId: userId, detail: detail),
      ),
    );
  }
}

class _UserDetailView extends ConsumerWidget {
  const _UserDetailView({required this.userId, required this.detail});

  final String userId;
  final RegistrationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(detail.fullName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              _StatusChip(status: detail.accountStatus),
              if (detail.isDeleted) ...[
                const SizedBox(width: 8),
                const Chip(
                  label: Text('Archived', style: TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: Colors.blueGrey,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Personal Information',
            children: [
              _Field('Email', detail.email),
              _Field('Affiliation', detail.affiliation),
              if (detail.studentNumber != null)
                _Field('Student Number', detail.studentNumber!),
              if (detail.section != null) _Field('Section', detail.section!),
              if (detail.enrollmentValidUntil != null)
                _Field('Enrolled Until',
                    DateFormat('MMM d, yyyy').format(detail.enrollmentValidUntil!.toLocal())),
              _Field('Verification Status', detail.verificationStatus),
              _Field('Joined', DateFormat('MMM d, yyyy').format(detail.createdAt.toLocal())),
              if (detail.rejectionReason != null)
                _Field('Rejection Reason', detail.rejectionReason!, danger: true),
              if (detail.canReapplyAt != null)
                _Field('Can Reapply At',
                    DateFormat('MMM d, yyyy HH:mm').format(detail.canReapplyAt!.toLocal())),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'RFID Access',
            children: [
              _Field('Tag ID', detail.rfidTagId ?? 'Not assigned'),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 180,
                      child: Text('Status',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
                    ),
                    _RfidStatusChip(status: detail.rfidStatus),
                  ],
                ),
              ),
              if (detail.rfidStatus == 'Suspended' && detail.rfidSuspendedUntil != null)
                _Field('Suspended Until',
                    DateFormat('MMM d, yyyy HH:mm').format(detail.rfidSuspendedUntil!.toLocal()))
              else if (detail.rfidStatus == 'Suspended')
                _Field('Suspended Until', 'Indefinite'),
            ],
          ),
          for (final (i, vehicle) in detail.vehicles.indexed) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: detail.vehicles.length > 1
                  ? 'Vehicle ${i + 1} of ${detail.vehicles.length}'
                  : 'Vehicle Information',
              children: [
                _Field('Brand', vehicle.brand ?? '—'),
                _Field('Model', vehicle.model ?? '—'),
                _Field('Vehicle Type', vehicle.vehicleType ?? '—'),
                _Field('Plate Number', vehicle.plateNumber ?? '—'),
                _Field('Color', vehicle.color ?? '—'),
              ],
            ),
          ],
          if (detail.documents.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Uploaded Documents',
              children: detail.documents
                  .map((doc) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(doc.type),
                        subtitle: Text(doc.fileName),
                        trailing: TextButton(
                          onPressed: () => viewDocument(
                            context,
                            title: doc.type,
                            fileName: doc.fileName,
                            url: doc.filePath,
                          ),
                          child: const Text('View'),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          _ActionRow(userId: userId, detail: detail),
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.userId, required this.detail});

  final String userId;
  final RegistrationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeleted = detail.isDeleted;
    final status = detail.accountStatus;

    return Wrap(
      spacing: 12,
      children: [
        if (isDeleted)
          FilledButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Restore'),
            style: FilledButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => _restore(context, ref),
          ),
        if (!isDeleted && status == 'Active')
          FilledButton.icon(
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Suspend'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => _suspend(context, ref),
          ),
        if (!isDeleted && status == 'Suspended')
          FilledButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Unsuspend'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => _unsuspend(context, ref),
          ),
        if (!isDeleted)
          FilledButton.icon(
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _archive(context, ref),
          ),
        if (!isDeleted)
          OutlinedButton.icon(
            icon: const Icon(Icons.nfc),
            label: Text(detail.rfidTagId == null ? 'Assign RFID' : 'Reassign RFID'),
            onPressed: () => _assignRfid(context, ref),
          ),
        if (!isDeleted && detail.rfidTagId != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.nfc_outlined),
            label: const Text('Revoke RFID'),
            onPressed: () => _revokeRfid(context, ref),
          ),
      ],
    );
  }

  Future<void> _assignRfid(BuildContext context, WidgetRef ref) async {
    final tagCtrl = TextEditingController(text: detail.rfidTagId ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign RFID to ${detail.fullName}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: tagCtrl,
            decoration: const InputDecoration(
              labelText: 'RFID Tag ID',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Tag ID is required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final msg = await ref
        .read(userActionsProvider.notifier)
        .assignRfid(userId, tagCtrl.text.trim());
    if (!context.mounted) return;
    _refreshAndSnack(context, ref, msg ?? 'RFID tag assigned.', Colors.blue);
  }

  Future<void> _revokeRfid(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke RFID Tag'),
        content: Text(
            'Revoke the RFID tag from ${detail.fullName}? They will no longer be able to use RFID entry/exit until a new tag is assigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final msg = await ref.read(userActionsProvider.notifier).revokeRfid(userId);
    if (!context.mounted) return;
    _refreshAndSnack(context, ref, msg ?? 'RFID tag revoked.', Colors.red);
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspend ${detail.fullName}'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(
                ctx, reasonCtrl.text.trim().isEmpty ? '' : reasonCtrl.text.trim()),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;

    final msg = await ref
        .read(userActionsProvider.notifier)
        .suspend(userId, reason: reason.isEmpty ? null : reason);
    if (!context.mounted) return;
    _refreshAndSnack(context, ref, msg ?? 'User suspended.', Colors.orange);
  }

  Future<void> _unsuspend(BuildContext context, WidgetRef ref) async {
    final msg = await ref.read(userActionsProvider.notifier).unsuspend(userId);
    if (!context.mounted) return;
    _refreshAndSnack(context, ref, msg ?? 'User unsuspended.', Colors.green);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final msg = await ref.read(userActionsProvider.notifier).restore(userId);
    if (!context.mounted) return;
    _refreshAndSnack(context, ref, msg ?? 'User restored.', Colors.blue);
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
                  'Archive ${detail.fullName}? The account data will be retained and can be restored later. The user will not be able to log in.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm your admin password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
        .archive(userId, passwordCtrl.text);
    if (!context.mounted) return;
    _refreshAndSnack(context, ref, msg ?? 'User archived.', Colors.red);
  }

  void _refreshAndSnack(BuildContext context, WidgetRef ref, String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(userListProvider);
  }
}

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
      label: Text(status, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _RfidStatusChip extends StatelessWidget {
  const _RfidStatusChip({required this.status});

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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.danger = false});

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: danger ? Colors.red.shade700 : null)),
          ),
        ],
      ),
    );
  }
}
