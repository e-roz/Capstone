import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';

/// The rule a violation cites, so a user can read it without leaving the app.
///
/// **The body text below is placeholder.** The app has no policy content: a
/// violation carries `policyRuleTitle` and nothing else — no code, no clause,
/// no wording. Until the parking office supplies the real text, this screen
/// says so on the screen itself rather than presenting a paraphrase as the
/// rule someone is being charged under.
///
/// That notice is the point of the screen existing at all in this state. A user
/// contesting a fine needs to know whether what they are reading is the actual
/// policy, and a plausible-looking paragraph with no such warning is worse than
/// no screen at all.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, this.ruleTitle});

  /// The rule named on the violation. Null when the screen is opened without
  /// one, in which case it falls back to a general heading.
  final String? ruleTitle;

  @override
  Widget build(BuildContext context) {
    final title = ruleTitle?.trim();
    final hasRule = title != null && title.isNotEmpty;

    return AppScreen(
      body: ListView(
        padding: kScreenListPadding,
        children: [
          const AppScreenTitle(title: 'Parking policy'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasRule ? title.toUpperCase() : 'GENERAL',
                  style: context.text.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sessions longer than the posted maximum for the slot type '
                  'are billed at the standard hourly rate for the full '
                  'duration, with a penalty applied to the excess period.',
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          AppNotice(
            title: 'Placeholder wording',
            message: 'This is not the official policy text. The parking office '
                'has not yet supplied the final wording, so do not rely on '
                'what is written above when contesting a violation — ask them '
                'directly.',
            intent: StatusIntent.warning,
          ),
        ],
      ),
    );
  }
}
