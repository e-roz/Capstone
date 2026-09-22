import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/screens/terms_screen.dart';

/// A plain index of the things a user might need explained.
///
/// No search, no chat widget, no illustration. Four destinations is not enough
/// content to search, and a help screen that opens with a picture of someone
/// wearing a headset is promising a person who is not there.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      body: ListView(
        padding: kScreenListPadding,
        children: [
          const AppScreenTitle(title: 'Help & support'),
          AppRowGroup(
            children: [
              AppListRow(
                title: 'How standing works',
                subtitle: 'Tiers, points and streaks explained',
                onTap: () => context.push('/home/user/standing'),
              ),
              AppListRow(
                title: 'Terms and conditions',
                subtitle: 'The parking terms you accepted at registration',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TermsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
