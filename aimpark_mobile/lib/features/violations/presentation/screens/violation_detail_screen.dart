import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/celebration_dialog.dart';
import '../providers/violations_provider.dart';

class ViolationDetailScreen extends ConsumerWidget {
  const ViolationDetailScreen({super.key, required this.violationId});
  final String violationId;

  Future<void> _openAppealSheet(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Submit an Appeal', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Explain why you believe this violation was issued in error.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: reasonController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Your reason...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Submit Appeal',
                    isLoading: isSubmitting,
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final reason = reasonController.text.trim();
                            if (reason.isEmpty) {
                              showAppMessage(sheetContext, 'Please enter a reason.', isError: true);
                              return;
                            }
                            setSheetState(() => isSubmitting = true);
                            try {
                              await ref
                                  .read(violationsRepositoryProvider)
                                  .submitAppeal(violationId, reason);
                              ref.invalidate(violationDetailProvider(violationId));
                              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                              if (context.mounted) {
                                await CelebrationDialog.show(
                                  context,
                                  title: 'Appeal Submitted',
                                  message: "We'll review it and update you soon.",
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSubmitting = false);
                              if (sheetContext.mounted) {
                                showAppMessage(sheetContext, apiErrorMessage(e), isError: true);
                              }
                            }
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(violationDetailProvider(violationId));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('Violation Detail', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(violationDetailProvider(violationId)),
              child: const Text('Retry'),
            ),
          ),
          data: (violation) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(violation.policyRuleTitle, style: AppTextStyles.h3),
                          ),
                          AppBadge(label: violation.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(violation.description, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: AppSpacing.md),
                      _InfoRow(label: 'Penalty', value: '₱${violation.penaltyAmount.toStringAsFixed(2)}'),
                      _InfoRow(
                        label: 'Suspension',
                        value: violation.suspensionDays != null
                            ? '${violation.suspensionType} · ${violation.suspensionDays} day(s)'
                            : violation.suspensionType,
                      ),
                      _InfoRow(
                        label: 'Issued',
                        value:
                            '${violation.createdAt.month}/${violation.createdAt.day}/${violation.createdAt.year}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (violation.appealStatus != null) ...[
                  Text('Appeal', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBadge(label: violation.appealStatus!),
                        const SizedBox(height: AppSpacing.sm),
                        if (violation.appealReasonText != null)
                          Text(violation.appealReasonText!, style: AppTextStyles.bodyMedium),
                        if (violation.appealAdminNotes != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text('Admin notes', style: AppTextStyles.labelSmall),
                          Text(violation.appealAdminNotes!, style: AppTextStyles.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ] else
                  AppButton(
                    label: 'Submit Appeal',
                    style: AppButtonStyle.secondary,
                    onPressed: () => _openAppealSheet(context, ref),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
