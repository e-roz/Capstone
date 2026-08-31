import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/scan_result.dart';

/// The plate, and how much confidence there is in it.
///
/// Given its own card because it is the one value nobody typed and the one the
/// gate depends on. The four outcomes read differently on purpose: agreement
/// needs no action, a near match or outright disagreement asks for another
/// plate photograph, and a missing reading asks for another receipt — because
/// without a plate there is no vehicle, and without a vehicle the gate has
/// nothing to open for.
class PlateVerdictCard extends StatelessWidget {
  const PlateVerdictCard({
    super.key,
    required this.plate,
    required this.seenInPhoto,
    required this.agreement,
    required this.onRetakePhoto,
    required this.onRetakeReceipt,
  });

  /// What the receipt said. Null when nothing was read.
  final String? plate;

  /// What the photo of the physical plate read.
  final String? seenInPhoto;

  final PlateAgreement agreement;

  /// Null while the form is submitting.
  final VoidCallback? onRetakePhoto;

  /// Back to the receipt, which is where the plate is read from. Offered only
  /// when nothing was read: retaking the photo of the metal cannot supply a
  /// plate the receipt never gave.
  final VoidCallback? onRetakeReceipt;

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
                : "We couldn't read a plate from your receipt, and your vehicle "
                    "can't be registered without one. Photograph the receipt "
                    'again, keeping the plate number inside the frame. If it '
                    'still will not read after a few tries, you can add your '
                    'vehicle from My vehicles once your account is approved.',
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
          if (!_hasPlate)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetakeReceipt,
                child: const Text('Retake the receipt'),
              ),
            ),
        ],
      ),
    );
  }
}
