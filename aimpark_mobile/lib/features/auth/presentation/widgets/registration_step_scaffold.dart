import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';

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

  /// Where this step's back arrow goes, or null for a step there is no going
  /// back from.
  ///
  /// A callback rather than a flag, and this is the whole fix: every step is
  /// reached with `go`, so the Navigator stack is one page deep,
  /// `automaticallyImplyLeading` found nothing to pop and drew no arrow at all.
  /// The flow had no way back from any screen — a mistyped email could not be
  /// corrected from the OTP step, and the third document could not be revisited
  /// from the fourth.
  ///
  /// Steps that pass null are the ones where back would undo something already
  /// committed on the server: the first document screen sits behind a profile
  /// that has been submitted and an account that now exists.
  final VoidCallback? onBack;

  /// True while a request this step started is still running.
  ///
  /// Distinct from having no [onBack]: a step with nowhere to go back to lets
  /// the gesture leave the app, but a step waiting on an upload must swallow it
  /// — leaving mid-request would abandon photographs the server is part way
  /// through receiving, and the user would come back to no record of either.
  final bool busy;

  static const _totalSteps = 5;

  @override
  Widget build(BuildContext context) {
    final back = busy ? null : onBack;

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

    // The hardware and gesture back had the same problem the arrow did: with
    // nothing on the stack to pop, Android's back closed the app from the
    // middle of registration. Where there is a step behind, it now goes there.
    //
    // Where there is not, the platform default stands and back still leaves the
    // app. Swallowing it would be the more protective choice and the wrong one
    // — a back that does nothing at all reads as a frozen screen, and leaving
    // now costs nothing: the draft is on disk and the token names the step, so
    // the next launch comes back here.
    return PopScope(
      canPop: back == null && !busy,
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
