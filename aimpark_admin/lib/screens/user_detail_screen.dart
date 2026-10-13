import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/registration_detail.dart';
import '../providers/registrations_provider.dart';
import '../providers/users_provider.dart';
import '../theme/theme.dart';
import '../widgets/document_viewer.dart';
import '../widgets/ui/ui.dart';
import '../widgets/user_actions.dart';

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
        loading: const SkeletonDetail(sections: 3, fieldsPerSection: 3),
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

    // Mirrors the rule the API enforces on assign-rfid. A card sets RfidStatus
    // to Active, which is what the gate reads, so it only belongs to an account
    // somebody has actually approved. Disabled rather than hidden: a reviewer
    // looking for the button needs to be told why it will not work, not left
    // hunting for one that is no longer there.
    final cardBlockedReason = switch (detail.accountStatus) {
      'PendingReview' => 'Approve this registration first — assigning a '
          'card activates it at the gate.',
      'Rejected' => 'A rejected registration cannot be given a card.',
      // Revoked is final: three accountable violations cost the account.
      'Revoked' => 'This account has been revoked, so it cannot be given a '
          'card.',
      _ => null,
    };

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
              Tooltip(
                message: cardBlockedReason ?? '',
                child: AppRowAction(
                  label: detail.rfidStatus == 'Revoked'
                      ? 'Assign & reinstate'
                      : detail.rfidTagId == null
                          ? 'Assign'
                          : 'Reassign',
                  icon: Icons.nfc,
                  onPressed: cardBlockedReason != null
                      ? null
                      : () => actions.assignRfid(context),
                ),
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
              if (detail.rfidStatus == 'Revoked')
                const AppField(
                  label: 'Why',
                  value: 'Revoked after 3 accountable violations. The card '
                      'went back to the pool. Assigning a card reinstates '
                      'this user.',
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
            // Sits with the documents rather than up with the account controls:
            // it deletes these files and nothing else, and putting it beside
            // Archive would read as another way of removing the user.
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: AppSizes.iconSm),
                label: const Text('Delete images'),
                style: TextButton.styleFrom(
                    foregroundColor: context.tokens.status.danger.fg),
                onPressed: () => actions.deleteDocuments(context),
              ),
            ],
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

  /// Archive, restore and the card actions are shared with the
  /// Users list's row menu, so both ask the same questions.
  UserAccountActions get _shared => UserAccountActions(
        ref: ref,
        userId: userId,
        fullName: detail.fullName,
        rfidTagId: detail.rfidTagId,
      );

  Future<void> assignRfid(BuildContext context) => _shared.assignRfid(context);
  Future<void> revokeRfid(BuildContext context) => _shared.revokeRfid(context);
  Future<void> restore(BuildContext context) => _shared.restore(context);
  Future<void> archive(BuildContext context) => _shared.archive(context);

  /// Deletes the identity photographs and nothing else.
  ///
  /// Archiving retains everything, which is right for the parking records and
  /// wrong for these: an RAF, a licence and an OR carry a home address, a
  /// licence number and a signature, and the reason to hold them ends with the
  /// review they were uploaded for. Kept apart from Archive rather than folded
  /// into it, because archiving is undoable and this is not.
  Future<void> deleteDocuments(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ID Documents'),
        content: SizedBox(
          width: ctx.dialogWidth(420),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Permanently delete the uploaded ID photos for '
                    '${detail.fullName}, and the text read from them.'),
                const SizedBox(height: AppSpacing.x3),
                const Text(
                    'The account stays, and so do its violations, payments and '
                    'parking history. This cannot be undone — the images are '
                    'gone from storage.'),
                const SizedBox(height: AppSpacing.x4),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason (kept in the audit log)',
                    hintText: 'Requested by the user, retention period ended…',
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final reason = reasonCtrl.text.trim();
    final msg = await ref.read(userActionsProvider.notifier).deleteDocuments(
          userId,
          passwordCtrl.text,
          reason: reason.isEmpty ? null : reason,
        );
    if (!context.mounted) return;
    _done(context, msg ?? 'Documents deleted.');
  }

  void _done(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(userListProvider);
    // Assigning pulls a card out of the Free pool; revoking puts one back in
    // it. Either way the RFID Cards page's list is now stale.
    ref.invalidate(rfidCardsProvider);
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
