import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../router/registration_back_stack.dart';

/// First screen an unauthenticated user lands on. It deliberately carries no
/// form — just the brand and the two ways in, so the entry point reads as a
/// welcome rather than a gate. Credentials live one tap away in
/// [LoginScreen] at `/login/sign-in`.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.notice});

  /// Why the app is showing this screen rather than the one the user was on.
  ///
  /// Set when a session ended underneath them — an account archived by an
  /// admin, most of all. Without it the app simply reappeared at the start with
  /// everything signed out and no explanation, which reads as a crash.
  final ScreenNotice? notice;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // No app bar at all: there is nowhere to go back to from the first screen.
    return AppScreen.tab(
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand block sits in the upper third; the open space below it
                // is the point of the layout, so the spacers are weighted
                // rather than even.
                const Spacer(flex: 2),
                Center(
                  child: SizedBox(
                    height: 132,
                    child: Image.asset(
                      'assets/images/mascot_wave.png',
                      fit: BoxFit.contain,
                      // Decoration. Everything it conveys is also in the words
                      // underneath it.
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Find a parking spot in seconds',
                  textAlign: TextAlign.center,
                  style: context.text.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'No more circles. No more stress.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge?.copyWith(
                    color: t.text.secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Three claims, each one the app can actually keep.
                //
                // The spec this came from offered "Reserve your spot instantly"
                // and "Hassle-free payment and permits". Neither is true: the
                // app holds no slots — the slot screen says so outright — and
                // there is no permit concept anywhere in it. A welcome screen
                // is the worst place to promise a feature, because it is the
                // one screen a user reads before they can check.
                const _Benefit(
                  icon: Icons.sensors_rounded,
                  text: 'Live slot availability, updated as cars come and go',
                ),
                const SizedBox(height: AppSpacing.sm),
                const _Benefit(
                  icon: Icons.receipt_long_rounded,
                  text:
                      'Every fee itemised — see the hours and the rate '
                      'behind it',
                ),
                const SizedBox(height: AppSpacing.sm),
                const _Benefit(
                  icon: Icons.history_rounded,
                  text: 'A clear record of every session and violation',
                ),
                const Spacer(flex: 3),
                if (notice != null) ...[
                  AppNotice(message: notice!.message, intent: notice!.intent),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppButton(
                  label: 'Get started',
                  // The start of the flow, and where its back arrow leads home
                  // to: registration records the path it takes from here, so
                  // back walks the steps in reverse and the last of them
                  // returns to this screen.
                  onPressed: () => context.startRegistration('/register/email'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'I already have an account',
                  style: AppButtonStyle.ghost,
                  onPressed: () => context.go('/login/sign-in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One promise, with a glyph. Small enough that three of them read as a list
/// rather than as three cards competing with the buttons below.
class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizes.iconMd, color: t.brand.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
        ),
      ],
    );
  }
}
