import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/update/update_dialog.dart';
import '../../../../core/update/update_provider.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/screens/terms_screen.dart';

/// A plain index of the things a user might need explained.
///
/// No search, no chat widget, no illustration. Four destinations is not enough
/// content to search, and a help screen that opens with a picture of someone
/// wearing a headset is promising a person who is not there.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  bool _checkingForUpdates = false;

  Future<void> _checkForUpdates() async {
    setState(() => _checkingForUpdates = true);

    final result = await ref
        .read(updateCheckerProvider.notifier)
        .checkManually();

    if (!mounted) return;
    setState(() => _checkingForUpdates = false);

    switch (result) {
      case ManualCheckUpToDate():
        showAppMessage(context, "You're on the latest version.");
      case ManualCheckOffer(offer: final offer):
        UpdateDialog.show(context, offer);
      case ManualCheckError(message: final message):
        showAppMessage(context, message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = ref.watch(appPackageInfoProvider);

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
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(title: 'About'),
          AppRowGroup(
            children: [
              AppListRow(
                title: 'App version',
                subtitle: packageInfo.when(
                  data: (info) => '${info.version} (build ${info.buildNumber})',
                  loading: () => '—',
                  error: (_, _) => '—',
                ),
                showChevron: false,
              ),
              AppListRow(
                title: 'Check for updates',
                trailing: _checkingForUpdates
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : null,
                onTap: _checkingForUpdates ? null : _checkForUpdates,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
