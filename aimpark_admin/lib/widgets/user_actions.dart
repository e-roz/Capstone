import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/responsive.dart';
import '../providers/registrations_provider.dart';
import '../providers/users_provider.dart';
import '../theme/theme.dart';
import 'rfid_revoke_dialog.dart';
import 'rfid_scan_field.dart';

/// The account mutations, shared by the Users list's row menu and the User
/// Detail screen so the two can never ask different questions before doing
/// the same thing on the server.
class UserAccountActions {
  const UserAccountActions({
    required this.ref,
    required this.userId,
    required this.fullName,
    this.rfidTagId,
  });

  final WidgetRef ref;
  final String userId;
  final String fullName;

  /// The card the user holds now, if any. Prefills the assign dialog.
  final String? rfidTagId;

  Future<void> suspend(BuildContext context) async {
    final reason = await showSuspendDialog(context, holderName: fullName);
    if (reason == null || !context.mounted) return;

    final msg = await ref
        .read(userActionsProvider.notifier)
        .suspend(userId, reason: reason);
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

  Future<void> assignRfid(BuildContext context) async {
    final tagCtrl = TextEditingController(text: rfidTagId ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign RFID to $fullName'),
        content: SizedBox(
          width: ctx.dialogWidth(420),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: RfidScanField(controller: tagCtrl, userId: userId),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
    final result = await showRevokeRfidDialog(context, holderName: fullName);
    if (result == null || !context.mounted) return;

    final msg = await ref
        .read(userActionsProvider.notifier)
        .revokeRfid(userId, result.reason, result.note);
    if (!context.mounted) return;
    _done(context, msg ?? 'RFID tag revoked.');
  }

  Future<void> archive(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive user'),
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
                  'Archive $fullName? The account data is kept and can be '
                  'restored later, but they will not be able to log in.',
                ),
                const SizedBox(height: AppSpacing.x4),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm your admin password',
                  ),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.tokens.status.danger.solid,
            ),
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

  /// The snackbar is untinted on purpose: a red one after Archive read as
  /// "this failed", and the colour said nothing the message did not.
  void _done(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(userListProvider);
    // Assigning pulls a card out of the Free pool; revoking puts one back in
    // it. Either way the RFID Cards page's list is now stale.
    ref.invalidate(rfidCardsProvider);
  }
}

// ── Suspend dialog ───────────────────────────────────────────────────────────

/// Common reasons, offered so the audit log reads the same way from one admin
/// to the next. "Other" leans on the note.
const suspendReasons = [
  'Unpaid fines',
  'Misuse of card',
  'Documents under review',
  'Other',
];

/// Asks why an account is being suspended, and returns the single `reason`
/// string the suspend endpoint takes ("Reason: note"), or null on cancel.
///
/// The reason is required. A suspension stops a person parking, so the audit
/// log has to say why; the dialog used to let it through blank.
Future<String?> showSuspendDialog(
  BuildContext context, {
  required String holderName,
}) {
  final noteCtrl = TextEditingController();
  String? reason;
  String? error;

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Suspend $holderName'),
        content: SizedBox(
          width: ctx.dialogWidth(440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'They will not be able to sign in until you lift the '
                'suspension.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: ctx.tokens.text.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Choose a reason',
                  errorText: error,
                ),
                items: [
                  for (final r in suspendReasons)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => setState(() {
                  reason = v;
                  error = null;
                }),
              ),
              const SizedBox(height: AppSpacing.x4),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  helperText: 'Saved in the audit log with this action.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.tokens.status.warning.solid,
            ),
            onPressed: () {
              final chosen = reason;
              if (chosen == null) {
                setState(() => error = 'Choose a reason first.');
                return;
              }
              final note = noteCtrl.text.trim();
              Navigator.pop(ctx, note.isEmpty ? chosen : '$chosen: $note');
            },
            child: const Text('Suspend'),
          ),
        ],
      ),
    ),
  );
}
