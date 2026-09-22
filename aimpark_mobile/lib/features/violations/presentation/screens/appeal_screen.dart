import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/widgets/image_picker_box.dart';
import '../../data/models/violation.dart';
import '../providers/violations_provider.dart';

/// Filing an appeal, as a screen rather than a bottom sheet.
///
/// It was a `showModalBottomSheet` with a four-line field and two photo boxes,
/// which put the one piece of writing in the app that actually decides
/// something into a panel half the screen tall with the keyboard over it. An
/// appeal is the user's only route back from a charge they think is wrong; it
/// deserves the whole screen.
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

  final _reason = TextEditingController();
  String? _photo1;
  String? _photo2;
  bool _wantsEvidence = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Drives the live counter and the submit button's enabled state.
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
    setState(() => _isSubmitting = true);
    try {
      await ref.read(violationsRepositoryProvider).submitAppeal(
            widget.violationId,
            _reason.text.trim(),
            evidencePaths: _wantsEvidence ? [?_photo1, ?_photo2] : const [],
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
      body: AsyncView(
        value: ref.watch(violationDetailProvider(widget.violationId)),
        errorTitle: "Couldn't load this violation",
        data: (violation) => ListView(
          padding: kScreenListPadding,
          children: [
            const AppScreenTitle(title: 'File an appeal'),
            _AppealingCard(violation: violation),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Explain your case',
              controller: _reason,
              maxLines: 5,
              maxLength: _maxLength,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.sentences,
              // The reason it cannot be sent, shown while it cannot be sent —
              // rather than a disabled button with no explanation, or an error
              // that only appears after a failed tap.
              helperText: _isValid
                  ? 'Ready to submit. $_length/$_maxLength'
                  : 'Add at least a sentence explaining what happened. '
                      '$_length/$_maxLength',
            ),
            const SizedBox(height: AppSpacing.md),
            _EvidenceToggle(
              value: _wantsEvidence,
              onChanged: _isSubmitting
                  ? null
                  : (v) => setState(() => _wantsEvidence = v),
            ),
            if (_wantsEvidence) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ImagePickerBox(
                      label: 'Photo 1',
                      imagePath: _photo1,
                      onImageSelected: (p) => setState(() => _photo1 = p),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ImagePickerBox(
                      label: 'Photo 2',
                      imagePath: _photo2,
                      onImageSelected: (p) => setState(() => _photo2 = p),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.xs),
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

/// What is being appealed, restated at the top so the user is not writing
/// about a violation they can no longer see.
class _AppealingCard extends StatelessWidget {
  const _AppealingCard({required this.violation});

  final ViolationDetail violation;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
        ],
      ),
    );
  }
}

/// An explicit opt-in, so the form is short for the common case.
///
/// Two empty photo boxes sitting open on every appeal implied evidence was
/// expected, and an appeal without a photo looked incomplete. Most appeals are
/// a sentence about a gate reading and nothing else.
class _EvidenceToggle extends StatelessWidget {
  const _EvidenceToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onChanged != null;

    return AppCard(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? t.brand.primary : t.surface.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? t.brand.primary : t.border.strong,
                width: 1.5,
              ),
            ),
            child: value
                ? Icon(Icons.check_rounded, size: 16, color: t.brand.onSolid)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'I have supporting evidence',
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Optional. Attach it only if it helps explain your case.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
