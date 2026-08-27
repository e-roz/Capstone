import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A pulsing placeholder standing in for content that hasn't arrived.
///
/// Used where showing a *shape* is more honest than showing a value. Home used
/// to read its three providers with `.valueOrNull` and no loading branch, so
/// the first frame after login greeted the user by no name, showed a 0-day
/// streak, 0 points, "Not Parked" and a Gold standing tier — a complete,
/// confident screen that was simply wrong, and then rearranged itself a moment
/// later. A skeleton says "this is loading" without asserting anything false.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadius.sm,
  });

  /// Convenience for a text-line placeholder — the height matches a body line
  /// so a skeleton row occupies the same space the real text will.
  const AppSkeleton.line({Key? key, required double width, double height = 14})
      : this(key: key, width: width, height: height, radius: AppRadius.full);

  /// A whole card's worth of placeholder.
  const AppSkeleton.block({Key? key, double height = 96})
      : this(
          key: key,
          width: double.infinity,
          height: height,
          radius: AppRadius.md,
        );

  final double width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      // Never fades to nothing — a placeholder that disappears entirely reads
      // as a rendering glitch rather than as loading.
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.tokens.surface.muted,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A skeleton shaped like an [AppListRow], for lists whose row height is known
/// before the data is.
///
/// Every list screen was showing a bare centred spinner while it loaded, which
/// tells the user nothing about what is coming. This tells them a list is.
class AppRowSkeleton extends StatelessWidget {
  const AppRowSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          const AppSkeleton.block(height: 72),
          if (i != count - 1) const SizedBox(height: AppSpacing.gutter),
        ],
      ],
    );
  }
}
