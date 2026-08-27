import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';

/// Where an Admin lands after signing in on a phone.
///
/// Administration is a desk job — reviewing documents, working a queue of
/// registrations, reading reports — and it lives in the web panel at
/// aim-park.web.app. There is no plan to build it twice.
///
/// This screen exists because an Admin *can* sign in here and has to land
/// somewhere. It replaces a 14-line placeholder that said "ADMIN DASHBOARD /
/// Coming soon", which promised a mobile admin app that is not coming and left
/// the reader with no idea where to actually go.
class AdminOnWebScreen extends ConsumerWidget {
  const AdminOnWebScreen({super.key});

  static const _panelUrl = 'aim-park.web.app';

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(authRepositoryProvider);

    try {
      await repo.logout();
    } catch (_) {
      // Clear the local session even if the server call fails.
    }
    await repo.clearToken();
    await repo.clearSessionToken();

    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    return AppScreen.tab(
      body: AppFormBody(
        maxWidth: 420,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.status.info.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.desktop_windows_rounded,
              size: 48,
              color: t.status.info.fg,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Admin lives on the web',
            textAlign: TextAlign.center,
            style: context.text.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reviewing registrations, documents and reports needs a bigger '
            'screen than this one. Sign in to the admin panel from a computer.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Shown as text rather than opened with a launcher: the panel needs a
          // desktop browser, so sending this phone to it would be a dead end.
          AppNotice(
            icon: Icons.language_rounded,
            title: _panelUrl,
            message: 'Open this on a computer to manage AimPark.',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Log out',
            style: AppButtonStyle.ghost,
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }
}
