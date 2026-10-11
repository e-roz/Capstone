import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'app_count_badge.dart';

/// The notifications bell, with its unread count.
///
/// Sits in a screen header beside the avatar, so it matches the avatar's 44dp
/// disc; the tappable area around it is 48dp square, which is the control
/// height every other target in the app is built to.
///
/// The count is read out as part of the label ("Notifications, 3 unread"),
/// because the badge itself is a picture of a number and a screen reader will
/// not announce it on its own.
class AppBellButton extends StatelessWidget {
  const AppBellButton({super.key, required this.onTap, this.unreadCount = 0});

  final VoidCallback onTap;
  final int unreadCount;

  static const double _disc = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasUnread = unreadCount > 0;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: hasUnread
          ? 'Notifications, $unreadCount unread'
          : 'Notifications',
      onTap: onTap,
      child: SizedBox(
        width: AppSizes.controlHeight,
        height: AppSizes.controlHeight,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            radius: AppSizes.controlHeight / 2,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: _disc,
                    height: _disc,
                    decoration: BoxDecoration(
                      color: t.surface.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.border.normal),
                    ),
                    child: Icon(
                      hasUnread
                          ? Icons.notifications_rounded
                          : Icons.notifications_none_rounded,
                      size: AppSizes.iconLg,
                      color: t.text.primary,
                    ),
                  ),
                  if (hasUnread)
                    PositionedDirectional(
                      top: -4,
                      end: -4,
                      child: AppCountBadge(
                        count: unreadCount,
                        ringColor: t.surface.canvas,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
