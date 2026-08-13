import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/registration_detail.dart';
import '../providers/registrations_provider.dart';
import '../widgets/document_viewer.dart';

class RegistrationDetailScreen extends ConsumerWidget {
  const RegistrationDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(registrationDetailProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (detail) => _DetailView(
          detail: detail,
          onApprove: () => _approve(context, ref, detail),
          onReject: () => _showRejectDialog(context, ref, detail),
        ),
      ),
    );
  }

  Future<void> _approve(
      BuildContext context, WidgetRef ref, RegistrationDetail detail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Registration'),
        content: Text(
            'Approve ${detail.fullName}\'s registration? This will activate their account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve')),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final msg = await ref
        .read(registrationActionsProvider.notifier)
        .approve(userId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg ?? 'Approved successfully'),
        backgroundColor: Colors.green,
      ),
    );
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(pendingRegistrationsProvider);
  }

  static const _rejectPresets = <String, String>{
    'Blurred document':
        'One or more of your uploaded documents is too blurry to verify. Please retake the photo in good lighting and re-apply.',
    'Mismatched information':
        'The information you provided does not match your uploaded documents. Please review and re-apply with matching details.',
    'Expired ID':
        'Your uploaded ID/license has expired. Please upload a valid, unexpired document and re-apply.',
    'Suspicious/altered document':
        'One or more of your uploaded documents appears to be altered or invalid. Please contact the administration office for assistance.',
  };

  Future<void> _showRejectDialog(
      BuildContext context, WidgetRef ref, RegistrationDetail detail) async {
    final reasonCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '24');
    final formKey = GlobalKey<FormState>();
    String? selectedPreset;

    final result = await showDialog<({String reason, int hours})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedPreset,
                decoration: const InputDecoration(
                  labelText: 'Reason preset (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  ..._rejectPresets.keys.map(
                      (label) => DropdownMenuItem(value: label, child: Text(label))),
                  const DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (label) {
                  setState(() => selectedPreset = label);
                  if (label != null && label != 'Other') {
                    reasonCtrl.text = _rejectPresets[label]!;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  helperText: 'Sent to the applicant by email — edit as needed.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Reason is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: hoursCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cooldown (hours)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 0) return 'Enter a valid number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, (
                  reason: reasonCtrl.text.trim(),
                  hours: int.parse(hoursCtrl.text.trim()),
                ));
              }
            },
            child: const Text('Reject'),
          ),
        ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    final msg = await ref
        .read(registrationActionsProvider.notifier)
        .reject(userId, result.reason, result.hours);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg ?? 'Rejected'),
        backgroundColor: Colors.red,
      ),
    );
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(pendingRegistrationsProvider);
  }
}

// ── Detail view widget ───────────────────────────────────────────────────────

class _DetailView extends StatelessWidget {
  const _DetailView({
    required this.detail,
    required this.onApprove,
    required this.onReject,
  });

  final RegistrationDetail detail;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Personal Information',
            children: [
              _Field('Full Name', detail.fullName),
              _Field('Email', detail.email),
              _Field('Affiliation', detail.affiliation),
              // Blank for faculty and staff, who have no RAF — the affiliation
              // above is what tells the reviewer which of those this is.
              if (detail.studentNumber != null)
                _Field('Student Number', detail.studentNumber!),
              if (detail.section != null) _Field('Section', detail.section!),
              if (detail.enrollmentValidUntil != null)
                _Field('Enrolled Until', _fmt(detail.enrollmentValidUntil!)),
              _Field('Account Status', detail.accountStatus),
              _Field('Verification Status', detail.verificationStatus),
              _Field('Registration Step', detail.registrationStep),
              if (detail.rejectionReason != null)
                _Field('Rejection Reason', detail.rejectionReason!,
                    danger: true),
              if (detail.rejectionCount > 0)
                _Field(
                    'Rejection Count', detail.rejectionCount.toString()),
              if (detail.canReapplyAt != null)
                _Field('Can Reapply At',
                    _fmt(detail.canReapplyAt!)),
            ],
          ),
          // One card per vehicle: a card holder may register several, and a single
          // card would silently show only the first.
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
                  .map((doc) => _DocumentTile(doc: doc))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: onApprove,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      DateFormat('MMM d, yyyy HH:mm').format(dt.toLocal());
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
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
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: danger ? Colors.red.shade700 : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc});

  final DocumentInfo doc;

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
    );
  }
}
