import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'api_error_message.dart';

/// The app's transient message.
///
/// Errors carry an icon as well as a colour, because a red bar and a green bar
/// look the same to a large minority of users and this is often the only
/// feedback a failed action gets.
void showAppMessage(
  BuildContext context,
  String message, {
  bool isError = false,
  String? traceId,
}) {
  final t = context.tokens;
  final c = isError ? t.status.danger : t.status.success;

  Flushbar<void>(
    messageText: _MessageBody(message: message, traceId: traceId, fg: c.fg),
    icon: Icon(
      isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
      color: c.fg,
      size: AppSizes.iconLg,
    ),
    // Errors stay up longer: a failure usually says something the user has to
    // act on, where a success only confirms what they already did. Longer again
    // when there is a trace ID, which someone may be copying down.
    duration: Duration(seconds: isError ? (traceId == null ? 4 : 7) : 3),
    // Flattened against the surface rather than used raw. The status `bg`
    // tokens are a low-alpha wash of their hue — right for a tinted card
    // sitting on a known background, wrong for a bar floating over arbitrary
    // content, where the app bar's title showed straight through it.
    backgroundColor: Color.alphaBlend(c.bg, t.surface.overlay),
    borderColor: c.border,
    borderWidth: 1.5,
    // Cleared of the status bar *and* the app bar. At the old all-round 8 it
    // landed on top of the screen title and the back arrow.
    margin: EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + kToolbarHeight,
      left: AppSpacing.sm,
      right: AppSpacing.sm,
    ),
    padding: const EdgeInsets.all(AppSpacing.md),
    borderRadius: AppRadius.mdAll,
    flushbarPosition: FlushbarPosition.TOP,
    animationDuration: AppMotion.normal,
    // Tapping copies the trace ID, so a tester can paste it into a bug report
    // instead of transcribing forty characters off a screenshot.
    onTap: traceId == null
        ? null
        : (bar) {
            Clipboard.setData(ClipboardData(text: traceId));
            HapticFeedback.selectionClick();
            bar.dismiss();
          },
  ).show(context);
}

/// Shows the server's own wording, and its trace ID where it sent one.
void showApiError(BuildContext context, Object error) {
  final e = apiError(error);
  showAppMessage(context, e.message, isError: true, traceId: e.traceId);
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    required this.traceId,
    required this.fg,
  });

  final String message;
  final String? traceId;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: context.text.bodyMedium?.copyWith(color: fg)),
        if (traceId != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Trace $traceId — tap to copy',
            style: context.text.labelSmall?.copyWith(color: fg),
          ),
        ],
      ],
    );
  }
}
