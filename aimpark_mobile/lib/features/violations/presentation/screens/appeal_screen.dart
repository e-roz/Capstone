import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/violation.dart';
import '../providers/violations_provider.dart';

/// Filing an appeal, as a screen rather than a bottom sheet.
///
/// It was a `showModalBottomSheet` with a four-line field and two photo boxes,
/// which put the one piece of writing in the app that actually decides
/// something into a panel half the screen tall with the keyboard over it. An
/// appeal is the user's only route back from a charge they think is wrong; it
/// deserves the whole screen.
///
/// Built the same way as the incident report form — numbered steps, a Required
/// tag, a live counter, and a photo strip that takes up to five — so the two
/// forms the app asks people to write in behave alike.
class AppealScreen extends ConsumerStatefulWidget {
  const AppealScreen({super.key, required this.violationId});

  final String violationId;

  @override
  ConsumerState<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends ConsumerState<AppealScreen> {
  /// Long enough to be a sentence. A one-word appeal ("wrong") gives the
  /// reviewer nothing to decide on and comes back rejected, which wastes the
  /// user's one attempt — so the form asks for more before it will send.
  static const int _minLength = 20;
  static const int _maxLength = 600;

  /// The most the photos may weigh together. The server refuses any request over
  /// 10 MB in total, so this stops a little short of it.
  static const int _maxPhotoBytes = 9 * 1024 * 1024;

  /// The server takes five evidence files in all, photos and PDFs together, and
  /// refuses any one over 5 MB.
  static const int _maxFiles = 5;

  final _reason = TextEditingController();
  List<String> _photos = const [];
  List<String> _pdfs = const [];
  String? _photosError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Drives the submit button's enabled state.
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int get _length => _reason.text.trim().length;
  bool get _isValid => _length >= _minLength;

  Future<void> _submit() async {
    // Checked here, with the numbers, rather than letting the server refuse the
    // whole upload with an error that does not say which photo to drop.
    final files = [..._photos, ..._pdfs];
    final sizes = await Future.wait(files.map((p) => File(p).length()));
    final totalBytes = sizes.fold<int>(0, (sum, b) => sum + b);
    if (totalBytes > _maxPhotoBytes) {
      final mb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      if (mounted) {
        setState(() {
          _photosError = 'Your files add up to $mb MB, and the limit is 9 MB '
              'together. Remove one or two.';
        });
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(violationsRepositoryProvider).submitAppeal(
            widget.violationId,
            _reason.text.trim(),
            evidencePaths: files,
          );
      ref.invalidate(violationDetailProvider(widget.violationId));
      ref.read(violationsNotifierProvider.notifier).refresh();

      if (mounted) {
        // Replaces rather than stacks: going "back" from the receipt should
        // land on the violation, not on a form that has already been sent.
        context.pushReplacement(
          '/home/user/violations/${widget.violationId}/appeal-sent',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppScreen(
      title: 'File an appeal',
      body: AsyncView(
        value: ref.watch(violationDetailProvider(widget.violationId)),
        errorTitle: "Couldn't load this violation",
        data: (violation) => ListView(
          padding: kScreenListPadding,
          children: [
            _AppealingCard(violation: violation),
            const SizedBox(height: AppSpacing.lg),

            // ── 1 · The explanation ────────────────────────────────────────
            const AppFormSectionHeader(
              number: 1,
              title: 'Your explanation',
              requirement: FieldRequirement.required,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'What should the office know?',
              controller: _reason,
              hintText: 'Tell the office what happened. For example: the gate '
                  'misread my plate, or I was in a permitted bay.',
              maxLines: 5,
              maxLength: _maxLength,
              showCounter: true,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.sentences,
              // The reason it cannot be sent, shown while it cannot be sent —
              // rather than a disabled button with no explanation, or an error
              // that only appears after a failed tap.
              helperText: _isValid
                  ? null
                  : 'At least $_minLength characters, so the office has '
                      'something to decide on.',
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── 2 · Evidence ───────────────────────────────────────────────
            const AppFormSectionHeader(
              number: 2,
              title: 'Evidence',
              requirement: FieldRequirement.optional,
            ),
            const SizedBox(height: AppSpacing.md),
            AppPhotoStrip(
              paths: _photos,
              // Photos and PDFs share the server's five-file limit.
              max: _maxFiles - _pdfs.length,
              enabled: !_isSubmitting,
              errorText: _photosError,
              onChanged: (paths) => setState(() {
                _photos = paths;
                _photosError = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            AppPdfAttachments(
              paths: _pdfs,
              max: _maxFiles - _photos.length,
              enabled: !_isSubmitting,
              onChanged: (paths) => setState(() {
                _pdfs = paths;
                _photosError = null;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              color: t.surface.muted,
              borderColor: t.border.subtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WHAT HAPPENS NEXT', style: context.text.labelSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Your appeal goes to the parking office for review. The '
                    'violation stays open while it is under review, and you '
                    'will get a notification when a decision is made.',
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomBar: AppBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Submit appeal',
              isLoading: _isSubmitting,
              onPressed: _isValid && !_isSubmitting ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Cancel',
              style: AppButtonStyle.ghost,
              onPressed: _isSubmitting ? null : () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is being appealed, restated at the top so the user is not writing about a
/// violation they can no longer see — with the deadline, because it is the one
/// thing here that is running out.
class _AppealingCard extends StatelessWidget {
  const _AppealingCard({required this.violation});

  final ViolationDetail violation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final deadline = violation.appealDeadline;
    final urgency = deadline == null ? null : appealUrgency(deadline);
    final c = urgency == null ? null : t.status.of(urgency);

    return AppCard(
      borderColor: c?.border,
      edgeColor: c?.solid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APPEALING', style: context.text.labelSmall),
          const SizedBox(height: 6),
          Text(
            '${violation.policyRuleTitle} · '
            '${Formatters.peso(violation.penaltyAmount)}',
            style: context.text.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            Formatters.date(violation.createdAt),
            style: context.text.bodySmall,
          ),
          if (deadline != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: AppSizes.iconMd, color: c!.fg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${appealCountdown(deadline)} · by '
                    '${Formatters.date(deadline)}',
                    style: context.text.labelLarge?.copyWith(
                      color: c.fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
