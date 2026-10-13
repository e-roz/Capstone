import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme.dart';

/// How a live list is doing, as the badge beside its title says it.
enum LiveState {
  /// Refreshing on its own and the server is answering.
  live,

  /// The last refresh failed. The list on screen is the last one that loaded,
  /// so it must not look current.
  reconnecting,

  /// Not refreshing: the list is for a day that is over.
  paused,
}

/// Re-runs [onTick] every [every] while [enabled], and only while the page can
/// be seen: a browser tab in the background would otherwise poll the guard
/// post's server all day for nobody.
class LiveRefresh extends StatefulWidget {
  const LiveRefresh({
    super.key,
    required this.enabled,
    required this.onTick,
    required this.child,
    this.every = const Duration(seconds: 5),
  });

  final bool enabled;
  final VoidCallback onTick;
  final Duration every;
  final Widget child;

  @override
  State<LiveRefresh> createState() => _LiveRefreshState();
}

class _LiveRefreshState extends State<LiveRefresh> with WidgetsBindingObserver {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void didUpdateWidget(covariant LiveRefresh old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled || old.every != widget.every) _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (visible == _visible) return;
    _visible = visible;
    // Catch up the moment the tab comes back instead of waiting out the tick.
    if (visible && widget.enabled) widget.onTick();
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!widget.enabled || !_visible) return;
    _timer = Timer.periodic(widget.every, (_) => widget.onTick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The small pill beside a live page's title.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key, required this.state});

  final LiveState state;

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final (label, intent, icon) = switch (widget.state) {
      LiveState.live => ('Live', StatusIntent.success, null),
      LiveState.reconnecting => (
          'Reconnecting…',
          StatusIntent.warning,
          Icons.sync_problem_outlined,
        ),
      LiveState.paused => (
          'Not live',
          StatusIntent.neutral,
          Icons.pause_circle_outline,
        ),
    };
    final c = t.status.of(intent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.bg, borderRadius: AppRadii.fullAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.state == LiveState.live)
            FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.25).animate(_pulse),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: c.solid, shape: BoxShape.circle),
              ),
            )
          else
            Icon(icon, size: 13, color: c.fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: c.fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Remembers which rows a live list already had, so a row that turns up on a
/// refresh can be shown as new for a few seconds.
///
/// Mix into the screen's state, call [trackRows] with every list that loads,
/// and [forgetRows] when a filter or the page changes: a different list is not
/// "new" rows, and the first list on screen is not either.
mixin FreshRows<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const _lasts = Duration(seconds: 4);

  Set<String> freshIds = const {};
  Set<String>? _known;
  Timer? _clear;

  void forgetRows() {
    _known = null;
    _clear?.cancel();
    if (freshIds.isNotEmpty && mounted) setState(() => freshIds = const {});
  }

  void trackRows(Set<String> ids) {
    final known = _known;
    _known = ids;
    if (known == null) return;

    final added = ids.difference(known);
    if (added.isEmpty) return;

    setState(() => freshIds = {...freshIds, ...added});
    _clear?.cancel();
    _clear = Timer(_lasts, () {
      if (mounted) setState(() => freshIds = const {});
    });
  }

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }
}
