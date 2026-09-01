import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';
import '../models/rfid_card.dart';
import '../theme/theme.dart';

class RevokeRfidResult {
  final String reason;
  final String? note;

  const RevokeRfidResult(this.reason, this.note);
}

/// Asks why a card is coming off an account. The reason is not a formality —
/// it decides whether the physical card goes back into circulation or is
/// blocked from ever being reissued, so the dialog is upfront about which
/// each choice means.
///
/// Shared by the single-user Revoke action and the bulk revoke flow, so the
/// two can never disagree about what "Lost" does to a card.
Future<RevokeRfidResult?> showRevokeRfidDialog(
  BuildContext context, {
  required String holderName,
}) {
  final noteCtrl = TextEditingController();
  var reason = RfidRevokeReasons.graduated;

  return showDialog<RevokeRfidResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final blocks = RfidRevokeReasons.blocks(reason);

        return AlertDialog(
          title: Text('Revoke RFID tag from $holderName'),
          content: SizedBox(
            width: ctx.dialogWidth(440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: [
                    for (final r in RfidRevokeReasons.all)
                      DropdownMenuItem(
                          value: r, child: Text(RfidRevokeReasons.label(r))),
                  ],
                  onChanged: (v) => setState(() => reason = v ?? reason),
                ),
                const SizedBox(height: AppSpacing.x4),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    helperText: 'Recorded in the audit log alongside this action.',
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x3),
                  decoration: BoxDecoration(
                    color: blocks
                        ? ctx.tokens.status.danger.bg
                        : ctx.tokens.status.success.bg,
                    borderRadius: AppRadii.mdAll,
                  ),
                  child: Text(
                    blocks
                        ? 'This card will be blocked — it can never be reissued to '
                            'anyone, even after this revoke.'
                        : 'This card goes back into the free pool and can be '
                            'reissued to a different user.',
                    style: TextStyle(
                      fontSize: 12,
                      color: blocks
                          ? ctx.tokens.status.danger.fg
                          : ctx.tokens.status.success.fg,
                    ),
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
                  backgroundColor: ctx.tokens.status.danger.solid),
              onPressed: () => Navigator.pop(
                ctx,
                RevokeRfidResult(
                  reason,
                  noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                ),
              ),
              child: const Text('Revoke'),
            ),
          ],
        );
      },
    ),
  );
}
