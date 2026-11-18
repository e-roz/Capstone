import 'dart:async';

import 'package:flutter/widgets.dart';

/// "45m", "1h 24m" or "2d 3h": how long a car has been in. Rounded down to
/// the minute, and never negative when the panel's clock runs behind.
String formatStay(Duration d) {
  if (d.isNegative) return '0m';
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
  final minutes = d.inMinutes.remainder(60);
  return d.inHours == 0 ? '${minutes}m' : '${d.inHours}h ${minutes}m';
}

/// How long since [since], counting up while it is on screen. Ends at [until]
/// instead, for a session that is over.
class TimeParked extends StatefulWidget {
  const TimeParked({super.key, required this.since, this.until, this.style});

  final DateTime since;
  final DateTime? until;
  final TextStyle? style;

  @override
  State<TimeParked> createState() => _TimeParkedState();
}

class _TimeParkedState extends State<TimeParked> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(TimeParked old) {
    super.didUpdateWidget(old);
    if ((old.until == null) != (widget.until == null)) _schedule();
  }

  // The label changes once a minute; a few seconds' lag is not worth more.
  void _schedule() {
    _tick?.cancel();
    _tick = widget.until != null
        ? null
        : Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        formatStay((widget.until ?? DateTime.now()).difference(widget.since)),
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: widget.style,
      );
}
