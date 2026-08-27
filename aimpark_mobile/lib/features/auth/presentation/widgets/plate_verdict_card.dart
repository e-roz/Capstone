import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/scan_result.dart';

/// The plate, and how much confidence there is in it.
///
/// Given its own card because it is the one value nobody typed and the one the
/// gate depends on. The four outcomes read differently on purpose: agreement
/// needs no action, a near match or outright disagreement asks for a
/// photograph, and a missing reading says an admin will finish the job — none
/// of them is a dead end.
class PlateVerdictCard extends StatelessWidget {
  const PlateVerdictCard({
    super.key,
    required this.plate,
    required this.seenInPhoto,
    required this.agreement,
    required this.onRetakePhoto,
  });

  /// What the receipt said. Null when nothing was read.
  final String? plate;

  /// What the photo of the physical plate read.
  final String? seenInPhoto;

  final PlateAgreement agreement;

  /// Null while the form is submitting.
  final VoidCallback? onRetakePhoto;

  bool get _hasPlate => plate != null && plate!.isNotEmpty;

  /// Whether another photograph would actually change anything. There is no
  /// point offering a retake when the receipt itself produced no plate to
  /// compare against.
  bool get _retakeHelps =>
      agreement == PlateAgreement.differs ||
      agreement == PlateAgreement.nearMatch ||
      (agreement == PlateAgreement.notChecked && _hasPlate);

  ({StatusIntent intent, IconData icon, String note}) get _verdict =>
      switch (agreement) {
        PlateAgreement.agreed => (
            intent: StatusIntent.success,
            icon: Icons.verified_outlined,
            note: 'The plate on your receipt and the plate in your photo match.',
          ),
        PlateAgreement.nearMatch => (
            intent: StatusIntent.warning,
            icon: Icons.rule_outlined,
            note: 'Your receipt says $plate, and your photo reads $seenInPhoto '
                '— close, but not quite the same. Retake the plate photo if it '
                "wasn't clear, otherwise an admin will confirm it by hand.",
          ),
        PlateAgreement.differs => (
            intent: StatusIntent.danger,
            icon: Icons.report_problem_outlined,
            note: 'Your photo reads $seenInPhoto, which is not what the '
                'receipt says. Retake the plate photo, or an admin will check '
                'it by hand.',
          ),
        PlateAgreement.notChecked => (
            intent: StatusIntent.neutral,
            icon: Icons.help_outline,
            note: _hasPlate
                ? "We couldn't read the plate in your photo, so this is from "
                    'the receipt alone. An admin will confirm it.'
                : "We couldn't read a plate from your receipt. An admin will "
                    'add it before your account goes live.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final verdict = _verdict;
    final c = t.status.of(verdict.intent);

    return AppCard(
      borderColor: c.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plate number', style: context.text.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _hasPlate ? plate! : 'Not read',
            style: context.text.headlineLarge?.copyWith(
              letterSpacing: 2,
              color: _hasPlate ? t.text.primary : t.text.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(verdict.icon, size: 18, color: c.fg),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  verdict.note,
                  style: context.text.bodySmall?.copyWith(color: c.fg),
                ),
              ),
            ],
          ),
          if (_retakeHelps)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetakePhoto,
                child: const Text('Retake the plate photo'),
              ),
            ),
        ],
      ),
    );
  }
}
