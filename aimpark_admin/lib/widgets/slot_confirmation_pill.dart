import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'ui/ui.dart';

/// How firmly a session's bay is known.
///
/// A bay only counts as the driver's own when they said so in the app. Until
/// then it is the one the gate suggested, which is not proof of where they
/// parked. Saying so after they have left is still worth something, but less,
/// because it rests on memory rather than on where the car was standing.
enum SlotConfirmation {
  confirmed,
  late,
  none;

  static SlotConfirmation of({DateTime? confirmedAt, DateTime? exitTime}) {
    if (confirmedAt == null) return SlotConfirmation.none;
    if (exitTime != null && confirmedAt.isAfter(exitTime)) {
      return SlotConfirmation.late;
    }
    return SlotConfirmation.confirmed;
  }

  String get label => switch (this) {
        SlotConfirmation.confirmed => 'Confirmed',
        SlotConfirmation.late => 'Confirmed late',
        SlotConfirmation.none => 'Unconfirmed',
      };

  String get tooltip => switch (this) {
        SlotConfirmation.confirmed =>
          'The driver confirmed this bay in the app while parked.',
        SlotConfirmation.late =>
          'The driver confirmed this bay after leaving, from memory.',
        SlotConfirmation.none =>
          'The driver did not confirm. This is the bay the gate suggested.',
      };

  StatusIntent get intent => switch (this) {
        SlotConfirmation.confirmed => StatusIntent.success,
        SlotConfirmation.late => StatusIntent.info,
        SlotConfirmation.none => StatusIntent.warning,
      };
}

/// The small pill that says how firmly a session's bay is known.
class SlotConfirmationPill extends StatelessWidget {
  const SlotConfirmationPill({
    super.key,
    required this.confirmedAt,
    required this.exitTime,
  });

  final DateTime? confirmedAt;
  final DateTime? exitTime;

  @override
  Widget build(BuildContext context) {
    final state = SlotConfirmation.of(confirmedAt: confirmedAt, exitTime: exitTime);
    return Tooltip(
      message: state.tooltip,
      child: StatusPill.of(
        state.label,
        intent: state.intent,
        showDot: false,
        dense: true,
      ),
    );
  }
}
