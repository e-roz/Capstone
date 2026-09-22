import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// How much variety and length a password has.
///
/// This measures *composition*, not safety. A fifteen-character password made
/// of a dictionary word and some punctuation scores Strong here and would fall
/// to a real attack in seconds. The labels are worded with that in mind: the
/// meter says what it can see, and never tells anyone their password is secure.
enum PasswordStrength {
  weak,
  medium,
  strong;

  /// Length is deliberately one of the four tests rather than a gate in front
  /// of them, so a short password with good variety still reads as partway
  /// there instead of flat Weak.
  static PasswordStrength of(String password) {
    if (password.isEmpty) return weak;

    final met = [
      password.length >= 8,
      password.contains(RegExp(r'[A-Z]')),
      password.contains(RegExp(r'[0-9]')),
      password.contains(RegExp(r'[^A-Za-z0-9]')),
    ].where((v) => v).length;

    // Length alone can carry it: a long passphrase of plain words is stronger
    // in practice than a short string with a symbol bolted on, and refusing to
    // acknowledge that is how strength meters push people toward "P@ssw0rd".
    if (password.length >= 15 || met == 4) return strong;
    if (met >= 3 && password.length >= 10) return medium;
    return weak;
  }

  int get filledBars => switch (this) {
        PasswordStrength.weak => 1,
        PasswordStrength.medium => 2,
        PasswordStrength.strong => 3,
      };

  StatusIntent get intent => switch (this) {
        PasswordStrength.weak => StatusIntent.danger,
        PasswordStrength.medium => StatusIntent.warning,
        PasswordStrength.strong => StatusIntent.success,
      };

  String get label => switch (this) {
        PasswordStrength.weak => 'Weak',
        PasswordStrength.medium => 'Good',
        PasswordStrength.strong => 'Strong',
      };

  /// What to do about it, rather than just what it is.
  String get advice => switch (this) {
        PasswordStrength.weak =>
          'Add length, a capital, a number or a symbol.',
        PasswordStrength.medium => 'Longer is better than more symbols.',
        // Not "this password is secure" — the meter cannot know that.
        PasswordStrength.strong => 'Good length and variety.',
      };
}

/// Three bars and a line of text under a password field.
///
/// Advisory only. It does not gate submission: the account minimum is eight
/// characters and that is the server's rule to set, so a Weak password here
/// still goes through. The meter exists to nudge, not to refuse — a client that
/// enforces a stricter rule than the server leaves users unable to create the
/// password the API would have accepted, with nothing explaining why.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // Nothing typed yet: no bars, no verdict. An empty field is not weak, it is
    // empty, and marking it red before the first keystroke is just scolding.
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = PasswordStrength.of(password);
    final c = t.status.of(strength.intent);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.standard,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < strength.filledBars ? c.solid : t.surface.muted,
                      borderRadius: AppRadius.fullAll,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: strength.label,
                  style: context.text.labelSmall?.copyWith(color: c.fg),
                ),
                TextSpan(
                  text: ' — ${strength.advice}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
