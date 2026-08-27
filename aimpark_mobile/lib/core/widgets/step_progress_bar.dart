import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Segmented step indicator — one rounded pill per step, filled as the user
/// progresses. Reads as a lesson path rather than a smooth percentage bar,
/// matching the gamified register-flow feel.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  /// 1-indexed current step.
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      label: 'Step $currentStep of $totalSteps',
      child: Row(
        children: List.generate(totalSteps, (i) {
          final isComplete = i < currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i == totalSteps - 1 ? 0 : AppSpacing.xs,
              ),
              child: AnimatedContainer(
                duration: AppMotion.normal,
                curve: AppMotion.standard,
                height: 8,
                decoration: BoxDecoration(
                  color: isComplete ? t.brand.primary : t.surface.muted,
                  borderRadius: AppRadius.fullAll,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
