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
import '../widgets/expiry_card.dart';
import '../widgets/ui/ui.dart';
import '../widgets/user_actions.dart';
import '../widgets/user_history_tabs.dart';
import '../widgets/user_vehicle_card.dart';

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

class _UserDetailView extends ConsumerStatefulWidget {
  const _UserDetailView({required this.userId, required this.detail});

  final String userId;
  final RegistrationDetail detail;

  @override
  ConsumerState<_UserDetailView> createState() => _UserDetailViewState();
}

class _UserDetailViewState extends ConsumerState<_UserDetailView> {
  UserTab _tab = UserTab.overview;

  String get userId => widget.userId;
  RegistrationDetail get detail => widget.detail;

  @override
  Widget build(BuildContext context) {
    final overview = _overview(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UserHistoryHeader(
          userId: userId,
          selected: _tab,
          onSelect: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: AppSpacing.gutter),
        switch (_tab) {
          UserTab.overview => overview,
          UserTab.parking => UserParkingTab(userId: userId),
          UserTab.violations => UserViolationsTab(userId: userId),
          UserTab.incidents => UserIncidentsTab(userId: userId),
          UserTab.payments => UserPaymentsTab(userId: userId),
          UserTab.taps => UserTapsTab(userId: userId),
        },
      ],
    );
  }

  /// The account, vehicle, expiry and documents cards: what this page showed
  /// before it had tabs.
  Widget _overview(BuildContext context) {
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
        // Status, RFID and personal details were three cards holding two or
        // three fields each. They are one account summary now: the state of the
        // account as pills first, because that is what is checked first, then
        // the plain facts under them.
        AppSectionCard(
          title: 'Account',
          icon: Icons.verified_user_outlined,
          // RFID controls live here rather than in the page header: they act on
          // the card, not on the account, and mixing them into the same row as
          // Archive made a six-button header nobody could scan.
          actions: [
            if (!detail.isDeleted)
              Tooltip(
                message: cardBlockedReason ?? '',
                child: AppRowAction(
                  label: detail.rfidStatus == 'Revoked'
                      ? 'Assign & reinstate'
                      : detail.rfidTagId == null
                          ? 'Assign RFID'
                          : 'Reassign RFID',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x2,
                children: [
                  StatusPill(
                    label: 'Account: ${detail.accountStatus}',
                    intent: StatusIntents.user(detail.accountStatus),
                    icon: Icons.person_outline,
                  ),
                  StatusPill(
                    label: 'Verification: ${detail.verificationStatus}',
                    intent:
                        StatusIntents.registration(detail.verificationStatus),
                    icon: Icons.verified_outlined,
                  ),
                  StatusPill(
                    label: 'RFID: ${detail.rfidStatus}',
                    intent: StatusIntents.rfid(detail.rfidStatus),
                    icon: Icons.nfc,
                  ),
                  if (detail.isDeleted)
                    const StatusPill(
                      label: 'Archived',
                      intent: StatusIntent.neutral,
                      icon: Icons.archive_outlined,
                    ),
                  if (detail.isEBike)
                    const StatusPill(
                      label: 'E-bike owner',
                      intent: StatusIntent.accent,
                      icon: Icons.pedal_bike_outlined,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),
              AppFieldGrid(
                fields: [
                  AppField(label: 'Joined', value: _date(detail.createdAt)),
                  AppField(label: 'Affiliation', value: detail.affiliation),
                  if (detail.studentNumber case final number?)
                    AppField(label: 'Student number', value: number),
                  if (detail.section case final section?)
                    AppField(label: 'Section', value: section),
                  AppField(
                    label: 'RFID tag',
                    value: detail.rfidTagId ?? 'Not assigned',
                    emphasis: detail.rfidTagId != null,
                  ),
                  if (detail.rfidStatus == 'Suspended')
                    AppField(
                      label: 'Suspended until',
                      value: detail.rfidSuspendedUntil == null
                          ? 'Indefinite'
                          : _stamp(detail.rfidSuspendedUntil!),
                    ),
                  if (detail.rejectionReason case final reason?)
                    AppField(label: 'Rejection reason', value: reason),
                  if (detail.canReapplyAt case final at?)
                    AppField(label: 'Can reapply at', value: _stamp(at)),
                ],
              ),
              if (detail.rfidStatus == 'Revoked') ...[
                const SizedBox(height: AppSpacing.x3),
                Text(
                  'Revoked after 3 accountable violations. The card went back '
                  'to the pool. Assigning a card reinstates this user.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.tokens.text.secondary),
                ),
              ],
            ],
          ),
        ),
        // Vehicles come before the dates and photos: the plate is what is looked
        // up most, and the dates below belong to it.
        for (final (i, vehicle) in detail.vehicles.indexed) ...[
          const SizedBox(height: AppSpacing.gutter),
          UserVehicleCard(
            vehicle: vehicle,
            index: i,
            count: detail.vehicles.length,
          ),
        ],
        if (ExpiryCard.hasData(detail)) ...[
          const SizedBox(height: AppSpacing.gutter),
          ExpiryCard(detail: detail),
        ],
        if (detail.documents.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gutter),
          AppSectionCard(
            title: 'Uploaded documents',
            subtitle: '${detail.documents.length} '
                '${detail.documents.length == 1 ? 'file' : 'files'}',
            icon: Icons.folder_outlined,
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
            child: _DocumentGrid(documents: detail.documents),
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

/// The uploaded files as thumbnails. An e-bike's photos are its identity, and a
/// filename like "ebikephoto.jpg" says nothing about which one is which.
class _DocumentGrid extends StatelessWidget {
  const _DocumentGrid({required this.documents});

  final List<DocumentInfo> documents;

  @override
  Widget build(BuildContext context) {
    // "E-bike photo 1, 2, 3" rather than three identical captions.
    final totals = <String, int>{};
    for (final d in documents) {
      totals[d.type] = (totals[d.type] ?? 0) + 1;
    }
    final seen = <String, int>{};

    return Wrap(
      spacing: AppSpacing.x4,
      runSpacing: AppSpacing.x4,
      children: [
        for (final doc in documents)
          _DocumentThumb(
            doc: doc,
            caption: () {
              final n = seen[doc.type] = (seen[doc.type] ?? 0) + 1;
              final label = documentLabel(doc.type);
              return (totals[doc.type] ?? 1) > 1 ? '$label $n' : label;
            }(),
          ),
      ],
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  const _DocumentThumb({required this.doc, required this.caption});

  final DocumentInfo doc;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final placeholder = Center(
      child: Icon(
        isImageDocument(doc.fileName)
            ? Icons.image_not_supported_outlined
            : Icons.picture_as_pdf_outlined,
        color: t.text.secondary,
        size: AppSizes.iconLg,
      ),
    );

    return SizedBox(
      width: 170,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => viewDocument(
          context,
          title: caption,
          fileName: doc.fileName,
          url: doc.filePath,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 128,
              decoration: BoxDecoration(
                color: t.surface.muted,
                border: Border.all(color: t.border.subtle),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: isImageDocument(doc.fileName)
                  ? Image.network(
                      doc.filePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => placeholder,
                    )
                  : placeholder,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(caption, style: text.titleSmall),
            Text(
              _date(doc.uploadedAt),
              style: text.bodySmall?.copyWith(color: t.text.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
