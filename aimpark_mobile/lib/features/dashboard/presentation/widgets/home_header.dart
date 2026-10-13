import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Greeting, first name, the notifications bell and the avatar.
///
/// The bell is here, and not on a tab, because this is where a notification is
/// looked for: the unread count used to ride on the Account tab, where it read
/// as something wrong with the account.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.unreadCount,
    required this.onBell,
    required this.onAvatar,
  });

  final String name;
  final int unreadCount;
  final VoidCallback onBell;
  final VoidCallback onAvatar;

  /// Morning / afternoon / evening, on the device clock. Not a personalisation
  /// feature — it is what makes the name underneath read as a greeting rather
  /// than as a page title.
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// Just the given name. The full name pushed the avatar off a 360dp screen
  /// for anyone with three names, which in the Philippines is most people.
  String get _firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: context.text.bodySmall),
              Text(
                _firstName,
                style: context.text.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        AppBellButton(onTap: onBell, unreadCount: unreadCount),
        Semantics(
          button: true,
          label: 'Account',
          excludeSemantics: true,
          onTap: onAvatar,
          child: SizedBox(
            width: AppSizes.controlHeight,
            height: AppSizes.controlHeight,
            child: InkResponse(
              onTap: () {
                HapticFeedback.selectionClick();
                onAvatar();
              },
              radius: AppSizes.controlHeight / 2,
              child: Center(child: AppAvatar(name: name, size: 44)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mirrors [HomeHeader]'s layout so the row does not jump when the real name
/// lands.
class HomeHeaderSkeleton extends StatelessWidget {
  const HomeHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton.line(width: 96, height: 13),
              SizedBox(height: 6),
              AppSkeleton.line(width: 148, height: 22),
            ],
          ),
        ),
        const AppSkeleton(width: 44, height: 44, radius: AppRadius.full),
        const SizedBox(width: AppSpacing.xs),
        const AppSkeleton(width: 44, height: 44, radius: AppRadius.full),
      ],
    );
  }
}
