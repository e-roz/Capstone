import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../router/registration_back_stack.dart';

/// The frame every registration step sits in: the mascot, where you are in the
/// five steps, and the step's own content beneath.
class RegistrationStepScaffold extends StatelessWidget {
  const RegistrationStepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.subStep,
    this.onBack,
    this.busy = false,
  });

  final int step;
  final String title;
  final Widget child;

  /// Position within a step that spans several screens, as "2 of 4".
  ///
  /// The document step is four screens long. Advancing the main bar four times
  /// would overstate how much of registration is done; saying nothing would
  /// leave someone on their third document with no idea how many are left.
  final String? subStep;

  /// Where this step's back arrow goes, when it is somewhere other than the
  /// screen the user came from.
  ///
  /// Left null by every step, and that is the point: back walks the flow's own
  /// history, so a step no longer has to work out how it was arrived at. The
  /// document step used to subtract one from its index and the profile step
  /// used to ask whether this was a revisit, and between them they made a loop
  /// no amount of pressing back could get out of.
  final VoidCallback? onBack;

  /// True while a request this step started is still running.
  ///
  /// Back is refused outright for the length of it — leaving mid-request would
  /// abandon photographs the server is part way through receiving, and the user
  /// would come back to no record of either.
  final bool busy;

  static const _totalSteps = 5;

  @override
  Widget build(BuildContext context) {
    final back = busy ? null : (onBack ?? () => context.registrationBack());

    final screen = AppScreen(
      title: title,
      showBack: back != null,
      onBack: back,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Image.asset('assets/images/owl_mascot.png', width: 64),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              subStep == null
                  ? 'Step $step of $_totalSteps'
                  : 'Step $step of $_totalSteps · $subStep',
              style: context.text.labelSmall
                  ?.copyWith(color: context.tokens.brand.subtleText),
            ),
            const SizedBox(height: AppSpacing.sm),
            StepProgressBar(currentStep: step, totalSteps: _totalSteps),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );

    // The hardware and gesture back is answered here rather than by the
    // Navigator, which has nothing to pop: every step is reached with `go`, so
    // the stack is one page deep however far into registration someone is.
    // Left to the platform, back closed the app from the middle of the flow.
    //
    // Never allowed to pop, then — the arrow, the gesture and the hardware
    // button all take the same recorded path back, and from the first step that
    // path leads out to the welcome screen. While a request is in flight there
    // is no path and the gesture does nothing, which is the one case where
    // swallowing it is right.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back?.call();
      },
      child: screen,
    );
  }
}

/// The heading pair at the top of a registration step: what this screen wants,
/// and one line saying why.
///
/// Six steps each wrote the same `Text` + `SizedBox(xs)` + muted `Text`, and
/// three of them had already drifted to a different gap.
class RegistrationStepHeading extends StatelessWidget {
  const RegistrationStepHeading({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.text.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: context.text.bodyMedium
                ?.copyWith(color: context.tokens.text.secondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
