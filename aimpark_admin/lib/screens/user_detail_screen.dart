import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/registration_detail.dart';
import '../providers/registrations_provider.dart';
import '../providers/users_provider.dart';
import '../theme/theme.dart';
import '../widgets/document_viewer.dart';
import '../widgets/ui/ui.dart';

String _date(DateTime dt) => DateFormat('MMM d, yyyy').format(dt.toLocal());
String _stamp(DateTime dt) =>
    DateFormat('MMM d, yyyy HH:mm').format(dt.toLocal());

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(registrationDetailProvider(userId));
    final detail = async.valueOrNull;

    return AppPage(
      title: detail?.fullName ?? 'User',
      subtitle: detail == null
          ? 'Account record.'
          : '${detail.affiliation} · ${detail.email}',
      scrollable: true,
      onBack: () => context.go('/users'),
      actions: [
        if (detail != null) ..._accountActions(context, ref, detail),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(registrationDetailProvider(userId)),
        ),
      ],
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(registrationDetailProvider(userId)),
        data: (detail) => _UserDetailView(userId: userId, detail: detail),
      ),
    );
  }

  /// The account-level controls. Which ones exist depends on the state the
  /// account is actually in, so an archived user never shows "Suspend".
  List<Widget> _accountActions(
      BuildContext context, WidgetRef ref, RegistrationDetail detail) {
    final t = context.tokens;
    final actions = _UserActions(userId: userId, detail: detail, ref: ref);

    if (detail.isDeleted) {
      return [
        FilledButton.icon(
          icon: const Icon(Icons.restore, size: AppSizes.iconSm),
          label: const Text('Restore'),
          onPressed: () => actions.restore(context),
        ),
      ];
    }

    return [
      if (detail.accountStatus == 'Active')
        OutlinedButton.icon(
          icon: const Icon(Icons.pause_circle_outline, size: AppSizes.iconSm),
          label: const Text('Suspend'),
          style: OutlinedButton.styleFrom(
            foregroundColor: t.status.warning.fg,
            side: BorderSide(color: t.status.warning.border),
          ),
          onPressed: () => actions.suspend(context),
        ),
      if (detail.accountStatus == 'Suspended')
        FilledButton.icon(
          icon: const Icon(Icons.play_circle_outline, size: AppSizes.iconSm),
          label: const Text('Unsuspend'),
          onPressed: () => actions.unsuspend(context),
        ),
      OutlinedButton.icon(
        icon: const Icon(Icons.archive_outlined, size: AppSizes.iconSm),
        label: const Text('Archive'),
        style: OutlinedButton.styleFrom(
          foregroundColor: t.status.danger.fg,
          side: BorderSide(color: t.status.danger.border),
        ),
        onPressed: () => actions.archive(context),
      ),
    ];
  }
}

class _UserDetailView extends ConsumerWidget {
  const _UserDetailView({required this.userId, required this.detail});

  final String userId;
  final RegistrationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _UserActions(userId: userId, detail: detail, ref: ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          title: 'Status',
          icon: Icons.verified_outlined,
          child: AppFieldGrid(
            fields: [
              AppField(
                label: 'Account Status',
                child: Wrap(
                  spacing: AppSpacing.controlGap,
                  runSpacing: AppSpacing.controlGap,
                  children: [
                    StatusPill.of(detail.accountStatus,
                        intent: StatusIntents.user(detail.accountStatus)),
                    if (detail.isDeleted)
                      const StatusPill.of('Archived',
                          intent: StatusIntent.neutral),
                  ],
                ),
              ),
              AppField(
                label: 'Verification Status',
                child: StatusPill.of(detail.verificationStatus,
                    intent:
                        StatusIntents.registration(detail.verificationStatus)),
              ),
              AppField(label: 'Joined', value: _date(detail.createdAt)),
              if (detail.rejectionReason case final reason?)
                AppField(label: 'Rejection Reason', value: reason),
              if (detail.canReapplyAt case final at?)
                AppField(label: 'Can Reapply At', value: _stamp(at)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutter),
        // RFID controls live on the RFID card rather than in the page header:
        // they act on the card, not on the account, and mixing them into the
        // same row as Archive made a six-button header nobody could scan.
        AppSectionCard(
          title: 'RFID Access',
          icon: Icons.nfc,
          actions: [
            if (!detail.isDeleted)
              AppRowAction(
                label: detail.rfidTagId == null ? 'Assign' : 'Reassign',
                icon: Icons.nfc,
                onPressed: () => actions.assignRfid(context),
              ),
            if (!detail.isDeleted && detail.rfidTagId != null)
              AppRowAction(
                label: 'Revoke',
                icon: Icons.block_outlined,
                intent: StatusIntent.danger,
                onPressed: () => actions.revokeRfid(context),
              ),
          ],
          child: AppFieldGrid(
            fields: [
              AppField(
                label: 'Tag ID',
                value: detail.rfidTagId ?? 'Not assigned',
                emphasis: detail.rfidTagId != null,
              ),
              AppField(
                label: 'Status',
                child: StatusPill.of(detail.rfidStatus,
                    intent: StatusIntents.rfid(detail.rfidStatus)),
              ),
              if (detail.rfidStatus == 'Suspended')
                AppField(
                  label: 'Suspended Until',
                  value: detail.rfidSuspendedUntil == null
                      ? 'Indefinite'
                      : _stamp(detail.rfidSuspendedUntil!),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutter),
        AppSectionCard(
          title: 'Personal Information',
          icon: Icons.person_outline,
          child: AppFieldGrid(
            fields: [
              AppField(label: 'Email', value: detail.email),
              AppField(label: 'Affiliation', value: detail.affiliation),
              if (detail.studentNumber case final number?)
                AppField(label: 'Student Number', value: number),
              if (detail.section case final section?)
                AppField(label: 'Section', value: section),
              if (detail.enrollmentValidUntil case final until?)
                AppField(label: 'Enrolled Until', value: _date(until)),
            ],
          ),
        ),
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
            icon: Icons.folder_outlined,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final doc in detail.documents)
                  _DocumentTile(doc: doc),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Actions ──────────────────────────────────────────────────────────────────

/// The account mutations, in one place so the page header and the RFID card
/// can both reach them without either owning the other's buttons.
class _UserActions {
  const _UserActions({
    required this.userId,
    required this.detail,
    required this.ref,
  });

  final String userId;
  final RegistrationDetail detail;
  final WidgetRef ref;

  Future<void> assignRfid(BuildContext context) async {
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
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'RFID Tag ID',
              helperText: 'Tap the card on a reader, or type the printed ID.',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Tag ID is required' : null,
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
    _done(context, msg ?? 'RFID tag assigned.');
  }

  Future<void> revokeRfid(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Revoke RFID Tag',
      message:
          'Revoke the RFID tag from ${detail.fullName}? They will no longer be '
          'able to use RFID entry/exit until a new tag is assigned.',
      confirmLabel: 'Revoke',
      danger: true,
    );
    if (!confirmed || !context.mounted) return;

    final msg = await ref.read(userActionsProvider.notifier).revokeRfid(userId);
    if (!context.mounted) return;
    _done(context, msg ?? 'RFID tag revoked.');
  }

  Future<void> suspend(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspend ${detail.fullName}'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              helperText: 'Recorded in the audit log alongside this action.',
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ctx.tokens.status.warning.solid),
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
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
    _done(context, msg ?? 'User suspended.');
  }

  Future<void> unsuspend(BuildContext context) async {
    final msg = await ref.read(userActionsProvider.notifier).unsuspend(userId);
    if (!context.mounted) return;
    _done(context, msg ?? 'User unsuspended.');
  }

  Future<void> restore(BuildContext context) async {
    final msg = await ref.read(userActionsProvider.notifier).restore(userId);
    if (!context.mounted) return;
    _done(context, msg ?? 'User restored.');
  }

  Future<void> archive(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive User'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Archive ${detail.fullName}? The account data will be retained '
                    'and can be restored later. The user will not be able to log in.'),
                const SizedBox(height: AppSpacing.x4),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Confirm your admin password'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password is required' : null,
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
            style: FilledButton.styleFrom(
                backgroundColor: ctx.tokens.status.danger.solid),
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
    _done(context, msg ?? 'User archived.');
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 420, child: Text(message)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: ctx.tokens.status.danger.solid)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _done(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(userListProvider);
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
