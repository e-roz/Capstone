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
  // No default on purpose: the reason decides whether the card can ever be
  // used again, so it has to be a choice, not something left as it was.
  String? reason;

  return showDialog<RevokeRfidResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final chosen = reason;
        final blocks = chosen != null && RfidRevokeReasons.blocks(chosen);

        return AlertDialog(
          title: Text('Revoke card from $holderName'),
          content: SizedBox(
            width: ctx.dialogWidth(440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Choose a reason',
                  ),
                  items: [
                    for (final r in RfidRevokeReasons.selectable)
                      DropdownMenuItem(
                        value: r,
                        child: Text(RfidRevokeReasons.label(r)),
                      ),
                  ],
                  onChanged: (v) => setState(() => reason = v),
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
                if (chosen != null) ...[
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
                          ? 'This card will be blocked. It can never be given to '
                                'anyone again.'
                          : 'This card goes back to the free pool. You can give '
                                'it to another user.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: blocks
                            ? ctx.tokens.status.danger.fg
                            : ctx.tokens.status.success.fg,
                      ),
                    ),
                  ),
                ],
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
                backgroundColor: ctx.tokens.status.danger.solid,
              ),
              onPressed: chosen == null
                  ? null
                  : () => Navigator.pop(
                      ctx,
                      RevokeRfidResult(
                        chosen,
                        noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
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
