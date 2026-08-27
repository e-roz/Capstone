import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/registration_checks.dart';
import '../models/registration_detail.dart';
import '../providers/registrations_provider.dart';
import '../theme/theme.dart';
import '../widgets/checks_panel.dart';
import '../widgets/document_viewer.dart';
import '../widgets/ui/ui.dart';

String _fmt(DateTime dt) => DateFormat('MMM d, yyyy HH:mm').format(dt.toLocal());

class RegistrationDetailScreen extends ConsumerWidget {
  const RegistrationDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(registrationDetailProvider(userId));
    final detail = async.valueOrNull;

    return AppPage(
      title: detail?.fullName ?? 'Registration',
      subtitle: detail == null
          ? 'Reviewing a submitted registration.'
          : '${detail.affiliation} · ${detail.email}',
      scrollable: true,
      onBack: () => context.go('/pending'),
      actions: [
        // Only offered while the application is actually awaiting a decision —
        // an already-approved record showing a live Approve button invites a
        // second, meaningless write.
        //
        // Gated on the *account* status, which is what the pending queue itself
        // selects on. Gating on `verificationStatus == 'Pending'` hid these
        // buttons on every single application: submitting sets that field to
        // `ManualReview`, and nothing in the API ever writes `Pending`.
        if (detail != null && detail.accountStatus == 'PendingReview') ...[
          FilledButton.icon(
            icon: const Icon(Icons.check, size: AppSizes.iconSm),
            label: const Text('Approve'),
            onPressed: () => _approve(context, ref, detail),
          ),
          // Sits between Approve and Reject because that is where it belongs in
          // the reviewer's thinking. Most refusals are not "this person may not
          // park here" but "I cannot read this receipt", and rejection was the
          // only tool available for both — which cost the applicant all four
          // documents and a cooldown to fix one photograph.
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera_outlined, size: AppSizes.iconSm),
            label: const Text('Ask to retake'),
            onPressed: () => _showRetakeDialog(context, ref, detail),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: AppSizes.iconSm),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.tokens.status.danger.fg,
              side: BorderSide(color: context.tokens.status.danger.border),
            ),
            onPressed: () => _showRejectDialog(context, ref, detail),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(registrationDetailProvider(userId)),
        ),
      ],
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(registrationDetailProvider(userId)),
        data: (detail) => _DetailView(detail: detail),
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

    final msg =
        await ref.read(registrationActionsProvider.notifier).approve(userId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Approved successfully')));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(pendingRegistrationsProvider);
  }

  /// The documents a reviewer can send back, in the order the applicant took
  /// them. Both identity kinds are offered; the server folds whichever is
  /// chosen onto the slot this particular account actually files under.
  static const _retakeDocuments = <String, String>{
    'Raf': 'Registration form',
    'SchoolId': 'School ID',
    'License': "Driver's licence",
    'OfficialReceipt': 'Official receipt',
    'PlatePhoto': 'Plate photo',
  };

  /// Common reasons, offered as one tap each.
  ///
  /// The reason reaches the applicant on the capture screen for that document,
  /// so it is written as an instruction to somebody standing in front of the
  /// thing — not as a note to a colleague.
  static const _retakeReasons = <String>[
    'Too blurry to read.',
    'Too dark — try again in better light.',
    'Part of it is cut off by the frame.',
    'Glare is covering the printed details.',
    'This is not the document we asked for.',
  ];

  Future<void> _showRetakeDialog(
      BuildContext context, WidgetRef ref, RegistrationDetail detail) async {
    final reasons = <String, TextEditingController>{};
    final selected = <String>{};
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final canSend = selected.isNotEmpty &&
              selected.every(
                  (key) => reasons[key]?.text.trim().isNotEmpty ?? false);

          return AlertDialog(
            title: const Text('Ask for documents again'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'They keep their place in the queue and their other '
                      'documents. No cooldown — they can answer straight away.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    for (final entry in _retakeDocuments.entries) ...[
                      CheckboxListTile(
                        value: selected.contains(entry.key),
                        title: Text(entry.value),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        onChanged: (on) => setState(() {
                          if (on == true) {
                            selected.add(entry.key);
                            reasons.putIfAbsent(
                                entry.key, () => TextEditingController());
                          } else {
                            selected.remove(entry.key);
                          }
                        }),
                      ),
                      if (selected.contains(entry.key)) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              left: AppSpacing.x6, bottom: AppSpacing.x2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: AppSpacing.x1,
                                children: [
                                  for (final preset in _retakeReasons)
                                    ActionChip(
                                      label: Text(preset,
                                          style: Theme.of(context).textTheme.labelSmall),
                                      onPressed: () => setState(() =>
                                          reasons[entry.key]!.text = preset),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.x1),
                              TextField(
                                controller: reasons[entry.key],
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'What was wrong with it?',
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.x2),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note to the applicant (optional)',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                // Every chosen document needs a reason. One sent back without
                // one gets retaken identically, because nothing told them what
                // to change.
                onPressed:
                    canSend ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Send back'),
              ),
            ],
          );
        },
      ),
    );

    final documents = {
      for (final key in selected) key: reasons[key]!.text.trim(),
    };

    for (final controller in reasons.values) {
      controller.dispose();
    }
    final note = noteCtrl.text;
    noteCtrl.dispose();

    if (confirmed != true || documents.isEmpty || !context.mounted) return;

    final msg = await ref
        .read(registrationActionsProvider.notifier)
        .requestRetake(userId, documents, note: note);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? 'Sent back to the applicant')));
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

  /// Which preset the checks point at, and why.
  ///
  /// A suggestion, filled in and still editable — the admin may have opened the
  /// documents and found a better reason than the one a rule inferred. Ordered
  /// by how specific the finding is: an expired document is a fact, a mismatch
  /// is a comparison, and an unreadable value is only ever a guess at blur.
  static ({String preset, String why})? _suggestPreset(RegistrationChecks? checks) {
    if (checks == null) return null;

    if (checks.firstFailing({'LicenseValidity', 'RegistrationValidity'})
        case final expired?) {
      return (preset: 'Expired ID', why: 'the ${expired.label} check failed');
    }

    if (checks.firstFailing({'NameMatch', 'PlateMatch', 'PlatePhotoMatch'})
        case final mismatch?) {
      return (
        preset: 'Mismatched information',
        why: 'the ${mismatch.label} check failed'
      );
    }

    // An identity value the applicant typed is a mismatch in substance: the
    // document and the account do not agree, we just never got to compare them.
    if (checks.edits.any((e) => e.isIdentity)) {
      return (
        preset: 'Mismatched information',
        why: 'an identity field was typed by the applicant'
      );
    }

    if (checks.unreadable > 0) {
      return (preset: 'Blurred document', why: 'a value could not be read');
    }

    return null;
  }

  Future<void> _showRejectDialog(
      BuildContext context, WidgetRef ref, RegistrationDetail detail) async {
    final suggestion = _suggestPreset(detail.checks);

    final reasonCtrl = TextEditingController(
        text: suggestion == null ? '' : _rejectPresets[suggestion.preset]);
    final hoursCtrl = TextEditingController(text: '24');
    final formKey = GlobalKey<FormState>();
    String? selectedPreset = suggestion?.preset;

    final result = await showDialog<({String reason, int hours})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Reject Registration'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedPreset,
                    decoration: InputDecoration(
                      labelText: 'Reason preset (optional)',
                      helperText: suggestion == null
                          ? null
                          : 'Chosen because ${suggestion.why}.',
                    ),
                    items: [
                      ..._rejectPresets.keys.map((label) =>
                          DropdownMenuItem(value: label, child: Text(label))),
                      const DropdownMenuItem(
                          value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (label) {
                      setState(() => selectedPreset = label);
                      if (label != null && label != 'Other') {
                        reasonCtrl.text = _rejectPresets[label]!;
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  TextFormField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rejection Reason',
                      helperText:
                          'Sent to the applicant by email — edit as needed.',
                    ),
                    maxLines: 3,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Reason is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  TextFormField(
                    controller: hoursCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cooldown (hours)',
                      helperText:
                          'How long before they may submit a new application.',
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
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: ctx.tokens.status.danger.solid),
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

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Rejected')));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(pendingRegistrationsProvider);
  }
}

// ── Detail view ──────────────────────────────────────────────────────────────

class _DetailView extends StatelessWidget {
  const _DetailView({required this.detail});

  final RegistrationDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A rejection is the one thing on this page that changes what the
        // reviewer should do next, so it sits above the record rather than
        // seventh in a list of fields where it previously hid.
        if (detail.rejectionReason case final reason?) ...[
          _RejectionBanner(
            reason: reason,
            count: detail.rejectionCount,
            canReapplyAt: detail.canReapplyAt,
          ),
          const SizedBox(height: AppSpacing.gutter),
        ],
        // What the checks found comes before the record they were run against.
        // The fields below are reference material; this is the part that tells
        // a reviewer where to spend their attention.
        if (detail.checks case final checks?) ...[
          ChecksVerdictBanner(checks: checks),
          const SizedBox(height: AppSpacing.gutter),
          if (checks.person case final person?) ...[
            CheckGroupCard(group: person),
            const SizedBox(height: AppSpacing.gutter),
          ],
          for (final group in checks.vehicles) ...[
            CheckGroupCard(group: group),
            const SizedBox(height: AppSpacing.gutter),
          ],
          if (checks.edits.isNotEmpty) ...[
            ValueEditsCard(edits: checks.edits),
            const SizedBox(height: AppSpacing.gutter),
          ],
        ],
        AppSectionCard(
          title: 'Status',
          icon: Icons.verified_outlined,
          child: AppFieldGrid(
            fields: [
              AppField(
                label: 'Account Status',
                child: StatusPill.of(detail.accountStatus,
                    intent: StatusIntents.user(detail.accountStatus)),
              ),
              AppField(
                label: 'Verification Status',
                child: StatusPill.of(detail.verificationStatus,
                    intent:
                        StatusIntents.registration(detail.verificationStatus)),
              ),
              AppField(
                  label: 'Registration Step', value: detail.registrationStep),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutter),
        AppSectionCard(
          title: 'Personal Information',
          icon: Icons.person_outline,
          child: AppFieldGrid(
            fields: [
              AppField(label: 'Full Name', value: detail.fullName, emphasis: true),
              AppField(label: 'Email', value: detail.email),
              AppField(label: 'Affiliation', value: detail.affiliation),
              // Blank for faculty and staff, who have no RAF — the affiliation
              // above is what tells the reviewer which of those this is.
              if (detail.studentNumber case final number?)
                AppField(label: 'Student Number', value: number),
              if (detail.section case final section?)
                AppField(label: 'Section', value: section),
              if (detail.enrollmentValidUntil case final until?)
                AppField(label: 'Enrolled Until', value: _fmt(until)),
            ],
          ),
        ),
        // One card per vehicle: a card holder may register several, and a single
        // card would silently show only the first.
        for (final (i, vehicle) in detail.vehicles.indexed) ...[
          const SizedBox(height: AppSpacing.gutter),
          AppSectionCard(
            title: detail.vehicles.length > 1
                ? 'Vehicle ${i + 1} of ${detail.vehicles.length}'
                : 'Vehicle Information',
            icon: Icons.directions_car_outlined,
            child: AppFieldGrid(
              fields: [
                AppField(
                  label: 'Plate Number',
                  value: vehicle.plateNumber ?? '—',
                  emphasis: true,
                ),
                AppField(label: 'Brand', value: vehicle.brand ?? '—'),
                AppField(label: 'Model', value: vehicle.model ?? '—'),
                AppField(
                    label: 'Vehicle Type', value: vehicle.vehicleType ?? '—'),
                AppField(label: 'Color', value: vehicle.color ?? '—'),
              ],
            ),
          ),
        ],
        if (detail.documents.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gutter),
          AppSectionCard(
            title: 'Uploaded Documents',
            subtitle: 'Open each one to check it against the details above.',
            icon: Icons.folder_outlined,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final doc in detail.documents) _DocumentTile(doc: doc),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({
    required this.reason,
    required this.count,
    required this.canReapplyAt,
  });

  final String reason;
  final int count;
  final DateTime? canReapplyAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.danger;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_bad_outlined, size: AppSizes.iconMd, color: c.fg),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 1
                      ? 'Previously rejected $count times'
                      : 'Previously rejected',
                  style: text.titleSmall?.copyWith(color: c.fg),
                ),
                const SizedBox(height: AppSpacing.labelGap),
                Text(reason, style: text.bodySmall?.copyWith(color: c.fg)),
                if (canReapplyAt case final at?)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.x2),
                    child: Text(
                      'Can reapply from ${_fmt(at)}',
                      style: text.labelSmall?.copyWith(color: c.fg),
                    ),
                  ),
              ],
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
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return ListTile(
      leading: Icon(Icons.insert_drive_file_outlined, color: t.text.secondary),
      title: Text(doc.type, style: text.titleSmall),
      subtitle: Text(
        doc.fileName,
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      ),
      trailing: AppRowAction(
        label: 'View',
        icon: Icons.visibility_outlined,
        onPressed: () => viewDocument(
          context,
          title: doc.type,
          fileName: doc.fileName,
          url: doc.filePath,
        ),
      ),
    );
  }
}
