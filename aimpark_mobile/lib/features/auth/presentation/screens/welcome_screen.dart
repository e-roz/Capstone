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
                const Spacer(flex: 3),
                Text(
                  'AimPark',
                  textAlign: TextAlign.center,
                  style: context.text.displayLarge?.copyWith(
                    fontSize: 44,
                    height: 52 / 44,
                    color: t.brand.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Park smarter. Pay less.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge?.copyWith(
                    color: t.text.secondary,
                  ),
                ),
                const Spacer(flex: 5),
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
