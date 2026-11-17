import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';

/// How long the driver has been parked, as hh:mm:ss, ticking every second.
///
/// Only this small widget redraws each second, not the whole parking screen.
/// Hours keep counting past 24 (26:04:10), since a day-long stay is still one
/// stay. The time comes from the phone's clock, the same as the rest of the
/// session card.
class ParkedClock extends StatefulWidget {
  const ParkedClock({super.key, required this.entryTime});

  final DateTime entryTime;

  @override
  State<ParkedClock> createState() => _ParkedClockState();
}

class _ParkedClockState extends State<ParkedClock> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 01:23:45. A clock running slightly behind the gate shows 00:00:00, never
  /// a negative time.
  static String hms(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${_two(h)}:${_two(m)}:${_two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.entryTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Read out as words, not "zero one colon two three".
        Semantics(
          label: 'Parked for ${Formatters.duration(elapsed)}',
          excludeSemantics: true,
          child: Text(
            hms(elapsed),
            style: AppTypography.tabular(context.text.headlineMedium!),
          ),
        ),
        Text(
          'Since ${Formatters.time(widget.entryTime)}',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}
