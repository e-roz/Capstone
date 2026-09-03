import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/widgets/image_picker_box.dart';
import '../../data/models/violation.dart';
import '../providers/violations_provider.dart';

class ViolationDetailScreen extends ConsumerWidget {
  const ViolationDetailScreen({super.key, required this.violationId});

  final String violationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      title: 'Violation Detail',
      body: AsyncView(
        value: ref.watch(violationDetailProvider(violationId)),
        onRefresh: () {
          ref.invalidate(violationDetailProvider(violationId));
          return ref.read(violationDetailProvider(violationId).future);
        },
        errorTitle: "Couldn't load this violation",
        data: (violation) => ListView(
          padding: kScreenListPadding,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          violation.policyRuleTitle,
                          style: context.text.headlineSmall,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppStatusBadge(
                        label: violation.displayStatus,
                        intent:
                            StatusIntents.violation(violation.displayStatus),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(violation.description, style: context.text.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  AppDetailRow(
                    label: 'Penalty',
                    value: Formatters.peso(violation.penaltyAmount),
                    // Only red while it is still owed. Colouring a settled fine
                    // as a problem is how a paid violation kept reading like an
                    // unpaid one.
                    intent: violation.isPayable
                        ? StatusIntent.danger
                        : StatusIntent.neutral,
                  ),
                  if (violation.isPaid)
                    AppDetailRow(
                      label: 'Paid',
                      value: violation.paidAt != null
                          ? Formatters.date(violation.paidAt!)
                          : 'Settled',
                      intent: StatusIntent.success,
                    )
                  else if (violation.isWaived)
                    const AppDetailRow(
                      label: 'Payment',
                      value: 'Waived',
                      intent: StatusIntent.info,
                    )
                  else if (violation.isPayable && violation.paymentDueAt != null)
                    AppDetailRow(
                      label: 'Due by',
                      value: Formatters.date(violation.paymentDueAt!),
                      intent: StatusIntent.warning,
                    ),
                  AppDetailRow(
                    label: 'Suspension',
                    value: violation.suspensionDays != null
                        ? '${violation.suspensionType} · '
                            '${violation.suspensionDays} day(s)'
                        : violation.suspensionType,
                  ),
                  AppDetailRow(
                    label: 'Issued',
                    value: Formatters.date(violation.createdAt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (violation.appealStatus != null)
              _AppealCard(violation: violation)
            else
              AppButton(
                label: 'Submit Appeal',
                style: AppButtonStyle.secondary,
                onPressed: () => _openAppealSheet(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppealSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AppealSheet(
        violationId: violationId,
        // The sheet's own context is gone by the time the celebration should
        // appear, so the screen's context is what gets it. Passing it in makes
        // that explicit rather than relying on a capture that reads like a bug.
        screenContext: context,
        ref: ref,
      ),
    );
  }
}

/// The appeal the user already submitted, and where it got to.
class _AppealCard extends StatelessWidget {
  const _AppealCard({required this.violation});

  final ViolationDetail violation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Appeal'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppStatusBadge(
                label: violation.appealStatus!,
                intent: StatusIntents.violation(violation.appealStatus!),
              ),
              if (violation.appealReasonText != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  violation.appealReasonText!,
                  style: context.text.bodyMedium,
                ),
              ],
              if (violation.appealEvidenceUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Evidence you submitted',
                  style: context.text.labelSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: violation.appealEvidenceUrls.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: AppRadius.smAll,
                      child: Image.network(
                        violation.appealEvidenceUrls[index],
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 90,
                          height: 90,
                          color: t.surface.muted,
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: t.text.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (violation.appealAdminNotes != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Admin notes', style: context.text.labelSmall),
                Text(
                  violation.appealAdminNotes!,
                  style: context.text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The appeal form.
///
/// A real `StatefulWidget` rather than the `StatefulBuilder` closure this used
/// to be: the reason controller was created inside the sheet builder and never
/// disposed, and the submitting flag lived in a local the builder captured.
class _AppealSheet extends StatefulWidget {
  const _AppealSheet({
    required this.violationId,
    required this.screenContext,
    required this.ref,
  });

  final String violationId;
  final BuildContext screenContext;
  final WidgetRef ref;

  @override
  State<_AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends State<_AppealSheet> {
  final _reason = TextEditingController();
  String? _photo1;
  String? _photo2;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      showAppMessage(context, 'Please enter a reason.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.ref.read(violationsRepositoryProvider).submitAppeal(
            widget.violationId,
            reason,
            evidencePaths: [?_photo1, ?_photo2],
          );
      widget.ref.invalidate(violationDetailProvider(widget.violationId));

      if (mounted) Navigator.of(context).pop();
      if (widget.screenContext.mounted) {
        await CelebrationDialog.show(
          widget.screenContext,
          title: 'Appeal Submitted',
          message: "We'll review it and update you soon.",
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        // Lifts the submit button clear of the keyboard while the reason field
        // is focused.
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Submit an Appeal', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Explain why you believe this violation was issued in error.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Your reason',
              controller: _reason,
              maxLines: 4,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.sentences,
              helperText: 'A photo, a permit or a receipt makes an appeal far '
                  'easier to decide.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Evidence (optional)', style: context.text.labelSmall),
            const SizedBox(height: AppSpacing.xs),
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
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Submit Appeal',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
