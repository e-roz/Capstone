import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Indeterminate "sliding pill" loader from the AimPark splash design: a short
/// bright thumb sweeps across a translucent track, easing in and out at either
/// end, then restarts from the left.
///
/// Unlike Material's indeterminate [LinearProgressIndicator] the thumb keeps a
/// fixed length instead of stretching, which is what the comp specifies.
///
/// Defaults reproduce the splash spec (160x6 track, 40%-wide white thumb,
/// 1.4s cycle); pass [color]/[trackColor] to reuse it on light surfaces.
class AppLoadingBar extends StatefulWidget {
  const AppLoadingBar({
    super.key,
    this.width = 160.0,
    this.height = 6.0,
    this.color = Colors.white,
    this.trackColor,
    this.thumbFraction = 0.4,
    this.duration = const Duration(milliseconds: 1400),
  })  : assert(thumbFraction > 0 && thumbFraction <= 1),
        assert(width > 0),
        assert(height > 0);

  /// Overall track width.
  final double width;

  /// Track (and thumb) thickness.
  final double height;

  /// Thumb colour.
  final Color color;

  /// Track colour. Defaults to [color] at 35% opacity, per the design.
  final Color? trackColor;

  /// Thumb length as a fraction of [width].
  final double thumbFraction;

  /// Duration of one left-to-right sweep.
  final Duration duration;

  @override
  State<AppLoadingBar> createState() => _AppLoadingBarState();
}

class _AppLoadingBarState extends State<AppLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _progress;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();

    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant AppLoadingBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.duration != oldWidget.duration) {
      _controller
        ..duration = widget.duration
        ..repeat();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.full);
    final thumbWidth = widget.width * widget.thumbFraction;

    // The thumb starts fully off the left edge and exits fully off the right,
    // so it travels its own length plus the whole track.
    final travel = widget.width + thumbWidth;

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(
          color:
              widget.trackColor ?? widget.color.withValues(alpha: 0.35),
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    left: -thumbWidth + travel * _progress.value,
                    top: 0,
                    bottom: 0,
                    width: thumbWidth,
                    child: child!,
                  ),
                ],
              );
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: radius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
