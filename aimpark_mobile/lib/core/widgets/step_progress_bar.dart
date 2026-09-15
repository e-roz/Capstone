import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Numbered-circle stepper — a circle per step, connected by a line. Filled
/// with a checkmark once done, highlighted while current, muted while still
/// ahead.
///
/// Replaces a run of five thin, unlabelled pill segments. Those read as a
/// loading bar, not something to check your position against — five circles
/// with numbers say "you are here" the way a pill segment never could,
/// without needing a name squeezed onto each one (the screen's own title
/// already says "Documents", "Check your details"; five step names would not
/// fit a phone width anyway).
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
        children: [
          for (var i = 1; i <= totalSteps; i++) ...[
            _StepCircle(
              number: i,
              state: i < currentStep
                  ? _StepState.done
                  : i == currentStep
                      ? _StepState.current
                      : _StepState.upcoming,
            ),
            if (i != totalSteps)
              Expanded(
                child: AnimatedContainer(
                  duration: AppMotion.normal,
                  curve: AppMotion.standard,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i < currentStep ? t.brand.primary : t.surface.muted,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { done, current, upcoming }

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.number, required this.state});

  final int number;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final Color background;
    final Color border;
    final Color foreground;

    switch (state) {
      case _StepState.done:
        background = t.brand.primary;
        border = t.brand.primary;
        foreground = t.brand.onSolid;
      case _StepState.current:
        background = t.surface.card;
        border = t.brand.primary;
        foreground = t.brand.primary;
      case _StepState.upcoming:
        background = t.surface.muted;
        border = t.border.normal;
        foreground = t.text.secondary;
    }

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: border,
          width: state == _StepState.current ? 2 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: state == _StepState.done
          ? Icon(Icons.check, size: 16, color: foreground)
          : Text(
              '$number',
              style: context.text.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
