import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../router/registration_back_stack.dart';

/// What was sent, passed to the receipt screen.
///
/// Carried as go_router `extra` rather than in the path: a name and a plate are
/// personal data, and personal data does not belong in a URL — it ends up in
/// logs, in history, and in anything that records where the app has been.
class RegistrationSummary {
  const RegistrationSummary({
    this.name,
    this.email,
    this.affiliation,
    this.plateNumber,
  });

  final String? name;
  final String? email;
  final String? affiliation;
  final String? plateNumber;
}

/// The last screen of registration: what was submitted, and what happens now.
///
/// Registration used to end in a dialog and a redirect to sign-in, so the final
/// impression of a five-minute flow was a toast that vanished. Worse, the
/// dialog said "You're all set!" — which is not true. The account is not set
/// up; an application has been filed and a person has to approve it. Someone
/// who reads "all set" and drives to the gate finds out the hard way.
///
/// So this screen acknowledges the submission, which *is* an achievement, and
/// is precise about what it does and does not mean.
class RegistrationSubmittedScreen extends StatelessWidget {
  const RegistrationSubmittedScreen({super.key, this.summary});

  /// Null when the screen is reached without its payload — a process restore,
  /// most likely. The receipt then drops its summary rather than inventing one.
  final RegistrationSummary? summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = summary;

    final facts = <AppFact>[
      if (s?.name != null && s!.name!.isNotEmpty) AppFact('Name', s.name!),
      if (s?.email != null && s!.email!.isNotEmpty) AppFact('Email', s.email!),
      if (s?.affiliation != null && s!.affiliation!.isNotEmpty)
        AppFact('Affiliation', s.affiliation!),
      if (s?.plateNumber != null && s!.plateNumber!.isNotEmpty)
        AppFact('Vehicle', s.plateNumber!),
    ];

    return AppScreen(
      // Nothing to go back to. The registration token is spent and the flow's
      // history describes something that is over.
      showBack: false,
      body: ListView(
        padding: kScreenListPadding,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: SizedBox(
              height: 120,
              child: Image.asset(
                'assets/images/mascot_wave.png',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Application sent',
            textAlign: TextAlign.center,
            style: context.text.headlineLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'That is everything we need from you. The parking office reviews '
            'it next.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (facts.isNotEmpty) ...[
            AppFactsCard(title: 'What we have on file', facts: facts),
            const SizedBox(height: AppSpacing.gutter),
          ],
          AppCard(
            color: t.status.info.bg,
            borderColor: t.status.info.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT HAPPENS NEXT',
                  style: context.text.labelMedium?.copyWith(
                    color: t.status.info.fg,
                  ),
                ),
                const SizedBox(height: 6),
                // Stated plainly, because the difference between "submitted"
                // and "approved" is the difference between the gate opening
                // and not.
                Text(
                  'Your account is pending review, so you cannot park yet. '
                  'Sign in any time to check the status — we will tell you as '
                  'soon as a decision is recorded.',
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: AppBottomBar(
        child: AppButton(
          label: 'Go to sign in',
          onPressed: () {
            registrationBackStack.clear();
            context.go('/login/sign-in');
          },
        ),
      ),
    );
  }
}
